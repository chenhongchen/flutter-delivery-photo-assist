import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_photo_assist/src/services/picodet_model.dart';
import 'package:delivery_photo_assist/src/domain/guidance.dart';
import 'dart:ui';

void main() {
  const model = PicoDetModel(
    path: 'unused',
    labels: ['parcel_box', 'beverage_case'],
  );
  test(
    'class order and model pixel coordinates match the delivery manifest',
    () {
      final objects = decodePicoDet([1, .8, 32, 64, 288, 256], 1, model, .35);
      expect(objects.single.label, 'beverage_case');
      expect(objects.single.box, const Rect.fromLTRB(.1, .2, .9, .8));
      expect(
        SceneFacts(
          receivedAtMs: 0,
          objects: objects,
        ).package(const GuideSettings()),
        isNotNull,
      );
    },
  );
  test('truncated output fails rather than reading beyond the tensor', () {
    expect(() => decodePicoDet([0, .8], 1, model, .35), throwsFormatException);
  });
  test(
    'invalid class scores and inverted boxes never become advice evidence',
    () {
      final values = [
        99,
        .9,
        0,
        0,
        100,
        100,
        0,
        double.nan,
        0,
        0,
        100,
        100,
        0,
        .9,
        200,
        200,
        20,
        20,
      ];
      expect(decodePicoDet(values, 3, model, .35), isEmpty);
    },
  );
  test('large intact beverage case is not judged too close just by area', () {
    final facts = SceneFacts(
      receivedAtMs: 0,
      objects: [
        const SceneObject(
          'beverage_case',
          .9,
          Rect.fromLTRB(.03, .03, .97, .97),
        ),
      ],
    );
    expect(
      const GuidanceRules()
          .evaluate(facts, ShotStage.parcel, const GuideSettings())
          .code,
      isNot(HintCode.wider),
    );
  });
}
