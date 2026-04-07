import 'dart:ui';

import 'body_part.dart';

/// Avatar构建结果
///
/// 包含生成的Avatar所有数据
class AvatarBuildResult {
  /// 构建是否成功
  final bool success;

  /// 身体部位纹理映射
  final Map<BodyPart, BodyPartTexture> textures;

  /// 错误信息（如果失败）
  final String? errorMessage;

  /// 失败原因类型
  final AvatarBuildError? errorType;

  /// 构建耗时（毫秒）
  final int buildTimeMs;

  /// 原始图像尺寸
  final Size sourceSize;

  /// 质量评分（综合）
  final double overallQuality;

  const AvatarBuildResult({
    required this.success,
    this.textures = const {},
    this.errorMessage,
    this.errorType,
    this.buildTimeMs = 0,
    this.sourceSize = Size.zero,
    this.overallQuality = 0.0,
  });

  /// 成功的结果
  factory AvatarBuildResult.success({
    required Map<BodyPart, BodyPartTexture> textures,
    required Size sourceSize,
    int buildTimeMs = 0,
    double overallQuality = 1.0,
  }) {
    return AvatarBuildResult(
      success: true,
      textures: textures,
      sourceSize: sourceSize,
      buildTimeMs: buildTimeMs,
      overallQuality: overallQuality,
    );
  }

  /// 失败的结果
  factory AvatarBuildResult.failure({
    required String errorMessage,
    AvatarBuildError? errorType,
    int buildTimeMs = 0,
  }) {
    return AvatarBuildResult(
      success: false,
      errorMessage: errorMessage,
      errorType: errorType,
      buildTimeMs: buildTimeMs,
    );
  }

  /// 获取指定部位的纹理
  BodyPartTexture? getTexture(BodyPart part) => textures[part];

  /// 是否有所有必需部位
  bool hasAllRequiredParts() {
    final requiredParts = BodyPart.mainParts;
    return requiredParts.every((part) => textures.containsKey(part));
  }

  /// 获取缺失的部位
  List<BodyPart> getMissingParts() {
    final requiredParts = BodyPart.mainParts;
    return requiredParts.where((part) => !textures.containsKey(part)).toList();
  }

  /// 复制并修改
  AvatarBuildResult copyWith({
    bool? success,
    Map<BodyPart, BodyPartTexture>? textures,
    String? errorMessage,
    AvatarBuildError? errorType,
    int? buildTimeMs,
    Size? sourceSize,
    double? overallQuality,
  }) {
    return AvatarBuildResult(
      success: success ?? this.success,
      textures: textures ?? this.textures,
      errorMessage: errorMessage ?? this.errorMessage,
      errorType: errorType ?? this.errorType,
      buildTimeMs: buildTimeMs ?? this.buildTimeMs,
      sourceSize: sourceSize ?? this.sourceSize,
      overallQuality: overallQuality ?? this.overallQuality,
    );
  }
}

/// Avatar构建失败原因
enum AvatarBuildError {
  /// 未检测到人体
  noHumanDetected,

  /// 关键点缺失
  missingJoints,

  /// 关键点置信度过低
  lowConfidence,

  /// 人体分割失败
  segmentationFailed,

  /// 姿势不合格（如手臂交叉、侧身等）
  invalidPose,

  /// 图像处理失败
  imageProcessingFailed,

  /// 图像质量过低
  lowImageQuality,

  /// 超时
  timeout,

  /// 内存不足
  memoryInsufficient,

  /// 其他错误
  unknown,
}

/// Avatar构建配置
class AvatarBuildConfig {
  /// 目标图像尺寸（预处理后）
  final int targetImageSize;

  /// 每个分块的最大尺寸
  final int maxPartSize;

  /// 羽化比例（相对于radius）
  final double featherRatio;

  /// Supersampling采样数（2x2=4 或 3x3=9）
  final int sampleCount;

  /// 最低置信度阈值
  final double minConfidenceThreshold;

  /// 是否启用调试模式
  final bool debugMode;

  /// 是否启用Bone Weight（解决粘连）
  final bool enableBoneWeight;

  /// Bone Weight衰减系数
  final double boneWeightDecay;

  const AvatarBuildConfig({
    this.targetImageSize = 512,
    this.maxPartSize = 256,
    this.featherRatio = 0.2,
    this.sampleCount = 4, // 2x2
    this.minConfidenceThreshold = 0.5,
    this.debugMode = false,
    this.enableBoneWeight = true,
    this.boneWeightDecay = 0.05,
  });

  /// 高质量配置（高端设备）
  static const AvatarBuildConfig highQuality = AvatarBuildConfig(
    targetImageSize: 720,
    maxPartSize: 320,
    featherRatio: 0.25,
    sampleCount: 9, // 3x3
    enableBoneWeight: true,
    boneWeightDecay: 0.03,
  );

  /// 快速配置（低端设备）
  static const AvatarBuildConfig fast = AvatarBuildConfig(
    targetImageSize: 480,
    maxPartSize: 192,
    featherRatio: 0.15,
    sampleCount: 4, // 2x2
    enableBoneWeight: true,
    boneWeightDecay: 0.08,
  );

  /// 获取采样点偏移
  List<Offset> get sampleOffsets {
    if (sampleCount == 4) {
      // 2x2 supersampling
      return const [
        Offset(0.25, 0.25),
        Offset(0.75, 0.25),
        Offset(0.25, 0.75),
        Offset(0.75, 0.75),
      ];
    } else {
      // 3x3 supersampling
      return const [
        Offset(0.17, 0.17),
        Offset(0.50, 0.17),
        Offset(0.83, 0.17),
        Offset(0.17, 0.50),
        Offset(0.50, 0.50),
        Offset(0.83, 0.50),
        Offset(0.17, 0.83),
        Offset(0.50, 0.83),
        Offset(0.83, 0.83),
      ];
    }
  }
}