import 'dart:math' as math;
import '../entities/joint_type.dart';
import '../entities/landmark.dart';
import '../../core/utils/geometry_utils.dart';

/// 角度计算服务
/// 
/// 负责从关键点计算关节角度
class AngleComputeService {
  /// 上一次的角度（用于平滑）
  final Map<JointType, double> _lastAngles = {};

  AngleComputeService();

  /// 计算所有关节的角度
  /// 
  /// 参数:
  /// - [joints] 关键点映射
  /// 返回: 角度映射（弧度）
  Map<JointType, double> compute(Map<JointType, Landmark> joints) {
    final result = <JointType, double>{};
    
    // 计算左肩角度
    final leftShoulderAngle = _computeShoulderAngle(
      joints,
      isLeft: true,
    );
    if (leftShoulderAngle != null) {
      result[JointType.leftShoulder] = leftShoulderAngle;
    }
    
    // 计算右肩角度
    final rightShoulderAngle = _computeShoulderAngle(
      joints,
      isLeft: false,
    );
    if (rightShoulderAngle != null) {
      result[JointType.rightShoulder] = rightShoulderAngle;
    }
    
    // 计算左肘角度
    final leftElbowAngle = _computeElbowAngle(
      joints,
      isLeft: true,
    );
    if (leftElbowAngle != null) {
      result[JointType.leftElbow] = leftElbowAngle;
    }
    
    // 计算右肘角度
    final rightElbowAngle = _computeElbowAngle(
      joints,
      isLeft: false,
    );
    if (rightElbowAngle != null) {
      result[JointType.rightElbow] = rightElbowAngle;
    }
    
    // 更新历史
    for (final entry in result.entries) {
      _lastAngles[entry.key] = entry.value;
    }
    
    return result;
  }

  /// 计算肩关节角度
  double? _computeShoulderAngle(
    Map<JointType, Landmark> joints, {
    required bool isLeft,
  }) {
    final shoulder = joints[isLeft ? JointType.leftShoulder : JointType.rightShoulder];
    final elbow = joints[isLeft ? JointType.leftElbow : JointType.rightElbow];
    
    if (shoulder == null || elbow == null) return null;
    if (shoulder.visibility < 0.5 || elbow.visibility < 0.5) return null;
    
    // 计算肩到肘的角度
    final angle = GeometryUtils.calculateAngle(shoulder, elbow);
    
    // 归一化到 [-π, π]
    return _normalizeAngle(angle);
  }

  /// 计算肘关节角度
  double? _computeElbowAngle(
    Map<JointType, Landmark> joints, {
    required bool isLeft,
  }) {
    final shoulder = joints[isLeft ? JointType.leftShoulder : JointType.rightShoulder];
    final elbow = joints[isLeft ? JointType.leftElbow : JointType.rightElbow];
    final wrist = joints[isLeft ? JointType.leftWrist : JointType.rightWrist];
    
    if (shoulder == null || elbow == null || wrist == null) return null;
    if (shoulder.visibility < 0.5 || elbow.visibility < 0.5 || wrist.visibility < 0.5) {
      return null;
    }
    
    // 计算肘关节弯曲角度
    final angle = GeometryUtils.calculateJointAngle(shoulder, elbow, wrist);
    
    // 肘关节角度通常在0到π之间
    return angle.clamp(0.0, math.pi);
  }

  /// 归一化角度到 [-π, π]
  double _normalizeAngle(double angle) {
    while (angle > math.pi) {
      angle -= 2 * math.pi;
    }
    while (angle < -math.pi) {
      angle += 2 * math.pi;
    }
    return angle;
  }

  /// 获取上一次的角度
  double? getLastAngle(JointType joint) => _lastAngles[joint];

  /// 重置
  void reset() {
    _lastAngles.clear();
  }
}