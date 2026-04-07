import 'dart:math' as math;
import '../../entities/body_metrics.dart';
import '../../entities/joint_type.dart';
import '../../entities/landmark.dart';

/// 人体归一化引擎
/// 
/// 消除不同体型用户的动作幅度差异
class NormalizationEngine {
  /// 当前的人体度量数据
  BodyMetrics? metrics;
  
  /// 标准肩宽基准值
  static const double baselineShoulderWidth = 0.35;

  NormalizationEngine();

  /// 是否已校准
  bool get isCalibrated => metrics != null && metrics!.isValid;

  /// 执行校准
  /// 
  /// 参数:
  /// - [joints] T-Pose姿态下的关键点映射
  void calibrate(Map<JointType, Landmark> joints) {
    final leftShoulder = joints[JointType.leftShoulder];
    final rightShoulder = joints[JointType.rightShoulder];
    final leftElbow = joints[JointType.leftElbow];
    final leftWrist = joints[JointType.leftWrist];
    final rightElbow = joints[JointType.rightElbow];
    final rightWrist = joints[JointType.rightWrist];

    if (leftShoulder == null || rightShoulder == null) {
      // 无法校准，使用默认值
      metrics = BodyMetrics.defaults();
      return;
    }

    // 计算肩宽
    final shoulderWidth = _distance(leftShoulder, rightShoulder);
    
    // 计算缩放因子
    final scaleFactor = shoulderWidth / baselineShoulderWidth;
    
    // 计算臂长
    double leftArmLength = 0.0;
    double rightArmLength = 0.0;
    
    if (leftElbow != null) {
      leftArmLength += _distance(leftShoulder, leftElbow);
      if (leftWrist != null) {
        leftArmLength += _distance(leftElbow, leftWrist);
      }
    }
    
    if (rightElbow != null) {
      rightArmLength += _distance(rightShoulder, rightElbow);
      if (rightWrist != null) {
        rightArmLength += _distance(rightElbow, rightWrist);
      }
    }

    metrics = BodyMetrics(
      shoulderWidth: shoulderWidth,
      scaleFactor: scaleFactor.clamp(0.5, 2.0), // 限制缩放范围
      leftArmLength: leftArmLength,
      rightArmLength: rightArmLength,
      calibratedAt: DateTime.now(),
    );
  }

  /// 归一化关键点
  /// 
  /// 参数:
  /// - [joints] 原始关键点映射
  /// 返回: 归一化后的关键点映射
  Map<JointType, Landmark> normalize(Map<JointType, Landmark> joints) {
    if (!isCalibrated) {
      return joints; // 未校准时直接返回原始数据
    }

    final scale = metrics!.scaleFactor;
    final result = <JointType, Landmark>{};
    
    // 计算中心点（通常是两肩中点）
    final leftShoulder = joints[JointType.leftShoulder];
    final rightShoulder = joints[JointType.rightShoulder];
    
    double centerX = 0.5;
    double centerY = 0.5;
    
    if (leftShoulder != null && rightShoulder != null) {
      centerX = (leftShoulder.x + rightShoulder.x) / 2;
      centerY = (leftShoulder.y + rightShoulder.y) / 2;
    }

    // 对每个关键点进行归一化
    for (final entry in joints.entries) {
      final joint = entry.key;
      final landmark = entry.value;
      
      // 相对于中心点的偏移，按缩放因子归一化
      final normalizedX = centerX + (landmark.x - centerX) / scale;
      final normalizedY = centerY + (landmark.y - centerY) / scale;
      
      result[joint] = landmark.copyWith(
        x: normalizedX.clamp(0.0, 1.0),
        y: normalizedY.clamp(0.0, 1.0),
      );
    }
    
    return result;
  }

  /// 归一化角度
  /// 
  /// 根据用户的体型特征调整角度幅度
  double normalizeAngle(double angle) {
    if (!isCalibrated) return angle;
    
    // 根据缩放因子调整角度
    // 身材较小的用户动作幅度放大，身材较大的用户动作幅度缩小
    final scale = 1.0 / math.sqrt(metrics!.scaleFactor);
    return angle * scale;
  }

  /// 计算两点之间的距离
  double _distance(Landmark a, Landmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// 重置校准
  void reset() {
    metrics = null;
  }

  /// 使用默认校准数据
  void useDefaults() {
    metrics = BodyMetrics.defaults();
  }
}