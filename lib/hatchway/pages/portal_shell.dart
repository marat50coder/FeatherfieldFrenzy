import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../services/audio.dart';
import '../infra/flock_probe.dart';
import '../infra/frenzy_safe.dart';
import '../infra/perch_signals.dart';
import '../infra/plume_agent.dart';
import 'no_connection_page.dart';

// Ladder of reflow "pokes" (ms after a rotation) — WKWebView keeps the
// pre-rotation viewport for ~a second, so we dispatch a resize/
// orientationchange bounce a few times as the native frame settles.
const List<int> _reflowLadder = <int>[55, 205, 380, 640, 950];

// How long the cold-start viewport-settle delay is (ms). Immersive UI
// must actually engage before WKWebView measures the viewport, or the
// page renders stretched.
const int _coldSettleMs = 300;

// Debounce for the post-rotation "re-assert viewport lock" pass.
const int _postRotationMs = 340;

/// WebView shell for the gray flow. Handles cold-start viewport settle,
/// rotation reflow, orientation-aware safe-area, push deep-links and a
/// suite of native-feel JS injections.
class PortalShell extends StatefulWidget {
  const PortalShell({
    super.key,
    required this.url,
    required this.safe,
    required this.probe,
    required this.signals,
    required this.agent,
    this.coldLaunch = false,
  });

  final String url;
  final FrenzySafe safe;
  final FlockNetProbe probe;
  final PerchSignalHub signals;
  final PlumeAgent agent;
  final bool coldLaunch;

  @override
  State<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends State<PortalShell> with WidgetsBindingObserver {
  late final WebViewController _controller;
  StreamSubscription<List<ConnectivityResult>>? _networkSubscription;
  bool _viewportReady = false;
  bool _coldReloadIssued = false;
  bool _offlineShown = false;
  int _redirectAttempts = 0;
  String? _lastMainUrl;
  Timer? _lockDebounce;
  Size? _priorMetrics;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Game music must never bleed into the gray WebView. It's normally
    // never started before MenuScreen, but be defensive: if the user
    // came back to the app after a push while the game was foregrounded,
    // we definitely don't want a loop of `music.wav` under the web page.
    Audio.instance.stopMusic();

    _pinImmersive();
    _allowAllOrientations();
    _controller = _buildController();
    _wireExternalTriggers();

    if (widget.coldLaunch) {
      _settleColdViewport();
    } else {
      _viewportReady = true;
      _controller.loadRequest(Uri.parse(widget.url));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _drainPendingPush());
  }

  WebViewController _buildController() {
    final params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    final controller = WebViewController.fromPlatformCreationParams(
      params,
      onPermissionRequest: (request) => request.grant(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(widget.agent.userAgent)
      ..enableZoom(false)
      ..setNavigationDelegate(_navigation());
    if (controller.platform is WebKitWebViewController) {
      (controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }
    return controller;
  }

  void _wireExternalTriggers() {
    widget.signals.onDestination = (url) {
      final uri = Uri.tryParse(url);
      if (!mounted || uri == null || !uri.hasScheme) return;
      _controller.loadRequest(uri);
    };
    _networkSubscription = widget.probe.changes.listen(_onConnectivityEvent);
  }

  void _onConnectivityEvent(List<ConnectivityResult> states) {
    // Connectivity is definitively gone — show offline immediately,
    // no DNS probe (a probe hangs for seconds while offline and lets
    // the WebView render its built-in error page first).
    if (states.every((state) => state == ConnectivityResult.none)) {
      _goOffline();
    }
  }

  void _pinImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _allowAllOrientations() {
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _settleColdViewport() async {
    _pinImmersive();
    // Let immersive mode settle in the phone's ACTUAL orientation before
    // WKWebView mounts, so it measures the correct viewport. We do NOT
    // force a landscape nudge here — that made a cold-start push link
    // open sideways and then flip. Any residual stretch is corrected
    // after load by the resize + single reload in onPageFinished, in
    // the current orientation.
    await Future<void>.delayed(const Duration(milliseconds: _coldSettleMs));
    if (!mounted) return;
    setState(() => _viewportReady = true);
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    setState(() {});
    // On rotation the physical size flips. WKWebView can briefly render
    // at the pre-rotation viewport (stretched / "broken") until it
    // recalcs. Once metrics settle, force a resize/orientationchange
    // bounce and re-assert the inset CSS so the site reflows cleanly
    // instead of jittering.
    final size = View.of(context).physicalSize;
    final prior = _priorMetrics;
    _priorMetrics = size;
    if (prior == null) return;
    final rotated =
        (prior.width < prior.height) != (size.width < size.height);
    if (!rotated) return;
    _pinImmersive();
    _lockDebounce?.cancel();
    _kickReflow(_reflowLadder);
  }

  void _kickReflow(List<int> ladder) {
    for (final ms in ladder) {
      Timer(Duration(milliseconds: ms), () {
        if (!mounted) return;
        _controller
            .runJavaScript(
              'window.dispatchEvent(new Event("orientationchange"));'
              'window.dispatchEvent(new Event("resize"));'
              'window.visualViewport?.dispatchEvent(new Event("resize"));',
            )
            .catchError((_) {});
      });
    }
    _lockDebounce = Timer(const Duration(milliseconds: _postRotationMs), () {
      if (!mounted) return;
      _reassertSafeInsets();
      _reassertPinchLock();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _pinImmersive();
    _drainPendingPush();
  }

  Future<void> _drainPendingPush() async {
    final value = await widget.safe.consumePushUrl();
    final uri = value == null ? null : Uri.tryParse(value);
    if (!mounted || uri == null || !uri.hasScheme) return;
    await _controller.loadRequest(uri);
  }

  NavigationDelegate _navigation() {
    return NavigationDelegate(
      onPageStarted: (url) => _lastMainUrl = url,
      onPageFinished: (_) => _afterPageLoaded(),
      onWebResourceError: _onResourceError,
      onNavigationRequest: _onNavigationRequest,
    );
  }

  void _afterPageLoaded() {
    _redirectAttempts = 0;
    _reassertSafeInsets();
    _reassertPinchLock();
    _installTapGloss();
    _installKeyboardLift();
    _installInputFontFloor();
    _installInlineVideoWake();
    Future<void>.delayed(const Duration(milliseconds: 820), () async {
      if (!mounted) return;
      setState(() {});
      await _controller.runJavaScript(
        'window.dispatchEvent(new Event("resize"));'
        'window.visualViewport?.dispatchEvent(new Event("resize"));',
      );
      _reassertSafeInsets();
      if (widget.coldLaunch && !_coldReloadIssued) {
        _coldReloadIssued = true;
        await _controller.reload();
      }
    });
  }

  void _onResourceError(WebResourceError error) {
    // -999 = cancelled (a new navigation superseded this one).
    if (error.errorCode == -999) return;
    // WKWebView sometimes reports isForMainFrame as null for the main
    // navigation — treat null as main-frame so a real load failure is
    // never silently swallowed (that was leaving the app "frozen").
    final mainFrame = error.isForMainFrame ?? true;
    final desc = error.description.toLowerCase();
    final loopedRedirect = error.errorCode == -1007 ||
        desc.contains('too_many_redirects') ||
        desc.contains('too many redirects');
    if (loopedRedirect && _lastMainUrl != null && _redirectAttempts < 3) {
      _redirectAttempts++;
      _controller.loadRequest(Uri.parse(_lastMainUrl!));
      return;
    }
    if (!mainFrame) return;
    _showOfflineAfterProbe();
  }

  FutureOr<NavigationDecision> _onNavigationRequest(
    NavigationRequest request,
  ) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    const inlineSchemes = <String>{'http', 'https', 'about', 'data', 'blob'};
    if (inlineSchemes.contains(uri.scheme)) {
      if (request.isMainFrame) _lastMainUrl = request.url;
      return NavigationDecision.navigate;
    }
    launchUrl(uri, mode: LaunchMode.externalApplication);
    return NavigationDecision.prevent;
  }

  Future<void> _showOfflineAfterProbe() async {
    if (_offlineShown) return;
    var online = true;
    try {
      online = await widget.probe.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (online) return;
    _goOffline();
  }

  Future<void> _goOffline() async {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    String current;
    try {
      current = await _controller.currentUrl() ?? widget.url;
    } catch (_) {
      current = widget.url;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NoConnectionPage(
          probe: widget.probe,
          retryBuilder: (_) => PortalShell(
            url: current,
            safe: widget.safe,
            probe: widget.probe,
            signals: widget.signals,
            agent: widget.agent,
          ),
        ),
      ),
    );
  }

  /// Zeros the site's own safe-area CSS variables and locks the document
  /// edges against rubber-band overscroll. Never touches html/body
  /// horizontal padding (see `webview_safe_area_injection`).
  void _reassertSafeInsets() {
    _controller.runJavaScript(r'''
(function(root){
  if (root['__fzyPortalX_safeSheet']) return;
  root['__fzyPortalX_safeSheet'] = true;
  var STYLE_ID = 'fzy-safe-sheet';
  var CSS = ''
    + ':root{'
    +   '--safe-area-inset-top:0px!important;'
    +   '--safe-area-inset-right:0px!important;'
    +   '--safe-area-inset-bottom:0px!important;'
    +   '--safe-area-inset-left:0px!important;'
    +   '--sat:0px!important;--sar:0px!important;'
    +   '--sab:0px!important;--sal:0px!important;'
    +   '--safe-top:0px!important;--safe-right:0px!important;'
    +   '--safe-bottom:0px!important;--safe-left:0px!important;'
    + '}'
    // Lock document edges: no rubber-band that would reveal the black
    // scaffold above/below the site. Makes the page feel native.
    + 'html,body{'
    +   'overscroll-behavior:none!important;'
    +   'overscroll-behavior-y:none!important;'
    + '}';

  function kbUp(){
    var vv = root.visualViewport;
    if (!vv) return false;
    return vv.height < root.innerHeight * 0.75;
  }

  function ensureViewportMeta(host){
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta){
      meta = document.createElement('meta');
      meta.name = 'viewport';
      meta.content = 'width=device-width, initial-scale=1, viewport-fit=contain';
      host.appendChild(meta);
      return;
    }
    var cleaned = (meta.content || '')
      .replace(/,?\s*viewport-fit\s*=\s*\w+/ig, '')
      .trim();
    meta.content = cleaned + (cleaned ? ', ' : '') + 'viewport-fit=contain';
  }

  function attachSheet(host){
    var sheet = document.getElementById(STYLE_ID);
    if (!sheet){
      sheet = document.createElement('style');
      sheet.id = STYLE_ID;
      host.appendChild(sheet);
    }
    sheet.textContent = CSS;
  }

  function apply(){
    if (kbUp()) return;
    var host = document.head || document.documentElement;
    if (!host) return;
    ensureViewportMeta(host);
    attachSheet(host);
  }

  function reschedule(){
    root.setTimeout(apply, 175);
    root.setTimeout(apply, 660);
  }

  var wrapHistory = function(name){
    var original = history[name];
    if (!original) return;
    history[name] = function(){
      var out = original.apply(this, arguments);
      reschedule();
      return out;
    };
  };
  wrapHistory('pushState');
  wrapHistory('replaceState');
  root.addEventListener('popstate', reschedule);

  apply();
  root.setInterval(apply, 2950);
})(window);
''');
  }

  /// Locks the page at 1:1 scale — no pinch / double-tap / gesture zoom.
  /// Idempotent + re-asserts the viewport on SPA navigations.
  void _reassertPinchLock() {
    _controller.runJavaScript(r'''
(function(win, doc){
  if (win['__fzyPortalX_pinchLock']) return;
  win['__fzyPortalX_pinchLock'] = true;

  var VIEWPORT_CONTENT =
    'width=device-width, initial-scale=1.0, maximum-scale=1.0, '
    + 'minimum-scale=1.0, user-scalable=no, viewport-fit=contain';

  function anchor(){
    var host = doc.head || doc.documentElement;
    if (!host) return;
    var meta = doc.querySelector('meta[name="viewport"]');
    if (!meta){
      meta = doc.createElement('meta');
      meta.setAttribute('name', 'viewport');
      host.appendChild(meta);
    }
    meta.setAttribute('content', VIEWPORT_CONTENT);
  }
  anchor();

  var swallow = function(ev){ ev.preventDefault(); };
  var gestureEvents = ['gesturestart', 'gesturechange', 'gestureend'];
  for (var i = 0; i < gestureEvents.length; i++){
    doc.addEventListener(gestureEvents[i], swallow, { passive: false });
  }

  doc.addEventListener('touchmove', function(ev){
    if (ev.scale !== undefined && ev.scale !== 1) ev.preventDefault();
  }, { passive: false });

  var priorTap = 0;
  doc.addEventListener('touchend', function(ev){
    var now = Date.now();
    if (now - priorTap <= 305) ev.preventDefault();
    priorTap = now;
  }, { passive: false });

  ['pushState', 'replaceState'].forEach(function(name){
    var original = history[name];
    if (!original) return;
    history[name] = function(){
      var out = original.apply(this, arguments);
      win.setTimeout(anchor, 155);
      return out;
    };
  });
  win.addEventListener('popstate', function(){ win.setTimeout(anchor, 155); });
})(window, document);
''');
  }

  /// Kills the grey tap-highlight WKWebView paints on every tap and the
  /// long-press callout — inputs stay selectable.
  void _installTapGloss() {
    _controller.runJavaScript(r'''
(function(){
  if (window['__fzyPortalX_tapGloss']) return;
  window['__fzyPortalX_tapGloss'] = true;
  var host = document.head || document.documentElement;
  if (!host) return;
  var sheet = document.createElement('style');
  sheet.id = 'fzy-tap-gloss';
  sheet.textContent =
    '*{-webkit-tap-highlight-color:transparent!important;}'
    + '*:not(input):not(textarea):not([contenteditable="true"]){'
    +   '-webkit-touch-callout:none!important;'
    + '}';
  host.appendChild(sheet);
})();
''');
  }

  void _installKeyboardLift() {
    _controller.runJavaScript(r'''
(function(win, doc){
  if (win['__fzyPortalX_kbLift']) return;
  win['__fzyPortalX_kbLift'] = true;

  function isEditable(node){
    return !!node && typeof node.matches === 'function'
      && node.matches('input, textarea, select, [contenteditable="true"]');
  }

  function reveal(){
    var target = doc.activeElement;
    if (!isEditable(target)) return;
    target.scrollIntoView({ behavior: 'auto', block: 'nearest' });
  }

  doc.addEventListener('focusin', function(ev){
    if (!isEditable(ev.target)) return;
    win.setTimeout(reveal, 360);
  }, true);
})(window, document);
''');
  }

  void _installInputFontFloor() {
    if (!Platform.isIOS) return;
    _controller.runJavaScript(r'''
(function(){
  if (window['__fzyPortalX_fontFloor']) return;
  window['__fzyPortalX_fontFloor'] = true;
  var host = document.head || document.documentElement;
  if (!host) return;
  var sheet = document.createElement('style');
  sheet.id = 'fzy-font-floor';
  sheet.textContent =
    'input,textarea,select,[contenteditable="true"]{'
    + 'font-size:max(16px,1em)!important;'
    + '}';
  host.appendChild(sheet);
})();
''');
  }

  void _installInlineVideoWake() {
    _controller.runJavaScript(r'''
(function(doc){
  if (window['__fzyPortalX_videoWake']) return;
  window['__fzyPortalX_videoWake'] = true;

  function wake(video){
    if (!(video instanceof HTMLVideoElement)) return;
    video.setAttribute('playsinline', '');
    video.setAttribute('webkit-playsinline', '');
    video.playsInline = true;
    video.autoplay = true;
    var promise = video.play();
    if (promise && typeof promise.then === 'function'){
      promise.catch(function(){});
    }
  }

  function walk(root){
    if (root instanceof HTMLVideoElement) wake(root);
    if (root && typeof root.querySelectorAll === 'function'){
      var found = root.querySelectorAll('video');
      for (var i = 0; i < found.length; i++) wake(found[i]);
    }
  }

  walk(doc);

  var observer = new MutationObserver(function(records){
    for (var r = 0; r < records.length; r++){
      var added = records[r].addedNodes;
      for (var n = 0; n < added.length; n++) walk(added[n]);
    }
  });
  observer.observe(doc.documentElement, { childList: true, subtree: true });
})(document);
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lockDebounce?.cancel();
    _networkSubscription?.cancel();
    widget.signals.onDestination = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).viewPadding;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _controller.canGoBack()) {
          await _controller.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: _viewportReady
            ? Padding(
                // Respect notch/Dynamic Island (top + sides) AND the home
                // indicator (bottom) in BOTH orientations. Cold-start
                // uses viewPadding (never EdgeInsets.zero) so the bottom
                // inset is not lost while immersive mode settles.
                padding: EdgeInsets.only(
                  top: safe.top,
                  bottom: safe.bottom,
                  left: safe.left,
                  right: safe.right,
                ),
                child: WebViewWidget(controller: _controller),
              )
            : const ColoredBox(color: Colors.black),
      ),
    );
  }
}
