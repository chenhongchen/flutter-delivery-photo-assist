# 第三方声明

本组件原创代码采用根目录 Apache-2.0。第三方版权、许可与修改标记保留；宿主发布时仍须随应用保留对应声明。组件源码不含 Ultralytics SDK、YOLO-World 权重或从其代码改名而来的相机实现。

| 组件 | 许可或条款 | 来源与用途 |
| --- | --- | --- |
| Flutter / camera / image_picker / path_provider | BSD-3-Clause | https://github.com/flutter/packages ，官方相机、相册、本地目录 |
| ONNX Runtime | MIT | https://github.com/microsoft/onnxruntime ，本机推理 |
| flutter_onnxruntime 1.9.0 | MIT | https://github.com/masicai/flutter_onnxruntime ，ONNX Runtime Flutter 包装 |
| dartcv4 2.2.2 | Apache-2.0 | https://github.com/rainyl/opencv_dart ，保留于 packages/dartcv4；启用 features2d/calib3d、Apple 默认 Ninja 及目标架构修正 |
| OpenCV / opencv_contrib | Apache-2.0（所用版本） | https://github.com/opencv/opencv ，通过 Native Assets 构建；仅启用本组件需要的模块 |
| crypto | BSD-3-Clause | https://github.com/dart-lang/core ，本机模型 SHA-256 校验 |
| permission_handler | MIT | https://github.com/Baseflow/flutter-permission-handler ，Android 相机权限 |
| share_plus | BSD-3-Clause | https://github.com/fluttercommunity/plus_plugins ，本机记录分享，由用户主动触发 |
| AndroidX ExifInterface | Apache-2.0 | https://developer.android.com/jetpack/androidx/releases/exifinterface ，相册图片转正 |
| Google ML Kit 文本识别 SDK | Google API/ML Kit 相应使用条款 | https://developers.google.com/ml-kit/terms ，Android 本机 OCR；不将此 SDK 宣称为组件的 Apache 源码 |
| Apple AVFoundation / Vision / UIKit | Apple 平台 SDK 条款 | iOS 相机权限、图片预处理、本机 OCR |

本仓库保留 dartcv4 的 LICENSE；其本机 C/C++ 依赖所带声明也须保留。最终依赖版本以宿主锁文件为准。运行与构建工具、系统 SDK、权重和训练数据是不同的授权对象。

## 模型

公共源码不携带模型权重。演示脚本下载 PaddleDetection 官方的 PicoDet-S/XS COCO ONNX 文件，核对 SHA-256，并移除冗余常量输入声明、固定 batch=1、从实际输出形状重建框数量，不修改类别或训练参数。

代码许可来源：https://github.com/PaddlePaddle/PaddleDetection/blob/release/2.9/LICENSE 。官方模型列表：https://github.com/PaddlePaddle/PaddleDetection/blob/release/2.9/configs/picodet/README.md 。当前未独立取得 checkpoint 的单独再分发许可声明，代码许可证不被用来替代权重/训练数据的核对。演示模型不会作为公开发行包附件。

生产模型交付方须提供预训练和训练数据来源、使用权限、导出过程、类别清单、模型版本与 SHA-256。业务照片、订单数据和私有训练模型不属于本公开仓库。

## 原创扩展的来源

Dart 取景规则、固定布局、性能策略、OpenCV 特征比较，以及 FrameQuality / SceneText 辅助算法源于本项目此前自行编写的演示扩展；已独立接入自有 MethodChannel。没有保留原第三方插件的视图、推理、相机控制器或 shared core。
