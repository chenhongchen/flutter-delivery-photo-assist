library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'src/domain/guidance.dart';
import 'src/screens/camera_screen.dart';
import 'src/services/session_store.dart';
import 'src/services/picodet_model.dart';
import 'src/services/delivery_camera.dart' show deliveryNative;

export 'src/domain/guidance.dart' show GuideSettings, ShotStage;
export 'src/services/picodet_model.dart' show PicoDetModel;

class DeliveryPhotoResult {
  const DeliveryPhotoResult({
    required this.parcelPhoto,
    required this.environmentPhoto,
    required this.report,
  });
  final File parcelPhoto;
  final File environmentPhoto;

  /// 本机报告。保存完成不代表照片通过合规、地址或物品校验。
  final File report;
}

class DeliveryPhotoAssist {
  /// 拍齐两张后返回本地文件；取消返回 null。宿主负责上传和文件留存。
  static Future<DeliveryPhotoResult?> capture(
    BuildContext context, {
    required PicoDetModel model,
    GuideSettings settings = const GuideSettings(),
  }) async {
    final granted = Platform.isIOS
        ? await deliveryNative.invokeMethod<bool>('requestCameraPermission') ==
              true
        : (await Permission.camera.request()).isGranted;
    if (!granted) throw StateError('需要相机权限，请在系统设置中开启');
    if (!context.mounted) return null;
    final session = await SessionStore().create(settings, model: model.name);
    if (!context.mounted) {
      await session.directory.delete(recursive: true);
      return null;
    }
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          model: model,
          session: session,
          settings: settings,
          returnWhenComplete: true,
        ),
      ),
    );
    if (completed != true || !session.complete) {
      // 只清理本次会话的副本，不删除相册原图或宿主目录。
      await session.directory.delete(recursive: true);
      return null;
    }
    return DeliveryPhotoResult(
      parcelPhoto: File(session.shots[ShotStage.parcel]!.path),
      environmentPhoto: File(session.shots[ShotStage.environment]!.path),
      report: File(session.reportPath),
    );
  }
}
