import '../../domain/entities/frame_result.dart';
import '../../domain/entities/joint_type.dart';
import '../../domain/engines/confidence/confidence_processor.dart';
import '../../domain/engines/filtering/motion_filter_engine.dart';
import '../../domain/engines/kinematics/kinematics_engine.dart';
import '../../domain/engines/normalization/normalization_engine.dart';
import '../../domain/engines/performance/performance_scheduler.dart';
import '../../domain/engines/semantic/semantic_engine.dart';
import '../../domain/services/angle_compute_service.dart';
import '../../domain/repositories/pose_repository.dart';

/// 运动处理管道
/// 
/// 核心编排层，串联所有引擎处理姿态数据
class MotionPipeline {
  /// 姿态检测仓库
  final PoseRepository poseRepository;
  
  /// 置信度处理器
  final ConfidenceProcessor confidenceProcessor;
  
  /// 人体归一化引擎
  final NormalizationEngine normalizationEngine;
  
  /// 关节运动学引擎
  final KinematicsEngine kinematicsEngine;
  
  /// 运动滤波引擎
  final MotionFilterEngine filterEngine;
  
  /// 动作语义引擎
  final SemanticEngine semanticEngine;
  
  /// 性能调度器
  final PerformanceScheduler performanceScheduler;
  
  /// 角度计算服务
  final AngleComputeService angleComputeService;

  MotionPipeline({
    required this.poseRepository,
    required this.confidenceProcessor,
    required this.normalizationEngine,
    required this.kinematicsEngine,
    required this.filterEngine,
    required this.semanticEngine,
    required this.performanceScheduler,
    required this.angleComputeService,
  });

  /// 处理单帧
  /// 
  /// 参数:
  /// - [timestamp] 时间戳（毫秒）
  /// - [image] 图像数据
  /// - [width] 图像宽度
  /// - [height] 图像高度
  /// 返回: 帧处理结果
  FrameResult process({
    required int timestamp,
    required dynamic image,
    required int width,
    required int height,
  }) {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    
    // 1. 姿态检测
    final joints = poseRepository.detect(image, width, height);
    
    if (joints.isEmpty) {
      return FrameResult.empty(timestamp);
    }
    
    // 2. 计算平均置信度
    final confidences = joints.values.map((l) => l.visibility).toList();
    final avgConfidence = ConfidenceProcessor.averageConfidence(confidences);
    
    // 3. 人体归一化
    final normalizedJoints = normalizationEngine.normalize(joints);
    
    // 4. 角度计算
    final rawAngles = angleComputeService.compute(normalizedJoints);
    
    if (rawAngles.isEmpty) {
      return FrameResult(
        jointAngles: {},
        timestamp: timestamp,
        confidence: avgConfidence,
      );
    }
    
    // 5. 关节约束
    final constrainedAngles = kinematicsEngine.apply(rawAngles);
    
    // 6. 滤波
    final filteredAngles = filterEngine.filter(constrainedAngles);
    
    // 7. 置信度混合（与idle姿态插值）
    final blendedAngles = <JointType, double>{};
    for (final entry in filteredAngles.entries) {
      final joint = entry.key;
      final angle = entry.value;
      final confidence = joints[joint]?.visibility ?? 0.0;
      
      blendedAngles[joint] = confidenceProcessor.blend(
        trackedAngle: angle,
        idleAngle: 0.0, // 默认idle角度
        confidence: confidence,
      );
    }
    
    // 8. 动作语义识别
    final gesture = semanticEngine.detect(joints);
    
    // 9. 性能调度
    final processingTime = DateTime.now().millisecondsSinceEpoch - startTime;
    performanceScheduler.update(
      fps: 1000.0 / processingTime.clamp(1, 1000),
      latencyMs: processingTime.toDouble(),
    );
    
    return FrameResult(
      jointAngles: blendedAngles,
      gesture: gesture,
      timestamp: timestamp,
      confidence: avgConfidence,
    );
  }

  /// 重置所有引擎
  void reset() {
    kinematicsEngine.reset();
    filterEngine.reset();
    semanticEngine.reset();
    angleComputeService.reset();
    normalizationEngine.reset();
    performanceScheduler.reset();
  }
}