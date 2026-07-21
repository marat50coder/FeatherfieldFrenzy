import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/frenzy_gate_config.dart';
import '../infra/frenzy_safe.dart';
import '../infra/perch_signals.dart';

/// Push-permission invite. Handles OS dialog + cooldown so the invite
/// isn't spammed on every launch.
class PushInvitationPage extends StatefulWidget {
  const PushInvitationPage({
    super.key,
    required this.safe,
    required this.signals,
    required this.nextBuilder,
    this.onTokenReady,
  });

  final FrenzySafe safe;
  final PerchSignalHub signals;
  final WidgetBuilder nextBuilder;
  final Future<void> Function(String token)? onTokenReady;

  @override
  State<PushInvitationPage> createState() => _PushInvitationPageState();
}

class _PushInvitationPageState extends State<PushInvitationPage>
    with WidgetsBindingObserver {
  bool _working = false;

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
    // Splash locks portrait before routing here; re-enable landscape so
    // the invite rotates with the device (matches WebView orientation).
    SystemChrome.setPreferredOrientations(_allowedOrientations);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Same defensive rebuild as NoConnectionPage — see comment there.
    // Without this, rotating while the invite is on screen after a
    // route replacement can leave the invite artwork rendered at the
    // pre-rotation aspect (portrait content in a landscape window).
    if (!mounted) return;
    setState(() {});
    SystemChrome.setPreferredOrientations(_allowedOrientations);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations(_allowedOrientations);
    }
  }

  Future<void> _accept() async {
    if (_working) return;
    setState(() => _working = true);
    final granted = await widget.signals.askPermission();
    final token = widget.signals.token;
    if (granted && token != null && token.isNotEmpty) {
      await widget.onTokenReady?.call(token);
    }
    if (!granted) await _snooze();
    _continue();
  }

  Future<void> _skip() async {
    if (_working) return;
    setState(() => _working = true);
    await _snooze();
    _continue();
  }

  Future<void> _snooze() {
    final until =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        FrenzyGateConfig.pushSnoozeSeconds;
    return widget.safe.snoozePushInvite(until);
  }

  void _continue() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: widget.nextBuilder));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      // Orientation derived from actual Scaffold constraints, not from
      // MediaQuery — see NoConnectionPage.build for the reasoning.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final landscape = constraints.maxWidth > constraints.maxHeight;
          final background = landscape
              ? 'assets/Horizontal_Notifications_Screen.webp'
              : 'assets/Vertical_Notifications_Screen.webp';
          // Landscape button sizes are the portrait defaults ×0.85 so
          // they don't crowd the horizontal invite artwork.
          final width = landscape
              ? (constraints.maxWidth * 0.357).clamp(272.0, 476.0)
              : (constraints.maxWidth * 0.80).clamp(280.0, 440.0);
          final acceptH = landscape ? 56.0 : 74.0;
          final skipH = landscape ? 49.0 : 64.0;
          final acceptFont = landscape ? 18.7 : 25.0;
          final skipFont = landscape ? 17.0 : 22.0;

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.asset(
                background,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
              Align(
                alignment: Alignment(0, landscape ? 0.80 : 0.90),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    _InviteButton(
                      width: width,
                      height: acceptH,
                      fontSize: acceptFont,
                      label: 'Accept',
                      emphasized: true,
                      busy: _working,
                      onTap: _accept,
                    ),
                    SizedBox(height: landscape ? 12 : 16),
                    _InviteButton(
                      width: width * 0.9,
                      height: skipH,
                      fontSize: skipFont,
                      label: 'Skip',
                      emphasized: false,
                      busy: false,
                      onTap: _skip,
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

class _InviteButton extends StatelessWidget {
  const _InviteButton({
    required this.width,
    required this.height,
    required this.fontSize,
    required this.label,
    required this.emphasized,
    required this.busy,
    required this.onTap,
  });

  final double width;
  final double height;
  final double fontSize;
  final String label;
  final bool emphasized;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = height / 2;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            colors: emphasized
                ? const <Color>[Color(0xFFFFCF4A), Color(0xFFFF7D2C)]
                : const <Color>[Color(0xFFFFA63D), Color(0xFFD94A2A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: const Color(0xFF6E301B), width: 3),
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
            borderRadius: BorderRadius.circular(radius),
            onTap: busy ? null : onTap,
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: Color(0xFF4A2315),
                      ),
                    )
                  : Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF3D1C12),
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        height: 1.0,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
