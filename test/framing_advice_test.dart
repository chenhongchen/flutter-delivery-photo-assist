import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_photo_assist/src/domain/framing.dart';
import 'package:delivery_photo_assist/src/domain/capture_guidance.dart';
import 'package:delivery_photo_assist/src/domain/guidance.dart';
import 'package:delivery_photo_assist/src/domain/clarity.dart';
import 'package:delivery_photo_assist/src/widgets/capture_status.dart';
import 'package:delivery_photo_assist/src/services/session_store.dart';

void main() {
  Map<String, Object> matched(double scale, [String reference = 'first']) => {
    'matched': true,
    'scale': scale,
    'inliers': 50,
    'inlierRatio': .7,
    'spread': .2,
    'scaleSpread': .08,
    'referenceId': reference,
  };
  SceneFacts facts() => SceneFacts(
    receivedAtMs: 500,
    clarity: FrameClarity({
      'global': {
        'laplacianVariance': 300,
        'contrastStd': 50,
        'meanLuma': 110,
        'edgeFraction': .2,
        'darkFraction': .02,
        'clippedFraction': 0,
        'analysisWidth': 240,
        'analysisHeight': 320,
      },
    }),
  );
  test(
    'same-scale scene is a red suggestion; wider scene becomes green only after fresh independent observations',
    () {
      final tracker = FramingTracker()..reset('first');
      tracker.add(FramingCheck.fromJson(matched(1)), 100);
      final near = const CaptureGuidance().evaluate(
        stage: ShotStage.environment,
        facts: facts(),
        settings: const GuideSettings(),
        nowMs: 600,
        stable: true,
        framing: tracker,
      );
      expect(near.state, CaptureState.attention);
      expect(near.title, contains('后退'));
      tracker.add(FramingCheck.fromJson(matched(.68)), 650);
      expect(tracker.ready(700), isFalse);
      tracker.add(FramingCheck.fromJson(matched(.69)), 1100);
      expect(tracker.ready(1200), isTrue);
      expect(tracker.ready(2700), isFalse);
      tracker.add(FramingCheck.fromJson(matched(.67)), 2800);
      expect(tracker.ready(2850), isFalse);
    },
  );
  test(
    'an unrelated reference or unreliable registration cannot create green advice',
    () {
      final tracker = FramingTracker()..reset('new');
      tracker.add(FramingCheck.fromJson(matched(.6, 'old')), 100);
      expect(tracker.ready(200), isFalse);
      expect(
        FramingCheck.fromJson({...matched(.6), 'inliers': 4}).state,
        FramingState.unmatched,
      );
      expect(
        FramingCheck.fromJson({...matched(.6), 'scaleSpread': .7}).state,
        FramingState.unmatched,
      );
      expect(
        FramingCheck.fromJson({...matched(.6), 'scale': double.nan}).state,
        FramingState.unmatched,
      );
    },
  );
  test('slow comparisons keep near advice until the next expected result', () {
    final tracker = FramingTracker()..reset('first');
    tracker.add(FramingCheck.fromJson(matched(1)), 100, maxGapMs: 3000);
    final advice = const CaptureGuidance().evaluate(
      stage: ShotStage.environment,
      facts: facts(),
      settings: const GuideSettings(),
      nowMs: 2600,
      stable: true,
      framing: tracker,
      sceneFreshMs: 3000,
      framingFreshMs: 3000,
    );
    expect(advice.reason, 'not_farther');
    tracker.add(FramingCheck.fromJson(matched(.68)), 2700, maxGapMs: 3000);
    tracker.add(FramingCheck.fromJson(matched(.69)), 4900, maxGapMs: 3000);
    expect(tracker.ready(5000, maxAgeMs: 3000), isTrue);
    expect(tracker.fresh(8001, maxAgeMs: 3000), isFalse);
  });
  testWidgets(
    'red, yellow and green shutters all respond; only an in-flight camera capture suppresses repeat taps',
    (tester) async {
      var count = 0;
      for (final state in CaptureState.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CaptureShutter(
                state: state,
                stageLabel: '第二张',
                onCapture: () => count++,
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('capture-shutter')));
        await tester.pump();
      }
      expect(count, 3);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CaptureShutter(
              state: CaptureState.ready,
              busy: true,
              stageLabel: '第二张',
              onCapture: () => count++,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('capture-shutter')));
      expect(count, 3);
    },
  );
  testWidgets(
    'status colors and icons distinguish suggestions without saying capture is forbidden',
    (tester) async {
      for (final state in CaptureState.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CaptureStatusBanner(
                decision: CaptureAdvice(state, '取景建议', '提示仅供参考，可直接拍照', 'test'),
              ),
            ),
          ),
        );
        expect(find.text('提示仅供参考，可直接拍照'), findsOneWidget);
        expect(
          find.byIcon(
            state == CaptureState.ready
                ? Icons.check_circle
                : state == CaptureState.attention
                ? Icons.warning_amber_rounded
                : Icons.hourglass_top,
          ),
          findsOneWidget,
        );
      }
      expect(captureColor(CaptureState.attention), captureRed);
      expect(captureColor(CaptureState.ready), captureGreen);
    },
  );
  test(
    'saving a second photo with near-scene advice records it normally and does not pretend the advice passed',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'delivery-advisory-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final session = PhotoSession(
        id: 'advisory-test',
        directory: directory,
        settings: const GuideSettings(),
        startedAt: DateTime.now(),
      );
      final bytes = await File('test/fixtures/synthetic.jpg').readAsBytes();
      final store = SessionStore();
      for (final stage in ShotStage.values) {
        await store.save(
          session: session,
          stage: stage,
          bytes: bytes,
          tapClock: Stopwatch()..start(),
          captureMs: 20,
          hint: '建议再后退一些',
          sceneAgeMs: 0,
          scene: null,
          timings: {},
          guidance: {
            'state': 'attention',
            'framingAdvice': matched(1),
            'scope': 'live_advice_only',
          },
        );
      }
      expect(session.complete, isTrue);
      final saved =
          jsonDecode(await File(session.reportPath).readAsString()) as Map;
      expect((saved['shots'] as List).length, 2);
      expect(
        ((saved['shots'] as List)[1]['guidance'] as Map)['state'],
        'attention',
      );
      expect((saved['shots'] as List)[1]['validation'], isNull);
    },
  );
}
