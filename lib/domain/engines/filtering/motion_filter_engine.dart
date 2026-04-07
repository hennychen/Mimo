import '../../entities/joint_type.dart';
import 'one_euro_filter.dart';

/// 运动滤波引擎
/// 
/// 组合多种滤波策略：死区过滤 + One Euro滤波 + 速度平滑
class MotionFilterEngine {
  /// 各关节的One Euro滤波器
  final Map<JointType, OneEuroFilter> _filters;
  
  /// 死区阈值（弧度）
  final double deadZoneThreshold;
  
  /// 速度平滑系数
  final double velocitySmoothing;

  MotionFilterEngine({
    this.deadZoneThreshold = 0.01, // 约0.57度
    this.velocitySmoothing = 0.3,
  }) : _filters = {};

  /// 过滤角度
  /// 
  /// 参数:
  /// - [angles] 原始角度映射（弧度）
  /// 返回: 过滤后的角度映射（弧度）
  Map<JointType, double> filter(Map<JointType, double> angles) {
    final result = <JointType, double>{};
    
    for (final entry in angles.entries) {
      final joint = entry.key;
      final rawAngle = entry.value;
      
      // 获取或创建滤波器
      final filter = _filters.putIfAbsent(
        joint,
        () => OneEuroFilter.forAngle(initialValue: rawAngle),
      );
      
      // 应用滤波
      final filteredAngle = _applyFilters(joint, rawAngle, filter);
      
      result[joint] = filteredAngle;
    }
    
    return result;
  }

  /// 应用所有滤波策略
  double _applyFilters(
    JointType joint,
    double rawAngle,
    OneEuroFilter filter,
  ) {
    // 1. 死区过滤：微小变化忽略
    final lastFiltered = _lastFilteredAngles[joint] ?? rawAngle;
    if ((rawAngle - lastFiltered).abs() < deadZoneThreshold) {
      return lastFiltered;
    }
    
    // 2. One Euro滤波
    final oneEuroResult = filter.filter(rawAngle);
    
    // 3. 速度平滑
    final smoothedResult = _applyVelocitySmoothing(joint, oneEuroResult);
    
    // 更新最后过滤结果
    _lastFilteredAngles[joint] = smoothedResult;
    
    return smoothedResult;
  }

  /// 上一次过滤后的角度
  final Map<JointType, double> _lastFilteredAngles = {};
  
  /// 角速度历史
  final Map<JointType, List<double>> _velocityHistory = {};

  /// 应用速度平滑
  double _applyVelocitySmoothing(JointType joint, double angle) {
    final lastAngle = _lastFilteredAngles[joint];
    if (lastAngle == null) return angle;
    
    // 计算当前速度
    final velocity = angle - lastAngle;
    
    // 更新速度历史
    _velocityHistory.putIfAbsent(joint, () => []);
    _velocityHistory[joint]!.add(velocity);
    if (_velocityHistory[joint]!.length > 5) {
      _velocityHistory[joint]!.removeAt(0);
    }
    
    // 计算平均速度
    final avgVelocity = _velocityHistory[joint]!.reduce((a, b) => a + b) / 
        _velocityHistory[joint]!.length;
    
    // 平滑结果
    return lastAngle + avgVelocity * velocitySmoothing + 
           velocity * (1 - velocitySmoothing);
  }

  /// 重置滤波器
  void reset() {
    _filters.clear();
    _lastFilteredAngles.clear();
    _velocityHistory.clear();
  }

  /// 重置特定关节的滤波器
  void resetJoint(JointType joint) {
    _filters.remove(joint);
    _lastFilteredAngles.remove(joint);
    _velocityHistory.remove(joint);
  }
}