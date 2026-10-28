import 'package:flutter/material.dart';
import '../domain/capture_guidance.dart';
import '../domain/guidance.dart';
import 'camera_controls.dart';
import 'capture_status.dart';

/// All changing content owns a reserved slot; analysis results never change control geometry.
class CameraChrome extends StatelessWidget {
  const CameraChrome({
    super.key,
    required this.stage,
    required this.savedStages,
    required this.advice,
    required this.capturing,
    required this.boxes,
    required this.torch,
    required this.zoom,
    required this.minimumZoom,
    required this.maximumZoom,
    required this.zoomAvailable,
    required this.qualityLabel,
    required this.onBack,
    required this.onMore,
    required this.onBoxes,
    required this.onStage,
    required this.onZoom,
    required this.onTorch,
    required this.onCapture,
    required this.onReview,
    required this.onReference,
    required this.onGallery,
    this.firstShot,
    this.notice,
    this.performanceLabel = '自动适配',
  });
  final ShotStage stage;
  final Set<ShotStage> savedStages;
  final CaptureAdvice advice;
  final bool capturing, boxes, torch, zoomAvailable;
  final double zoom, minimumZoom, maximumZoom;
  final String qualityLabel, performanceLabel;
  final String? notice;
  final ImageProvider? firstShot;
  final VoidCallback onBack,
      onMore,
      onTorch,
      onCapture,
      onReview,
      onReference,
      onGallery;
  final ValueChanged<bool> onBoxes;
  final ValueChanged<ShotStage> onStage;
  final ValueChanged<double> onZoom;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final compact = MediaQuery.sizeOf(context).height < 650;
    final panelHeight =
        12 + captureStatusHeight(context) + 10 + 88 + 26 + safe.bottom;
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: safe.top + 194,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xD9121516), Color(0x00121516)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: safe.top,
          left: 12,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 54,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '返回',
                      onPressed: capturing ? null : onBack,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        '配送拍照',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '补光灯',
                      onPressed: capturing ? null : onTorch,
                      icon: Icon(
                        torch
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        color: torch ? Colors.white : Colors.white70,
                        size: 22,
                      ),
                    ),
                    IconButton(
                      tooltip: '相机设置',
                      onPressed: onMore,
                      icon: const Icon(
                        Icons.tune_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                key: const Key('camera-stage-tabs'),
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xB3232729),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    for (final shot in ShotStage.values)
                      Expanded(
                        child: TextButton(
                          onPressed: capturing ? null : () => onStage(shot),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: stage == shot
                                ? const Color(0xFFF1F2F4)
                                : Colors.transparent,
                            foregroundColor: stage == shot
                                ? const Color(0xFF26292D)
                                : Colors.white70,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (savedStages.contains(shot))
                                  const Padding(
                                    padding: EdgeInsets.only(right: 5),
                                    child: Icon(Icons.check_rounded, size: 15),
                                  ),
                                Text(
                                  shot == ShotStage.parcel
                                      ? '1  包裹位置'
                                      : '2  周围环境',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: compact ? 36 : 44,
                child: Center(
                  child: Text(
                    stage == ShotStage.parcel
                        ? '拍清包裹，保留周围位置特征'
                        : '对照第一张，扩大周围环境的取景',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE1E3E6),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (stage == ShotStage.environment && firstShot != null)
          Positioned(
            top: safe.top + (compact ? 138 : 148),
            left: 16,
            child: Material(
              color: const Color(0xC9232729),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onReference,
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  key: const Key('camera-first-reference'),
                  width: 164,
                  height: 48,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(5),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image(
                            image: ResizeImage(firstShot!, width: 96),
                            width: 34,
                            height: 38,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          '第一张对照',
                          maxLines: 1,
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(right: 9),
                        child: Icon(
                          Icons.open_in_full_rounded,
                          size: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (!compact)
          Positioned(
            bottom: panelHeight + 76,
            left: 20,
            right: 20,
            height: 24,
            child: IgnorePointer(
              child: Row(
                children: [
                  const Icon(
                    Icons.center_focus_strong_rounded,
                    size: 14,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '清晰度 · $qualityLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                  Text(
                    performanceLabel,
                    style: const TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          bottom: panelHeight + 8,
          left: 16,
          right: 16,
          height: 64,
          child: Center(
            child: CameraZoomControls(
              zoom: zoom,
              minimum: minimumZoom,
              maximum: maximumZoom,
              onChanged: zoomAvailable && !capturing ? onZoom : null,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            key: const Key('camera-bottom-dock'),
            padding: EdgeInsets.fromLTRB(16, 12, 16, safe.bottom),
            decoration: const BoxDecoration(
              color: Color(0xFF121516),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CaptureStatusBanner(decision: advice),
                const SizedBox(height: 10),
                SizedBox(
                  height: 88,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _SideAction(
                        key: const Key('camera-gallery'),
                        label: '相册',
                        onTap: capturing ? null : onGallery,
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ),
                      CaptureShutter(
                        state: advice.state,
                        busy: capturing,
                        stageLabel: stage.label,
                        onCapture: onCapture,
                      ),
                      _SideAction(
                        key: const Key('camera-review'),
                        label: '已拍 ${savedStages.length}/2',
                        onTap: savedStages.isEmpty || capturing
                            ? null
                            : onReview,
                        child: firstShot == null
                            ? const Icon(
                                Icons.photo_library_outlined,
                                color: Colors.white54,
                                size: 23,
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Image(
                                  image: ResizeImage(firstShot!, width: 96),
                                  width: 34,
                                  height: 36,
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 26,
                  child: Center(
                    child: Text(
                      notice ?? '提示仅供参考，任何状态都可拍照',
                      key: const Key('camera-notice'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8B9096),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SideAction extends StatelessWidget {
  const _SideAction({
    super.key,
    required this.label,
    required this.child,
    this.onTap,
  });
  final String label;
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 72,
    height: 76,
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        foregroundColor: Colors.white70,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 38, child: Center(child: child)),
          const SizedBox(height: 5),
          Text(label, maxLines: 1, style: const TextStyle(fontSize: 11)),
        ],
      ),
    ),
  );
}
