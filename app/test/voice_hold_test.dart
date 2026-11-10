// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoobird/ui/voice_hold.dart';

void main() {
  test('Halten, nach oben sperren, nach links abbrechen, zu kurz verwerfen', () {
    final machine = VoiceHoldMachine();
    machine.down();
    expect(machine.up(1500), 'idle');

    machine.down();
    machine.arm();
    expect(machine.move(0, -80), 'lock');
    expect(machine.up(1500), 'locked');

    machine.down();
    machine.arm();
    expect(machine.move(-100, 0), 'cancel');
    expect(machine.up(1500), 'cancelled');

    machine.down();
    machine.arm();
    expect(machine.up(200), 'tooShort');
    machine.down();
    machine.arm();
    expect(machine.up(1500), 'send');
  });

  testWidgets('Gedrückt halten sendet, Wischen sperrt oder verwirft', (tester) async {
    final counts = _Counts();
    await tester.pumpWidget(_Harness(counts: counts));

    var gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('voice-mic'))));
    await tester.pump(const Duration(milliseconds: 280));
    await tester.pump();
    expect(counts.started, 1);
    expect(find.text('Wischen zum Abbrechen'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    counts.elapsed = 1500;
    await gesture.up();
    await tester.pump();
    expect(counts.sent, 1);

    gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('voice-mic'))));
    await tester.pump(const Duration(milliseconds: 280));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(counts.locked, 1);
    counts.elapsed = 1500;
    await gesture.up();
    await tester.pump();
    expect(counts.sent, 1);

    gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('voice-mic'))));
    await tester.pump(const Duration(milliseconds: 280));
    await tester.pump();
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    expect(counts.cancelled, 1);
    await gesture.up();
    await tester.pump();
    expect(counts.sent, 1);

    gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('voice-mic'))));
    await tester.pump(const Duration(milliseconds: 280));
    await tester.pump();
    counts.elapsed = 200;
    await gesture.up();
    await tester.pump();
    expect(counts.tooShort, 1);
    expect(counts.sent, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Counts {
  var started = 0;
  var locked = 0;
  var cancelled = 0;
  var sent = 0;
  var tooShort = 0;
  var elapsed = 0;
  var recording = false;
}

class _Harness extends StatefulWidget {
  const _Harness({required this.counts});

  final _Counts counts;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  @override
  Widget build(BuildContext context) {
    final counts = widget.counts;
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            VoiceMicButton(
              key: const ValueKey('voice-mic'),
              enabled: true,
              elapsedMs: () => counts.elapsed,
              onStart: () async {
                counts.started += 1;
                setState(() => counts.recording = true);
                return true;
              },
              onLock: () => counts.locked += 1,
              onCancel: () => counts.cancelled += 1,
              onSend: () => counts.sent += 1,
              onTooShort: () => counts.tooShort += 1,
            ),
            if (counts.recording)
              VoiceRecordingChrome(
                clock: '0:01',
                levels: const [0.2, 0.8],
                locked: counts.locked > 0,
              ),
          ],
        ),
      ),
    );
  }
}
