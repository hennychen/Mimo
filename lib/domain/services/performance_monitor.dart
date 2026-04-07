import 'dart:async';

/// 性能状态
class PerformanceState {
  /// 当前FPS
  final double fps;
  
  /// 平均延迟（毫秒）
  final double avgLatencyMs;
  
  /// P90延迟（毫秒）
  final double p90LatencyMs;
  
  /// 性能等级
  final PerformanceLevel level;
  
  /// 是否需要降级
  final bool needsDegradation;
  
  /// 时间戳
  final DateTime timestamp;

  const PerformanceState({
    required this.fps,
    required this.avgLatencyMs,
    required this.p90LatencyMs,
    required this.level,
    required this.needsDegradation,
    required this.timestamp,
  });

  /// 创建默认状态
  factory PerformanceState.initial() {
    return PerformanceState(
      fps: 0,
      avgLatencyMs: 0,
      p90LatencyMs: 0,
      level: PerformanceLevel.normal,
      needsDegradation: false,
      timestamp: DateTime.now(),
    );
  }
}

/// 性能等级
enum PerformanceLevel {
  /// 高性能 - FPS >= 25
  high,
  
  /// 正常 - FPS >= 20
  normal,
  
  /// 低性能 - FPS >= 15
  low,
  
  /// 极低 - FPS < 15
  critical,
}

/// 性能监控服务
/// 
/// 监控帧率、延迟等性能指标，并提供降级建议
class PerformanceMonitor {
  /// FPS历史记录
  final List<double> _fpsHistory = [];
  
  /// 延迟历史记录
  final List<double> _latencyHistory = [];
  
  /// 最大历史记录数量
  final int maxHistorySize;
  
  /// 低FPS阈值
  final double lowFpsThreshold;
  
  /// 极低FPS阈值
  final double criticalFpsThreshold;
  
  /// 高延迟阈值（毫秒）
  final double highLatencyThreshold;
  
  /// 当前状态
  PerformanceState _currentState = PerformanceState.initial();
  
  /// 状态变化回调
  void Function(PerformanceState state)? onStateChanged;
  
  /// 定时器
  Timer? _monitorTimer;

  PerformanceMonitor({
    this.maxHistorySize = 60,
    this.lowFpsThreshold = 20.0,
    this.criticalFpsThreshold = 15.0,
    this.highLatencyThreshold = 100.0,
  });

  /// 当前状态
  PerformanceState get currentState => _currentState;
  
  /// 开始监控
  void startMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateState();
    });
  }
  
  /// 停止监控
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  /// 记录帧时间
  void recordFrame(int processingTimeMs) {
    // 记录延迟
    _latencyHistory.add(processingTimeMs.toDouble());
    if (_latencyHistory.length > maxHistorySize) {
      _latencyHistory.removeAt(0);
    }
  }

  /// 记录FPS
  void recordFps(double fps) {
    _fpsHistory.add(fps);
    if (_fpsHistory.length > maxHistorySize) {
      _fpsHistory.removeAt(0);
    }
  }

  /// 更新状态
  void _updateState() {
    if (_fpsHistory.isEmpty) return;
    
    final avgFps = _fpsHistory.reduce((a, b) => a + b) / _fpsHistory.length;
    final avgLatency = _latencyHistory.isEmpty 
        ? 0.0 
        : _latencyHistory.reduce((a, b) => a + b) / _latencyHistory.length;
    final p90Latency = _calculateP90();
    final level = _determineLevel(avgFps);
    final needsDegradation = avgFps < lowFpsThreshold || avgLatency > highLatencyThreshold;
    
    final newState = PerformanceState(
      fps: avgFps,
      avgLatencyMs: avgLatency,
      p90LatencyMs: p90Latency,
      level: level,
      needsDegradation: needsDegradation,
      timestamp: DateTime.now(),
    );
    
    if (_currentState.fps != newState.fps || 
        _currentState.level != newState.level ||
        _currentState.needsDegradation != newState.needsDegradation) {
      _currentState = newState;
      onStateChanged?.call(newState);
    }
  }

  /// 计算P90延迟
  double _calculateP90() {
    if (_latencyHistory.isEmpty) return 0.0;
    
    final sorted = List<double>.from(_latencyHistory)..sort();
    final index = (sorted.length * 0.9).floor();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  /// 确定性能等级
  PerformanceLevel _determineLevel(double fps) {
    if (fps >= 25) return PerformanceLevel.high;
    if (fps >= 20) return PerformanceLevel.normal;
    if (fps >= 15) return PerformanceLevel.low;
    return PerformanceLevel.critical;
  }

  /// 获取降级建议
  DegradationSuggestion getDegradationSuggestion() {
    final fps = _currentState.fps;
    final latency = _currentState.avgLatencyMs;
    
    if (fps < criticalFpsThreshold) {
      return DegradationSuggestion(
        shouldReduceResolution: true,
        shouldReduceFps: true,
        targetFps: 15,
        reason: 'FPS过低 (${fps.toStringAsFixed(1)})，建议降低分辨率和帧率',
      );
    }
    
    if (fps < lowFpsThreshold) {
      return DegradationSuggestion(
        shouldReduceResolution: true,
        shouldReduceFps: false,
        targetFps: 20,
        reason: 'FPS较低 (${fps.toStringAsFixed(1)})，建议降低分辨率',
      );
    }
    
    if (latency > highLatencyThreshold) {
      return DegradationSuggestion(
        shouldReduceResolution: true,
        shouldReduceFps: false,
        targetFps: 30,
        reason: '延迟过高 (${latency.toStringAsFixed(0)}ms)，建议降低分辨率',
      );
    }
    
    return DegradationSuggestion(
      shouldReduceResolution: false,
      shouldReduceFps: false,
      targetFps: 30,
      reason: '性能正常',
    );
  }

  /// 重置
  void reset() {
    _fpsHistory.clear();
    _latencyHistory.clear();
    _currentState = PerformanceState.initial();
  }

  /// 释放资源
  void dispose() {
    stopMonitoring();
    _fpsHistory.clear();
    _latencyHistory.clear();
  }
}

/// 降级建议
class DegradationSuggestion {
  final bool shouldReduceResolution;
  final bool shouldReduceFps;
  final int targetFps;
  final String reason;

  const DegradationSuggestion({
    required this.shouldReduceResolution,
    required this.shouldReduceFps,
    required this.targetFps,
    required this.reason,
  });
}