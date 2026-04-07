/// 性能配置
class PerformanceConfig {
  PerformanceConfig._();

  /// 目标推理帧率
  static const int targetInferenceFPS = 30;

  /// 降级后的推理帧率
  static const int degradedInferenceFPS = 15;

  /// 最低推理帧率
  static const int minimumInferenceFPS = 5;

  /// 渲染帧率（固定60FPS，使用插值）
  static const int renderFPS = 60;

  /// 推理图像分辨率（宽度）
  static const int inferenceWidth = 640;
  static const int inferenceHeight = 480;

  /// 低分辨率模式
  static const int lowResWidth = 320;
  static const int lowResHeight = 240;

  /// 温度阈值
  static const double temperatureWarning = 42.0; // 摄氏度
  static const double temperatureCritical = 45.0;

  /// 延迟阈值（毫秒）
  static const int latencyWarning = 100;
  static const int latencyCritical = 120;

  /// 性能级别
  static const PerformanceLevel defaultLevel = PerformanceLevel.high;

  /// 获取指定级别的配置
  static PerformanceSettings getSettings(PerformanceLevel level) {
    switch (level) {
      case PerformanceLevel.high:
        return PerformanceSettings(
          inferenceFPS: targetInferenceFPS,
          width: inferenceWidth,
          height: inferenceHeight,
        );
      case PerformanceLevel.medium:
        return PerformanceSettings(
          inferenceFPS: degradedInferenceFPS,
          width: lowResWidth * 2,
          height: lowResHeight * 2,
        );
      case PerformanceLevel.low:
        return PerformanceSettings(
          inferenceFPS: minimumInferenceFPS,
          width: lowResWidth,
          height: lowResHeight,
        );
    }
  }
}

/// 性能级别
enum PerformanceLevel {
  high,
  medium,
  low,
}

/// 性能设置
class PerformanceSettings {
  final int inferenceFPS;
  final int width;
  final int height;

  const PerformanceSettings({
    required this.inferenceFPS,
    required this.width,
    required this.height,
  });
}