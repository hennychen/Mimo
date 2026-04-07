import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/frame_result.dart';
import '../../domain/entities/joint_type.dart';
import '../../domain/entities/landmark.dart';
import '../../domain/engines/calibration/calibration_engine.dart';
import '../../domain/engines/confidence/confidence_processor.dart';
import '../../domain/engines/filtering/motion_filter_engine.dart';
import '../../domain/engines/kinematics/kinematics_engine.dart';
import '../../domain/engines/normalization/normalization_engine.dart';
import '../../domain/engines/performance/performance_scheduler.dart';
import '../../domain/engines/semantic/semantic_engine.dart';
import '../../domain/services/angle_compute_service.dart';
import '../providers/providers.dart';
import '../../data/repositories_impl/camera_repository_impl.dart';
import '../../data/repositories_impl/pose_repository_impl.dart';

/// 帧处理状态
enum FrameProcessingState { idle, calibrating, tracking, paused }

/// 帧处理服务
///
/// 连接摄像头、姿态检测和运动处理管道
class FrameProcessingService {
  final Ref _ref;
  final CameraRepositoryImpl _cameraRepository;
  final PoseRepositoryImpl _poseRepository;

  final NormalizationEngine _normalizationEngine;
  final KinematicsEngine _kinematicsEngine;
  final MotionFilterEngine _filterEngine;
  final SemanticEngine _semanticEngine;
  // ignore: unused_field
  final PerformanceScheduler _performanceScheduler;
  final AngleComputeService _angleComputeService;
  final ConfidenceProcessor _confidenceProcessor;
  final CalibrationEngine _calibrationEngine;

  FrameProcessingState _state = FrameProcessingState.idle;
  int _poseDetectedFrameCount = 0; // 检测到姿态的帧数
  StreamSubscription? _imageStreamSubscription;
  int _frameCount = 0;
  int _lastFpsUpdate = 0;
  double _currentFps = 0.0;

  FrameProcessingService(this._ref)
    : _cameraRepository = _ref.read(cameraRepositoryProvider),
      _poseRepository = _ref.read(poseRepositoryProvider),
      _normalizationEngine = _ref.read(normalizationEngineProvider),
      _kinematicsEngine = _ref.read(kinematicsEngineProvider),
      _filterEngine = _ref.read(motionFilterEngineProvider),
      _semanticEngine = _ref.read(semanticEngineProvider),
      _performanceScheduler = _ref.read(performanceSchedulerProvider),
      _angleComputeService = _ref.read(angleComputeServiceProvider),
      _confidenceProcessor = _ref.read(confidenceProcessorProvider),
      _calibrationEngine = _ref.read(calibrationEngineProvider);

  /// 当前状态
  FrameProcessingState get state => _state;

  /// 当前FPS
  double get currentFps => _currentFps;

  /// 开始帧处理
  Future<void> start() async {
    if (_state != FrameProcessingState.idle) return;

    try {
      // 初始化摄像头
      await _cameraRepository.initialize();

      // 等待相机完全就绪(CameraX 需要更多时间)
      await Future.delayed(const Duration(milliseconds: 500));

      // 验证相机是否真的初始化成功
      if (!_cameraRepository.isInitialized) {
        throw Exception('Camera initialization failed or not completed');
      }

      print('✅ Camera repository ready, proceeding with pose detection');

      // 初始化姿态检测
      await _poseRepository.initialize();

      // 再次等待确保所有服务就绪
      await Future.delayed(const Duration(milliseconds: 100));

      // 设置图像回调
      _cameraRepository.onImageReceived = _processCameraImage;

      // 开始图像流 - 添加重试机制
      print('📷 Starting image stream...');

      int retryCount = 0;
      const maxRetries = 3;
      bool streamStarted = false;

      while (retryCount < maxRetries && !streamStarted) {
        try {
          await _cameraRepository.startPreview();
          streamStarted = true;
          print('✅ Image stream started successfully');
        } catch (e) {
          retryCount++;
          if (retryCount < maxRetries) {
            print(
              '⚠️ Failed to start stream (attempt $retryCount/$maxRetries): $e',
            );
            print('⏳ Retrying in 500ms...');
            await Future.delayed(const Duration(milliseconds: 500));
          } else {
            print('❌ Failed to start image stream after $maxRetries attempts');
            rethrow;
          }
        }
      }

      _state = FrameProcessingState.calibrating;
      _ref.read(calibrationStatusProvider.notifier).state =
          CalibrationStatus.waiting;

      // 通知相机已就绪
      _ref.read(isCameraReadyProvider.notifier).state = true;

      print('✅ Frame processing started successfully');
    } catch (e) {
      print('❌ Failed to start frame processing: $e');
      print('⚠️ Application will continue in limited mode');

      // 即使相机失败,也允许应用继续运行
      // 用户可以看到UI,只是没有相机功能
      _state = FrameProcessingState.paused;
    }
  }

  /// 停止帧处理
  Future<void> stop() async {
    await _cameraRepository.stopPreview();
    _imageStreamSubscription?.cancel();
    _state = FrameProcessingState.idle;
  }

  /// 暂停/恢复
  void pause() {
    _state = FrameProcessingState.paused;
  }

  void resume() {
    if (_state == FrameProcessingState.paused) {
      _state = FrameProcessingState.tracking;
    }
  }

  /// 处理摄像头图像
  void _processCameraImage(CameraImage image) {
    if (_state == FrameProcessingState.paused ||
        _state == FrameProcessingState.idle) {
      return;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // 更新FPS
    _updateFps(timestamp);

    // 异步处理图像
    _processImageAsync(image, timestamp);
  }

  /// 异步处理图像
  Future<void> _processImageAsync(CameraImage image, int timestamp) async {
    try {
      // 1. 姿态检测
      // 尝试0度rotation (可能是正面摄像头不需要旋转)
      const rotation = 0; // 尝试0度

      final joints = await _poseRepository.detectFromCameraImage(
        image,
        width: image.width,
        height: image.height,
        rotation: rotation,
      );

      if (joints.isEmpty) {
        _handleNoPoseDetected(timestamp);

        // 每300帧输出一次状态(约每10秒)
        if (_frameCount % 300 == 0) {
          debugPrint(
            '⚠️ Pose detection: 0 poses detected in ${_frameCount} frames (rotation=$rotation)',
          );
        }
        return;
      }

      // 检测到姿态
      _poseDetectedFrameCount++;
      print('✅ Pose detected! Frame #$_frameCount, Landmarks: ${joints.length} (rotation=$rotation)');

      // 2. 根据状态处理
      if (_state == FrameProcessingState.calibrating) {
        _handleCalibration(joints);
      } else if (_state == FrameProcessingState.tracking) {
        _handleTracking(joints, timestamp);
      }
    } catch (e) {
      print('Error processing image: $e');
    }
  }

  /// 处理校准阶段
  void _handleCalibration(Map<JointType, Landmark> joints) {
    final result = _calibrationEngine.processFrame(joints);

    _ref.read(calibrationStatusProvider.notifier).state = result.status;

    if (result.isSuccess && result.metrics != null) {
      // 校准成功
      _normalizationEngine.calibrate(joints);
      _ref.read(bodyMetricsProvider.notifier).state = result.metrics;

      // 保存校准数据
      _ref.read(storageRepositoryProvider).saveCalibration(result.metrics!);

      // 切换到追踪状态
      _state = FrameProcessingState.tracking;
    }
  }

  /// 处理追踪阶段
  void _handleTracking(Map<JointType, Landmark> joints, int timestamp) {
    // 计算平均置信度
    final confidences = joints.values.map((l) => l.visibility).toList();
    final avgConfidence = ConfidenceProcessor.averageConfidence(confidences);

    // 归一化
    final normalizedJoints = _normalizationEngine.normalize(joints);

    // 角度计算
    final rawAngles = _angleComputeService.compute(normalizedJoints);

    if (rawAngles.isEmpty) return;

    // 关节约束
    final constrainedAngles = _kinematicsEngine.apply(rawAngles);

    // 滤波
    final filteredAngles = _filterEngine.filter(constrainedAngles);

    // 置信度混合
    final blendedAngles = <JointType, double>{};
    for (final entry in filteredAngles.entries) {
      final joint = entry.key;
      final angle = entry.value;
      final confidence = joints[joint]?.visibility ?? 0.0;

      blendedAngles[joint] = _confidenceProcessor.blend(
        trackedAngle: angle,
        idleAngle: 0.0,
        confidence: confidence,
      );
    }

    // 动作语义识别
    final gesture = _semanticEngine.detect(joints);

    // 创建帧结果
    final frameResult = FrameResult(
      jointAngles: blendedAngles,
      gesture: gesture,
      timestamp: timestamp,
      confidence: avgConfidence,
    );

    // 通知UI更新
    _onFrameResult(frameResult);
  }

  /// 处理未检测到姿态
  void _handleNoPoseDetected(int timestamp) {
    // 可以在这里触发idle动画
  }

  /// 帧结果回调
  void Function(FrameResult result)? onFrameResult;

  void _onFrameResult(FrameResult result) {
    // 更新Provider
    _ref.read(frameResultProvider.notifier).state = result;
    // 调用回调
    onFrameResult?.call(result);
  }

  /// 更新FPS
  void _updateFps(int timestamp) {
    _frameCount++;

    if (timestamp - _lastFpsUpdate > 1000) {
      _currentFps = _frameCount * 1000.0 / (timestamp - _lastFpsUpdate);
      _frameCount = 0;
      _lastFpsUpdate = timestamp;

      _ref.read(currentFpsProvider.notifier).state = _currentFps;
    }
  }

  /// 释放资源
  void dispose() {
    stop();
    _poseRepository.dispose();
    _cameraRepository.dispose();
  }
}

/// 帧处理服务Provider
final frameProcessingServiceProvider = Provider((ref) {
  return FrameProcessingService(ref);
});
