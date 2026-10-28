import 'package:delivery_photo_assist/src/domain/clarity.dart';
import 'package:delivery_photo_assist/src/domain/guidance.dart';
import 'package:delivery_photo_assist/src/domain/scene_text.dart';
import 'package:delivery_photo_assist/src/widgets/first_shot_reference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> reading(double detail) => {
    'laplacianVariance': detail,
    'contrastStd': 50,
    'meanLuma': 110,
    'edgeFraction': .2,
    'darkFraction': .02,
    'clippedFraction': 0,
    'analysisWidth': 240,
    'analysisHeight': 320,
  };
  test(
    'second-shot clarity ignores an unrelated local bag while preserving whole-image blur',
    () {
      final quality = FrameClarity({
        'global': reading(300),
        'package': reading(2),
      });
      final facts = SceneFacts(receivedAtMs: 0, clarity: quality);
      const rules = GuidanceRules();
      expect(
        rules.evaluate(facts, ShotStage.parcel, const GuideSettings()).code,
        HintCode.blurry,
      );
      final second = rules.evaluate(
        facts,
        ShotStage.environment,
        const GuideSettings(),
      );
      expect(second.needsAttention, isFalse);
      expect(second.title, '画面较清晰，可拍第二张');
      expect(second.isReady, isFalse);
      expect(
        rules
            .evaluate(
              SceneFacts(
                receivedAtMs: 0,
                clarity: FrameClarity({'global': reading(2)}),
              ),
              ShotStage.environment,
              const GuideSettings(),
            )
            .code,
        HintCode.blurry,
      );
    },
  );

  test(
    'a chair-back backpack detection cannot drive delivery parcel advice',
    () {
      const scene = SceneFacts(
        receivedAtMs: 0,
        objects: [SceneObject('backpack', .92, Rect.fromLTWH(0, 0, .9, .9))],
      );
      expect(scene.package(const GuideSettings()), isNull);
      expect(
        const GuidanceRules()
            .evaluate(scene, ShotStage.environment, const GuideSettings())
            .needsAttention,
        isFalse,
      );
    },
  );

  test('text clues remain informational and expired OCR disappears', () {
    final packet = {
      'status': 'available',
      'ageMs': 100,
      'lines': [
        {
          'text': 'ENTRANCE A12',
          'confidence': .9,
          'box': [.2, .2, .6, .3],
        },
        {
          'text': 'unreliable',
          'confidence': .1,
          'box': [.2, .2, .6, .3],
        },
        {
          'text': 'ÜMALL',
          'confidence': .99,
          'box': [.2, .2, .6, .3],
        },
      ],
    };
    final clues = SceneTextClues.parse(packet);
    expect(clues.lines.single.text, 'ENTRANCE A12');
    expect(SceneTextClues.parse({...packet, 'ageMs': 2000}).lines, isEmpty);
    final hint = const GuidanceRules().evaluate(
      SceneFacts(receivedAtMs: 0, textClues: clues),
      ShotStage.environment,
      const GuideSettings(),
    );
    expect(hint.isReady, isFalse);
  });
  test(
    'one-digit door-number clues and stage-specific waiting are supported',
    () {
      final clues = SceneTextClues.parse({
        'status': 'available',
        'lines': [
          {
            'text': '7',
            'box': [.2, .2, .3, .3],
          },
        ],
      });
      expect(clues.lines.single.text, '7');
      expect(
        GuideHint.waiting.forStage(ShotStage.environment).title,
        '对照第一张，拍清周围环境',
      );
      expect(
        GuideHint.stale.forStage(ShotStage.environment).title,
        '请确认环境与放置位置能看清',
      );
    },
  );

  testWidgets(
    'first-shot reference stays usable on a narrow screen and opens comparison',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FirstShotReference(
              image: AssetImage('test/fixtures/synthetic.jpg'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('第一张对照 · 点击放大'));
      await tester.pumpAndSettle();
      expect(find.text('第一张照片对照'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('收起第一张对照'));
      await tester.pumpAndSettle();
      expect(find.text('查看第一张，对照放置位置'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
