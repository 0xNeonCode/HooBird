// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoobird/ui/image_view.dart';

void main() {
  testWidgets('Doppeltipp vergrößert das entschlüsselte Bild', (tester) async {
    final png = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ImageViewerPage(bytes: png, allowExport: false),
      ),
    );
    await tester.pump();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.textContaining('Sperrbildschirm'), findsOneWidget);
    expect(find.byTooltip('Speichern'), findsNothing);

    final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
    await tester.tap(find.byType(InteractiveViewer));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(InteractiveViewer));
    await tester.pump(const Duration(milliseconds: 400));
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), greaterThan(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
