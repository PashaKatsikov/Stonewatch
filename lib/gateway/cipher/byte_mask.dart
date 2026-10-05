import 'dart:convert';
import 'dart:typed_data';

// ============================================================
// BYTE MASK — runtime string de-obfuscator for the gateway
// ============================================================
// Nothing sensitive (endpoint URL, attribution key, Firebase
// project number, browser-identity fragments) ships as a plain
// string literal. Each one lives as a masked byte array in
// `sealed_values.dart` and is only turned back into text here,
// at call time, via [unmask].
//
// The transform is a symmetric keystream XOR, so the encoder in
// `tool/seal_values.dart` reuses [maskBytes] unchanged — mask and
// unmask are literally the same operation.
//
// Keystream derivation (deliberately unlike any sibling project's
// decoder loop shape):
//   1. Fold [_grain] into a 32-bit accumulator with FNV-1a.
//   2. Walk a Numerical-Recipes LCG from that accumulator, taking
//      the top byte of each state into a [_span]-byte keystream.
//   3. For byte i:
//        plain[i] = cipher[i] ^ keystream[i % span] ^ drift(i)
//      where drift(i) is a Fibonacci-hash of the index so that a
//      run of identical plaintext bytes never masks identically.
//
// If the input array is empty the result is "" — that is the
// expected state before the operator seals the real credentials
// into `sealed_values.dart`.
// ============================================================

// Project-unique grain. Distinct from every sibling build.
const List<int> _grain = <int>[
  0x5A, 0x13, 0xE7, 0x90, 0x4C, 0xB2, 0x6F, 0x38, 0xD1,
  0x07, 0xA9, 0x52, 0xFC, 0x81, 0x2E, 0x63, 0xBD, 0x44,
];

// Keystream length. Project-unique.
const int _span = 29;

const int _fnvOffset = 0x811C9DC5;
const int _fnvPrime = 0x01000193;
const int _lcgMul = 0x0019660D; // 1664525
const int _lcgAdd = 0x3C6EF35F; // 1013904223
const int _driftMul = 0x85EBCA77; // murmur finalizer constant

int _accumulate() {
  int acc = _fnvOffset;
  for (final int b in _grain) {
    acc = ((acc ^ b) * _fnvPrime) & 0xFFFFFFFF;
  }
  return acc == 0 ? _fnvPrime : acc;
}

Uint8List _buildKeystream() {
  int state = _accumulate();
  final Uint8List ks = Uint8List(_span);
  for (int i = 0; i < _span; i++) {
    state = ((_lcgMul * state) + _lcgAdd) & 0xFFFFFFFF;
    ks[i] = (state >> 24) & 0xFF;
  }
  return ks;
}

final Uint8List _keystream = _buildKeystream();

int _drift(int index) => ((index * _driftMul) >> 19) & 0xFF;

/// Core symmetric transform. Shared by [unmask] and the sealing tool.
Uint8List maskBytes(List<int> input) {
  final Uint8List out = Uint8List(input.length);
  for (int i = 0; i < input.length; i++) {
    out[i] = (input[i] ^ _keystream[i % _span] ^ _drift(i)) & 0xFF;
  }
  return out;
}

/// Reveal the plaintext behind a masked byte array. Empty in → "".
String unmask(List<int> cipher) {
  if (cipher.isEmpty) return '';
  return utf8.decode(maskBytes(cipher));
}

/// Mask a plaintext string into the byte array to paste into
/// `sealed_values.dart`. Only used by the offline sealing tool.
List<int> seal(String plain) => maskBytes(utf8.encode(plain));
