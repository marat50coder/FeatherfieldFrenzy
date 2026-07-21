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
  Timer? _metricsDebounce;
  Size? _lastMetricsSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Game music must never bleed into the gray WebView. It's normally
    // never started before MenuScreen, but be defensive: if the user comes
    // back to the app after a push while the game was foregrounded, we
    // definitely don't want a loop of `music.wav` under the web page.
    Audio.instance.stopMusic();
    _enterImmersive();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    _controller =
        WebViewController.fromPlatformCreationParams(
            params,
            onPermissionRequest: (request) => request.grant(),
          )
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.black)
          ..setUserAgent(widget.agent.userAgent)
          ..enableZoom(false)
          ..setNavigationDelegate(_navigation());
    if (_controller.platform is WebKitWebViewController) {
      (_controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }

    widget.signals.onDestination = (url) {
      final uri = Uri.tryParse(url);
      if (mounted && uri != null && uri.hasScheme) {
        _controller.loadRequest(uri);
      }
    };
    _networkSubscription = widget.probe.changes.listen((states) {
      if (states.every((state) => state == ConnectivityResult.none)) {
        // Connectivity is definitively gone — show offline immediately,
        // no DNS probe (a probe hangs for seconds while offline and lets
        // the WebView render its built-in error page first).
        _goOffline();
      }
    });

    if (widget.coldLaunch) {
      _settleColdViewport();
    } else {
      _viewportReady = true;
      _controller.loadRequest(Uri.parse(widget.url));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _settleColdViewport() async {
    _enterImmersive();
    // Let immersive mode settle in the phone's ACTUAL orientation before
    // WKWebView mounts, so it measures the correct viewport. We do NOT
    // force a landscape nudge here — that made a cold-start push link
    // open sideways and then flip. Any residual stretch is corrected
    // after load by the resize + single reload in onPageFinished, in the
    // current orientation.
    await Future<void>.delayed(const Duration(milliseconds: 280));
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
    // recalcs. Once metrics settle, force a single resize + re-assert
    // the inset CSS so the site reflows cleanly instead of jittering.
    final view = View.of(context);
    final size = view.physicalSize;
    final rotated =
        _lastMetricsSize != null &&
        ((_lastMetricsSize!.width < _lastMetricsSize!.height) !=
            (size.width < size.height));
    _lastMetricsSize = size;
    if (!rotated) return;
    _enterImmersive();
    _metricsDebounce?.cancel();
    _pokeReflow(const [40, 160, 320, 560, 850]);
  }

  void _pokeReflow(List<int> delaysMs) {
    for (final ms in delaysMs) {
      Timer(Duration(milliseconds: ms), () {
        if (!mounted) return;
        _controller
            .runJavaScript(
              'window.dispatchEvent(new Event("orientationchange"));'
              'window.dispatchEvent(new Event("resize"));'
              'if(window.visualViewport)'
              '  window.visualViewport.dispatchEvent(new Event("resize"));',
            )
            .catchError((_) {});
      });
    }
    // Re-assert viewport lock once things have settled.
    _metricsDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      _installSafeAreaSheet();
      _installPinchLock();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enterImmersive();
      _consumePending();
    }
  }

  Future<void> _consumePending() async {
    final value = await widget.safe.consumePushUrl();
    final uri = value == null ? null : Uri.tryParse(value);
    if (mounted && uri != null && uri.hasScheme) {
      await _controller.loadRequest(uri);
    }
  }

  NavigationDelegate _navigation() {
    return NavigationDelegate(
      onPageStarted: (url) {
        _lastMainUrl = url;
      },
      onPageFinished: (_) {
        _redirectAttempts = 0;
        _installSafeAreaSheet();
        _installPinchLock();
        _installTapGloss();
        _installKeyboardLift();
        _installInputFontFloor();
        _installInlineVideoWake();
        Future<void>.delayed(const Duration(milliseconds: 800), () async {
          if (!mounted) return;
          setState(() {});
          await _controller.runJavaScript(
            'window.dispatchEvent(new Event("resize"));'
            'window.visualViewport?.dispatchEvent(new Event("resize"));',
          );
          _installSafeAreaSheet();
          if (widget.coldLaunch && !_coldReloadIssued) {
            _coldReloadIssued = true;
            await _controller.reload();
          }
        });
      },
      onWebResourceError: (error) {
        // -999 = cancelled (a new navigation superseded this one).
        if (error.errorCode == -999) return;
        // WKWebView sometimes reports isForMainFrame as null for the main
        // navigation — treat null as main-frame so a real load failure
        // is never silently swallowed (that was leaving the app "frozen").
        final mainFrame = error.isForMainFrame ?? true;
        final lower = error.description.toLowerCase();
        final redirectLoop =
            error.errorCode == -1007 ||
            lower.contains('too_many_redirects') ||
            lower.contains('too many redirects');
        if (redirectLoop && _lastMainUrl != null && _redirectAttempts < 3) {
          _redirectAttempts++;
          _controller.loadRequest(Uri.parse(_lastMainUrl!));
          return;
        }
        if (!mainFrame) return;
        _showOfflineAfterProbe();
      },
      onNavigationRequest: (request) {
        final uri = Uri.tryParse(request.url);
        if (uri == null) return NavigationDecision.prevent;
        if (<String>{
          'http',
          'https',
          'about',
          'data',
          'blob',
        }.contains(uri.scheme)) {
          if (request.isMainFrame) _lastMainUrl = request.url;
          return NavigationDecision.navigate;
        }
        launchUrl(uri, mode: LaunchMode.externalApplication);
        return NavigationDecision.prevent;
      },
    );
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

  /// Overwrites the site's safe-area CSS variables to zero and locks
  /// the document edges against rubber-band overscroll. Never touches
  /// html/body horizontal padding — see webview_safe_area_injection.
  void _installSafeAreaSheet() {
    _controller.runJavaScript(r'''
(() => {
  const root = window;
  if (root.__ffrSafeSheetGuard) return;
  root.__ffrSafeSheetGuard = true;
  const sheetId = 'ffr-safe-sheet';
  const rules = [
    ':root{',
      '--safe-area-inset-top:0px!important;',
      '--safe-area-inset-right:0px!important;',
      '--safe-area-inset-bottom:0px!important;',
      '--safe-area-inset-left:0px!important;',
      '--sat:0px!important;--sar:0px!important;',
      '--sab:0px!important;--sal:0px!important;',
      '--safe-top:0px!important;--safe-right:0px!important;',
      '--safe-bottom:0px!important;--safe-left:0px!important;',
    '}',
    // Lock document edges: no rubber-band that would reveal the black
    // scaffold above/below the site. Makes the page feel native.
    'html,body{',
      'overscroll-behavior:none!important;',
      'overscroll-behavior-y:none!important;',
    '}'
  ].join('');
  const keyboardOpen = () => {
    const visual = root.visualViewport;
    return !!visual && visual.height < root.innerHeight * 0.75;
  };
  const apply = () => {
    if (keyboardOpen()) return;
    const host = document.head || document.documentElement;
    if (!host) return;
    let meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'viewport';
      meta.content = 'width=device-width, initial-scale=1, viewport-fit=contain';
      host.appendChild(meta);
    } else {
      const scrubbed = (meta.content || '')
        .replace(/,?\s*viewport-fit\s*=\s*\w+/ig, '').trim();
      meta.content = scrubbed + (scrubbed ? ', ' : '') + 'viewport-fit=contain';
    }
    let sheet = document.getElementById(sheetId);
    if (!sheet) {
      sheet = document.createElement('style');
      sheet.id = sheetId;
      host.appendChild(sheet);
    }
    sheet.textContent = rules;
  };
  const later = () => {
    root.setTimeout(apply, 170);
    root.setTimeout(apply, 640);
  };
  ['pushState', 'replaceState'].forEach((name) => {
    const original = history[name];
    history[name] = function () {
      const outcome = original.apply(this, arguments);
      later();
      return outcome;
    };
  });
  root.addEventListener('popstate', later);
  apply();
  root.setInterval(apply, 2900);
})();
''');
  }

  /// Locks the page at 1:1 scale — no pinch/double-tap/gesture zoom.
  /// Idempotent + re-asserts the viewport on SPA navigations.
  void _installPinchLock() {
    _controller.runJavaScript(r'''
(() => {
  if (window.__ffrPinchLockGuard) return;
  window.__ffrPinchLockGuard = true;
  const anchorViewport = () => {
    const host = document.head || document.documentElement;
    if (!host) return;
    let meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.setAttribute('name', 'viewport');
      host.appendChild(meta);
    }
    meta.setAttribute(
      'content',
      'width=device-width, initial-scale=1.0, maximum-scale=1.0, ' +
      'minimum-scale=1.0, user-scalable=no, viewport-fit=contain'
    );
  };
  anchorViewport();
  const swallow = (event) => { event.preventDefault(); };
  ['gesturestart', 'gesturechange', 'gestureend'].forEach((name) =>
    document.addEventListener(name, swallow, { passive: false })
  );
  document.addEventListener('touchmove', (event) => {
    if (event.scale !== undefined && event.scale !== 1) event.preventDefault();
  }, { passive: false });
  let previousTap = 0;
  document.addEventListener('touchend', (event) => {
    const now = Date.now();
    if (now - previousTap <= 300) event.preventDefault();
    previousTap = now;
  }, { passive: false });
  ['pushState', 'replaceState'].forEach((name) => {
    const original = history[name];
    history[name] = function () {
      const outcome = original.apply(this, arguments);
      setTimeout(anchorViewport, 150);
      return outcome;
    };
  });
  window.addEventListener('popstate', () => setTimeout(anchorViewport, 150));
})();
''');
  }

  /// Kills the grey tap highlight WKWebView paints on every tap and the
  /// long-press callout, so tapping elements feels native. Inputs still
  /// remain selectable.
  void _installTapGloss() {
    _controller.runJavaScript(r'''
(() => {
  if (window.__ffrTapGlossSuppressor) return;
  window.__ffrTapGlossSuppressor = true;
  const sheet = document.createElement('style');
  sheet.id = 'ffr-tap-gloss';
  sheet.textContent =
    '*{-webkit-tap-highlight-color:transparent!important;}' +
    '*:not(input):not(textarea):not([contenteditable="true"]){' +
      '-webkit-touch-callout:none!important;}';
  (document.head || document.documentElement).appendChild(sheet);
})();
''');
  }

  void _installKeyboardLift() {
    _controller.runJavaScript(r'''
(() => {
  if (window.__ffrKeyboardLift) return;
  window.__ffrKeyboardLift = true;
  const isEditable = (node) => !!node && (
    node.matches?.('input, textarea, select, [contenteditable="true"]')
  );
  const revealActive = () => {
    const focus = document.activeElement;
    if (!isEditable(focus)) return;
    focus.scrollIntoView({ behavior: 'auto', block: 'nearest' });
  };
  document.addEventListener('focusin', (event) => {
    if (isEditable(event.target)) window.setTimeout(revealActive, 350);
  }, true);
})();
''');
  }

  void _installInputFontFloor() {
    if (!Platform.isIOS) return;
    _controller.runJavaScript(r'''
(() => {
  if (window.__ffrInputFontFloor) return;
  window.__ffrInputFontFloor = true;
  const sheet = document.createElement('style');
  sheet.textContent =
    'input,textarea,select,[contenteditable="true"]{' +
      'font-size:max(16px,1em)!important;}';
  (document.head || document.documentElement).appendChild(sheet);
})();
''');
  }

  void _installInlineVideoWake() {
    _controller.runJavaScript(r'''
(() => {
  if (window.__ffrInlineVideoWake) return;
  window.__ffrInlineVideoWake = true;
  const wake = (video) => {
    if (!(video instanceof HTMLVideoElement)) return;
    video.setAttribute('playsinline', '');
    video.setAttribute('webkit-playsinline', '');
    video.playsInline = true;
    video.autoplay = true;
    const started = video.play();
    if (started?.catch) started.catch(() => {});
  };
  const sweep = (node) => {
    if (node instanceof HTMLVideoElement) wake(node);
    node.querySelectorAll?.('video').forEach(wake);
  };
  sweep(document);
  new MutationObserver((records) => {
    records.forEach((record) => record.addedNodes.forEach(sweep));
  }).observe(document.documentElement, { childList: true, subtree: true });
})();
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metricsDebounce?.cancel();
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
                // indicator (bottom) in BOTH orientations. Cold-start uses
                // viewPadding (never EdgeInsets.zero) so the bottom inset
                // is not lost while immersive mode settles.
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
