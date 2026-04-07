import '../../domain/entities/joint_type.dart';

/// 关节约束常量
class JointConstants {
  JointConstants._();

  /// 关节角度约束（度）
  static const Map<JointType, _AngleConstraint> angleConstraints = {
    JointType.leftShoulder: _AngleConstraint(minAngle: -180, maxAngle: 180),
    JointType.leftElbow: _AngleConstraint(minAngle: 0, maxAngle: 150),
    JointType.rightShoulder: _AngleConstraint(minAngle: -180, maxAngle: 180),
    JointType.rightElbow: _AngleConstraint(minAngle: 0, maxAngle: 150),
  };

  /// 单帧最大角度变化量（度）
  static const double maxDeltaPerFrame = 25.0;

  /// 获取关节的最小角度
  static double getMinAngle(JointType joint) {
    return angleConstraints[joint]?.minAngle ?? -180.0;
  }

  /// 获取关节的最大角度
  static double getMaxAngle(JointType joint) {
    return angleConstraints[joint]?.maxAngle ?? 180.0;
  }

  /// 角度转换为弧度
  static double degreesToRadians(double degrees) => degrees * 3.14159265359 / 180.0;

  /// 弧度转换为角度
  static double radiansToDegrees(double radians) => radians * 180.0 / 3.14159265359;
}

/// 角度约束
class _AngleConstraint {
  final double minAngle;
  final double maxAngle;

  const _AngleConstraint({required this.minAngle, required this.maxAngle});
}