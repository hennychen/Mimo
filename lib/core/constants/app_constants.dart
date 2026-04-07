/// 应用常量
class AppConstants {
  AppConstants._();

  /// 应用名称
  static const String appName = 'Mimo';

  /// 应用版本
  static const String appVersion = '1.0.0';

  /// 性能相关常量
  static const int targetFPS = 30;
  static const int minFPS = 15;
  static const int maxLatencyMs = 120;

  /// 校准相关常量
  static const int calibrationTimeoutSeconds = 30;
  static const double calibrationArmAngleThreshold = 60.0; // 度
  static const int calibrationHoldFrames = 30; // 持续帧数

  /// 安全框相关常量
  static const double safetyFrameWidthRatio = 0.6;
  static const double safetyFrameHeightRatio = 0.8;
  static const double safetyFrameTopMargin = 0.1;

  /// 置信度阈值
  static const double confidenceHighThreshold = 0.6;
  static const double confidenceLowThreshold = 0.3;

  /// 性能降级阈值
  static const double temperatureWarningThreshold = 45.0; // 摄氏度
  static const double temperatureCriticalThreshold = 50.0;
  static const int idleTimeoutSeconds = 30;
  static const int idleDeepTimeoutSeconds = 120;
}