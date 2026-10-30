import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:delivery_photo_assist/delivery_photo_assist.dart';
import 'package:delivery_photo_assist/src/services/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// 示例是独立应用，放在根测试中核对真实接入流程，避免互相添加包依赖。
// ignore: avoid_relative_lib_imports
import '../example/lib/main.dart' as demo;

const _model = PicoDetModel(path: '', labels: [], inputSize: 0);
const _permission = MethodChannel('flutter.baseflow.com/permissions/methods');
const _paths = MethodChannel('plugins.flutter.io/path_provider');
const _native = MethodChannel('delivery_photo_assist');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late _Camera camera;
  late CameraPlatform originalCamera;
  late DeliveryPhotoResult previous;
  late Uint8List jpeg;
  late PhotoSession originalSession;

  Future<CapturedShot> save(
    PhotoSession session,
    ShotStage stage,
    Uint8List bytes, {
    SessionStore? store,
    Uint8List? reference,
  }) => (store ?? SessionStore()).save(
    session: session,
    stage: stage,
    bytes: bytes,
    tapClock: Stopwatch()..start(),
    captureMs: 12,
    hint: '原照片提示',
    sceneAgeMs: null,
    scene: null,
    timings: {},
    captureSource: 'camera_photo',
    framingReference: reference,
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('delivery-retake-');
    jpeg = await File('test/fixtures/synthetic.jpg').readAsBytes();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_paths, (_) async => temp.path);
    messenger.setMockMethodCallHandler(_permission, (_) async => {1: 1});
    messenger.setMockMethodCallHandler(
      _native,
      (_) async => <String, Object>{},
    );
    originalCamera = CameraPlatform.instance;
    camera = _Camera(temp, jpeg);
    CameraPlatform.instance = camera;
    originalSession = await SessionStore().create(const GuideSettings());
    final first = await save(originalSession, ShotStage.parcel, jpeg);
    final second = await save(
      originalSession,
      ShotStage.environment,
      Uint8List.fromList([...jpeg, 2]),
    );
    previous = DeliveryPhotoResult(
      parcelPhoto: File(first.path),
      environmentPhoto: File(second.path),
      report: File(originalSession.reportPath),
    );
  });

  tearDown(() async {
    CameraPlatform.instance = originalCamera;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [_paths, _permission, _native]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    await temp.delete(recursive: true);
  });

  Future<void> tapAndFlush(WidgetTester tester, Finder target) async {
    await tester.runAsync(() async {
      await tester.tap(target);
      // 仅让测试中的真实磁盘写入完成，不模拟相机/模型性能。
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    // 图片解码和文件写入会跨越一次 widget pump，让真实 I/O 持续前进。
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }

  Future<void> host(WidgetTester tester, GlobalKey<_HostState> key) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _Host(key: key, previous: previous),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('initial capture still takes two photos before returning', (
    tester,
  ) async {
    final key = GlobalKey<_HostState>();
    await host(tester, key);
    await tapAndFlush(tester, find.text('开始'));
    expect(find.text('配送拍照'), findsOneWidget);
    await tapAndFlush(tester, find.byKey(const Key('capture-shutter')));
    expect(find.text('配送拍照'), findsOneWidget);
    expect(key.currentState!.result, same(previous));
    await tapAndFlush(tester, find.byKey(const Key('capture-shutter')));
    expect(find.text('配送拍照'), findsNothing);
    expect(key.currentState!.result, isNot(same(previous)));
    expect(camera.captures, 2);
  });

  for (final stage in ShotStage.values) {
    testWidgets(
      '${stage.name}: one capture returns and preserves the other photo',
      (tester) async {
        final key = GlobalKey<_HostState>();
        await host(tester, key);
        await tapAndFlush(tester, find.text('修改${stage.label}'));
        expect(find.text('重拍${stage.label}'), findsOneWidget);
        for (final target in ShotStage.values) {
          final tab = tester.widget<TextButton>(
            find.byKey(ValueKey('camera-stage-${target.name}')),
          );
          expect(tab.onPressed, isNull);
        }
        await tapAndFlush(tester, find.byKey(const Key('capture-shutter')));
        expect(find.text('重拍${stage.label}'), findsNothing);
        final result = key.currentState!.result;
        expect(result, isNot(same(previous)));
        expect(camera.captures, 1);
        await tester.runAsync(() async {
          expect(await previous.parcelPhoto.readAsBytes(), jpeg);
          expect(await previous.environmentPhoto.readAsBytes(), [...jpeg, 2]);
          expect(
            await result.parcelPhoto.readAsBytes(),
            stage == ShotStage.parcel ? [...jpeg, 101] : jpeg,
          );
          expect(
            await result.environmentPhoto.readAsBytes(),
            stage == ShotStage.environment ? [...jpeg, 101] : [...jpeg, 2],
          );
          final report = jsonDecode(await result.report.readAsString()) as Map;
          expect(report['complete'], isTrue);
          expect(report['retakeStage'], stage.name);
          expect((report['shots'] as List).length, 2);
        });
      },
    );

    testWidgets(
      '${stage.name}: cancelling preserves originals and removes only the edit copy',
      (tester) async {
        final key = GlobalKey<_HostState>();
        await host(tester, key);
        await tapAndFlush(tester, find.text('修改${stage.label}'));
        await tapAndFlush(tester, find.byTooltip('返回'));
        expect(key.currentState!.result, same(previous));
        expect(camera.captures, 0);
        await tester.runAsync(() async {
          final sessions = await originalSession.directory.parent
              .list()
              .toList();
          expect(sessions.map((d) => d.path), [originalSession.directory.path]);
          expect(await previous.parcelPhoto.readAsBytes(), jpeg);
          expect(await previous.environmentPhoto.readAsBytes(), [...jpeg, 2]);
        });
      },
    );
  }

  testWidgets(
    'failed capture stays on the selected photo; retry returns normally',
    (tester) async {
      final key = GlobalKey<_HostState>();
      await host(tester, key);
      await tapAndFlush(tester, find.text('修改第一张'));
      camera.failNext = true;
      await tapAndFlush(tester, find.byKey(const Key('capture-shutter')));
      expect(find.text('重拍第一张'), findsOneWidget);
      expect(key.currentState!.result, same(previous));
      await tapAndFlush(tester, find.byKey(const Key('capture-shutter')));
      expect(find.text('重拍第一张'), findsNothing);
      expect(key.currentState!.result, isNot(same(previous)));
    },
  );

  testWidgets(
    'example photo buttons and images edit only their selected photo',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final manifest = utf8.encode(
        jsonEncode({
          'name': 'test',
          'labels': [],
          'inputSize': 0,
          'boxesOutput': 'boxes',
          'countOutput': 'count',
        }),
      );
      // 示例使用合成图片和无推理测试模型，仅验证真实返回页及接口流程。
      messenger.setMockMessageHandler('flutter/assets', (message) async {
        final name = const StringCodec().decodeMessage(message);
        if (name == 'assets/models/picodet_s_320.onnx') return ByteData(1);
        if (name == 'assets/models/picodet_s_320.json') {
          return ByteData.sublistView(Uint8List.fromList(manifest));
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMessageHandler('flutter/assets', null);
        rootBundle.evict('assets/models/picodet_s_320.onnx');
        rootBundle.evict('assets/models/picodet_s_320.json');
      });
      await tester.pumpWidget(const MaterialApp(home: demo.ExampleHome()));
      await tapAndFlush(tester, find.text('开始拍照'));
      await tapAndFlush(tester, find.byKey(const Key('capture-shutter')));
      await tapAndFlush(tester, find.byKey(const Key('capture-shutter')));
      expect(find.byKey(const Key('edit-parcel')), findsOneWidget);
      expect(find.byKey(const Key('edit-environment')), findsOneWidget);
      File photo(ShotStage stage) =>
          (tester
                      .widget<Image>(
                        find.byKey(ValueKey('photo-${stage.name}')),
                      )
                      .image
                  as FileImage)
              .file;
      final firstBefore = photo(ShotStage.parcel);
      final secondBefore = photo(ShotStage.environment);
      await tester.ensureVisible(find.byKey(const Key('edit-parcel')));
      await tester.pumpAndSettle();
      await tapAndFlush(tester, find.byKey(const Key('edit-parcel')));
      expect(find.text('重拍第一张'), findsOneWidget);
      await tapAndFlush(tester, find.byKey(const Key('capture-shutter')));
      await tester.runAsync(() async {
        expect(
          await photo(ShotStage.parcel).readAsBytes(),
          isNot(await firstBefore.readAsBytes()),
        );
        expect(
          await photo(ShotStage.environment).readAsBytes(),
          await secondBefore.readAsBytes(),
        );
      });
      final firstAfter = photo(ShotStage.parcel);
      await tester.ensureVisible(find.byKey(const Key('photo-environment')));
      await tester.pumpAndSettle();
      await tapAndFlush(tester, find.byKey(const Key('photo-environment')));
      expect(find.text('重拍第二张'), findsOneWidget);
      await tapAndFlush(tester, find.byKey(const Key('capture-shutter')));
      await tester.runAsync(() async {
        expect(
          await photo(ShotStage.parcel).readAsBytes(),
          await firstAfter.readAsBytes(),
        );
        expect(
          await photo(ShotStage.environment).readAsBytes(),
          isNot(await secondBefore.readAsBytes()),
        );
      });
      expect(camera.captures, 4);
    },
  );

  test(
    'edit snapshots preserve the exact preview reference across repeated edits',
    () async {
      await save(originalSession, ShotStage.parcel, jpeg, reference: jpeg);
      expect(originalSession.complete, isTrue); // 不因第一张重拍清掉第二张。
      final store = SessionStore();
      Future<PhotoSession> copy(
        File report,
        File first,
        File second,
        ShotStage stage,
      ) => store.createRetake(
        settings: const GuideSettings(),
        model: 'test',
        stage: stage,
        parcelPhoto: first,
        environmentPhoto: second,
        report: report,
      );
      final edit = await copy(
        File(originalSession.reportPath),
        File(originalSession.shots[ShotStage.parcel]!.path),
        previous.environmentPhoto,
        ShotStage.environment,
      );
      final ref = edit.shots[ShotStage.parcel]!.framingReferencePath!;
      expect(await File(ref).readAsBytes(), jpeg);
      await save(edit, ShotStage.environment, jpeg);
      final again = await copy(
        File(edit.reportPath),
        File(edit.shots[ShotStage.parcel]!.path),
        File(edit.shots[ShotStage.environment]!.path),
        ShotStage.parcel,
      );
      expect(
        await File(
          again.shots[ShotStage.parcel]!.framingReferencePath!,
        ).readAsBytes(),
        jpeg,
      );
      await save(again, ShotStage.parcel, jpeg);
      expect(again.complete, isTrue);
      expect(again.shots[ShotStage.parcel]!.framingReferencePath, isNull);
      expect(await File(ref).exists(), isTrue);
    },
  );

  test(
    'missing legacy report allows editing without claiming a framing reference',
    () async {
      await previous.report.delete();
      final edit = await SessionStore().createRetake(
        settings: const GuideSettings(),
        model: 'test',
        stage: ShotStage.environment,
        parcelPhoto: previous.parcelPhoto,
        environmentPhoto: previous.environmentPhoto,
        report: previous.report,
      );
      expect(edit.complete, isTrue);
      expect(edit.shots[ShotStage.parcel]!.framingReferencePath, isNull);
      expect(edit.shots[ShotStage.parcel]!.captureSource, 'preserved');
    },
  );

  test(
    'failed report save rolls back the replacement and preserves the other photo',
    () async {
      final oldFirst = originalSession.shots[ShotStage.parcel];
      final oldSecond = originalSession.shots[ShotStage.environment];
      await expectLater(
        save(originalSession, ShotStage.parcel, jpeg, store: _FailingStore()),
        throwsA(isA<FileSystemException>()),
      );
      expect(originalSession.shots[ShotStage.parcel], same(oldFirst));
      expect(originalSession.shots[ShotStage.environment], same(oldSecond));
      expect(originalSession.history.length, 2);
    },
  );
}

class _FailingStore extends SessionStore {
  @override
  Future<void> writeReport(
    PhotoSession session,
    Map<String, Object> timings,
  ) async {
    throw const FileSystemException('模拟写入失败');
  }
}

class _Host extends StatefulWidget {
  const _Host({super.key, required this.previous});
  final DeliveryPhotoResult previous;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late DeliveryPhotoResult result = widget.previous;
  Future<void> open([ShotStage? stage]) async {
    final next = stage == null
        ? await DeliveryPhotoAssist.capture(context, model: _model)
        : await DeliveryPhotoAssist.retake(
            context,
            model: _model,
            previous: result,
            stage: stage,
          );
    if (mounted && next != null) setState(() => result = next);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextButton(onPressed: open, child: const Text('开始')),
        for (final stage in ShotStage.values)
          TextButton(
            onPressed: () => open(stage),
            child: Text('修改${stage.label}'),
          ),
      ],
    ),
  );
}

/// 只替代系统相机，不替代组件导航、会话保存和公开 API。
class _Camera extends CameraPlatform {
  _Camera(this.temp, this.jpeg);
  final Directory temp;
  final Uint8List jpeg;
  final _errors = StreamController<CameraErrorEvent>.broadcast();
  int captures = 0;
  bool failNext = false;
  @override
  Future<List<CameraDescription>> availableCameras() async => [
    const CameraDescription(
      name: 'test-back',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
      lensType: CameraLensType.wide,
    ),
  ];
  @override
  Future<int> createCamera(
    CameraDescription description,
    ResolutionPreset? preset, {
    bool enableAudio = false,
  }) async => 1;
  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {}
  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        CameraInitializedEvent(
          cameraId,
          1280,
          720,
          ExposureMode.auto,
          false,
          FocusMode.auto,
          false,
        ),
      );
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _errors.stream;
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Future<void> lockCaptureOrientation(
    int cameraId,
    DeviceOrientation orientation,
  ) async {}
  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async {}
  @override
  Future<double> getMinZoomLevel(int cameraId) async => 1;
  @override
  Future<double> getMaxZoomLevel(int cameraId) async => 4;
  @override
  Future<void> setZoomLevel(int cameraId, double zoom) async {}
  @override
  Future<void> pausePreview(int cameraId) async {}
  @override
  Future<void> resumePreview(int cameraId) async {}
  @override
  Future<void> dispose(int cameraId) async {}
  @override
  Widget buildPreview(int cameraId) => const ColoredBox(color: Colors.black);
  @override
  Stream<CameraImageData> onStreamedFrameAvailable(
    int cameraId, {
    CameraImageStreamOptions? options,
  }) => const Stream.empty();
  @override
  bool supportsImageStreaming() => true;
  @override
  Future<XFile> takePicture(int cameraId) async {
    if (failNext) {
      failNext = false;
      throw PlatformException(code: 'capture_failed', message: '模拟相机失败');
    }
    captures++;
    final file = File('${temp.path}/camera_$captures.jpg');
    await file.writeAsBytes([...jpeg, 100 + captures]);
    return XFile(file.path);
  }
}
