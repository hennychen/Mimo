import 'dart:math' as math;
import '../../domain/entities/landmark.dart';

/// 几何计算工具类
class GeometryUtils {
  GeometryUtils._();

  /// 计算两关节之间的角度（弧度）
  /// 
  /// 参数:
  /// - [start] 起始关键点
  /// - [end] 结束关键点
  /// 返回: 从start指向end的角度（弧度）
  static double calculateAngle(Landmark start, Landmark end) {
    final dx = end.x - start.x;
    final dy = end.y - start.y;
    return _atan2(dy, dx);
  }

  /// 计算三个关节形成的角度（弧度）
  /// 
  /// 参数:
  /// - [a] 第一个点
  /// - [vertex] 顶点
  /// - [c] 第三个点
  /// 返回: 在vertex处形成的角度（弧度）
  static double calculateJointAngle(Landmark a, Landmark vertex, Landmark c) {
    final angle1 = calculateAngle(vertex, a);
    final angle2 = calculateAngle(vertex, c);
    double diff = angle1 - angle2;
    
    // 归一化到 [-π, π]
    while (diff > _pi) {
      diff -= 2 * _pi;
    }
    while (diff < -_pi) {
      diff += 2 * _pi;
    }
    
    return diff.abs();
  }

  /// 计算肩肘腕三点形成的肘关节角度
  static double calculateElbowAngle(
    Landmark shoulder,
    Landmark elbow,
    Landmark wrist,
  ) {
    return calculateJointAngle(shoulder, elbow, wrist);
  }

  /// 计算肩关节角度（相对于躯干）
  static double calculateShoulderAngle(
    Landmark shoulder,
    Landmark elbow,
    Landmark hip,
  ) {
    // 躯干方向（肩膀到髋部）
    final torsoAngle = calculateAngle(shoulder, hip);
    // 手臂方向（肩膀到肘部）
    final armAngle = calculateAngle(shoulder, elbow);
    
    // 相对角度
    double diff = armAngle - torsoAngle;
    while (diff > _pi) {
      diff -= 2 * _pi;
    }
    while (diff < -_pi) {
      diff += 2 * _pi;
    }
    
    return diff;
  }

  /// 检查是否是T-Pose
  /// 
  /// 返回: 角度是否大于阈值（度）
  static bool isTPose(
    Landmark leftShoulder,
    Landmark leftElbow,
    Landmark rightShoulder,
    Landmark rightElbow,
    double thresholdDegrees,
  ) {
    // 左臂与躯干夹角
    final leftArmAngle = calculateAngle(leftShoulder, leftElbow);
    // 右臂与躯干夹角（需要翻转）
    final rightArmAngle = calculateAngle(rightShoulder, rightElbow);
    
    // 检查手臂是否水平伸展
    final threshold = thresholdDegrees * _pi / 180.0;
    
    // 水平方向角度约为0或π
    return leftArmAngle.abs() < threshold || 
           (leftArmAngle - _pi).abs() < threshold ||
           rightArmAngle.abs() < threshold ||
           (rightArmAngle - _pi).abs() < threshold;
  }

  /// 计算两关键点之间的距离
  static double distance(Landmark a, Landmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// 检查关键点是否在安全框内
  static bool isInSafetyFrame(
    Landmark landmark,
    double frameLeft,
    double frameTop,
    double frameRight,
    double frameBottom,
  ) {
    return landmark.x >= frameLeft &&
           landmark.x <= frameRight &&
           landmark.y >= frameTop &&
           landmark.y <= frameBottom;
  }

  static const double _pi = 3.14159265359;
  static double _atan2(double y, double x) => math.atan2(y, x);
}
