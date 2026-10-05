// ignore_for_file: avoid_print
// ============================================================
// SEAL VALUES — offline encoder for lib/gateway/cipher/sealed_values.dart
// ============================================================
// This is the companion to `byte_mask.dart`. It masks plaintext
// values with the SAME keystream the app decodes with, and prints
// ready-to-paste `const List<int> _name = <int>[...];` lines.
//
// Usage:
//   dart run tool/seal_values.dart                 # seals the UA scaffolding
//   dart run tool/seal_values.dart endpoint:https://x.y/verdict
//   dart run tool/seal_values.dart devKey:ABC projectId:123456789012
//
// Pass any number of `name:plaintext` pairs. The leading underscore
// is added automatically, so `endpoint:` prints `_endpoint`.
//
// NEVER commit the plaintext you pass here. Only the masked arrays
// (the printed output) belong in the repo.
// ============================================================

import 'dart:io';

import 'package:stonewatch/gateway/cipher/byte_mask.dart';

// Browser-identity scaffolding. These are not secrets, but they are
// the #1 static-analysis cluster marker, so they ship masked too.
const Map<String, String> _uaScaffolding = <String, String>{
  'uaProduct': 'Mozilla/5.0',
  'uaPlatformOpen': '(Linux; Android',
  'uaBuildTag': ' Build/',
  'uaPlatformClose': ')',
  'uaEngineTag': ' AppleWebKit/',
  'uaEngineTail': ' (KHTML, like Gecko)',
  'uaChromeTag': ' Chrome/',
  'uaSafariTag': ' Mobile Safari/',
  // Rotate the Chrome build.patch per project.
  'chromeBuild': '150.0.7655.84',
  'webkitBuild': '537.36',
};

void main(List<String> argv) {
  final Map<String, String> jobs = <String, String>{};

  if (argv.isEmpty) {
    jobs.addAll(_uaScaffolding);
  } else {
    for (final String arg in argv) {
      final int sep = arg.indexOf(':');
      if (sep <= 0) {
        stderr.writeln('skip malformed arg (want name:value): $arg');
        continue;
      }
      jobs[arg.substring(0, sep)] = arg.substring(sep + 1);
    }
  }

  print('// ---- paste into lib/gateway/cipher/sealed_values.dart ----');
  jobs.forEach((String name, String plain) {
    final List<int> bytes = seal(plain);
    // Round-trip self-check.
    final String back = unmask(bytes);
    final String flag = back == plain ? 'OK' : 'MISMATCH';
    print('// $flag  _$name  (${plain.length} chars)');
    print('const List<int> _$name = ${_fmt(bytes)};');
  });
}

String _fmt(List<int> bytes) {
  if (bytes.isEmpty) return '<int>[]';
  final StringBuffer buf = StringBuffer('<int>[\n');
  for (int i = 0; i < bytes.length; i++) {
    if (i % 12 == 0) buf.write('  ');
    buf.write('0x${bytes[i].toRadixString(16).padLeft(2, '0').toUpperCase()}');
    buf.write(',');
    buf.write(i % 12 == 11 || i == bytes.length - 1 ? '\n' : ' ');
  }
  buf.write(']');
  return buf.toString();
}
