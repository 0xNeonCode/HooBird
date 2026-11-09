// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoobird/audio_prep.dart';

Uint8List _box(String type, List<int> body) {
  final size = 8 + body.length;
  return Uint8List.fromList([
    (size >> 24) & 0xFF,
    (size >> 16) & 0xFF,
    (size >> 8) & 0xFF,
    size & 0xFF,
    ...ascii.encode(type),
    ...body,
  ]);
}

void main() {
  test('MP4-Metadaten mit Ortsmarkierung werden entfernt, Audiodaten bleiben', () {
    final udta = _box('udta', ascii.encode('GPSLAT-48.12345'));
    final moov = _box('moov', [..._box('mvhd', ascii.encode('head')), ...udta]);
    final file = Uint8List.fromList([
      ..._box('ftyp', ascii.encode('isom')),
      ...moov,
      ..._box('mdat', ascii.encode('audio-samples')),
    ]);
    expect(ascii.decode(file, allowInvalid: true), contains('GPSLAT-48.12345'));
    final stripped = stripMp4Metadata(file);
    final text = ascii.decode(stripped, allowInvalid: true);
    expect(text.contains('GPSLAT-48.12345'), isFalse);
    expect(text, contains('audio-samples'));
    expect(text, contains('mvhd'));
    expect(stripped.sublist(4, 8), ascii.encode('ftyp'));
  });

  test('Keine MP4-Datei wird abgelehnt', () {
    expect(
      () => stripMp4Metadata(Uint8List.fromList(ascii.encode('RIFF-not-aac'))),
      throwsA(isA<AudioPrepException>()),
    );
  });
}
