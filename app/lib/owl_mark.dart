// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'package:flutter/material.dart';

/// Small original owl mark for the HooBird header. Not a third-party logo.
class OwlMark extends StatelessWidget {
  const OwlMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _OwlPainter()),
    );
  }
}

class _OwlPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Paint()..color = const Color(0xFF6E5A99);
    final tuft = Paint()..color = const Color(0xFF4E3B73);
    final face = Paint()..color = const Color(0xFFF7F1E8);
    final pupil = Paint()..color = const Color(0xFF24182E);
    final beak = Paint()..color = const Color(0xFFC4A06A);

    canvas.drawOval(Rect.fromLTWH(w * 0.12, h * 0.22, w * 0.76, h * 0.7), body);
    final leftTuft = Path()
      ..moveTo(w * 0.28, h * 0.28)
      ..lineTo(w * 0.18, h * 0.06)
      ..lineTo(w * 0.42, h * 0.24)
      ..close();
    final rightTuft = Path()
      ..moveTo(w * 0.72, h * 0.28)
      ..lineTo(w * 0.82, h * 0.06)
      ..lineTo(w * 0.58, h * 0.24)
      ..close();
    canvas.drawPath(leftTuft, tuft);
    canvas.drawPath(rightTuft, tuft);
    canvas.drawCircle(Offset(w * 0.37, h * 0.48), w * 0.13, face);
    canvas.drawCircle(Offset(w * 0.63, h * 0.48), w * 0.13, face);
    canvas.drawCircle(Offset(w * 0.39, h * 0.49), w * 0.055, pupil);
    canvas.drawCircle(Offset(w * 0.65, h * 0.49), w * 0.055, pupil);
    final beakPath = Path()
      ..moveTo(w * 0.46, h * 0.62)
      ..lineTo(w * 0.54, h * 0.62)
      ..lineTo(w * 0.5, h * 0.72)
      ..close();
    canvas.drawPath(beakPath, beak);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
