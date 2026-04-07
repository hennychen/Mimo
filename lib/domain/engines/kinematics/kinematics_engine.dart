import 'dart:math' as math;
import '../../entities/joint_type.dart';
import 'joint_constraint.dart';
import 'joint_state.dart';

/// 关节运动学引擎
/// 
/// 负责限制关节角度范围、防止突变、保证动作符合人体生物力学
class KinematicsEngine {
  /// 关节约束配置
  final Map<JointType, JointConstraint> constraints;
  
  /// 关节状态
  final JointStates states;

  KinematicsEngine({
    Map<JointType, JointConstraint>? constraints,
  })  : constraints = constraints ?? _defaultConstraints(),
        states = JointStates();

  /// 创建默认约束
  static Map<JointType, JointConstraint> _defaultConstraints() {
    return {
      JointType.leftShoulder: JointConstraint.defaultShoulder,
      JointType.leftElbow: JointConstraint.defaultElbow,
      JointType.rightShoulder: JointConstraint.defaultShoulder,
      JointType.rightElbow: JointConstraint.defaultElbow,
    };
  }

  /// 应用运动学约束
  /// 
  /// 参数:
  /// - [rawAngles] 原始角度映射（弧度）
  /// 返回: 约束后的角度映射（弧度）
  Map<JointType, double> apply(Map<JointType, double> rawAngles) {
    final result = <JointType, double>{};
    
    for (final entry in rawAngles.entries) {
      final joint = entry.key;
      final rawAngle = entry.value;
      
      // 获取约束配置
      final constraint = constraints[joint] ?? JointConstraint.defaultShoulder;
      
      // 应用约束
      final constrainedAngle = _applyConstraints(joint, rawAngle, constraint);
      
      result[joint] = constrainedAngle;
    }
    
    return result;
  }

  /// 对单个关节应用约束
  double _applyConstraints(
    JointType joint,
    double rawAngle,
    JointConstraint constraint,
  ) {
    final state = states[joint];
    
    // 1. 角度范围限制
    final minRad = constraint.minAngle * math.pi / 180.0;
    final maxRad = constraint.maxAngle * math.pi / 180.0;
    double angle = rawAngle.clamp(minRad, maxRad);
    
    // 2. 单帧变化量限制
    final maxDelta = constraint.maxDeltaPerFrame * math.pi / 180.0;
    final delta = angle - state.currentAngle;
    
    if (delta.abs() > maxDelta) {
      // 限制变化量
      angle = state.currentAngle + (maxDelta * delta.sign);
    }
    
    // 3. 更新状态
    state.update(angle);
    
    return angle;
  }

  /// 重置所有关节状态
  void reset() {
    states.resetAll();
  }

  /// 更新特定关节的约束
  void updateConstraint(JointType joint, JointConstraint constraint) {
    constraints[joint] = constraint;
  }

  /// 获取关节的当前状态
  JointState getState(JointType joint) => states[joint];
}