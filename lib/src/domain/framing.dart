enum FramingState { waiting, unmatched, near, far, tooFar }

/// Relative visual scale of shared scene features, never a distance in metres.
class FramingCheck {
  const FramingCheck({
    required this.state,
    this.scale = 1,
    this.inliers = 0,
    this.inlierRatio = 0,
    this.spread = 0,
    this.scaleSpread = 1,
    this.processingMs = 0,
    this.referenceId = '',
  });
  final FramingState state;
  final double scale, inlierRatio, spread, scaleSpread, processingMs;
  final int inliers;
  final String referenceId;
  static const waiting = FramingCheck(state: FramingState.waiting);

  factory FramingCheck.fromJson(Map<dynamic, dynamic> data) {
    double n(String key, [double fallback = 0]) =>
        data[key] is num && (data[key] as num).isFinite
        ? (data[key] as num).toDouble()
        : fallback;
    final scale = n('scale', 1);
    final count = n('inliers').toInt();
    final ratio = n('inlierRatio');
    final spread = n('spread');
    final variation = n('scaleSpread', 1);
    final matched =
        data['matched'] == true &&
        data['scale'] is num &&
        (data['scale'] as num).isFinite &&
        count >= 16 &&
        ratio >= .25 &&
        spread >= .06 &&
        variation <= .35 &&
        scale > 0;
    final state = !matched
        ? FramingState.unmatched
        : scale < .20
        ? FramingState.tooFar
        : scale <= .80
        ? FramingState.far
        : FramingState.near;
    return FramingCheck(
      state: state,
      scale: scale,
      inliers: count,
      inlierRatio: ratio,
      spread: spread,
      scaleSpread: variation,
      processingMs: n('processingMs'),
      referenceId: data['referenceId'] as String? ?? '',
    );
  }

  Map<String, Object> toJson() => {
    'state': state.name,
    'matched': state != FramingState.waiting && state != FramingState.unmatched,
    'scale': scale,
    'inliers': inliers,
    'inlierRatio': inlierRatio,
    'spread': spread,
    'scaleSpread': scaleSpread,
    'processingMs': processingMs,
    'referenceId': referenceId,
    'method':
        'SIFT/RANSAC relative-scale advice; <=0.80 suggests a wider view; not metres or address verification',
  };
}

/// Only independent analyses count toward green. Failed/new/expired results clear the green recommendation.
class FramingTracker {
  FramingCheck current = FramingCheck.waiting;
  int _farCount = 0;
  int? _startedAtMs;
  String referenceId = '';
  void reset([String reference = '']) {
    current = FramingCheck.waiting;
    _farCount = 0;
    _startedAtMs = null;
    referenceId = reference;
  }

  void add(FramingCheck next, int startedAtMs) {
    if (next.referenceId != referenceId) return;
    if (_startedAtMs != null && startedAtMs <= _startedAtMs!) return;
    if (_startedAtMs != null && startedAtMs - _startedAtMs! > 1500) {
      _farCount = 0;
    }
    _startedAtMs = startedAtMs;
    current = next;
    _farCount = next.state == FramingState.far ? _farCount + 1 : 0;
  }

  bool fresh(int nowMs) =>
      _startedAtMs != null && nowMs - _startedAtMs! <= 1500;
  bool ready(int nowMs) =>
      fresh(nowMs) &&
      current.referenceId == referenceId &&
      current.state == FramingState.far &&
      _farCount >= 2;
}
