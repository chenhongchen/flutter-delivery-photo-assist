import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_photo_assist/src/services/frame_tensor.dart';

void main() {
  test('unaligned channel bytes preserve float32 values', () {
    final storage = Uint8List(10);
    final data = ByteData.sublistView(storage);
    data.setFloat32(2, 1.5, Endian.little);
    data.setFloat32(6, -2.25, Endian.little);
    expect(frameTensor(Uint8List.sublistView(storage, 2)), [1.5, -2.25]);
  });
  test('truncated tensor bytes do not become valid model input', () {
    expect(() => frameTensor(Uint8List(3)), throwsFormatException);
  });
}
