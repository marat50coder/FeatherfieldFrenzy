import 'dart:typed_data';

/// Cipher family: FNV-1a mixed keystream + position-keyed XOR + additive
/// offset. Distinct from the RC4-style KSA/PRGA the sibling app template
/// uses, so the machine code, keystream table and byte distribution all
/// differ. Rotate this whole family (not just the seed) between projects.
///
/// Seed bytes below are unique to Fietherfield Frenzy — if you change them
/// you MUST re-run `dart run tool/encode_frenzy_gate.dart` (which carries
/// an identical copy of `_frenzySeed`) and repaste every encoded array in
/// `frenzy_gate_config.dart`.
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
    // Rotate right 11 to break linear correlation across positions.
    state = (((state >>> 11) | ((state << 21) & _mask32))) & _mask32;
    result[i] = (state ^ (state >>> 16)) & 0xFF;
  }
  return result;
}

/// Reveals a plaintext string from an obfuscated byte array. Returns `''`
/// for an empty input (used by the gate to detect missing credentials).
String revealFrenzy(List<int> encoded) {
  if (encoded.isEmpty) return '';
  final stream = _makeFrenzyKeystream(encoded.length);
  final plain = Uint8List(encoded.length);
  for (var i = 0; i < encoded.length; i++) {
    final xored = encoded[i] ^ ((i * 61) & 0xFF);
    plain[i] = (xored - stream[i] - (i * 41)) & 0xFF;
  }
  return String.fromCharCodes(plain);
}
