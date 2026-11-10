// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hold the mic to record. Slide up to lock, slide left to cancel, release to send.
class VoiceHoldMachine {
  static const lockDistance = 72.0;
  static const cancelDistance = 88.0;
  static const armDelay = Duration(milliseconds: 200);

  bool holding = false;
  bool armed = false;
  bool locked = false;
  bool cancelled = false;
  double dx = 0;
  double dy = 0;

  void down() {
    holding = true;
    armed = false;
    locked = false;
    cancelled = false;
    dx = 0;
    dy = 0;
  }

  void arm() {
    if (holding && !cancelled) armed = true;
  }

  /// [originDx] and [originDy] are from the pointer-down position.
  /// Negative y is up. Negative x is left.
  String? move(double originDx, double originDy) {
    if (!holding || !armed || locked || cancelled) return null;
    dx = originDx;
    dy = originDy;
    if (dy <= -lockDistance) {
      locked = true;
      return 'lock';
    }
    if (dx <= -cancelDistance) {
      cancelled = true;
      return 'cancel';
    }
    return null;
  }

  /// `idle` before the hold arms, `locked` after slide-up, `cancelled` after
  /// slide-left, `tooShort` under 1000 milliseconds, otherwise `send`.
  String up(int elapsedMs) {
    final wasArmed = armed;
    holding = false;
    armed = false;
    if (!wasArmed) return 'idle';
    if (cancelled) return 'cancelled';
    if (locked) return 'locked';
    if (elapsedMs < 1000) return 'tooShort';
    return 'send';
  }

  void reset() {
    holding = false;
    armed = false;
    locked = false;
    cancelled = false;
    dx = 0;
    dy = 0;
  }
}

class VoiceMicButton extends StatefulWidget {
  const VoiceMicButton({
    super.key,
    required this.enabled,
    required this.elapsedMs,
    required this.onStart,
    required this.onLock,
    required this.onCancel,
    required this.onSend,
    required this.onTooShort,
  });

  final bool enabled;
  final int Function() elapsedMs;
  final Future<bool> Function() onStart;
  final VoidCallback onLock;
  final VoidCallback onCancel;
  final VoidCallback onSend;
  final VoidCallback onTooShort;

  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<VoiceMicButton> {
  final _machine = VoiceHoldMachine();
  Timer? _armTimer;
  Offset? _origin;

  @override
  void dispose() {
    _armTimer?.cancel();
    super.dispose();
  }

  void _haptic(String kind) {
    final future = switch (kind) {
      'lock' => HapticFeedback.heavyImpact(),
      'cancel' => HapticFeedback.vibrate(),
      _ => HapticFeedback.mediumImpact(),
    };
    unawaited(future.then<void>((_) {}, onError: (_) {}));
  }

  void _down(PointerDownEvent event) {
    if (!widget.enabled) return;
    _origin = event.position;
    _machine.down();
    _armTimer?.cancel();
    _armTimer = Timer(VoiceHoldMachine.armDelay, () async {
      if (!mounted || !_machine.holding) return;
      final ok = await widget.onStart();
      if (!mounted) return;
      if (!_machine.holding) {
        if (ok) widget.onTooShort();
        _machine.reset();
        setState(() {});
        return;
      }
      if (!ok) {
        _machine.reset();
        setState(() {});
        return;
      }
      _machine.arm();
      setState(() {});
      _haptic('start');
    });
  }

  void _move(PointerMoveEvent event) {
    final origin = _origin;
    if (origin == null) return;
    final delta = event.position - origin;
    final hit = _machine.move(delta.dx, delta.dy);
    if (hit == 'lock') {
      _haptic('lock');
      widget.onLock();
    } else if (hit == 'cancel') {
      _haptic('cancel');
      widget.onCancel();
    }
    if (mounted) setState(() {});
  }

  void _up(PointerEvent event) {
    _armTimer?.cancel();
    final result = _machine.up(widget.elapsedMs());
    _origin = null;
    if (mounted) setState(() {});
    switch (result) {
      case 'send':
        widget.onSend();
      case 'tooShort':
        widget.onTooShort();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final armed = _machine.armed && !_machine.locked && !_machine.cancelled;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: Semantics(
        button: true,
        label: 'Sprachnachricht. Gedrückt halten sendet, nach oben sperrt, nach links bricht ab.',
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            armed ? Icons.mic : Icons.mic_none,
            color: armed ? const Color(0xFFE53935) : null,
          ),
        ),
      ),
    );
  }
}

class VoiceRecordingChrome extends StatelessWidget {
  const VoiceRecordingChrome({
    super.key,
    required this.clock,
    required this.levels,
    required this.locked,
  });

  final String clock;
  final List<double> levels;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _PulseDot(),
        const SizedBox(width: 8),
        Text(clock),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 36,
            child: CustomPaint(painter: WaveformPainter(levels)),
          ),
        ),
        const SizedBox(width: 8),
        if (locked)
          const Icon(Icons.lock, color: Color(0xFFE53935))
        else
          SizedBox(
            width: 92,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 16),
                const Icon(Icons.keyboard_arrow_up, size: 16),
                Text(
                  'Wischen zum Abbrechen',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
      child: const Icon(Icons.circle, color: Color(0xFFE53935), size: 14),
    );
  }
}

class WaveformPainter extends CustomPainter {
  WaveformPainter(this.levels);

  final List<double> levels;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const slots = 40;
    final gap = size.width / slots;
    final shown = levels.length > slots ? levels.sublist(levels.length - slots) : levels;
    for (var i = 0; i < slots; i++) {
      final sample = i < shown.length ? shown[i].clamp(0.0, 1.0) : 0.04;
      final height = 4 + sample * (size.height - 6);
      final x = gap * i + gap / 2;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) => oldDelegate.levels != levels;
}
