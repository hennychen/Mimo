import '../../../core/config/performance_config.dart';

/// 性能状态
class PerformanceState {
  /// 当前FPS
  final double fps;
  
  /// 延迟（毫秒）
  final double latencyMs;
  
  /// 设备温度（摄氏度）
  final double temperature;
  
  /// 连续高负载帧数
  final int consecutiveHighLoadFrames;
  
  /// 连续低负载帧数
  final int consecutiveLowLoadFrames;

  const PerformanceState({
    this.fps = 30.0,
    this.latencyMs = 0.0,
    this.temperature = 25.0,
    this.consecutiveHighLoadFrames = 0,
    this.consecutiveLowLoadFrames = 0,
  });

  /// 是否需要降级
  bool get needsDegradation {
    return temperature > PerformanceConfig.temperatureWarning ||
           latencyMs > PerformanceConfig.latencyWarning ||
           fps < PerformanceConfig.degradedInferenceFPS;
  }

  /// 是否可以升级
  bool get canUpgrade {
    return temperature < PerformanceConfig.temperatureWarning - 5 &&
           latencyMs < PerformanceConfig.latencyWarning - 20 &&
           fps > PerformanceConfig.targetInferenceFPS - 5;
  }

  /// 复制并修改
  PerformanceState copyWith({
    double? fps,
    double? latencyMs,
    double? temperature,
    int? consecutiveHighLoadFrames,
    int? consecutiveLowLoadFrames,
  }) {
    return PerformanceState(
      fps: fps ?? this.fps,
      latencyMs: latencyMs ?? this.latencyMs,
      temperature: temperature ?? this.temperature,
      consecutiveHighLoadFrames: consecutiveHighLoadFrames ?? this.consecutiveHighLoadFrames,
      consecutiveLowLoadFrames: consecutiveLowLoadFrames ?? this.consecutiveLowLoadFrames,
    );
  }
}

/// 性能调度器
/// 
/// 主动管理性能状态，实现降级和升级策略
class PerformanceScheduler {
  /// 当前性能级别
  PerformanceLevel _currentLevel = PerformanceLevel.high;
  
  /// 当前性能状态
  PerformanceState _state = const PerformanceState();
  
  /// 性能设置
  PerformanceSettings _settings = PerformanceConfig.getSettings(PerformanceLevel.high);
  
  /// 连续高负载阈值（帧数）
  static const int highLoadThreshold = 30;
  
  /// 连续低负载阈值（帧数）
  static const int lowLoadThreshold = 60;

  PerformanceScheduler();

  /// 当前性能级别
  PerformanceLevel get currentLevel => _currentLevel;
  
  /// 当前性能设置
  PerformanceSettings get settings => _settings;
  
  /// 当前性能状态
  PerformanceState get state => _state;

  /// 更新性能状态
  /// 
  /// 参数:
  /// - [fps] 当前FPS
  /// - [latencyMs] 当前延迟
  /// - [temperature] 当前温度
  void update({
    required double fps,
    required double latencyMs,
    double? temperature,
  }) {
    // 更新状态
    bool needsUpdate = _state.needsDegradation;
    bool canUpgrade = _state.canUpgrade;
    
    int highLoadFrames = _state.consecutiveHighLoadFrames;
    int lowLoadFrames = _state.consecutiveLowLoadFrames;
    
    if (needsUpdate) {
      highLoadFrames++;
      lowLoadFrames = 0;
    } else if (canUpgrade) {
      lowLoadFrames++;
      highLoadFrames = 0;
    } else {
      highLoadFrames = 0;
      lowLoadFrames = 0;
    }
    
    _state = _state.copyWith(
      fps: fps,
      latencyMs: latencyMs,
      temperature: temperature ?? _state.temperature,
      consecutiveHighLoadFrames: highLoadFrames,
      consecutiveLowLoadFrames: lowLoadFrames,
    );
    
    // 触发调整
    _adjustIfNeeded();
  }

  /// 根据状态调整性能
  void _adjustIfNeeded() {
    // 检查是否需要降级
    if (_state.consecutiveHighLoadFrames >= highLoadThreshold) {
      _reducePerformance();
      _state = _state.copyWith(consecutiveHighLoadFrames: 0);
      return;
    }
    
    // 检查是否可以升级
    if (_state.consecutiveLowLoadFrames >= lowLoadThreshold) {
      _increasePerformance();
      _state = _state.copyWith(consecutiveLowLoadFrames: 0);
      return;
    }
  }

  /// 降低性能
  void _reducePerformance() {
    switch (_currentLevel) {
      case PerformanceLevel.high:
        _currentLevel = PerformanceLevel.medium;
        break;
      case PerformanceLevel.medium:
        _currentLevel = PerformanceLevel.low;
        break;
      case PerformanceLevel.low:
        // 已经是最低级别
        return;
    }
    
    _settings = PerformanceConfig.getSettings(_currentLevel);
  }

  /// 提升性能
  void _increasePerformance() {
    switch (_currentLevel) {
      case PerformanceLevel.low:
        _currentLevel = PerformanceLevel.medium;
        break;
      case PerformanceLevel.medium:
        _currentLevel = PerformanceLevel.high;
        break;
      case PerformanceLevel.high:
        // 已经是最高级别
        return;
    }
    
    _settings = PerformanceConfig.getSettings(_currentLevel);
  }

  /// 强制设置性能级别
  void setLevel(PerformanceLevel level) {
    _currentLevel = level;
    _settings = PerformanceConfig.getSettings(level);
  }

  /// 重置为默认
  void reset() {
    _currentLevel = PerformanceLevel.high;
    _settings = PerformanceConfig.getSettings(PerformanceLevel.high);
    _state = const PerformanceState();
  }
}