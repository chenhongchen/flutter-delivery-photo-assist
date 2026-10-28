import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:dartcv4/dartcv.dart' as cv;
import '../domain/framing.dart';

typedef _Point = ({double x, double y});

class _Features {
  _Features(this.points, this.descriptors, this.width, this.height);
  final List<_Point> points;
  final cv.Mat descriptors;
  final int width, height;
  void dispose() => descriptors.dispose();
}

/// Runs only in the worker isolate (also used by local native regression scripts).
class FramingEngine {
  FramingEngine() {
    cv.setNumThreads(1);
    _detector = cv.SIFT.create(nfeatures: 1000);
    _matcher = cv.BFMatcher.create(type: cv.NORM_L2);
  }
  late final cv.SIFT _detector;
  late final cv.BFMatcher _matcher;
  _Features? _reference;
  String _referenceId = '';

  _Features _extract(Uint8List jpeg) {
    final encoded = cv.VecUChar.fromList(jpeg);
    cv.Mat? image, small, mask;
    try {
      image = cv.imdecodeVec(encoded, cv.IMREAD_GRAYSCALE);
      if (image.isEmpty) {
        throw const FormatException('Image could not be decoded');
      }
      final scale = math.min(1.0, 768 / math.max(image.cols, image.rows));
      small = scale < 1
          ? cv.resize(image, (
              (image.cols * scale).round(),
              (image.rows * scale).round(),
            ))
          : image;
      mask = cv.Mat.empty();
      final (keys, descriptors) = _detector.detectAndCompute(small, mask);
      try {
        final points = <_Point>[];
        for (var i = 0; i < keys.length; i++) {
          final key = keys[i];
          points.add((x: key.x, y: key.y));
          key.dispose();
        }
        return _Features(points, descriptors, small.cols, small.rows);
      } finally {
        keys.dispose();
      }
    } finally {
      mask?.dispose();
      if (small != null && !identical(small, image)) small.dispose();
      image?.dispose();
      encoded.dispose();
    }
  }

  Map<String, Object> setReference(Uint8List jpeg, String id) {
    final next = _extract(jpeg);
    _reference?.dispose();
    _reference = next;
    _referenceId = id;
    return {'referenceId': id, 'features': next.points.length};
  }

  Map<String, Object> compare(Uint8List jpeg) {
    final clock = Stopwatch()..start();
    final reference = _reference;
    Map<String, Object> result(Map<String, Object> fields) => {
      'referenceId': _referenceId,
      'matched': false,
      ...fields,
      'processingMs': clock.elapsedMicroseconds / 1000,
    };
    if (reference == null || reference.descriptors.isEmpty) return result({});
    final frame = _extract(jpeg);
    try {
      if (frame.descriptors.isEmpty) return result({});
      final matches = _matcher.knnMatch(
        reference.descriptors,
        frame.descriptors,
        2,
      );
      final pairs = <(_Point, _Point)>[];
      try {
        for (var i = 0; i < matches.length; i++) {
          final row = matches[i];
          try {
            if (row.length < 2) continue;
            final a = row[0], b = row[1];
            try {
              if (a.distance < .75 * b.distance) {
                pairs.add((
                  reference.points[a.queryIdx],
                  frame.points[a.trainIdx],
                ));
              }
            } finally {
              a.dispose();
              b.dispose();
            }
          } finally {
            row.dispose();
          }
        }
      } finally {
        matches.dispose();
      }
      if (pairs.length < 16) return result({'goodMatches': pairs.length});
      final source = cv.Mat.fromList(pairs.length, 1, cv.MatType.CV_32FC2, [
        for (final p in pairs) ...[p.$1.x, p.$1.y],
      ]);
      final target = cv.Mat.fromList(pairs.length, 1, cv.MatType.CV_32FC2, [
        for (final p in pairs) ...[p.$2.x, p.$2.y],
      ]);
      final mask = cv.Mat.empty();
      cv.Mat? transform;
      try {
        transform = cv.findHomography(
          source,
          target,
          method: cv.RANSAC,
          ransacReprojThreshold: 3,
          mask: mask,
        );
        if (transform.isEmpty || mask.isEmpty) return result({});
        final flags = mask.data;
        final inliers = [
          for (var i = 0; i < pairs.length; i++)
            if (flags[i] != 0) pairs[i],
        ];
        if (inliers.length < 16) return result({'inliers': inliers.length});
        final xs = inliers.map((p) => p.$1.x).toList(),
            ys = inliers.map((p) => p.$1.y).toList();
        final width =
            (xs.reduce(math.max) - xs.reduce(math.min)) / reference.width;
        final height =
            (ys.reduce(math.max) - ys.reduce(math.min)) / reference.height;
        final spread = width * height;
        final rs = math.min(reference.width, reference.height).toDouble();
        final fs = math.min(frame.width, frame.height).toDouble();
        // Keep spatial registration checks on every inlier, but bound the O(n²) scale estimator.
        final scalePoints = inliers.length <= 160
            ? inliers
            : [
                for (var k = 0; k < 160; k++)
                  inliers[(k * (inliers.length - 1) / 159).round()],
              ];
        final ratios = <double>[];
        for (var i = 0; i < scalePoints.length; i++) {
          for (var j = 0; j < i; j++) {
            final a = scalePoints[i], b = scalePoints[j];
            final before =
                math.sqrt(
                  math.pow(a.$1.x - b.$1.x, 2) + math.pow(a.$1.y - b.$1.y, 2),
                ) /
                rs;
            if (before < .16) continue;
            final after =
                math.sqrt(
                  math.pow(a.$2.x - b.$2.x, 2) + math.pow(a.$2.y - b.$2.y, 2),
                ) /
                fs;
            final ratio = after / before;
            if (ratio.isFinite && ratio > 0) ratios.add(ratio);
          }
        }
        if (ratios.length < 20 || width < .15 || height < .12) {
          return result({'inliers': inliers.length});
        }
        ratios.sort();
        double quantile(double p) => ratios[((ratios.length - 1) * p).round()];
        final scale = quantile(.5),
            variation = (quantile(.75) - quantile(.25)) / scale;
        return result({
          'matched': true,
          'scale': scale,
          'inliers': inliers.length,
          'inlierRatio': inliers.length / pairs.length,
          'spread': spread,
          'scaleSpread': variation,
          'goodMatches': pairs.length,
        });
      } finally {
        transform?.dispose();
        source.dispose();
        target.dispose();
        mask.dispose();
      }
    } finally {
      frame.dispose();
    }
  }

  void dispose() {
    _reference?.dispose();
    _reference = null;
    _detector.dispose();
    _matcher.dispose();
  }
}

void _framingWorker(SendPort parent) {
  final inbox = ReceivePort();
  parent.send(inbox.sendPort);
  FramingEngine? engine;
  inbox.listen((dynamic message) {
    final data = message as Map;
    final id = data['id'] as int;
    try {
      if (data['method'] == 'dispose') {
        engine?.dispose();
        parent.send({'id': id, 'result': <String, Object>{}});
        inbox.close();
        return;
      }
      engine ??= FramingEngine();
      final bytes = (data['jpeg'] as TransferableTypedData)
          .materialize()
          .asUint8List();
      final result = data['method'] == 'reference'
          ? engine!.setReference(bytes, data['referenceId'] as String)
          : engine!.compare(bytes);
      parent.send({'id': id, 'result': result});
    } catch (error) {
      parent.send({'id': id, 'error': error.toString()});
    }
  });
}

class FramingService {
  final _pending = <int, Completer<Map<dynamic, dynamic>>>{};
  final _inbox = ReceivePort();
  final _ready = Completer<SendPort>();
  Isolate? _isolate;
  Future<void>? _startup;
  int _id = 0;
  bool _disposed = false;
  Future<void> _start() => _startup ??= _spawn();
  Future<void> _spawn() async {
    _inbox.listen((dynamic data) {
      if (data is SendPort) {
        _ready.complete(data);
        return;
      }
      if (data is! Map) return;
      final job = _pending.remove(data['id']);
      if (data['error'] != null) {
        job?.completeError(StateError(data['error'] as String));
      } else {
        job?.complete((data['result'] as Map?) ?? {});
      }
    });
    _isolate = await Isolate.spawn(_framingWorker, _inbox.sendPort);
  }

  Future<Map<dynamic, dynamic>> _request(
    String method, {
    Uint8List? jpeg,
    String? referenceId,
  }) async {
    await _start();
    final port = await _ready.future;
    final id = ++_id;
    final job = Completer<Map<dynamic, dynamic>>();
    _pending[id] = job;
    port.send({
      'id': id,
      'method': method,
      if (jpeg != null) 'jpeg': TransferableTypedData.fromList([jpeg]),
      'referenceId': referenceId,
    });
    try {
      return await job.future.timeout(const Duration(seconds: 10));
    } finally {
      _pending.remove(id);
    }
  }

  Future<void> setReference(Uint8List jpeg, String id) async {
    if (_disposed) throw StateError('Framing service disposed');
    await _request('reference', jpeg: jpeg, referenceId: id);
  }

  Future<FramingCheck> compare(Uint8List jpeg) async {
    if (_disposed) return FramingCheck.waiting;
    return FramingCheck.fromJson(await _request('compare', jpeg: jpeg));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_startup != null) {
      try {
        await _request('dispose');
      } catch (_) {
        _isolate?.kill(priority: Isolate.immediate);
      }
    }
    _inbox.close();
    for (final job in _pending.values) {
      if (!job.isCompleted) {
        job.completeError(StateError('Framing service disposed'));
      }
    }
    _pending.clear();
  }
}
