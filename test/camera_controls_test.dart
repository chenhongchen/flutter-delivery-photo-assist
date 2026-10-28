import 'package:delivery_photo_assist/src/domain/guidance.dart';
import 'package:delivery_photo_assist/src/widgets/camera_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boxes default off; switch can be enabled and disabled', (
    tester,
  ) async {
    expect(const GuideSettings().showBoxes, isFalse);
    var enabled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => DetectionBoxSwitch(
              value: enabled,
              onChanged: (value) => setState(() => enabled = value),
            ),
          ),
        ),
      ),
    );
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    await tester.tap(find.byKey(const Key('detection-box-switch')));
    await tester.pumpAndSettle();
    expect(enabled, isTrue);
    await tester.tap(find.byKey(const Key('detection-box-switch')));
    await tester.pumpAndSettle();
    expect(enabled, isFalse);
  });

  testWidgets(
    'zoom presets respect camera limits and send requested display factors',
    (tester) async {
      double? requested;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraZoomControls(
              zoom: 1,
              minimum: 1,
              maximum: 3,
              onChanged: (value) => requested = value,
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('camera-zoom-0.5')), findsNothing);
      expect(find.byKey(const Key('camera-zoom-5.0')), findsNothing);
      await tester.tap(find.byKey(const Key('camera-zoom-2.0')));
      expect(requested, 2);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraZoomControls(
              zoom: 1.4,
              minimum: .5,
              maximum: 5,
              onChanged: (value) => requested = value,
            ),
          ),
        ),
      );
      expect(find.textContaining('1.4×'), findsOneWidget);
      await tester.tap(find.byKey(const Key('camera-zoom-0.5')));
      expect(requested, .5);
    },
  );

  testWidgets(
    'two-finger pinch changes zoom within hardware limits; single drag does not',
    (tester) async {
      final requests = <double>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraZoomGesture(
              zoom: 1,
              minimum: .5,
              maximum: 2,
              onChanged: requests.add,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.dragFrom(const Offset(250, 300), const Offset(100, 0));
      expect(requests, isEmpty);
      final first = await tester.startGesture(
        const Offset(300, 300),
        pointer: 1,
      );
      final second = await tester.startGesture(
        const Offset(400, 300),
        pointer: 2,
      );
      await first.moveTo(const Offset(270, 300));
      await second.moveTo(const Offset(430, 300));
      await first.moveTo(const Offset(100, 300));
      await second.moveTo(const Offset(600, 300));
      await tester.pump();
      expect(requests, isNotEmpty);
      expect(requests.every((v) => v >= .5 && v <= 2), isTrue);
      expect(requests.last, 2);
      await first.up();
      await second.up();
    },
  );
}
