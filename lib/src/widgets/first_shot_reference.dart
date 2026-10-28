import 'package:flutter/material.dart';

class FirstShotReference extends StatefulWidget {
  const FirstShotReference({
    super.key,
    required this.image,
    this.compact = false,
  });
  final ImageProvider image;
  final bool compact;
  @override
  State<FirstShotReference> createState() => _FirstShotReferenceState();
}

class _FirstShotReferenceState extends State<FirstShotReference> {
  bool _collapsed = false;
  void _open() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: Column(
            children: [
              ListTile(
                title: const Text('第一张照片对照'),
                subtitle: const Text('确认同一放置位置，第二张多拍一些周围环境'),
                trailing: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  child: Image(
                    image: ResizeImage(widget.image, width: 1280),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_collapsed || widget.compact) {
      return TextButton.icon(
        onPressed: _open,
        icon: const Icon(Icons.photo_outlined, size: 17),
        label: const Text('查看第一张，对照放置位置'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.black54,
        ),
      );
    }
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image(
                  image: ResizeImage(widget.image, width: 128),
                  width: 48,
                  height: 58,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '第一张对照 · 点击放大',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '保持同一放置位置，多拍周围环境',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '收起第一张对照',
                onPressed: () => setState(() => _collapsed = true),
                icon: const Icon(Icons.expand_less, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
