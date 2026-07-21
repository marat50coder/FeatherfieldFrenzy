// ignore_for_file: avoid_print

import 'dart:typed_data';

/// ⚠️ Keep the seed and constants below byte-for-byte identical to
/// `lib/hatchway/core/frenzy_cipher.dart`. Fietherfield Frenzy uses a
/// unique cipher family (FNV-1a keystream + position-keyed XOR) that
/// differs from every sibling project — do NOT port this file verbatim
/// to another app.
const List<int> _frenzySeed = <int>[
  0x46,
  0x69,
  0x65,
  0x54,
  0x68,
  0x72,
  0x2E,
  0x46,
  0x72,
  0x7A,
  0x39,
  0x37,
  0x71,
  0x2A,
  0x1B,
];

const int _fnvOffset = 0x811C9DC5;
const int _fnvPrime = 0x01000193;
const int _mask32 = 0xFFFFFFFF;
const int _mixConst = 0x85EBCA6B;
const int _goldenGamma = 0x9E3779B9;

int _seedState() {
  var state = _fnvOffset;
  for (final byte in _frenzySeed) {
    state = ((state ^ byte) * _fnvPrime) & _mask32;
  }
  for (var round = 0; round < 4; round++) {
    state = ((state ^ _goldenGamma) * _fnvPrime) & _mask32;
  }
  return state;
}

Uint8List _makeFrenzyKeystream(int length) {
  var state = _seedState();
  final result = Uint8List(length);
  for (var i = 0; i < length; i++) {
    state = (state ^ ((i * _mixConst) & _mask32)) & _mask32;
    state = (state * _fnvPrime) & _mask32;
    state = (((state >>> 11) | ((state << 21) & _mask32))) & _mask32;
    result[i] = (state ^ (state >>> 16)) & 0xFF;
  }
  return result;
}

List<int> foldFrenzy(String value) {
  final bytes = Uint8List.fromList(value.codeUnits);
  final stream = _makeFrenzyKeystream(bytes.length);
  return List<int>.generate(bytes.length, (i) {
    final mixed = (bytes[i] + stream[i] + (i * 41)) & 0xFF;
    return mixed ^ ((i * 61) & 0xFF);
  });
}

String unfoldFrenzy(List<int> encoded) {
  final stream = _makeFrenzyKeystream(encoded.length);
  return String.fromCharCodes(
    List<int>.generate(encoded.length, (i) {
      final xored = encoded[i] ^ ((i * 61) & 0xFF);
      return (xored - stream[i] - (i * 41)) & 0xFF;
    }),
  );
}

void main() {
  // Fietherfield Frenzy — real production credentials. After running, paste
  // each printed array into lib/hatchway/config/frenzy_gate_config.dart and
  // confirm the VERIFY line at the end matches.
  const values = <String, String>{
    'endpoint': 'https://featherfieldfrenzy.com/config.php',
    'privacy': 'https://featherfieldfrenzy.com/privacy-policy.html',
    'support': 'https://featherfieldfrenzy.com/support.html',
    'gcd': 'https://gcdsdk.appsflyer.com/install_data/v5.0/',
    'webkit': '605.1.15',
    'safari': '18.6',
    'safariTail': '604.1',
    'appsFlyerDevKey': 'N6ZJuLosa7PdPk2NzANkqd',
    'firebaseProjectNumber': '970361620296',
    'oneLinkHost': 'featherfieldfrenzy.onelink.me',
  };

  for (final entry in values.entries) {
    final encoded = foldFrenzy(entry.value);
    print('${entry.key}: <int>[${encoded.join(', ')}]');
    if (unfoldFrenzy(encoded) != entry.value) {
      throw StateError('Round-trip failed for ${entry.key}');
    }
  }
  print('VERIFY: all values round-tripped');
}
