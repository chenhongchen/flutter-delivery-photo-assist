import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../domain/guidance.dart';

class CapturedShot {
  CapturedShot({
    required this.stage,
    required this.path,
    required this.captureMs,
    required this.savedMs,
    required this.at,
    required this.hint,
    required this.sceneAgeMs,
    required this.scene,
    this.quality,
    this.captureSource,
    this.guidance,
    this.framingReferencePath,
  });
  final ShotStage stage;
  final String path;
  final double captureMs;
  final double savedMs;
  final DateTime at;
  final String hint;
  final int? sceneAgeMs;
  final Map<String, Object>? scene;
  final Map<String, dynamic>? quality;
  final String? captureSource;
  final Map<String, dynamic>? guidance;

  /// 第一张快门时的预览参考，与原始照片画幅可能不同。
  final String? framingReferencePath;
  Map<String, Object?> toJson() => {
    'stage': stage.name,
    'file': path.split(Platform.pathSeparator).last,
    'captureToJpegBytesMs': captureMs,
    'tapToSavedJpegMs': savedMs,
    'at': at.toIso8601String(),
    'hintAtTap': hint,
    'sceneAgeAtTapMs': sceneAgeMs,
    'sceneAtTap': scene,
    'quality': quality,
    'captureSource': captureSource,
    'guidance': guidance,
    if (framingReferencePath != null)
      'framingReferenceFile': framingReferencePath!
          .split(Platform.pathSeparator)
          .last,
  };
}

class PhotoSession {
  PhotoSession({
    required this.id,
    required this.directory,
    required this.settings,
    required this.startedAt,
    this.model = 'PP-PicoDet',
    this.retakeStage,
  });
  final String id;
  final Directory directory;
  final GuideSettings settings;
  final DateTime startedAt;
  final String model;
  final ShotStage? retakeStage;
  final Map<ShotStage, CapturedShot> shots = {};
  final List<CapturedShot> history = [];
  bool get complete => shots.length == 2;
  String get reportPath => '${directory.path}/report.json';
}

class SessionStore {
  Future<Directory> root() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(
      '${docs.path}/delivery_photo_sessions',
    ).create(recursive: true);
  }

  Future<PhotoSession> create(
    GuideSettings settings, {
    String model = 'PP-PicoDet',
    ShotStage? retakeStage,
  }) async {
    final at = DateTime.now();
    final id = at.microsecondsSinceEpoch.toString();
    final dir = await Directory('${(await root()).path}/$id').create();
    return PhotoSession(
      id: id,
      directory: dir,
      settings: settings,
      startedAt: at,
      model: model,
      retakeStage: retakeStage,
    );
  }

  /// 新建独立修改副本。取消、失败或保存均不会修改上一份结果。
  Future<PhotoSession> createRetake({
    required GuideSettings settings,
    required String model,
    required ShotStage stage,
    required File parcelPhoto,
    required File environmentPhoto,
    required File report,
  }) async {
    final session = await create(settings, model: model, retakeStage: stage);
    try {
      Map<String, dynamic> previous = {};
      try {
        final decoded = jsonDecode(await report.readAsString());
        if (decoded is Map<String, dynamic>) previous = decoded;
      } on FileSystemException {
        // 宿主可能只保留照片；缺少诊断报告不影响重拍。
      } on FormatException {
        // 不从损坏的报告恢复识别结论。
      }
      final saved = previous['shots'];
      for (final shotStage in ShotStage.values) {
        final source = shotStage == ShotStage.parcel
            ? parcelPhoto
            : environmentPhoto;
        final copy = await source.copy(
          '${session.directory.path}/${shotStage.name}_original.jpg',
        );
        final data = saved is List
            ? saved
                  .whereType<Map<String, dynamic>>()
                  .where((s) => s['stage'] == shotStage.name)
                  .firstOrNull
            : null;
        String? referencePath;
        final referenceName = data?['framingReferenceFile'];
        if (shotStage == ShotStage.parcel &&
            referenceName is String &&
            RegExp(r'^parcel_[a-zA-Z0-9_.-]+\.jpg$').hasMatch(referenceName)) {
          final reference = File('${report.parent.path}/$referenceName');
          if (await reference.exists()) {
            referencePath = (await reference.copy(
              '${session.directory.path}/parcel_original.reference.jpg',
            )).path;
          }
        }
        final shot = CapturedShot(
          stage: shotStage,
          path: copy.path,
          captureMs: (data?['captureToJpegBytesMs'] as num?)?.toDouble() ?? 0,
          savedMs: (data?['tapToSavedJpegMs'] as num?)?.toDouble() ?? 0,
          at:
              DateTime.tryParse(data?['at'] as String? ?? '') ??
              session.startedAt,
          hint: data?['hintAtTap'] as String? ?? '保留原照片',
          sceneAgeMs: (data?['sceneAgeAtTapMs'] as num?)?.toInt(),
          scene: (data?['sceneAtTap'] as Map<String, dynamic>?)
              ?.cast<String, Object>(),
          quality: data?['quality'] as Map<String, dynamic>?,
          captureSource: data?['captureSource'] as String? ?? 'preserved',
          guidance: data?['guidance'] as Map<String, dynamic>?,
          framingReferencePath: referencePath,
        );
        session.shots[shotStage] = shot;
        session.history.add(shot);
      }
      return session;
    } catch (_) {
      await session.directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<CapturedShot> save({
    required PhotoSession session,
    required ShotStage stage,
    required Uint8List bytes,
    required Stopwatch tapClock,
    required double captureMs,
    required String hint,
    required int? sceneAgeMs,
    required SceneFacts? scene,
    required Map<String, Object> timings,
    Map<String, dynamic>? quality,
    String? captureSource,
    Map<String, dynamic>? guidance,
    Uint8List? framingReference,
  }) async {
    if (bytes.length < 3 || bytes[0] != 0xff || bytes[1] != 0xd8) {
      throw const FormatException('相机没有返回有效的 JPEG，请重试');
    }
    final filename =
        '${stage.name}_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final path = '${session.directory.path}/$filename';
    await File(path).writeAsBytes(bytes, flush: true);
    String? referencePath;
    if (stage == ShotStage.parcel && framingReference != null) {
      referencePath = '$path.reference.jpg';
      await File(referencePath).writeAsBytes(framingReference, flush: true);
    }
    final shot = CapturedShot(
      stage: stage,
      path: path,
      captureMs: captureMs,
      savedMs: tapClock.elapsedMicroseconds / 1000,
      at: DateTime.now(),
      hint: hint,
      sceneAgeMs: sceneAgeMs,
      scene: scene?.toJson(),
      quality: quality,
      captureSource: captureSource,
      guidance: guidance,
      framingReferencePath: referencePath,
    );
    final previous = session.shots[stage];
    session.shots[stage] = shot;
    session.history.add(shot);
    try {
      await writeReport(session, timings);
    } catch (_) {
      if (previous == null) {
        session.shots.remove(stage);
      } else {
        session.shots[stage] = previous;
      }
      session.history.remove(shot);
      rethrow;
    }
    return shot;
  }

  Future<void> writeReport(
    PhotoSession session,
    Map<String, Object> timings,
  ) async {
    final data = {
      'schemaVersion': 6,
      'id': session.id,
      'startedAt': session.startedAt.toIso8601String(),
      'platform': Platform.operatingSystem,
      'model': session.model,
      'captureMode': session.retakeStage == null ? 'pair' : 'retake',
      if (session.retakeStage != null) 'retakeStage': session.retakeStage!.name,
      'guidancePolicy':
          'advisory-v4; live relative scene scale; shutter always available; no post-photo framing verification; no arrangement check',
      'complete': session.complete,
      'settings': session.settings.toJson(),
      'shots': session.shots.values.map((s) => s.toJson()).toList(),
      'captureHistory': session.history.map((s) => s.toJson()).toList(),
      'timings': timings,
      'limitations': [
        'Generic box/bag candidates are not verified delivery parcels.',
        'Presence of an anchor does not verify a correct address or customer findability.',
        'Missing detections do not establish missing scene elements; framing extremes are suggestions only.',
        'Live framing advice compares visual features and relative scale, not metres or delivery address; it does not block saving.',
        'Arrangement/tidiness checking is not included.',
        'Complete means two photos saved, not that the photo rules passed. No post-photo framing verification is performed.',
        'Photos use the official Flutter camera plugin still-image capture; saved photos are not preview screenshots.',
        'Clarity is a spatial-detail heuristic, not a guarantee of readability; low-texture images remain uncertain.',
        'Quality and text are live preview references, not post-photo verification. A saved photo has no automatic acceptance verdict.',
      ],
    };
    final temp = File('${session.reportPath}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    await temp.rename(session.reportPath);
  }

  Future<List<File>> listReports() async {
    final dir = await root();
    final reports = <File>[];
    await for (final item in dir.list()) {
      if (item is Directory) {
        final file = File('${item.path}/report.json');
        if (await file.exists()) reports.add(file);
      }
    }
    return reports..sort((a, b) => b.path.compareTo(a.path));
  }
}
