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
  };
}

class PhotoSession {
  PhotoSession({
    required this.id,
    required this.directory,
    required this.settings,
    required this.startedAt,
    this.model = 'PP-PicoDet',
  });
  final String id;
  final Directory directory;
  final GuideSettings settings;
  final DateTime startedAt;
  final String model;
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
    );
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
  }) async {
    if (bytes.length < 3 || bytes[0] != 0xff || bytes[1] != 0xd8) {
      throw const FormatException('相机没有返回有效的 JPEG，请重试');
    }
    final filename =
        '${stage.name}_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final path = '${session.directory.path}/$filename';
    await File(path).writeAsBytes(bytes, flush: true);
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
    );
    // Re-taking the first image invalidates the second image's correspondence.
    if (stage == ShotStage.parcel) session.shots.remove(ShotStage.environment);
    session.shots[stage] = shot;
    session.history.add(shot);
    await writeReport(session, timings);
    return shot;
  }

  Future<void> writeReport(
    PhotoSession session,
    Map<String, Object> timings,
  ) async {
    final data = {
      'schemaVersion': 5,
      'id': session.id,
      'startedAt': session.startedAt.toIso8601String(),
      'platform': Platform.operatingSystem,
      'model': session.model,
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
