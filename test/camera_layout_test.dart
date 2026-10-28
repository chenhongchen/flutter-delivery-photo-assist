import 'dart:io';
import 'dart:ui' as ui;
import 'package:delivery_photo_assist/src/domain/capture_guidance.dart';
import 'package:delivery_photo_assist/src/domain/guidance.dart';
import 'package:delivery_photo_assist/src/widgets/camera_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final icons = File(
      '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (await icons.exists()) {
      await (FontLoader('MaterialIcons')..addFont(
            icons.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          ))
          .load();
    }
    final font = File('/System/Library/Fonts/STHeiti Light.ttc');
    if (await font.exists()) {
      await (FontLoader('QaChinese')..addFont(
            font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          ))
          .load();
    }
  });
  testWidgets(
    'status, zoom, save count and reference changes never move the shutter or dock',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final snapshots = <String, List<double>>{};
      Rect? shutter, dock, tabs, zoomOne;
      var galleryTaps = 0;
      final boundary = GlobalKey();
      for (final state in CaptureState.values) {
        final stage = state == CaptureState.attention
            ? ShotStage.parcel
            : ShotStage.environment;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'QaChinese'),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                padding: EdgeInsets.only(top: 44, bottom: 24),
              ),
              child: Scaffold(
                body: RepaintBoundary(
                  key: boundary,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'test/fixtures/synthetic.jpg',
                        fit: BoxFit.cover,
                      ),
                      CameraChrome(
                        stage: stage,
                        savedStages: state == CaptureState.ready
                            ? ShotStage.values.toSet()
                            : {},
                        advice: CaptureAdvice(
                          state,
                          state == CaptureState.ready
                              ? '取景较合适，可以拍照'
                              : state == CaptureState.attention
                              ? '包裹细节太小，请靠近一些'
                              : '正在确认画面',
                          state == CaptureState.ready
                              ? '包裹位置与周围环境较清楚，提示仅供参考'
                              : '同时保留周围能说明放置位置的特征',
                          'test',
                        ),
                        capturing: false,
                        boxes: false,
                        torch: false,
                        zoom: state == CaptureState.ready ? 1.4 : 1,
                        minimumZoom: .5,
                        maximumZoom: 5,
                        zoomAvailable: true,
                        qualityLabel: state == CaptureState.attention
                            ? '可能模糊'
                            : '较清晰',
                        firstShot: stage == ShotStage.environment
                            ? const AssetImage('test/fixtures/synthetic.jpg')
                            : null,
                        notice: state == CaptureState.ready
                            ? '两张已保存，可回看或重新拍摄'
                            : null,
                        onBack: () {},
                        onMore: () {},
                        onBoxes: (_) {},
                        onStage: (_) {},
                        onZoom: (_) {},
                        onTorch: () {},
                        onCapture: () {},
                        onReview: () {},
                        onReference: () {},
                        onGallery: () => galleryTaps++,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final current = tester.getRect(
          find.byKey(const Key('capture-shutter')),
        );
        final currentDock = tester.getRect(
          find.byKey(const Key('camera-bottom-dock')),
        );
        final currentTabs = tester.getRect(
          find.byKey(const Key('camera-stage-tabs')),
        );
        final currentZoom = tester.getRect(
          find.byKey(const Key('camera-zoom-1.0')),
        );
        shutter ??= current;
        dock ??= currentDock;
        tabs ??= currentTabs;
        zoomOne ??= currentZoom;
        expect(current, shutter);
        expect(currentDock, dock);
        expect(currentTabs, tabs);
        expect(currentZoom, zoomOne);
        await tester.tap(find.byKey(const Key('camera-gallery')));
        await tester.pumpAndSettle();
        snapshots[state.name] = [
          current.left,
          current.top,
          current.width,
          current.height,
        ];
        if (Platform.isMacOS) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final out = File('.tools/v15-ui/camera-${state.name}.png');
            await out.parent.create(recursive: true);
            await out.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
      expect(galleryTaps, 3);
      // These are rendered UI fixtures, not screenshots of live recognition or business accuracy evidence.
      debugPrint('FIXED_CAMERA_LAYOUT $snapshots');
    },
  );
  testWidgets('small screen and larger text keep the main controls visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: CameraChrome(
              stage: ShotStage.parcel,
              savedStages: {},
              advice: const CaptureAdvice(
                CaptureState.attention,
                '包裹细节太小，请靠近一些',
                '同时保留周围能说明放置位置的特征',
                'test',
              ),
              capturing: false,
              boxes: false,
              torch: false,
              zoom: 1,
              minimumZoom: 1,
              maximumZoom: 2,
              zoomAvailable: true,
              qualityLabel: '待确认',
              onBack: () {},
              onMore: () {},
              onBoxes: (_) {},
              onStage: (_) {},
              onZoom: (_) {},
              onTorch: () {},
              onCapture: () {},
              onReview: () {},
              onReference: () {},
              onGallery: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byKey(const Key('capture-shutter'))).bottom,
      lessThan(568),
    );
    expect(find.text('相册'), findsOneWidget);
  });
}
