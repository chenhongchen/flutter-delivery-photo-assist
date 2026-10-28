import 'dart:typed_data';

/// MethodChannel 字节块可能从非 4 字节边界开始，不能直接创建 float32 视图。
Float32List frameTensor(Uint8List bytes) {
  if (bytes.lengthInBytes % 4 != 0) {
    throw const FormatException('相机张量字节数无效');
  }
  final aligned = bytes.offsetInBytes % 4 == 0
      ? bytes
      : Uint8List.fromList(bytes);
  return aligned.buffer.asFloat32List(
    aligned.offsetInBytes,
    aligned.lengthInBytes ~/ 4,
  );
}
