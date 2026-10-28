import 'dart:ui';
import 'package:delivery_photo_assist/src/domain/guidance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rules = GuidanceRules();
  const settings = GuideSettings();
  const box = SceneObject('Box', .9, Rect.fromLTWH(.2, .55, .3, .3));
  const door = SceneObject('Door', .9, Rect.fromLTWH(.5, .1, .3, .6));
  SceneFacts scene(List<SceneObject> objects) =>
      SceneFacts(objects: objects, receivedAtMs: 0);
  HintCode first(List<SceneObject> objects) =>
      rules.evaluate(scene(objects), ShotStage.parcel, settings).code;

  test('a background object cannot stand in for a parcel', () {
    expect(first([door]), HintCode.packageMissing);
  });
  test('normal small packaging does not imply excessive physical distance', () {
    expect(
      first([
        const SceneObject('Box', .9, Rect.fromLTWH(.4, .6, .1, .1)),
        door,
      ]),
      HintCode.ready,
    );
  });
  test(
    'large intact parcels remain allowed; clipped parcels suggest wider framing',
    () {
      expect(
        first([
          const SceneObject('Box', .9, Rect.fromLTWH(.05, .05, .85, .85)),
          door,
        ]),
        HintCode.ready,
      );
      expect(
        first([
          const SceneObject('Box', .9, Rect.fromLTWH(0, .3, .9, .5)),
          door,
        ]),
        HintCode.wider,
      );
    },
  );
  test('a licence plate alone is not a fixed-location anchor', () {
    expect(
      first([
        box,
        const SceneObject(
          'Vehicle registration plate',
          .95,
          Rect.fromLTWH(.5, .1, .3, .2),
        ),
      ]),
      HintCode.contextUncertain,
    );
  });
  test(
    'unconfirmed context remains neutral rather than a missing-element error',
    () {
      final hint = rules.evaluate(scene([box]), ShotStage.parcel, settings);
      expect(hint.code, HintCode.contextUncertain);
      expect(hint.needsAttention, isFalse);
      expect(hint.isReady, isFalse);
      expect(first([box, door]), HintCode.ready);
    },
  );
  test('second image permits context without forcing a package close-up', () {
    expect(
      rules.evaluate(scene([door]), ShotStage.environment, settings).code,
      HintCode.ready,
    );
    expect(
      rules
          .evaluate(
            scene([
              const SceneObject('Box', .9, Rect.fromLTWH(.05, .05, .9, .8)),
              door,
            ]),
            ShotStage.environment,
            settings,
          )
          .code,
      HintCode.ready,
    );
  });
  test('low confidence and degenerate detections cannot produce ready', () {
    expect(
      first([
        const SceneObject('Box', .1, Rect.fromLTWH(.2, .55, .3, .3)),
        door,
      ]),
      HintCode.packageMissing,
    );
    expect(
      first([
        const SceneObject('Box', .9, Rect.fromLTWH(.2, .2, -.1, .2)),
        door,
      ]),
      HintCode.packageMissing,
    );
    expect(
      first([
        const SceneObject('Box', .9, Rect.fromLTWH(double.nan, .2, .2, .2)),
        door,
      ]),
      HintCode.packageMissing,
    );
  });
  test('bags can be excluded to evaluate false positives', () {
    final facts = scene([
      const SceneObject('Plastic bag', .95, Rect.fromLTWH(.2, .5, .3, .3)),
      door,
    ]);
    expect(
      rules.evaluate(facts, ShotStage.parcel, settings).code,
      HintCode.ready,
    );
    expect(
      rules
          .evaluate(
            facts,
            ShotStage.parcel,
            settings.copyWith(includeBagCandidates: false),
          )
          .code,
      HintCode.packageMissing,
    );
  });

  test(
    'offline vocabulary carton and bag appearances share package-candidate rules',
    () {
      for (final label in [
        'cardboard box',
        'plastic bag',
        'shopping bag',
        'paper bag',
        'delivery package',
        'insulated delivery bag',
      ]) {
        final object = SceneObject(
          label,
          .8,
          const Rect.fromLTWH(.2, .55, .3, .3),
        );
        expect(first([object, door]), HintCode.ready, reason: label);
        expect(object.displayName, '包裹候选');
      }
      final bag = const SceneObject(
        'shopping bag',
        .8,
        Rect.fromLTWH(.2, .55, .3, .3),
      );
      expect(
        rules
            .evaluate(
              scene([bag, door]),
              ShotStage.parcel,
              settings.copyWith(includeBagCandidates: false),
            )
            .code,
        HintCode.packageMissing,
      );
    },
  );

  test(
    'whole-frame building predictions do not pass as a localized entrance',
    () {
      expect(
        first([
          box,
          const SceneObject('Office building', .9, Rect.fromLTWH(0, 0, 1, 1)),
        ]),
        HintCode.contextUncertain,
      );
      expect(
        first([
          box,
          const SceneObject('glass door', .8, Rect.fromLTWH(.5, .1, .3, .6)),
        ]),
        HintCode.ready,
      );
    },
  );
  test('only strong extreme framing evidence triggers size advice', () {
    const tiny = Rect.fromLTWH(.5, .5, .04, .04);
    expect(first([const SceneObject('Box', .9, tiny), door]), HintCode.closer);
    final weakHint = rules.evaluate(
      scene([const SceneObject('shopping bag', .42, tiny), door]),
      ShotStage.parcel,
      settings,
    );
    expect(weakHint.needsAttention, isFalse);
    expect(
      first([const SceneObject('Box', .42, Rect.fromLTWH(0, 0, .9, .9))]),
      HintCode.contextUncertain,
    );
  });
  test('second shot does not require an anchor to occupy ten percent', () {
    final hint = rules.evaluate(
      scene([const SceneObject('mailbox', .8, Rect.fromLTWH(.2, .3, .1, .08))]),
      ShotStage.environment,
      settings,
    );
    expect(hint.code, HintCode.ready);
  });
  test(
    'boxes outside the image do not contribute negative or oversized area',
    () {
      expect(
        const SceneObject('Box', .9, Rect.fromLTWH(-.1, -.1, .2, .2)).area,
        closeTo(.01, .000001),
      );
      expect(
        const SceneObject('Box', .9, Rect.fromLTWH(2, 2, .3, .3)).isValid,
        isFalse,
      );
    },
  );
  test(
    'rapid alternating suggestions do not make the displayed hint flicker',
    () {
      final stabilizer = HintStabilizer();
      const closer = GuideHint(HintCode.closer, 'closer', '');
      const wider = GuideHint(HintCode.wider, 'wider', '');
      for (var i = 0; i < 10; i++) {
        stabilizer.add(i.isEven ? closer : wider, i * 200);
      }
      expect(stabilizer.current.code, HintCode.waiting);
      stabilizer.add(closer, 2000);
      stabilizer.add(closer, 2200);
      stabilizer.add(closer, 2400);
      expect(stabilizer.current.code, HintCode.closer);
      stabilizer.add(wider, 2600);
      stabilizer.add(wider, 2800);
      stabilizer.add(wider, 3000);
      expect(stabilizer.current.code, HintCode.closer);
      stabilizer.add(wider, 3200);
      expect(stabilizer.current.code, HintCode.wider);
    },
  );
  test(
    'stale observations lose ready state and must establish a new quorum',
    () {
      final stabilizer = HintStabilizer();
      const ready = GuideHint(HintCode.ready, 'ready', '');
      stabilizer.add(ready, 0);
      stabilizer.add(ready, 200);
      stabilizer.add(ready, 400);
      expect(stabilizer.at(500).isReady, isTrue);
      expect(stabilizer.at(2000).code, HintCode.stale);
      expect(stabilizer.add(ready, 2100).isReady, isFalse);
      expect(stabilizer.add(ready, 2300).isReady, isFalse);
      expect(stabilizer.add(ready, 2500).isReady, isTrue);
    },
  );
  test('a burst arriving after a pause cannot reuse pre-pause votes', () {
    final stabilizer = HintStabilizer();
    const ready = GuideHint(HintCode.ready, 'ready', '');
    stabilizer.add(ready, 0);
    stabilizer.add(ready, 200);
    expect(stabilizer.add(ready, 3000).isReady, isFalse);
  });
  test('timing window stays bounded and rejects invalid samples', () {
    final timings = TimingSummary();
    for (var i = 1; i <= 400; i++) {
      timings.add(i.toDouble(), i * 200);
    }
    timings.add(double.nan, 90000);
    expect(timings.count, 300);
    expect(timings.percentile(.5), 250);
    expect(timings.percentile(.95), 385);
    expect(timings.callbackFps, 5);
  });
}
