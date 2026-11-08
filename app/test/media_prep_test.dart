// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoobird/media_prep.dart';

void main() {
  test('JPEG-Metadaten mit GPS-Text werden entfernt, Bildanfang bleibt', () {
    final payload = Uint8List.fromList('GPSLAT-48.12345'.codeUnits);
    final length = payload.length + 2;
    final jpeg = Uint8List.fromList([
      0xFF,
      0xD8,
      0xFF,
      0xE1,
      (length >> 8) & 0xFF,
      length & 0xFF,
      ...payload,
      0xFF,
      0xD9,
    ]);
    expect(String.fromCharCodes(jpeg), contains('GPSLAT-48.12345'));
    final stripped = stripJpegMetadata(jpeg);
    expect(stripped.first, 0xFF);
    expect(stripped[1], 0xD8);
    expect(String.fromCharCodes(stripped).contains('GPSLAT-48.12345'), isFalse);
  });

  test('Keine JPEG-Datei wird abgelehnt', () {
    expect(
      () => stripJpegMetadata(Uint8List.fromList([1, 2, 3, 4])),
      throwsA(isA<JpegPrepException>()),
    );
  });
}
