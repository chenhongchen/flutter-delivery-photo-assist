import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:delivery_photo_assist/delivery_photo_assist.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '配送拍照·PicoDet',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF62676E),
          primary: const Color(0xFF24272B),
          surface: const Color(0xFFF6F7F9),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7F9),
      ),
      home: const ExampleHome(),
    ),
  );
}

class ExampleHome extends StatefulWidget {
  const ExampleHome({super.key});
  @override
  State<ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<ExampleHome> {
  String _variant = 's';
  bool _opening = false;
  DeliveryPhotoResult? _result;
  String? _error;
  Future<PicoDetModel> _model() async {
    final dir = await getApplicationSupportDirectory();
    for (final ext in ['onnx', 'json']) {
      final name = 'picodet_${_variant}_320.$ext';
      final data = await rootBundle.load('assets/models/$name');
      await File('${dir.path}/$name').writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }
    return PicoDetModel.fromFiles(
      modelPath: '${dir.path}/picodet_${_variant}_320.onnx',
      manifestPath: '${dir.path}/picodet_${_variant}_320.json',
    );
  }

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final model = await _model();
      if (!mounted) return;
      final result = await DeliveryPhotoAssist.capture(context, model: model);
      if (mounted && result != null) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = '暂时无法打开：$error');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        '配送拍照助手',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            '拍清包裹\n也拍清放在哪里',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '第一张拍包裹与位置，第二张拍更多周围环境。提示仅供参考，任何状态都可以拍照。',
            style: TextStyle(height: 1.8),
          ),
          const SizedBox(height: 28),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 's', label: Text('PicoDet-S')),
              ButtonSegment(value: 'xs', label: Text('PicoDet-XS')),
            ],
            selected: {_variant},
            onSelectionChanged: _opening
                ? null
                : (v) => setState(() => _variant = v.first),
          ),
          const SizedBox(height: 16),
          const Text(
            '接入验证版 · 当前为 COCO 通用模型\n纸箱、配送软袋、整箱饮料等专项类别待训练模型接入。',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.7),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _opening ? null : _open,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(_opening ? '准备中' : '开始拍照'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!),
            ),
          if (_result != null) ...[
            const SizedBox(height: 28),
            const Text('最近拍摄', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final file in [
                  _result!.parcelPhoto,
                  _result!.environmentPhoto,
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Image.file(file, height: 180, fit: BoxFit.cover),
                    ),
                  ),
              ],
            ),
            const Text(
              '已返回两张本地照片，宿主可复用原有上传流程。',
              style: TextStyle(fontSize: 12, height: 1.7),
            ),
          ],
        ],
      ),
    ),
  );
}
