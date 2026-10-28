import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class GalleryImport {
  GalleryImport({
    Future<XFile?> Function()? choose,
    Future<Map<dynamic, dynamic>?> Function(Uint8List)? normalizer,
  }) : _choose =
           choose ??
           (() => ImagePicker().pickImage(
             source: ImageSource.gallery,
             requestFullMetadata: false,
           )),
       _normalizer = normalizer ?? normalize;
  final Future<XFile?> Function() _choose;
  final Future<Map<dynamic, dynamic>?> Function(Uint8List) _normalizer;
  Future<Map<dynamic, dynamic>?> pick() async {
    final file = await _choose();
    if (file == null) return null;
    final clock = Stopwatch()..start();
    final bytes = await file.readAsBytes();
    final packet = await _normalizer(bytes);
    return packet == null
        ? null
        : {...packet, 'importProcessingMs': clock.elapsedMicroseconds / 1000};
  }

  /// The selected image is normalized locally, with orientation applied and its long edge capped at 4096 px.
  static Future<Map<dynamic, dynamic>?> normalize(Uint8List bytes) =>
      const MethodChannel(
        'delivery_photo_assist',
      ).invokeMapMethod<dynamic, dynamic>('prepareImportedPhoto', {
        'image': bytes,
      });
}
