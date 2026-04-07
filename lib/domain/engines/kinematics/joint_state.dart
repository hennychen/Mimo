import '../../entities/joint_type.dart';

/// 关节状态
/// 
/// 跟踪关节的当前角度、历史角度和速度
class JointState {
  /// 当前角度（弧度）
  double currentAngle;
  
  /// 上一帧角度（弧度）
  double lastAngle;
  
  /// 角速度（弧度/帧）
  double velocity;
  
  /// 角度变化历史（用于平滑）
  final List<double> angleHistory;
  
  /// 最大历史记录数
  static const int maxHistoryLength = 5;

  JointState({
    double initialAngle = 0.0,
  })  : currentAngle = initialAngle,
        lastAngle = initialAngle,
        velocity = 0.0,
        angleHistory = [];

  /// 更新角度
  void update(double newAngle) {
    lastAngle = currentAngle;
    currentAngle = newAngle;
    velocity = currentAngle - lastAngle;
    
    // 更新历史记录
    angleHistory.add(newAngle);
    if (angleHistory.length > maxHistoryLength) {
      angleHistory.removeAt(0);
    }
  }

  /// 获取平滑后的角度（移动平均）
  double get smoothedAngle {
    if (angleHistory.isEmpty) return currentAngle;
    return angleHistory.reduce((a, b) => a + b) / angleHistory.length;
  }

  /// 重置状态
  void reset({double angle = 0.0}) {
    currentAngle = angle;
    lastAngle = angle;
    velocity = 0.0;
    angleHistory.clear();
  }

  /// 转换为Map（用于序列化）
  Map<String, dynamic> toMap() {
    return {
      'currentAngle': currentAngle,
      'lastAngle': lastAngle,
      'velocity': velocity,
    };
  }

  /// 从Map创建
  factory JointState.fromMap(Map<String, dynamic> map) {
    return JointState(
      initialAngle: map['currentAngle'] as double? ?? 0.0,
    )..lastAngle = map['lastAngle'] as double? ?? 0.0
     ..velocity = map['velocity'] as double? ?? 0.0;
  }
}

/// 所有关节的状态集合
class JointStates {
  final Map<JointType, JointState> _states;

  JointStates() : _states = {};

  /// 获取指定关节的状态
  JointState operator [](JointType joint) {
    return _states.putIfAbsent(joint, () => JointState());
  }

  /// 设置指定关节的状态
  void operator []=(JointType joint, JointState state) {
    _states[joint] = state;
  }

  /// 重置所有状态
  void resetAll() {
    for (final state in _states.values) {
      state.reset();
    }
  }

  /// 获取所有关节类型
  Iterable<JointType> get joints => _states.keys;
}