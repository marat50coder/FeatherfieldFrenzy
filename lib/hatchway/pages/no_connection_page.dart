import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../infra/flock_probe.dart';

/// Offline screen. Retry re-runs the whole pipeline by pushing a fresh
/// `retryBuilder` widget using THIS page's own (mounted) context — never
/// a captured parent context, which would be defunct after
/// pushReplacement.
class NoConnectionPage extends StatefulWidget {
  const NoConnectionPage({
    super.key,
    required this.probe,
    required this.retryBuilder,
  });

  final FlockNetProbe probe;
  final WidgetBuilder retryBuilder;

  @override
  State<NoConnectionPage> createState() => _NoConnectionPageState();
}

class _NoConnectionPageState extends State<NoConnectionPage>
    with WidgetsBindingObserver {
  bool _checking = false;
  bool _stillOffline = false;

  static const List<DeviceOrientation> _allowedOrientations =
      <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Allow landscape so the offline artwork rotates (splash locks
    // portrait right before routing here).
    SystemChrome.setPreferredOrientations(_allowedOrientations);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Forces a rebuild whenever the UIWindow reports a new size (rotation,
    // keyboard, screen-split on iPad, DisplayZoom toggle). Without this
    // the Scaffold could hang onto a stale MediaQuery snapshot after a
    // pushReplacement done concurrently with a device rotation, and
    // render its background at the pre-rotation size — visible as a
    // portrait-sized offline artwork occupying the LEFT half of a
    // landscape screen while the right half stays black.
    if (!mounted) return;
    setState(() {});
    // Nudge iOS in case it missed the rotation because the transition
    // absorbed the trait-change event. Cheap no-op if orientations were
    // already applied.
    SystemChrome.setPreferredOrientations(_allowedOrientations);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations(_allowedOrientations);
    }
  }

  Future<void> _retry() async {
    if (_checking) return;
    HapticFeedback.lightImpact();
    setState(() {
      _checking = true;
      _stillOffline = false;
    });
    var online = false;
    try {
      online = await widget.probe.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (!mounted) return;
    if (online) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: widget.retryBuilder),
      );
      return;
    }
    setState(() {
      _checking = false;
      _stillOffline = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      // LayoutBuilder — NOT MediaQuery — decides orientation and sizing.
      // MediaQuery.orientation can lag one frame behind the real Scaffold
      // constraints when a rotation happens together with a route change
      // (pushReplacement during a system-triggered event like Wi-Fi
      // toggle). Constraint-based logic always matches what we actually
      // render into, so the background never renders at the wrong aspect.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final landscape = constraints.maxWidth > constraints.maxHeight;
          final background = landscape
              ? 'assets/Horizontal_Nowifi_Screen.webp'
              : 'assets/Vertical_Nowifi_Screen.webp';
          final width = landscape
              ? (constraints.maxWidth * 0.40).clamp(300.0, 520.0)
              : (constraints.maxWidth * 0.66).clamp(260.0, 420.0);
          final height = landscape ? 70.0 : 74.0;
          final align = landscape
              ? const Alignment(0, 0.82)
              : const Alignment(0, 0.80);

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.asset(
                background,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
              Align(
                alignment: align,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    _RetryButton(
                      width: width,
                      height: height,
                      busy: _checking,
                      onTap: _retry,
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      child: _stillOffline
                          ? const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                'No connection yet',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  shadows: <Shadow>[
                                    Shadow(
                                      color: Colors.black,
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({
    required this.width,
    required this.height,
    required this.busy,
    required this.onTap,
  });

  final double width;
  final double height;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFFFCC45), Color(0xFFFF762D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: const Color(0xFF61301C), width: 3),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black45,
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(34),
            onTap: busy ? null : onTap,
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.8,
                        color: Color(0xFF422014),
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.refresh_rounded,
                          color: Color(0xFF422014),
                          size: 28,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Retry',
                          style: TextStyle(
                            color: Color(0xFF422014),
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
