// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

/// Public read receipt. Other people, and the owl, see only this type.
/// `m.read.private` stays on the sender's own devices and is not a read.
const publicReceiptType = 'm.read';

/// Private read receipt. Sent even when public receipts are off, so this
/// user's other devices can catch up. It is not shown as someone else reading.
const privateReceiptType = 'm.read.private';

class ReceiptPlan {
  const ReceiptPlan({required this.publicRead});

  /// When true, the client also posts [publicReceiptType].
  /// [privateReceiptType] is always posted.
  final bool publicRead;

  bool get privateRead => true;
}

ReceiptPlan receiptPlan({required bool sendReceipts}) {
  return ReceiptPlan(publicRead: sendReceipts);
}

enum ReaderLineKind { off, none, read, waiting }

class ReaderLine {
  const ReaderLine(this.kind, [this.userId]);

  final ReaderLineKind kind;
  final String? userId;
}

/// Info-sheet rows. With receipts off, other people's read state is omitted.
List<ReaderLine> readerLines({
  required bool sendReceipts,
  required List<String> readers,
  required List<String> waiting,
}) {
  if (!sendReceipts) return const [ReaderLine(ReaderLineKind.off)];
  return [
    if (readers.isEmpty) const ReaderLine(ReaderLineKind.none),
    for (final id in readers) ReaderLine(ReaderLineKind.read, id),
    for (final id in waiting) ReaderLine(ReaderLineKind.waiting, id),
  ];
}
