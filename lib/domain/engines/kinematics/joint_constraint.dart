import '../../entities/joint_type.dart';

/// 关节约束配置
class JointConstraint {
  /// 最小角度限制（度）
  final double minAngle;
  
  /// 最大角度限制（度）
  final double maxAngle;
  
  /// 单帧最大变化量（度）
  final double maxDeltaPerFrame;

  const JointConstraint({
    required this.minAngle,
    required this.maxAngle,
    required this.maxDeltaPerFrame,
  });

  /// 默认肩关节约束
  static const JointConstraint defaultShoulder = JointConstraint(
    minAngle: -180,
    maxAngle: 180,
    maxDeltaPerFrame: 25,
  );

  /// 默认肘关节约束
  static const JointConstraint defaultElbow = JointConstraint(
    minAngle: 0,
    maxAngle: 150,
    maxDeltaPerFrame: 25,
  );

  /// 根据关节类型获取默认约束
  static JointConstraint forJoint(JointType joint) {
    switch (joint) {
      case JointType.leftShoulder:
      case JointType.rightShoulder:
        return defaultShoulder;
      case JointType.leftElbow:
      case JointType.rightElbow:
        return defaultElbow;
      default:
        return defaultShoulder;
    }
  }
}