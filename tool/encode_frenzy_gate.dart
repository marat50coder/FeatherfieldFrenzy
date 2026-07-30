// ignore_for_file: avoid_print

import 'dart:typed_data';

/// ⚠️ Keep the seed and every mixing constant below byte-for-byte
/// identical to `lib/hatchway/core/frenzy_cipher.dart`. Fietherfield
/// Frenzy runs a **XorShift32 keystream + nibble-swap** cipher which is
/// unique to this app — no FNV loop, no RC4 S-box, no shared constants
/// with any sibling project. Do NOT port this file verbatim to another
/// app.
const List<int> _frenzySeed = <int>[
  0x66,
  0x7A,
  0x2D,
  0x6E,
  0x37,
  0x39,
  0x2A,
  0x50,
  0x72,
  0x74,
  0x21,
  0x35,
  0x1D,
  0x62,
  0x4C,
  0x33,
  0x5F,
];

const int _u32 = 0xFFFFFFFF;

const int _pumpA = 0x85EBCA6B;
const int _pumpB = 0xC2B2AE35;

const int _quadPhase = 47;
const int _quadStep = 13;
const int _finalStep = 89;
const int _finalBias = 17;

int _forgeSeed() {
  var acc = 0;
  for (final byte in _frenzySeed) {
    acc = ((acc << 5) - acc + byte) & _u32;
  }
  acc ^= acc >>> 16;
  acc = (acc * _pumpA) & _u32;
  acc ^= acc >>> 13;
  acc = (acc * _pumpB) & _u32;
  acc ^= acc >>> 16;
  return acc == 0 ? 0x9E3779B1 : acc;
}

Uint8List _weaveKeystream(int length) {
  var state = _forgeSeed();
  final stream = Uint8List(length);
  for (var i = 0; i < length; i++) {
    state = (state ^ ((state << 13) & _u32)) & _u32;
    state = state ^ (state >>> 17);
    state = (state ^ ((state << 5) & _u32)) & _u32;
    stream[i] = (state ^ (state >>> 8) ^ (state >>> 16) ^ (state >>> 24)) & 0xFF;
  }
  return stream;
}

int _flipNibbles(int byte) => (((byte & 0x0F) << 4) | ((byte & 0xF0) >>> 4));

List<int> foldFrenzy(String value) {
  final bytes = Uint8List.fromList(value.codeUnits);
  final stream = _weaveKeystream(bytes.length);
  return List<int>.generate(bytes.length, (i) {
    final shifted = (bytes[i] + ((i * i * _quadStep + _quadPhase) & 0xFF)) & 0xFF;
    final swapped = _flipNibbles(shifted);
    final xored = swapped ^ stream[i];
    return xored ^ ((i * _finalStep + _finalBias) & 0xFF);
  });
}

String unfoldFrenzy(List<int> encoded) {
  final stream = _weaveKeystream(encoded.length);
  return String.fromCharCodes(
    List<int>.generate(encoded.length, (i) {
      final unmasked = encoded[i] ^ ((i * _finalStep + _finalBias) & 0xFF);
      final unxored = unmasked ^ stream[i];
      final unswapped = _flipNibbles(unxored);
      return (unswapped - ((i * i * _quadStep + _quadPhase) & 0xFF)) & 0xFF;
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
    'safari': '18.7',
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
