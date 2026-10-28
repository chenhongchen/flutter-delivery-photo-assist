import 'dart:ui';
import 'package:delivery_photo_assist/src/domain/clarity.dart';
import 'package:delivery_photo_assist/src/domain/guidance.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object> reading({
  double lap = 200,
  double contrast = 45,
  double mean = 120,
  double edge = .3,
  double dark = 0,
  double clipped = 0,
}) => {
  'laplacianVariance': lap,
  'contrastStd': contrast,
  'meanLuma': mean,
  'edgeFraction': edge,
  'darkFraction': dark,
  'clippedFraction': clipped,
  'analysisWidth': 320,
  'analysisHeight': 240,
};
void main() {
  test('clear textured view has usable spatial detail', () {
    expect(FrameClarity({'global': reading()}).state, ClarityState.clear);
  });
  test('blurred package overrides a sharp background', () {
    final quality = FrameClarity({
      'global': reading(),
      'package': reading(lap: 12),
    });
    expect(quality.state, ClarityState.blurry);
    expect(quality.needsRetake, isTrue);
    expect(quality.advice, contains('包裹区域'));
    final scene = SceneFacts(
      receivedAtMs: 0,
      clarity: quality,
      objects: const [
        SceneObject('cardboard box', .9, Rect.fromLTWH(.2, .5, .3, .3)),
        SceneObject('door', .9, Rect.fromLTWH(.5, .1, .3, .6)),
      ],
    );
    expect(
      const GuidanceRules()
          .evaluate(scene, ShotStage.parcel, const GuideSettings())
          .code,
      HintCode.blurry,
    );
  });
  test('flat white bag is uncertain rather than automatically blurry', () {
    final quality = FrameClarity({
      'global': reading(),
      'package': reading(lap: 2, contrast: 3, edge: .001, mean: 180),
    });
    expect(quality.state, ClarityState.uncertain);
    expect(quality.needsRetake, isFalse);
  });
  test(
    'low-light image recommends light even if sensor noise creates edges',
    () {
      expect(
        FrameClarity({'global': reading(lap: 500, mean: 20, dark: .9)}).state,
        ClarityState.dark,
      );
    },
  );
  test('blown highlights cannot be marked clear', () {
    expect(
      FrameClarity({'global': reading(mean: 250, clipped: .8)}).state,
      ClarityState.glare,
    );
  });
  test('AF transition does not show a clear status', () {
    expect(
      FrameClarity({'global': reading(), 'isAdjustingFocus': true}).state,
      ClarityState.focusing,
    );
  });
  test('invalid or absent metrics never imply clear', () {
    expect(FrameClarity.parse(null), isNull);
    expect(
      FrameClarity({
        'global': {'laplacianVariance': double.nan},
      }).state,
      ClarityState.uncertain,
    );
  });
}
