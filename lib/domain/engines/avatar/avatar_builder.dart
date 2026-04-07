import 'dart:ui';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import '../../entities/joint_type.dart';
import '../../entities/landmark.dart';
import '../../entities/body_part.dart';
import '../../entities/avatar_build_result.dart';
import '../../repositories/pose_repository.dart';
import 'body_partition_engine.dart';

/// Avatar构建器接口
///
/// 总入口，编排Avatar生成的完整流程
abstract class AvatarBuilder {
  /// 从图片构建Avatar
  ///
  /// 流程：
  /// [1] ImagePreprocess - 图像预处理
  /// [2] PoseDetection - 姿态检测（复用现有）
  /// [3] Segmentation - 人体分割
  /// [4] BodyPartition - 身体分区裁剪
  /// [5] TextureBinding - 纹理绑定（由Rive处理）
  Future<AvatarBuildResult> build(File image);

  /// 加载缓存的Avatar
  Future<AvatarBuildResult?> loadCached();

  /// 清除缓存
  void clearCache();

  /// 验证图片是否适合生成Avatar
  Future<AvatarValidationResult> validate(File image);
}

/// Avatar验证结果
class AvatarValidationResult {
  /// 是否有效
  final bool isValid;

  /// 问题列表
  final List<String> issues;

  /// 关键点是否完整
  final bool hasAllJoints;

  /// 姿势是否合格
  final bool isPoseValid;

  /// 图像质量评分
  final double qualityScore;

  const AvatarValidationResult({
    required this.isValid,
    this.issues = const [],
    this.hasAllJoints = false,
    this.isPoseValid = false,
    this.qualityScore = 0.0,
  });

  factory AvatarValidationResult.valid({
    double qualityScore = 1.0,
  }) {
    return AvatarValidationResult(
      isValid: true,
      hasAllJoints: true,
      isPoseValid: true,
      qualityScore: qualityScore,
    );
  }

  factory AvatarValidationResult.invalid(List<String> issues) {
    return AvatarValidationResult(
      isValid: false,
      issues: issues,
    );
  }
}

/// Avatar构建器实现
///
/// 核心实现，整合各引擎模块
class AvatarBuilderImpl implements AvatarBuilder {
  /// 姿态检测仓库（复用现有）
  final PoseRepository _poseRepository;

  /// 图像预处理引擎
  final ImagePreprocessEngine _preprocessEngine;

  /// 人体分割引擎
  final SegmentationEngine _segmentationEngine;

  /// 身体分区引擎
  final BodyPartitionEngine _partitionEngine;

  /// 构建配置
  final AvatarBuildConfig _config;

  /// 缓存的Avatar结果
  AvatarBuildResult? _cachedResult;

  AvatarBuilderImpl({
    required PoseRepository poseRepository,
    ImagePreprocessEngine? preprocessEngine,
    SegmentationEngine? segmentationEngine,
    BodyPartitionEngine? partitionEngine,
    AvatarBuildConfig config = const AvatarBuildConfig(),
  })  : _poseRepository = poseRepository,
        _preprocessEngine = preprocessEngine ?? ImagePreprocessEngineImpl(),
        _segmentationEngine = segmentationEngine ?? SegmentationEnginePlaceholder(),
        _partitionEngine = partitionEngine ?? BodyPartitionEngineImpl(config: config),
        _config = config;

  @override
  Future<AvatarBuildResult> build(File image) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;

    try {
      // Step 1: 图像预处理
      final preprocessResult = await _preprocessEngine.process(image);
      if (!preprocessResult.success) {
        return AvatarBuildResult.failure(
          errorMessage: preprocessResult.errorMessage ?? '预处理失败',
          errorType: AvatarBuildError.imageProcessingFailed,
          buildTimeMs: DateTime.now().millisecondsSinceEpoch - startTime,
        );
      }

      final processedImage = preprocessResult.image!;
      final rgba = preprocessResult.rgba!;
      final width = preprocessResult.width;
      final height = preprocessResult.height;

      // Step 2: 姿态检测（复用现有）
      final joints = _poseRepository.detect(
        processedImage,
        width,
        height,
      );

      if (joints.isEmpty) {
        return AvatarBuildResult.failure(
          errorMessage: '未检测到人体',
          errorType: AvatarBuildError.noHumanDetected,
          buildTimeMs: DateTime.now().millisecondsSinceEpoch - startTime,
        );
      }

      // 验证关键点完整性
      final missingJoints = _checkMissingJoints(joints);
      if (missingJoints.isNotEmpty) {
        return AvatarBuildResult.failure(
          errorMessage: '关键点缺失: ${missingJoints.join(', ')}',
          errorType: AvatarBuildError.missingJoints,
          buildTimeMs: DateTime.now().millisecondsSinceEpoch - startTime,
        );
      }

      // 验证置信度
      final lowConfidenceJoints = _checkLowConfidenceJoints(joints);
      if (lowConfidenceJoints.isNotEmpty) {
        return AvatarBuildResult.failure(
          errorMessage: '关键点置信度过低: ${lowConfidenceJoints.join(', ')}',
          errorType: AvatarBuildError.lowConfidence,
          buildTimeMs: DateTime.now().millisecondsSinceEpoch - startTime,
        );
      }

      // Step 3: 人体分割
      final segmentationResult = await _segmentationEngine.segment(
        processedImage,
        width,
        height,
      );

      // Step 4: 身体分区裁剪
      final textures = await _partitionEngine.partition(
        source: processedImage,
        rgba: rgba,
        mask: segmentationResult.mask,
        joints: joints,
        width: width,
        height: height,
        config: _config,
      );

      // Step 5: 构建结果
      final buildTimeMs = DateTime.now().millisecondsSinceEpoch - startTime;
      final overallQuality = _computeOverallQuality(textures, joints);

      final result = AvatarBuildResult.success(
        textures: textures,
        sourceSize: Size(width.toDouble(), height.toDouble()),
        buildTimeMs: buildTimeMs,
        overallQuality: overallQuality,
      );

      // 缓存结果
      _cachedResult = result;

      return result;
    } catch (e) {
      return AvatarBuildResult.failure(
        errorMessage: '构建异常: $e',
        errorType: AvatarBuildError.unknown,
        buildTimeMs: DateTime.now().millisecondsSinceEpoch - startTime,
      );
    }
  }

  @override
  Future<AvatarBuildResult?> loadCached() async {
    return _cachedResult;
  }

  @override
  void clearCache() {
    _cachedResult = null;
  }

  @override
  Future<AvatarValidationResult> validate(File image) async {
    final issues = <String>[];

    // 预处理
    final preprocessResult = await _preprocessEngine.process(image);
    if (!preprocessResult.success) {
      issues.add('图像预处理失败');
      return AvatarValidationResult.invalid(issues);
    }

    // 检测姿态
    final joints = _poseRepository.detect(
      preprocessResult.image!,
      preprocessResult.width,
      preprocessResult.height,
    );

    if (joints.isEmpty) {
      issues.add('未检测到人体');
      return AvatarValidationResult.invalid(issues);
    }

    // 检查关键点
    final missingJoints = _checkMissingJoints(joints);
    if (missingJoints.isNotEmpty) {
      issues.add('关键点缺失: ${missingJoints.join(', ')}');
    }

    // 检查置信度
    final lowConfidenceJoints = _checkLowConfidenceJoints(joints);
    if (lowConfidenceJoints.isNotEmpty) {
      issues.add('置信度过低: ${lowConfidenceJoints.join(', ')}');
    }

    // 检查姿势（手臂是否分开）
    final poseValid = _checkPoseValidity(joints);
    if (!poseValid) {
      issues.add('姿势不合格：手臂应分开，接近T-Pose或自然下垂');
    }

    if (issues.isNotEmpty) {
      return AvatarValidationResult.invalid(issues);
    }

    return AvatarValidationResult.valid(qualityScore: 1.0);
  }

  /// 检查缺失的关键点
  List<String> _checkMissingJoints(Map<JointType, Landmark> joints) {
    final requiredJoints = [
      JointType.nose,
      JointType.leftShoulder,
      JointType.rightShoulder,
      JointType.leftElbow,
      JointType.rightElbow,
    ];

    return requiredJoints
        .where((j) => !joints.containsKey(j))
        .map((j) => j.name)
        .toList();
  }

  /// 检查置信度过低的关键点
  List<String> _checkLowConfidenceJoints(Map<JointType, Landmark> joints) {
    return joints.entries
        .where((e) => e.value.visibility < _config.minConfidenceThreshold)
        .map((e) => e.key.name)
        .toList();
  }

  /// 检查姿势是否合格
  ///
  /// 验证手臂是否分开（不交叉）
  bool _checkPoseValidity(Map<JointType, Landmark> joints) {
    final leftShoulder = joints[JointType.leftShoulder];
    final leftElbow = joints[JointType.leftElbow];
    final rightShoulder = joints[JointType.rightShoulder];
    final rightElbow = joints[JointType.rightElbow];

    if (leftShoulder == null ||
        leftElbow == null ||
        rightShoulder == null ||
        rightElbow == null) {
      return false;
    }

    // 计算肩宽
    final shoulderWidth = (rightShoulder.x - leftShoulder.x).abs();

    // 验证手臂是否分开（肘部不在身体内侧）
    final leftElbowX = leftElbow.x;
    final rightElbowX = rightElbow.x;

    // 左肘应该在左肩左侧或附近
    // 右肘应该在右肩右侧或附近
    final leftArmValid = leftElbowX <= leftShoulder.x + shoulderWidth * 0.3;
    final rightArmValid = rightElbowX >= rightShoulder.x - shoulderWidth * 0.3;

    // 手臂不能交叉
    final armsNotCrossed = leftElbowX < rightElbowX;

    return leftArmValid && rightArmValid && armsNotCrossed;
  }

  /// 计算整体质量评分
  double _computeOverallQuality(
    Map<BodyPart, BodyPartTexture> textures,
    Map<JointType, Landmark> joints,
  ) {
    if (textures.isEmpty) return 0.0;

    // 部位完整性评分（占50%）
    final completenessScore = textures.length / BodyPart.mainParts.length;

    // 平均置信度评分（占30%）
    final avgConfidence = joints.values
        .map((l) => l.visibility)
        .reduce((a, b) => a + b) / joints.length;
    final confidenceScore = avgConfidence;

    // 各部位质量评分（占20%）
    final qualityScores = textures.values.map((t) => t.qualityScore);
    final avgPartQuality = qualityScores.isEmpty
        ? 1.0
        : qualityScores.reduce((a, b) => a + b) / qualityScores.length;

    return (completenessScore * 0.5 +
            confidenceScore * 0.3 +
            avgPartQuality * 0.2)
        .clamp(0.0, 1.0);
  }
}

/// 图像预处理引擎接口
abstract class ImagePreprocessEngine {
  /// 处理图像
  ///
  /// 返回预处理后的图像和像素数据
  Future<ImagePreprocessResult> process(File image);
}

/// 图像预处理结果
class ImagePreprocessResult {
  /// 是否成功
  final bool success;

  /// 预处理后的图像
  final Image? image;

  /// RGBA像素数据
  final Uint8List? rgba;

  /// 图像宽度
  final int width;

  /// 图像高度
  final int height;

  /// 错误信息
  final String? errorMessage;

  const ImagePreprocessResult({
    required this.success,
    this.image,
    this.rgba,
    this.width = 0,
    this.height = 0,
    this.errorMessage,
  });

  factory ImagePreprocessResult.success({
    required Image image,
    required Uint8List rgba,
    required int width,
    required int height,
  }) {
    return ImagePreprocessResult(
      success: true,
      image: image,
      rgba: rgba,
      width: width,
      height: height,
    );
  }

  factory ImagePreprocessResult.failure(String errorMessage) {
    return ImagePreprocessResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}

/// 图像预处理引擎实现
class ImagePreprocessEngineImpl implements ImagePreprocessEngine {
  /// 目标尺寸
  final int targetSize;

  ImagePreprocessEngineImpl({
    this.targetSize = 512,
  });

  @override
  Future<ImagePreprocessResult> process(File image) async {
    try {
      // 读取文件为字节
      final bytes = await image.readAsBytes();

      // 解码为Image
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final originalImage = frame.image;

      // 获取原始尺寸
      final originalWidth = originalImage.width;
      final originalHeight = originalImage.height;

      // 计算缩放比例（保持比例）
      final scale = targetSize / math.max(originalWidth, originalHeight);
      final newWidth = (originalWidth * scale).round();
      final newHeight = (originalHeight * scale).round();

      // 缩放图像
      final resizedImage = await _resizeImage(
        originalImage,
        newWidth,
        newHeight,
      );

      // 获取RGBA像素数据
      final rgba = await _extractRGBA(resizedImage);

      return ImagePreprocessResult.success(
        image: resizedImage,
        rgba: rgba,
        width: newWidth,
        height: newHeight,
      );
    } catch (e) {
      return ImagePreprocessResult.failure('预处理失败: $e');
    }
  }

  /// 缩放图像
  Future<Image> _resizeImage(Image source, int width, int height) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint() ..filterQuality = FilterQuality.high;

    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      paint,
    );

    final picture = recorder.endRecording();
    return picture.toImage(width, height);
  }

  /// 提取RGBA像素数据
  Future<Uint8List> _extractRGBA(Image image) async {
    final byteData = await image.toByteData(format: ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }
}

/// 人体分割引擎接口
abstract class SegmentationEngine {
  /// 执行人体分割
  ///
  /// 返回分割mask（人体区域为白色255，背景为黑色0）
  Future<SegmentationResult> segment(Image image, int width, int height);
}

/// 分割结果
class SegmentationResult {
  /// 是否成功
  final bool success;

  /// 分割mask（Uint8List，每个像素0-255）
  final Uint8List? mask;

  /// 错误信息
  final String? errorMessage;

  const SegmentationResult({
    required this.success,
    this.mask,
    this.errorMessage,
  });

  factory SegmentationResult.success(Uint8List mask) {
    return SegmentationResult(success: true, mask: mask);
  }

  factory SegmentationResult.failure(String errorMessage) {
    return SegmentationResult(success: false, errorMessage: errorMessage);
  }
}

/// 人体分割引擎占位实现
///
/// 返回全白mask（表示整个图像都是人体）
/// 实际实现需要集成MediaPipe Selfie Segmentation
class SegmentationEnginePlaceholder implements SegmentationEngine {
  @override
  Future<SegmentationResult> segment(Image image, int width, int height) async {
    // 占位实现：返回全白mask
    final mask = Uint8List(width * height);
    for (int i = 0; i < mask.length; i++) {
      mask[i] = 255; // 全部标记为人体
    }
    return SegmentationResult.success(mask);
  }
}