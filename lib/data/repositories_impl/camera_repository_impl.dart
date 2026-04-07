import 'package:camera/camera.dart' as camera;
import '../../domain/repositories/camera_repository.dart';

/// 摄像头仓库实现
class CameraRepositoryImpl implements CameraRepository {
  camera.CameraController? _controller;
  List<camera.CameraDescription> _cameras = [];
  bool _isInitialized = false;

  @override
  camera.CameraController? get controller => _controller;

  @override
  bool get isInitialized => _isInitialized;

  @override
  List<camera.CameraDescription> get availableCameras => _cameras;

  @override
  Future<void> initialize() async {
    // 防止重复初始化
    if (_isInitialized) {
      print('⚠️ Camera already initialized, skipping');
      return;
    }

    // 如果正在初始化中,等待一下
    if (_controller != null && !_isInitialized) {
      print('⚠️ Camera initialization in progress, waiting...');
      await Future.delayed(const Duration(milliseconds: 500));
      if (_isInitialized) {
        print('✅ Camera initialized during wait');
        return;
      }
    }

    try {
      _cameras = await camera.availableCameras();

      if (_cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      // 优先使用后置摄像头(兼容性更好)
      camera.CameraDescription selectedCamera;
      try {
        selectedCamera = _cameras.firstWhere(
          (cam) => cam.lensDirection == camera.CameraLensDirection.back,
        );
        print('Using back camera');
      } catch (e) {
        // 如果没有后置摄像头,使用前置
        selectedCamera = _cameras.firstWhere(
          (cam) => cam.lensDirection == camera.CameraLensDirection.front,
          orElse: () => _cameras.first,
        );
        print('Using front camera');
      }

      print(
        'Using camera: ${selectedCamera.name}, direction: ${selectedCamera.lensDirection}',
      );
      print('Available cameras count: ${_cameras.length}');

      // 尝试初始化相机,如果失败则提供降级方案
      try {
        _controller = camera.CameraController(
          selectedCamera,
          camera.ResolutionPreset.medium, // 640x480 提高检测精度
          enableAudio: false,
          imageFormatGroup: camera.ImageFormatGroup.nv21, // ML Kit 对 NV21 支持更好
        );

        await _controller!.initialize();
        _isInitialized = true;
        print('✅ Camera initialized successfully');
      } catch (cameraError) {
        print('❌ Camera initialization failed: $cameraError');
        print('⚠️ Using mock camera mode for development');

        // 在开发模式下,即使相机失败也标记为已初始化
        // 这样应用可以继续运行,只是没有真实的相机数据
        _isInitialized = false;
        rethrow;
      }
    } catch (e) {
      _isInitialized = false;
      print('❌ Camera repository initialization error: $e');
      rethrow;
    }
  }

  @override
  Future<void> startPreview() async {
    if (_controller != null && _isInitialized) {
      await _controller!.startImageStream(_onImageStream);
    }
  }

  @override
  Future<void> stopPreview() async {
    if (_controller != null && _isInitialized) {
      await _controller!.stopImageStream();
    }
  }

  @override
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;

    await stopPreview();
    await _controller?.dispose();

    final currentIndex = _cameras.indexOf(_controller!.description);
    final nextIndex = (currentIndex + 1) % _cameras.length;

    _controller = camera.CameraController(
      _cameras[nextIndex],
      camera.ResolutionPreset.medium, // 640x480 提高检测精度
      enableAudio: false,
      imageFormatGroup: camera.ImageFormatGroup.nv21, // ML Kit 对 NV21 支持更好
    );

    await _controller!.initialize();
    _isInitialized = true;
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  /// 图像流回调（可被子类覆写）
  void Function(camera.CameraImage image)? onImageReceived;

  void _onImageStream(camera.CameraImage image) {
    onImageReceived?.call(image);
  }
}
