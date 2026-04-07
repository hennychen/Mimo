
/// 置信度处理器
/// 
/// 根据关键点置信度平滑过渡角度，避免直接冻结
class ConfidenceProcessor {
  /// 高置信度阈值
  final double highThreshold;
  
  /// 低置信度阈值
  final double lowThreshold;
  
  /// idle姿态角度（弧度）
  final Map<String, double> idleAngles;

  ConfidenceProcessor({
    this.highThreshold = 0.6,
    this.lowThreshold = 0.3,
  }) : idleAngles = {};

  /// 设置idle角度
  void setIdleAngle(String jointName, double angle) {
    idleAngles[jointName] = angle;
  }

  /// 混合角度
  /// 
  /// 根据置信度在跟踪角度和idle角度之间平滑过渡
  double blend({
    required double trackedAngle,
    required double idleAngle,
    required double confidence,
  }) {
    // 计算权重
    double weight;
    
    if (confidence >= highThreshold) {
      // 高置信度：完全跟踪
      weight = 1.0;
    } else if (confidence > lowThreshold) {
      // 中等置信度：线性过渡
      weight = (confidence - lowThreshold) / (highThreshold - lowThreshold);
    } else {
      // 低置信度：向idle过渡
      weight = 0.0;
    }
    
    // 线性插值
    return _lerp(idleAngle, trackedAngle, weight);
  }

  /// 处理多个角度
  Map<String, double> processAngles(
    Map<String, double> trackedAngles,
    Map<String, double> confidences,
  ) {
    final result = <String, double>{};
    
    for (final entry in trackedAngles.entries) {
      final jointName = entry.key;
      final trackedAngle = entry.value;
      final confidence = confidences[jointName] ?? 0.0;
      final idleAngle = idleAngles[jointName] ?? trackedAngle;
      
      result[jointName] = blend(
        trackedAngle: trackedAngle,
        idleAngle: idleAngle,
        confidence: confidence,
      );
    }
    
    return result;
  }

  /// 线性插值
  double _lerp(double a, double b, double t) {
    return a + (b - a) * t.clamp(0.0, 1.0);
  }

  /// 计算平均置信度
  static double averageConfidence(List<double> confidences) {
    if (confidences.isEmpty) return 0.0;
    return confidences.reduce((a, b) => a + b) / confidences.length;
  }

  /// 判断是否应该进入idle状态
  bool shouldEnterIdle(List<double> confidences, {int consecutiveFrames = 10}) {
    final avg = averageConfidence(confidences);
    return avg < lowThreshold;
  }
}