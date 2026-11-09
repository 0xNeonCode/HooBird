// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

/// Outbound bubble state. Two grey checks are not used.
///
/// Matrix has no receipt that means "the other device has the ciphertext".
/// `EventStatus.sent` is the homeserver accepting the send. `EventStatus.synced`
/// is this client seeing that event come back in sync. Neither one says a
/// recipient device stored it, so both stay a single grey check, "Gesendet".
/// "Gelesen" comes only from public read receipts, and only when that display
/// is switched on.
enum OutboundDelivery { sending, sent, read, failed }

String deliveryLabel(OutboundDelivery state) {
  return switch (state) {
    OutboundDelivery.sending => 'Wird gesendet',
    OutboundDelivery.sent => 'Gesendet',
    OutboundDelivery.read => 'Gelesen',
    OutboundDelivery.failed => 'Senden fehlgeschlagen',
  };
}

OutboundDelivery outboundDelivery({
  required EventStatus status,
  required bool showRead,
}) {
  return switch (status) {
    EventStatus.error => OutboundDelivery.failed,
    EventStatus.sending => OutboundDelivery.sending,
    EventStatus.sent || EventStatus.synced => showRead ? OutboundDelivery.read : OutboundDelivery.sent,
  };
}

/// Timeline index 0 is the newest loaded event. A receipt covers a message
/// when that receipt's event is loaded and is the same event or a newer one.
/// A receipt that points outside the loaded window does not count: its
/// timestamp is when the receipt was sent, not proof of which message it passed.
bool receiptCoversMessage({required int messageIndex, required int? receiptIndex}) {
  if (messageIndex < 0 || receiptIndex == null || receiptIndex < 0) return false;
  return receiptIndex <= messageIndex;
}

List<String> membersWhoRead({
  required int messageIndex,
  required Map<String, int?> receiptIndexByMember,
  required List<String> otherJoinedMemberIds,
}) {
  return [
    for (final id in otherJoinedMemberIds)
      if (receiptCoversMessage(messageIndex: messageIndex, receiptIndex: receiptIndexByMember[id])) id,
  ];
}

/// Joined members other than the sender. An empty room is never "everyone".
bool everyoneJoinedHasRead({
  required int messageIndex,
  required Map<String, int?> receiptIndexByMember,
  required List<String> otherJoinedMemberIds,
}) {
  if (otherJoinedMemberIds.isEmpty) return false;
  return membersWhoRead(
        messageIndex: messageIndex,
        receiptIndexByMember: receiptIndexByMember,
        otherJoinedMemberIds: otherJoinedMemberIds,
      ).length ==
      otherJoinedMemberIds.length;
}

class DeliveryMark extends StatefulWidget {
  const DeliveryMark({
    super.key,
    required this.state,
    this.blink = false,
    this.onRetry,
  });

  final OutboundDelivery state;
  final bool blink;
  final VoidCallback? onRetry;

  @override
  State<DeliveryMark> createState() => _DeliveryMarkState();
}

class _DeliveryMarkState extends State<DeliveryMark> with SingleTickerProviderStateMixin {
  AnimationController? _blink;
  var _played = false;

  @override
  void initState() {
    super.initState();
    if (widget.blink && widget.state == OutboundDelivery.read) _startBlink();
  }

  @override
  void didUpdateWidget(DeliveryMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_played && widget.blink && widget.state == OutboundDelivery.read && !oldWidget.blink) {
      _startBlink();
    }
  }

  void _startBlink() {
    _played = true;
    final blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _blink = blink;
    blink.forward();
  }

  @override
  void dispose() {
    _blink?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = deliveryLabel(widget.state);
    final Widget mark = switch (widget.state) {
      OutboundDelivery.sending => Icon(Icons.schedule, size: 15, color: scheme.outline),
      OutboundDelivery.sent => Icon(Icons.done, size: 16, color: scheme.outline),
      OutboundDelivery.read => _OwlEyes(color: scheme.primary, blink: _blink),
      OutboundDelivery.failed => Icon(Icons.error_outline, size: 16, color: scheme.error),
    };
    final shown = Semantics(
      container: true,
      button: widget.state == OutboundDelivery.failed,
      label: label,
      child: mark,
    );
    if (widget.state != OutboundDelivery.failed) return shown;
    return Tooltip(
      message: 'Erneut senden',
      child: InkWell(
        onTap: widget.onRetry,
        borderRadius: BorderRadius.circular(12),
        child: Padding(padding: const EdgeInsets.all(2), child: shown),
      ),
    );
  }
}

class _OwlEyes extends StatelessWidget {
  const _OwlEyes({required this.color, required this.blink});

  final Color color;
  final AnimationController? blink;

  @override
  Widget build(BuildContext context) {
    final eyes = CustomPaint(
      key: const Key('owl-eyes'),
      size: const Size(16, 10),
      painter: _OwlEyesPainter(color),
    );
    final animation = blink;
    if (animation == null) return eyes;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final opacity = t < 0.5 ? 1 - t : t;
        return Opacity(opacity: opacity.clamp(0.45, 1), child: child);
      },
      child: eyes,
    );
  }
}

class _OwlEyesPainter extends CustomPainter {
  _OwlEyesPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final radius = size.height * 0.34;
    final y = size.height / 2;
    canvas.drawCircle(Offset(size.width * 0.28, y), radius, paint);
    canvas.drawCircle(Offset(size.width * 0.72, y), radius, paint);
  }

  @override
  bool shouldRepaint(_OwlEyesPainter oldDelegate) => oldDelegate.color != color;
}
