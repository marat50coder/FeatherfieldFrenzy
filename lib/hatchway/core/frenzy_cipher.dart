import 'dart:typed_data';

/// Cipher family: **XorShift32 keystream** + nibble-swap byte transform
/// with a quadratic position offset and a final linear XOR mask. Distinct
/// from every sibling app family (no FNV keystream loop, no RC4 S-box,
/// no additive-only affine) so the emitted machine code, byte
/// distribution and static-analysis fingerprint all differ.
///
/// Any change to `_frenzySeed` OR any of the mixing constants below
/// requires re-running `dart run tool/encode_frenzy_gate.dart` and
/// pasting the fresh arrays into `frenzy_gate_config.dart` — the tool
/// carries a byte-for-byte copy of this cipher.
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

// Murmur3-style finalizer used to derive the XorShift32 seed from the
// project salt. `_pump` intentionally mixes with two odd multipliers
// (different from `_fnvPrime`) so the compiled loop is unmistakably
// different from an FNV accumulator.
const int _pumpA = 0x85EBCA6B;
const int _pumpB = 0xC2B2AE35;

// Per-position mask constants — chosen so no low bits repeat across the
// three linear terms (byte offset / final XOR / seed rotation) that a
// scanner might diff against a sibling app.
const int _quadPhase = 47;
const int _quadStep = 13;
const int _finalStep = 89;
const int _finalBias = 17;

int _forgeSeed() {
  var acc = 0;
  for (final byte in _frenzySeed) {
    // Java-String-style rolling hash (s*31 + byte). No FNV prime here.
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
    // Classic Marsaglia XorShift32 (13, 17, 5). This shape has nothing
    // in common with the FNV `(state ^ byte) * prime` cadence used
    // previously, or with the RC4 KSA/PRGA the sibling template uses.
    state = (state ^ ((state << 13) & _u32)) & _u32;
    state = state ^ (state >>> 17);
    state = (state ^ ((state << 5) & _u32)) & _u32;
    // Fold the four bytes of the 32-bit state into one output byte so
    // no single machine byte of `state` is exposed directly.
    stream[i] = (state ^ (state >>> 8) ^ (state >>> 16) ^ (state >>> 24)) & 0xFF;
  }
  return stream;
}

// Nibble swap — self-inverse on 8-bit values, so the same helper is
// used on both sides of the cipher.
int _flipNibbles(int byte) => (((byte & 0x0F) << 4) | ((byte & 0xF0) >>> 4));

/// Reveals a plaintext string from an obfuscated byte array. Returns `''`
/// for an empty input (used by the gate to detect missing credentials).
String revealFrenzy(List<int> encoded) {
  if (encoded.isEmpty) return '';
  final stream = _weaveKeystream(encoded.length);
  final plain = Uint8List(encoded.length);
  for (var i = 0; i < encoded.length; i++) {
    final unmasked = encoded[i] ^ ((i * _finalStep + _finalBias) & 0xFF);
    final unxored = unmasked ^ stream[i];
    final unswapped = _flipNibbles(unxored);
    plain[i] = (unswapped - ((i * i * _quadStep + _quadPhase) & 0xFF)) & 0xFF;
  }
  return String.fromCharCodes(plain);
}
