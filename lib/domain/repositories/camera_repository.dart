import 'package:camera/camera.dart' as camera;

/// 摄像头仓库接口
abstract class CameraRepository {
  /// 获取摄像头控制器
  camera.CameraController? get controller;
  
  /// 是否已初始化
  bool get isInitialized;
  
  /// 初始化摄像头
  Future<void> initialize();
  
  /// 开始预览
  Future<void> startPreview();
  
  /// 停止预览
  Future<void> stopPreview();
  
  /// 切换摄像头
  Future<void> switchCamera();
  
  /// 释放资源
  void dispose();
  
  /// 获取可用摄像头列表
  List<camera.CameraDescription> get availableCameras;
}