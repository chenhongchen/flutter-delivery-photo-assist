import 'package:flutter/material.dart';

class DetectionBoxSwitch extends StatelessWidget {
  const DetectionBoxSwitch({
    super.key,
    this.value = false,
    required this.onChanged,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('识别框', style: TextStyle(color: Colors.white, fontSize: 12)),
        Switch(
          key: const Key('detection-box-switch'),
          value: value,
          onChanged: onChanged,
          activeTrackColor: const Color(0xFF727881),
          inactiveTrackColor: const Color(0xFF383D40),
          thumbColor: const WidgetStatePropertyAll(Colors.white),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    ),
  );
}

/// Flutter owns pinch gestures on both native camera surfaces.
class CameraZoomGesture extends StatefulWidget {
  const CameraZoomGesture({
    super.key,
    required this.zoom,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
    required this.child,
  });
  final double zoom, minimum, maximum;
  final ValueChanged<double>? onChanged;
  final Widget child;

  @override
  State<CameraZoomGesture> createState() => _CameraZoomGestureState();
}

class _CameraZoomGestureState extends State<CameraZoomGesture> {
  double _startZoom = 1;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onScaleStart: widget.onChanged == null
        ? null
        : (_) => _startZoom = widget.zoom,
    onScaleUpdate: widget.onChanged == null
        ? null
        : (details) {
            if (details.pointerCount < 2) return;
            widget.onChanged!(
              (_startZoom * details.scale).clamp(
                widget.minimum,
                widget.maximum,
              ),
            );
          },
    child: widget.child,
  );
}

class CameraZoomControls extends StatelessWidget {
  const CameraZoomControls({
    super.key,
    required this.zoom,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
  });
  final double zoom, minimum, maximum;
  final ValueChanged<double>? onChanged;
  @override
  Widget build(BuildContext context) {
    const presets = [.5, 1.0, 2.0, 5.0];
    String label(double value) =>
        '${value == value.roundToDouble() ? value.toInt() : value.toStringAsFixed(1)}×';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 224,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xC9232729),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final value in presets)
                SizedBox(
                  width: 48,
                  height: 44,
                  child: value < minimum - .01 || value > maximum + .01
                      ? const SizedBox.shrink()
                      : TextButton(
                          key: ValueKey('camera-zoom-$value'),
                          onPressed: onChanged == null
                              ? null
                              : () => onChanged!(value),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 44),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                            foregroundColor: (zoom - value).abs() < .04
                                ? Colors.white
                                : Colors.white60,
                            backgroundColor: (zoom - value).abs() < .04
                                ? const Color(0xFF41464C)
                                : Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label(value),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 14,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${label(zoom)} · 双指缩放',
              style: const TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }
}
