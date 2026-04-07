import 'dart:math' as math;

/// One Euro Filter
/// 
/// 低延迟自适应低通滤波器，用于消除抖动同时保持快速响应
/// 论文: https://cristal.univ-lille.fr/~casiez/1euro/
class OneEuroFilter {
  /// 最小截止频率
  final double minCutoff;
  
  /// 速度系数（越大越快）
  final double beta;
  
  /// 导数截止频率
  final double dCutoff;

  /// 上一次的值
  double _lastValue;
  
  /// 上一次的时间戳
  double _lastTimestamp;
  
  /// 导数滤波器
  LowPassFilter? _derivativeFilter;
  
  /// 值滤波器
  LowPassFilter? _valueFilter;

  OneEuroFilter({
    this.minCutoff = 1.0,
    this.beta = 0.007,
    this.dCutoff = 1.0,
    double initialValue = 0.0,
    double initialTimestamp = 0.0,
  })  : _lastValue = initialValue,
        _lastTimestamp = initialTimestamp;

  /// 过滤值
  /// 
  /// 参数:
  /// - [value] 当前值
  /// - [timestamp] 当前时间戳（秒）
  double filter(double value, [double? timestamp]) {
    final t = timestamp ?? DateTime.now().millisecondsSinceEpoch / 1000.0;
    
    // 初始化滤波器
    _derivativeFilter ??= LowPassFilter(alpha: _alpha(minCutoff, t - _lastTimestamp));
    _valueFilter ??= LowPassFilter(alpha: _alpha(minCutoff, t - _lastTimestamp));
    
    // 计算导数
    final dValue = (value - _lastValue) / (t - _lastTimestamp).clamp(0.001, 1.0);
    
    // 过滤导数
    final edValue = _derivativeFilter!.filter(dValue, _alpha(dCutoff, t - _lastTimestamp));
    
    // 动态计算截止频率
    final cutoff = minCutoff + beta * edValue.abs();
    
    // 过滤值
    final result = _valueFilter!.filter(value, _alpha(cutoff, t - _lastTimestamp));
    
    _lastValue = result;
    _lastTimestamp = t;
    
    return result;
  }

  /// 计算alpha系数
  double _alpha(double cutoff, double te) {
    final tau = 1.0 / (2 * math.pi * cutoff);
    return 1.0 / (1.0 + tau / te.clamp(0.001, 1.0));
  }

  /// 重置滤波器
  void reset([double initialValue = 0.0]) {
    _lastValue = initialValue;
    _lastTimestamp = DateTime.now().millisecondsSinceEpoch / 1000.0;
    _derivativeFilter = null;
    _valueFilter = null;
  }

  /// 创建适用于角度的滤波器
  static OneEuroFilter forAngle({
    double initialValue = 0.0,
  }) {
    return OneEuroFilter(
      minCutoff: 1.0,
      beta: 0.007,
      dCutoff: 1.0,
      initialValue: initialValue,
    );
  }
}

/// 低通滤波器
class LowPassFilter {
  double _value;
  bool _initialized = false;

  LowPassFilter({double alpha = 0.5}) : _value = 0.0;

  double filter(double value, double alpha) {
    if (!_initialized) {
      _value = value;
      _initialized = true;
      return _value;
    }
    
    _value = alpha * value + (1 - alpha) * _value;
    return _value;
  }
}