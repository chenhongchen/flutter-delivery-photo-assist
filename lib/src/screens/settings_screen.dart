import 'package:flutter/material.dart';
import '../domain/guidance.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});
  final GuideSettings settings;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late GuideSettings _settings = widget.settings;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('测试设置')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('用于比较识别效果和耗时。调整后从首页重新开始实拍。', style: TextStyle(height: 1.6)),
        const SizedBox(height: 28),
        const Text('每秒识别次数上限', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 2, label: Text('2 次')),
            ButtonSegment(value: 3, label: Text('3 次')),
            ButtonSegment(value: 5, label: Text('5 次')),
          ],
          selected: {_settings.inferenceFps},
          onSelectionChanged: (s) => setState(
            () => _settings = _settings.copyWith(inferenceFps: s.first),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          '置信度阈值  ${(_settings.confidence * 100).round()}%',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Slider(
          value: _settings.confidence,
          min: .2,
          max: .7,
          divisions: 10,
          label: '${(_settings.confidence * 100).round()}%',
          onChanged: (v) =>
              setState(() => _settings = _settings.copyWith(confidence: v)),
        ),
        const Text(
          '提高阈值会减少部分误报，也可能增加遗漏。',
          style: TextStyle(fontSize: 12, color: Colors.blueGrey),
        ),
        const SizedBox(height: 18),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('显示识别框'),
          subtitle: const Text('便于核对识别到的物体'),
          value: _settings.showBoxes,
          onChanged: (v) =>
              setState(() => _settings = _settings.copyWith(showBoxes: v)),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('启用袋装候选'),
          subtitle: const Text('手提袋、塑料袋可能被当作包裹，误报较多'),
          value: _settings.includeBagCandidates,
          onChanged: (v) => setState(
            () => _settings = _settings.copyWith(includeBagCandidates: v),
          ),
        ),
        const SizedBox(height: 24),
        const Text('当前判断范围', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
          '• 包裹候选与环境特征的识别参考\n• 明显占满画面或细节极小时的取景建议\n• 预览与保存照片的模糊、亮度参考\n\n绿色表示取景较合适，红色表示建议调整；所有状态都能拍照。第二张仅实时参考第一张的共同画面特征与缩放，不做拍后远景复核。画面占比不能测量实际距离。低纹理包装的清晰度可能无法确认。\n\n已加入文字候选参考、第一张缩略图和相对远景建议；尚未实现门牌语义解析或订单地址核验。车牌、花盆仅作辅助。',
          style: TextStyle(height: 1.8, fontSize: 13),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_settings),
          child: const Text('保存测试设置'),
        ),
      ],
    ),
  );
}
