import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/providers.dart';

/// 摄像头预览Widget
class CameraPreviewWidget extends ConsumerWidget {
  const CameraPreviewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听相机是否就绪的状态
    final isCameraReady = ref.watch(isCameraReadyProvider);

    // 从 CameraRepository 获取相机控制器
    final cameraRepository = ref.read(cameraRepositoryProvider);
    final controller = cameraRepository.controller;

    // 如果相机未就绪或控制器为空，显示提示
    if (!isCameraReady || controller == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: Colors.white.withOpacity(0.5),
              ),
              SizedBox(height: 16),
              Text(
                '相机未就绪',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '正在初始化...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 显示相机预览
    return ClipRect(
      child: Transform.scale(
        scale: _calculateScale(context, controller),
        child: Center(child: CameraPreview(controller)),
      ),
    );
  }

  double _calculateScale(BuildContext context, CameraController controller) {
    // 计算缩放比例以适应屏幕
    final size = MediaQuery.of(context).size;
    final aspectRatio = controller.value.aspectRatio;

    var scale = size.aspectRatio * aspectRatio;

    if (scale < 1) {
      scale = 1 / scale;
    }

    return scale;
  }
}
