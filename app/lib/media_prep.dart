// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'dart:typed_data';

class JpegPrepException implements Exception {
  JpegPrepException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Remove JPEG metadata segments that can carry GPS, EXIF, XMP or a comment.
///
/// The pixel data is copied, not re-encoded. This does not invent a decoder.
/// A file that is not a JPEG is rejected so it is not uploaded with its metadata.
Uint8List stripJpegMetadata(Uint8List data) {
  if (data.length < 4 || data[0] != 0xFF || data[1] != 0xD8) {
    throw JpegPrepException('Nur JPEG. Die Datei wurde nicht gesendet.');
  }
  final out = BytesBuilder(copy: false)..add(const [0xFF, 0xD8]);
  var index = 2;
  while (index < data.length) {
    if (data[index] != 0xFF) {
      throw JpegPrepException('JPEG-Struktur unerwartet. Die Datei wurde nicht gesendet.');
    }
    while (index < data.length && data[index] == 0xFF) {
      index += 1;
    }
    if (index >= data.length) break;
    final marker = data[index];
    index += 1;
    if (marker == 0xD9) {
      out.add(const [0xFF, 0xD9]);
      break;
    }
    if (marker == 0xDA) {
      out.add(const [0xFF, 0xDA]);
      out.add(data.sublist(index));
      break;
    }
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      out.add([0xFF, marker]);
      continue;
    }
    if (index + 2 > data.length) {
      throw JpegPrepException('JPEG-Struktur unerwartet. Die Datei wurde nicht gesendet.');
    }
    final length = (data[index] << 8) | data[index + 1];
    if (length < 2 || index + length > data.length) {
      throw JpegPrepException('JPEG-Struktur unerwartet. Die Datei wurde nicht gesendet.');
    }
    final drop = marker == 0xE1 || marker == 0xED || marker == 0xFE;
    if (!drop) {
      out.add([0xFF, marker]);
      out.add(data.sublist(index, index + length));
    }
    index += length;
  }
  return out.toBytes();
}
