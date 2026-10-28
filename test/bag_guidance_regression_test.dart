import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:delivery_photo_assist/src/domain/guidance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'synthetic bag and uncertain context observations do not demand repeated repositioning',
    () {
      final samples =
          jsonDecode(
                File('test/fixtures/synthetic_framing.json').readAsStringSync(),
              )
              as List;
      for (final sample in samples.cast<Map<String, dynamic>>()) {
        final facts = SceneFacts(
          receivedAtMs: 0,
          objects: (sample['objects'] as List).map((o) {
            final b = (o['box'] as List).cast<num>();
            return SceneObject(
              o['label'] as String,
              (o['confidence'] as num).toDouble(),
              Rect.fromLTRB(
                b[0].toDouble(),
                b[1].toDouble(),
                b[2].toDouble(),
                b[3].toDouble(),
              ),
            );
          }).toList(),
        );
        final hint = const GuidanceRules().evaluate(
          facts,
          ShotStage.values.byName(sample['stage'] as String),
          const GuideSettings(),
        );
        expect(
          hint.code,
          HintCode.contextUncertain,
          reason: sample['scenario'] as String,
        );
        expect(hint.needsAttention, isFalse);
        // Relaxed prompts must not disguise a model miss as confirmed compliance.
        expect(hint.isReady, isFalse);
      }
    },
  );
}
