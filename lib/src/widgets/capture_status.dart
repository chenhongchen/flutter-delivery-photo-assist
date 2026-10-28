import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../domain/capture_guidance.dart';

const captureGreen = Color(0xFF8AD8A5);
const captureRed = Color(0xFFF0A09A);
const captureAmber = Color(0xFFECD18C);
double captureStatusHeight(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context);
  return math.max(100, 40 + scale.scale(16) * 1.3 + scale.scale(12) * 2.8);
}

Color captureColor(CaptureState state) => switch (state) {
  CaptureState.ready => captureGreen,
  CaptureState.attention => captureRed,
  CaptureState.observing => captureAmber,
};

class CaptureStatusBanner extends StatelessWidget {
  const CaptureStatusBanner({super.key, required this.decision});
  final CaptureAdvice decision;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      key: const Key('capture-status-panel'),
      height: captureStatusHeight(context),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF202326),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: captureColor(decision.state).withValues(alpha: .42),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            decision.isRecommended
                ? Icons.check_circle
                : decision.state == CaptureState.attention
                ? Icons.warning_amber_rounded
                : Icons.hourglass_top,
            color: captureColor(decision.state),
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  decision.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: captureColor(decision.state),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  decision.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB6BBBE),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class CaptureShutter extends StatelessWidget {
  const CaptureShutter({
    super.key,
    required this.state,
    required this.onCapture,
    required this.stageLabel,
    this.busy = false,
  });
  final CaptureState state;
  final VoidCallback onCapture;
  final String stageLabel;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final enabled = !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: enabled ? '拍摄$stageLabel' : '正在拍摄$stageLabel',
      child: GestureDetector(
        key: const Key('capture-shutter'),
        onTap: enabled ? onCapture : null,
        child: Container(
          width: 82,
          height: 82,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: captureColor(state), width: 3),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              shape: BoxShape.circle,
            ),
            child: busy
                ? const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        color: Color(0xFF4A4E54),
                        strokeWidth: 3,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
