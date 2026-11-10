// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoobird/link_code.dart';
import 'package:hoobird/ui/link_scan.dart';

void main() {
  test('Der dreizeilige Text und ein gerasterter QR ergeben denselben Code', () {
    const code = LinkCode(childId: '@jonas:hoobird.local', code: 'abc123');
    expect(parseLinkPayload(code.payload)?.childId, '@jonas:hoobird.local');
    expect(parseLinkPayload(code.payload)?.code, 'abc123');
    expect(parseLinkPayload('nur text'), isNull);
    expect(parseLinkPayload('hoobird-link:v1\n\nabc'), isNull);

    final pixels = rasterizeLinkQr(code.payload);
    final side = _side(pixels.length);
    final text = decodeQrPixels(width: side, height: side, argb: pixels);
    expect(parseLinkPayload(text ?? ''), code.payload.isEmpty ? isNull : isNotNull);
    expect(text, code.payload);

    final gray = Uint8List.fromList(List<int>.filled(4, 200));
    final argb = yPlaneToArgb(gray, width: 2, height: 2, rowStride: 2);
    expect(argb.length, 4);
    expect(argb.first & 0xFF, 200);
  });

  testWidgets('Ohne Kamera bleibt das Abtippen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LinkScanPage(useCamera: false)));
    expect(find.text('Abtippen'), findsOneWidget);
    await tester.tap(find.text('Abtippen'));
    await tester.pump();
  });

  testWidgets('Ein gerastertes Bild wird als Code zurückgegeben', (tester) async {
    const code = LinkCode(childId: '@kind:hoobird.local', code: 'zzz');
    final pixels = rasterizeLinkQr(code.payload);
    final side = _side(pixels.length);
    String? scanned;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              scanned = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => LinkScanPage(
                    useCamera: false,
                    debugPixels: (width: side, height: side, argb: pixels),
                  ),
                ),
              );
            },
            child: const Text('öffnen'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();
    expect(scanned, code.payload);
  });
}

int _side(int length) {
  var side = 1;
  while (side * side < length) {
    side++;
  }
  return side;
}
