import 'package:delivery_photo_assist/src/services/gallery_import.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('cancelling the gallery does not decode or produce a photo', () async {
    var decoded = false;
    final importer = GalleryImport(
      choose: () async => null,
      normalizer: (_) async {
        decoded = true;
        return {};
      },
    );
    expect(await importer.pick(), isNull);
    expect(decoded, isFalse);
  });
  test(
    'only the selected bytes are normalized locally and retain gallery provenance',
    () async {
      final selected = Uint8List.fromList([255, 216, 255, 0]);
      final importer = GalleryImport(
        choose: () async => XFile.fromData(selected),
        normalizer: (bytes) async {
          expect(bytes, selected);
          return {'jpeg': bytes, 'source': 'gallery'};
        },
      );
      final packet = await importer.pick();
      expect(packet?['source'], 'gallery');
      expect(packet?['jpeg'], selected);
      expect(packet?['importProcessingMs'], greaterThanOrEqualTo(0));
    },
  );
  test(
    'gallery normalization uses the native byte bridge and reports invalid images',
    () async {
      const channel = MethodChannel('delivery_photo_assist');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'prepareImportedPhoto');
            expect((call.arguments as Map)['image'], isA<Uint8List>());
            throw PlatformException(code: 'invalid_image');
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await expectLater(
        GalleryImport.normalize(Uint8List(4)),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
