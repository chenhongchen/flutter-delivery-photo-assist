import 'clarity.dart';
import 'framing.dart';
import 'guidance.dart';

enum CaptureState { attention, observing, ready }

class CaptureAdvice {
  const CaptureAdvice(this.state, this.title, this.detail, this.reason);
  final CaptureState state;
  final String title, detail, reason;
  bool get isRecommended => state == CaptureState.ready;
}

class CaptureGuidance {
  const CaptureGuidance();
  CaptureAdvice evaluate({
    required ShotStage stage,
    required SceneFacts? facts,
    required GuideSettings settings,
    required int nowMs,
    required bool stable,
    required FramingTracker framing,
    int sceneFreshMs = 1200,
    int framingFreshMs = 1500,
  }) {
    if (facts == null || nowMs - facts.receivedAtMs > sceneFreshMs) {
      return const CaptureAdvice(
        CaptureState.observing,
        '正在检查画面',
        '可先对准包裹与环境，拍摄不必等待提示',
        'stale_or_waiting',
      );
    }
    final quality = stage == ShotStage.environment
        ? facts.clarity?.environmentOnly
        : facts.clarity;
    final hint = const GuidanceRules().evaluate(facts, stage, settings);
    if (quality?.needsRetake == true ||
        quality?.state == ClarityState.focusing) {
      return CaptureAdvice(
        CaptureState.attention,
        hint.title,
        hint.detail,
        'quality',
      );
    }
    if (quality?.global?.state != ClarityState.clear) {
      return const CaptureAdvice(
        CaptureState.observing,
        '清晰度参考待更新',
        '请稳住手机，调整角度或补光，让细节更清楚',
        'quality_unknown',
      );
    }
    if (stage == ShotStage.parcel) {
      final package = facts.package(settings);
      if (package == null) {
        return const CaptureAdvice(
          CaptureState.observing,
          '包裹识别待确认',
          '请确认包裹与位置能看清，仍可直接拍照',
          'package_missing',
        );
      }
      if (package.area < .003 || hint.code == HintCode.closer) {
        return const CaptureAdvice(
          CaptureState.attention,
          '包裹细节太小，请靠近一些',
          '同时保留周围能说明放置位置的特征',
          'package_small',
        );
      }
      if (hint.code == HintCode.wider) {
        return CaptureAdvice(
          CaptureState.attention,
          hint.title,
          hint.detail,
          'package_closeup',
        );
      }
      if (!stable) {
        return const CaptureAdvice(
          CaptureState.observing,
          '请稍稳住手机',
          '正在确认包裹与画面清晰度',
          'stabilizing',
        );
      }
      return const CaptureAdvice(
        CaptureState.ready,
        '近景取景较合适',
        '请拍清完整包裹，并保留能识别放置位置的周围特征',
        'first_ready',
      );
    }
    if (!framing.fresh(nowMs, maxAgeMs: framingFreshMs)) {
      return const CaptureAdvice(
        CaptureState.observing,
        '正在参考第一张画面',
        '请保留同一位置，并后退扩大取景范围',
        'framing_waiting',
      );
    }
    final check = framing.current;
    if (check.state == FramingState.near) {
      return const CaptureAdvice(
        CaptureState.attention,
        '建议再后退一些',
        '当前取景与第一张过于接近，请拍入更多周围环境',
        'not_farther',
      );
    }
    if (check.state == FramingState.tooFar) {
      return const CaptureAdvice(
        CaptureState.attention,
        '原放置位置太小，请稍靠近',
        '请保留能与第一张对应的环境特征',
        'too_far',
      );
    }
    if (check.state == FramingState.unmatched) {
      return const CaptureAdvice(
        CaptureState.observing,
        '画面对应关系待确认',
        '可保留第一张附近的固定特征，仍可直接拍照',
        'unmatched',
      );
    }
    if (!framing.ready(nowMs, maxAgeMs: framingFreshMs) || !stable) {
      return const CaptureAdvice(
        CaptureState.observing,
        '正在确认远景',
        '可保持当前取景，也可直接拍照',
        'framing_stabilizing',
      );
    }
    return const CaptureAdvice(
      CaptureState.ready,
      '远景取景较合适',
      '共同画面特征已缩小，取景较第一张扩大；提示仅供参考',
      'second_ready',
    );
  }
}
