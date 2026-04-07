import 'dart:math' as math;

/// 数学工具类
class MathUtils {
  MathUtils._();

  /// 角度转弧度
  static const double degreesToRadians = math.pi / 180.0;

  /// 弧度转角度
  static const double radiansToDegrees = 180.0 / math.pi;

  /// 将值限制在指定范围内
  static double clamp(double value, double min, double max) {
    return value.clamp(min, max);
  }

  /// 线性插值
  static double lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  /// 计算两点之间的角度（弧度）
  static double angleBetweenPoints(
    double x1, double y1,
    double x2, double y2,
  ) {
    return math.atan2(y2 - y1, x2 - x1);
  }

  /// 计算两点之间的距离
  static double distance(
    double x1, double y1,
    double x2, double y2,
  ) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// 归一化角度到 [-π, π]
  static double normalizeAngle(double angle) {
    while (angle > math.pi) {
      angle -= 2 * math.pi;
    }
    while (angle < -math.pi) {
      angle += 2 * math.pi;
    }
    return angle;
  }

  /// 角度差（考虑周期性）
  static double angleDifference(double a, double b) {
    double diff = a - b;
    while (diff > math.pi) {
      diff -= 2 * math.pi;
    }
    while (diff < -math.pi) {
      diff += 2 * math.pi;
    }
    return diff;
  }

  /// 平滑阶跃函数
  static double smoothStep(double edge0, double edge1, double x) {
    final t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// 判断值是否在范围内
  static bool inRange(double value, double min, double max) {
    return value >= min && value <= max;
  }
}