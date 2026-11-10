// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

/// Draws a standard QR of a parent-link payload. This screen does not open a camera.
class LinkQr extends StatelessWidget {
  const LinkQr({super.key, required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    final image = QrImage(QrCode(payload: QrPayload.fromString(payload)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomPaint(
          size: const Size(220, 220),
          painter: _QrPainter(image),
        ),
        const SizedBox(height: 8),
        const Text(
          'Der Code beweist nur, dass beide denselben kurzen Text kennen. Er beweist keine Sorgeberechtigung, keine Nähe und kein Alter. Das andere Elternteil kann ihn scannen oder abtippen.',
        ),
        const SizedBox(height: 8),
        SelectableText(payload),
      ],
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final quiet = 4;
    final count = image.moduleCount + quiet * 2;
    final cell = size.shortestSide / count;
    final paint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(Offset.zero & size, paint);
    paint.color = const Color(0xFF000000);
    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (image.isDark(row, col)) {
          canvas.drawRect(
            Rect.fromLTWH((col + quiet) * cell, (row + quiet) * cell, cell + 0.4, cell + 0.4),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) => oldDelegate.image.moduleCount != image.moduleCount;
}
