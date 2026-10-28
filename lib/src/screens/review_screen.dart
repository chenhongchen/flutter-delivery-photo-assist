import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/session_store.dart';
import '../domain/clarity.dart';

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({super.key});
  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  late Future<List<File>> _reports = SessionStore().listReports();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('实拍记录')),
    body: FutureBuilder<List<File>>(
      future: _reports,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('读取失败：${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reports = snap.data!;
        if (reports.isEmpty) {
          return const Center(
            child: Text(
              '还没有实拍记录\n拍摄后的照片和耗时会保存在这里',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.8),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) => Card(
            child: ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('双照测试 ${reports.length - index}'),
              subtitle: Text(
                DateTime.fromMicrosecondsSinceEpoch(
                  int.parse(reports[index].parent.path.split('/').last),
                ).toString().split('.').first,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReviewScreen(report: reports[index]),
                  ),
                );
                if (mounted) {
                  setState(() => _reports = SessionStore().listReports());
                }
              },
            ),
          ),
        );
      },
    ),
  );
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.report});
  final File report;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final Future<Map<String, dynamic>> _data = widget.report
      .readAsString()
      .then((s) => jsonDecode(s) as Map<String, dynamic>);
  Future<void> _share(Map<String, dynamic> data) async {
    try {
      final files = <XFile>[XFile(widget.report.path)];
      for (final shot in data['shots'] as List<dynamic>) {
        final name = shot['file'] as String;
        // Only local filenames written by SessionStore are accepted.
        if (name.contains('/') || name.contains('\\') || name.contains('..')) {
          continue;
        }
        final path = '${widget.report.parent.path}/$name';
        if (await File(path).exists()) files.add(XFile(path));
      }
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: files,
          title: '配送拍照 Demo 实测记录',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('分享失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('照片与实测数据')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('记录读取失败：${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!;
        final shots = data['shots'] as List<dynamic>;
        final timings = data['timings'] as Map<String, dynamic>;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              data['complete'] == true ? '两张照片已保存' : '当前拍摄进度已保存',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              '请核对包裹位置是否容易识别；远景比较不能证明配送地址正确。',
              style: TextStyle(color: Colors.blueGrey),
            ),
            for (final shot in shots) ...[
              const SizedBox(height: 20),
              Text(
                shot['stage'] == 'parcel' ? '第一张 · 包裹与放置位置' : '第二张 · 周围环境',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.file(
                  File('${widget.report.parent.path}/${shot['file']}'),
                  fit: BoxFit.contain,
                  height: 320,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 150,
                    child: Center(child: Text('照片文件读取失败')),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (shot['quality'] != null)
                Builder(
                  builder: (context) {
                    final quality = FrameClarity.parse(shot['quality']);
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F1F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '清晰度参考：${quality?.label ?? '待确认'} · ${quality?.raw['photoWidth'] ?? '—'} × ${quality?.raw['photoHeight'] ?? '—'}\n'
                        '${quality?.advice ?? ''}${shot['captureSource'] == 'preview_fallback' ? '\n本次为预览帧照片，请放大检查细节' : ''}',
                        style: const TextStyle(fontSize: 12, height: 1.7),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 8),
              Text(
                shot['guidance'] is Map ? '拍摄时建议仅作参考，未执行拍后远景复核' : '旧版拍摄记录',
                style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                '拍照至 JPEG 返回：${(shot['captureToJpegBytesMs'] as num).toStringAsFixed(0)} ms\n'
                '拍照至图片落盘：${(shot['tapToSavedJpegMs'] as num).toStringAsFixed(0)} ms\n'
                '按快门时提示：${shot['hintAtTap']}',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  color: Colors.blueGrey,
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              '识别性能',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              '最近 ${timings['windowFrames']} 帧 · SDK 处理 P50 ${(timings['processingP50Ms'] as num).toStringAsFixed(1)} ms\n'
              'P95 ${(timings['processingP95Ms'] as num).toStringAsFixed(1)} ms · 结果回调 ${(timings['callbackFps'] as num).toStringAsFixed(1)} 次/秒',
              style: const TextStyle(height: 1.8),
            ),
            const SizedBox(height: 10),
            const Text(
              'SDK 处理耗时不等于完整提示延迟。1.4 起第二张增加共同特征与相对缩放的实时建议，不阻止拍摄，也不做拍后远景复核。照片保存不等于合规结论。',
              style: TextStyle(
                color: Colors.blueGrey,
                fontSize: 12,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _share(data),
              icon: const Icon(Icons.ios_share),
              label: const Text('分享照片与 JSON 记录'),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    ),
  );
}
