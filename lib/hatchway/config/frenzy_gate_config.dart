import '../core/frenzy_cipher.dart';

/// ════════════════════════════════════════════════════════════
/// Fietherfield Frenzy — gray-flow credential vault.
/// ════════════════════════════════════════════════════════════
///
/// Every secret ships as an obfuscated byte array (never plaintext). The
/// cipher family (FNV-1a keystream + position-keyed XOR) is defined in
/// `lib/hatchway/core/frenzy_cipher.dart` — a different family than the
/// sibling app template uses, so the compiled bytes of decode() differ
/// project-to-project.
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
    110, 69, 202, 137, 202, 118, 231, 217, 6, 30, 60, 54, 145, 239, 197, 55,
    224, 189, 236, 182, 42, 2, 101, 246, 20, 171, 10, 212, 150, 26, 65, 4,
    174, 108, 56, 233, 90, 231, 134, 37, 43,
  ];
  // privacy: https://featherfieldfrenzy.com/privacy-policy.html
  static const List<int> _privacy = <int>[
    110, 69, 202, 137, 202, 118, 231, 217, 6, 30, 60, 54, 145, 239, 197, 55,
    224, 189, 236, 182, 42, 2, 101, 246, 20, 171, 10, 212, 150, 26, 65, 23,
    177, 113, 40, 225, 94, 80, 75, 61, 42, 164, 102, 65, 41, 216, 164, 193,
    165, 228,
  ];
  // support: https://featherfieldfrenzy.com/support.html
  static const List<int> _support = <int>[
    110, 69, 202, 137, 202, 118, 231, 217, 6, 30, 60, 54, 145, 239, 197, 55,
    224, 189, 236, 182, 42, 2, 101, 246, 20, 171, 10, 212, 150, 26, 65, 20,
    180, 110, 54, 147, 77, 173, 72, 37, 47, 167, 101,
  ];
  // AppsFlyer GCD base — safe endpoint, still routed through the cipher so
  // it never appears in a strings dump.
  static const List<int> _gcd = <int>[
    110, 69, 202, 137, 202, 118, 231, 217, 7, 28, 3, 55, 149, 229, 25, 12,
    231, 182, 231, 180, 48, 11, 101, 234, 216, 189, 75, 170, 86, 6, 128, 20,
    179, 121, 50, 150, 82, 189, 119, 49, 28, 225, 115, 111, 118, 218, 239,
  ];
  // User-Agent version fragments — unique per app (see gray_user_agent).
  // webkit: 605.1.15
  static const List<int> _webkit = <int>[60, 9, 11, 75, 8, 10, 229, 211];
  // safari: 18.6
  static const List<int> _safari = <int>[55, 1, 16, 179];
  // safariTail: 604.1
  static const List<int> _safariTail = <int>[60, 9, 10, 75, 8];
  // appsFlyerDevKey: N6ZJuLosa7PdPk2NzANkqd
  static const List<int> _appsFlyerKey = <int>[
    84, 7, 236, 175, 180, 104, 167, 29, 1, 40, 47, 6, 233, 229, 5, 31,
    145, 129, 194, 191, 61, 244,
  ];
  // firebaseProjectNumber: 970361620296
  static const List<int> _firebaseProject = <int>[
    63, 6, 22, 182, 245, 15, 254, 222, 80, 45, 84, 244,
  ];
  // OneLink is OPTIONAL — it must NEVER be part of the gate-enable check.
  // oneLinkHost: featherfieldfrenzy.onelink.me
  static const List<int> _oneLinkHost = <int>[
    108, 84, 231, 245, 199, 67, 162, 2, 25, 30, 11, 6, 151, 26, 208, 63,
    145, 201, 34, 187, 50, 247, 92, 243, 24, 165, 10, 170, 156,
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
