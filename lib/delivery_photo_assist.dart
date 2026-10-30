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

  static DeliveryPhotoResult _fromSession(PhotoSession session) =>
      DeliveryPhotoResult(
        parcelPhoto: File(session.shots[ShotStage.parcel]!.path),
        environmentPhoto: File(session.shots[ShotStage.environment]!.path),
        report: File(session.reportPath),
      );
}

class DeliveryPhotoAssist {
  /// 拍齐两张后返回本地文件；取消返回 null。宿主负责上传和文件留存。
  static Future<DeliveryPhotoResult?> capture(
    BuildContext context, {
    required PicoDetModel model,
    GuideSettings settings = const GuideSettings(),
  }) async {
    await _requestCameraPermission();
    if (!context.mounted) return null;
    final session = await SessionStore().create(settings, model: model.name);
    if (!context.mounted) {
      await session.directory.delete(recursive: true);
      return null;
    }
    return _openSession(context, model, settings, session);
  }

  /// 只重拍 [stage]，保存一张后立即返回新的双照片结果。
  ///
  /// [previous] 的两张原图和报告不被修改；取消返回 null。
  /// 新结果拥有独立会话目录，宿主采用新结果后可清理旧结果目录。
  static Future<DeliveryPhotoResult?> retake(
    BuildContext context, {
    required PicoDetModel model,
    required DeliveryPhotoResult previous,
    required ShotStage stage,
    GuideSettings settings = const GuideSettings(),
  }) async {
    await _requestCameraPermission();
    if (!context.mounted) return null;
    final session = await SessionStore().createRetake(
      settings: settings,
      model: model.name,
      stage: stage,
      parcelPhoto: previous.parcelPhoto,
      environmentPhoto: previous.environmentPhoto,
      report: previous.report,
    );
    if (!context.mounted) {
      await session.directory.delete(recursive: true);
      return null;
    }
    return _openSession(context, model, settings, session);
  }

  static Future<void> _requestCameraPermission() async {
    final granted = Platform.isIOS
        ? await deliveryNative.invokeMethod<bool>('requestCameraPermission') ==
              true
        : (await Permission.camera.request()).isGranted;
    if (!granted) throw StateError('需要相机权限，请在系统设置中开启');
  }

  static Future<DeliveryPhotoResult?> _openSession(
    BuildContext context,
    PicoDetModel model,
    GuideSettings settings,
    PhotoSession session,
  ) async {
    var keep = false;
    var pushed = false;
    final route = MaterialPageRoute<bool>(
      builder: (_) => CameraScreen(
        model: model,
        session: session,
        settings: settings,
        returnWhenComplete: true,
      ),
    );
    try {
      final navigation = Navigator.of(context).push<bool>(route);
      pushed = true;
      final completed = await navigation;
      if (completed != true || !session.complete) return null;
      keep = true;
      return DeliveryPhotoResult._fromSession(session);
    } finally {
      // 只清理本次会话的副本，不删除原结果、相册原图或宿主目录。
      if (!keep) {
        // pop 的 Future 早于退出动画完成，避免缩略图仍在解码时删除文件。
        if (pushed) await route.completed;
        await session.directory.delete(recursive: true);
      }
    }
  }
}
