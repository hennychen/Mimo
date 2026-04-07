import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/body_metrics.dart';
import '../../domain/entities/frame_result.dart';
import '../../domain/engines/calibration/calibration_engine.dart';
import '../../domain/engines/confidence/confidence_processor.dart';
import '../../domain/engines/filtering/motion_filter_engine.dart';
import '../../domain/engines/kinematics/kinematics_engine.dart';
import '../../domain/engines/normalization/normalization_engine.dart';
import '../../domain/engines/performance/performance_scheduler.dart';
import '../../domain/engines/semantic/semantic_engine.dart';
import '../../domain/services/angle_compute_service.dart';
import '../../domain/services/analytics_service.dart';
import '../../domain/services/avatar_state_machine.dart';
import '../../domain/services/performance_monitor.dart';
import '../../domain/services/sound_service.dart';
import '../pipeline/motion_pipeline.dart';
import '../../data/repositories_impl/camera_repository_impl.dart';
import '../../data/repositories_impl/pose_repository_impl.dart';
import '../../data/repositories_impl/storage_repository_impl.dart';

/// 摄像头仓库Provider
final cameraRepositoryProvider = Provider<CameraRepositoryImpl>((ref) {
  return CameraRepositoryImpl();
});

/// 姿态检测仓库Provider
final poseRepositoryProvider = Provider<PoseRepositoryImpl>((ref) {
  return PoseRepositoryImpl();
});

/// 存储仓库Provider
final storageRepositoryProvider = Provider<StorageRepositoryImpl>((ref) {
  return StorageRepositoryImpl();
});

/// 置信度处理器Provider
final confidenceProcessorProvider = Provider<ConfidenceProcessor>((ref) {
  return ConfidenceProcessor();
});

/// 人体归一化引擎Provider
final normalizationEngineProvider = Provider<NormalizationEngine>((ref) {
  return NormalizationEngine();
});

/// 关节运动学引擎Provider
final kinematicsEngineProvider = Provider<KinematicsEngine>((ref) {
  return KinematicsEngine();
});

/// 运动滤波引擎Provider
final motionFilterEngineProvider = Provider<MotionFilterEngine>((ref) {
  return MotionFilterEngine();
});

/// 动作语义引擎Provider
final semanticEngineProvider = Provider<SemanticEngine>((ref) {
  return SemanticEngine();
});

/// 性能调度器Provider
final performanceSchedulerProvider = Provider<PerformanceScheduler>((ref) {
  return PerformanceScheduler();
});

/// 角度计算服务Provider
final angleComputeServiceProvider = Provider<AngleComputeService>((ref) {
  return AngleComputeService();
});

/// 校准引擎Provider
final calibrationEngineProvider = Provider<CalibrationEngine>((ref) {
  return CalibrationEngine();
});

/// 运动处理管道Provider
final motionPipelineProvider = Provider<MotionPipeline>((ref) {
  return MotionPipeline(
    poseRepository: ref.watch(poseRepositoryProvider),
    confidenceProcessor: ref.watch(confidenceProcessorProvider),
    normalizationEngine: ref.watch(normalizationEngineProvider),
    kinematicsEngine: ref.watch(kinematicsEngineProvider),
    filterEngine: ref.watch(motionFilterEngineProvider),
    semanticEngine: ref.watch(semanticEngineProvider),
    performanceScheduler: ref.watch(performanceSchedulerProvider),
    angleComputeService: ref.watch(angleComputeServiceProvider),
  );
});

/// 校准状态Provider
final calibrationStatusProvider = StateProvider<CalibrationStatus>((ref) {
  return CalibrationStatus.waiting;
});

/// 人体度量数据Provider
final bodyMetricsProvider = StateProvider<BodyMetrics?>((ref) {
  return null;
});

/// 相机是否就绪Provider
final isCameraReadyProvider = StateProvider<bool>((ref) {
  return false;
});

/// 是否正在追踪Provider
final isTrackingProvider = StateProvider<bool>((ref) {
  return false;
});

/// 当前FPS Provider
final currentFpsProvider = StateProvider<double>((ref) {
  return 0.0;
});

/// 帧结果Provider
final frameResultProvider = StateProvider<FrameResult?>((ref) {
  return null;
});

/// 音效服务Provider
final soundServiceProvider = Provider<SoundService>((ref) {
  return SoundService();
});

/// 性能监控Provider
final performanceMonitorProvider = Provider<PerformanceMonitor>((ref) {
  return PerformanceMonitor();
});

/// 埋点服务Provider
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

/// 角色状态机Provider
final avatarStateMachineProvider = StateProvider<AvatarStateMachine>((ref) {
  return AvatarStateMachine();
});

/// 角色状态Provider
final avatarStateProvider = StateProvider<AvatarState>((ref) {
  return AvatarState.idle;
});
