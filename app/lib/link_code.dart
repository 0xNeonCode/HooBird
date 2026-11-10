// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'dart:typed_data';

import 'package:qr/qr.dart';
import 'package:zxing2/qrcode.dart';

const linkPayloadVersion = 'hoobird-link:v1';

class LinkCode {
  const LinkCode({required this.childId, required this.code});

  final String childId;
  final String code;

  String get payload => '$linkPayloadVersion\n$childId\n$code';
}

/// The three-line text printed under the QR. Anything else is not a link code.
LinkCode? parseLinkPayload(String raw) {
  final lines = raw
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.length < 3 || lines.first != linkPayloadVersion) return null;
  if (lines[1].isEmpty || lines[2].isEmpty) return null;
  return LinkCode(childId: lines[1], code: lines[2]);
}

/// Black and white ARGB pixels, quiet zone included. Used to prove the decoder.
Int32List rasterizeLinkQr(String payload, {int scale = 8, int quiet = 4}) {
  final image = QrImage(QrCode(payload: QrPayload.fromString(payload)));
  final modules = image.moduleCount;
  final side = (modules + quiet * 2) * scale;
  final pixels = Int32List(side * side);
  for (var y = 0; y < side; y++) {
    for (var x = 0; x < side; x++) {
      final moduleX = x ~/ scale - quiet;
      final moduleY = y ~/ scale - quiet;
      final dark = moduleX >= 0 &&
          moduleY >= 0 &&
          moduleX < modules &&
          moduleY < modules &&
          image.isDark(moduleY, moduleX);
      pixels[y * side + x] = dark ? 0xFF000000 : 0xFFFFFFFF;
    }
  }
  return pixels;
}

/// Null when the picture is not a QR. The camera page uses the same function.
String? decodeQrPixels({required int width, required int height, required Int32List argb}) {
  if (width <= 0 || height <= 0 || argb.length < width * height) return null;
  try {
    final source = RGBLuminanceSource(width, height, argb);
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    return QRCodeReader().decode(bitmap).text;
  } catch (_) {
    return null;
  }
}

/// Camera Y plane to ARGB so [decodeQrPixels] can read a live frame.
Int32List yPlaneToArgb(Uint8List yPlane, {required int width, required int height, required int rowStride}) {
  final pixels = Int32List(width * height);
  var index = 0;
  for (var row = 0; row < height; row++) {
    final start = row * rowStride;
    for (var column = 0; column < width; column++) {
      final y = yPlane[start + column];
      pixels[index++] = 0xFF000000 | (y << 16) | (y << 8) | y;
    }
  }
  return pixels;
}
