enum ClarityState { clear, blurry, dark, glare, focusing, uncertain }

class ClarityReading {
  const ClarityReading({
    required this.laplacian,
    required this.contrast,
    required this.luminance,
    required this.edgeFraction,
    required this.darkFraction,
    required this.clippedFraction,
    required this.width,
    required this.height,
  });
  final double laplacian,
      contrast,
      luminance,
      edgeFraction,
      darkFraction,
      clippedFraction;
  final int width, height;
  static ClarityReading? parse(dynamic value) {
    if (value is! Map) return null;
    final numbers =
        [
              'laplacianVariance',
              'contrastStd',
              'meanLuma',
              'edgeFraction',
              'darkFraction',
              'clippedFraction',
              'analysisWidth',
              'analysisHeight',
            ]
            .map(
              (k) =>
                  value[k] is num ? (value[k] as num).toDouble() : double.nan,
            )
            .toList();
    if (numbers.any((n) => !n.isFinite) || numbers[6] < 16 || numbers[7] < 16) {
      return null;
    }
    return ClarityReading(
      laplacian: numbers[0],
      contrast: numbers[1],
      luminance: numbers[2],
      edgeFraction: numbers[3],
      darkFraction: numbers[4],
      clippedFraction: numbers[5],
      width: numbers[6].toInt(),
      height: numbers[7].toInt(),
    );
  }

  ClarityState get state {
    if (luminance < 35 || darkFraction > .75) return ClarityState.dark;
    if (clippedFraction > .60) return ClarityState.glare;
    // Flat paper/plastic or a blank wall is not automatically an out-of-focus image.
    if (contrast < 12 || edgeFraction < .01) return ClarityState.uncertain;
    if (laplacian < 35) return ClarityState.blurry;
    if (laplacian < 80) return ClarityState.uncertain;
    return ClarityState.clear;
  }
}

class FrameClarity {
  FrameClarity(this.raw)
    : global = ClarityReading.parse(raw['global']),
      package = ClarityReading.parse(raw['package']);
  final Map<String, dynamic> raw;
  final ClarityReading? global, package;
  FrameClarity get environmentOnly => FrameClarity({
    ...raw,
    'package': null,
    'packageCheck': 'not_used_for_environment',
  });
  static FrameClarity? parse(dynamic value) => value is Map && value.isNotEmpty
      ? FrameClarity(value.map((k, v) => MapEntry(k.toString(), v)))
      : null;
  ClarityState get state {
    if (global == null) return ClarityState.uncertain;
    if (global!.state == ClarityState.dark ||
        global!.state == ClarityState.glare) {
      return global!.state;
    }
    if (raw['isAdjustingFocus'] == true) return ClarityState.focusing;
    if (global!.state == ClarityState.blurry ||
        package?.state == ClarityState.blurry) {
      return ClarityState.blurry;
    }
    if (global!.state == ClarityState.uncertain ||
        package?.state == ClarityState.uncertain) {
      return ClarityState.uncertain;
    }
    return ClarityState.clear;
  }

  bool get needsRetake => [
    ClarityState.blurry,
    ClarityState.dark,
    ClarityState.glare,
  ].contains(state);
  String get label => switch (state) {
    ClarityState.clear => '较清晰',
    ClarityState.blurry => '可能模糊',
    ClarityState.dark => '光线不足',
    ClarityState.glare => '画面过亮',
    ClarityState.focusing => '正在对焦',
    ClarityState.uncertain => '细节待确认',
  };
  String get advice => switch (state) {
    ClarityState.clear => '请确认包裹和环境细节都能看清',
    ClarityState.blurry =>
      package?.state == ClarityState.blurry
          ? '包裹区域可能模糊，请稳住手机并对焦包裹'
          : '画面可能模糊，请稳住手机后再拍',
    ClarityState.dark => '光线不足，请补光后再拍',
    ClarityState.glare => '画面过亮，请调整角度，避免强光直射',
    ClarityState.focusing => '请稳住手机，等待对焦稳定',
    ClarityState.uncertain => '可辨纹理较少，请放大检查包裹细节',
  };
  Map<String, dynamic> toJson() => {
    ...raw,
    'state': state.name,
    'label': label,
    'advice': advice,
    'method': '320px spatial detail heuristic; not a guarantee of readability',
  };
}
