import 'dart:io';
import 'dart:ui';
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'dart:math' as math;

import '../../domain/entities/avatar_build_result.dart';
import '../../domain/entities/body_part.dart';
import '../../domain/entities/joint_type.dart';
import '../../domain/entities/landmark.dart';
import '../../domain/engines/avatar/avatar_builder.dart';
import '../../domain/engines/avatar/body_partition_engine.dart';

import '../../domain/repositories/pose_repository.dart';
import '../../data/engines_impl/avatar/segmentation_engine_impl.dart';
import '../../data/services/avatar_cache_service.dart';

/// Avatar构建服务
///
/// 完整的Avatar生成服务，整合所有引擎和流程
class AvatarBuilderService {
  /// 姿态检测仓库
  final PoseRepository _poseRepository;

  /// 人体分割引擎
  final SegmentationEngine _segmentationEngine;

  /// 身体分区引擎
  final BodyPartitionEngine _partitionEngine;

  /// 缓存服务
  final AvatarCache _cache;

  /// 构建配置
  final AvatarBuildConfig _config;

  /// 构建状态流
  final _statusController = StreamController<AvatarBuildStatus>.broadcast();

  /// 进度流
  final _progressController = StreamController<AvatarBuildProgress>.broadcast();

  AvatarBuilderService({
    required PoseRepository poseRepository,
    SegmentationEngine? segmentationEngine,
    BodyPartitionEngine? partitionEngine,
    AvatarCache? cache,
    AvatarBuildConfig config = const AvatarBuildConfig(),
  })  : _poseRepository = poseRepository,
        _segmentationEngine = segmentationEngine ?? SegmentationEngineFallback(),
        _partitionEngine = partitionEngine ?? BodyPartitionEngineImpl(config: config),
        _cache = cache ?? AvatarCache(),
        _config = config;

  /// 构建状态流
  Stream<AvatarBuildStatus> get statusStream => _statusController.stream;

  /// 进度流
  Stream<AvatarBuildProgress> get progressStream => _progressController.stream;

  /// 当前状态
  // ignore: unused_field
  AvatarBuildStatus _currentStatus = AvatarBuildStatus.idle;

  /// 从文件构建Avatar
  Future<AvatarBuildResult> buildFromFile(File imageFile) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;

    try {
      _updateStatus(AvatarBuildStatus.preprocessing);
      _emitProgress('预处理图像', 0.1);

      // Step 1: 预处理图像
      final preprocessResult = await _preprocessImage(imageFile);
      if (!preprocessResult.success) {
        return _createErrorResult(preprocessResult.errorMessage ?? '预处理失败', startTime);
      }

      _updateStatus(AvatarBuildStatus.detectingPose);
      _emitProgress('检测姿态', 0.2);

      // Step 2: 姿态检测
      final joints = _poseRepository.detect(
        preprocessResult.image,
        preprocessResult.width,
        preprocessResult.height,
      );

      if (joints.isEmpty) {
        return _createErrorResult('未检测到人体', startTime, errorType: AvatarBuildError.noHumanDetected);
      }

      _emitProgress('验证关键点', 0.3);

      // Step 3: 验证关键点
      final validationResult = _validateJoints(joints);
      if (!validationResult.isValid) {
        return _createErrorResult(validationResult.errorMessage!, startTime, errorType: validationResult.errorType);
      }

      _updateStatus(AvatarBuildStatus.segmenting);
      _emitProgress('人体分割', 0.4);

      // Step 4: 人体分割
      final image = preprocessResult.image!;
      final rgba = Uint8List.fromList(preprocessResult.rgba!);

      final segmentationResult = await _segmentationEngine.segment(
        image,
        preprocessResult.width,
        preprocessResult.height,
      );

      _updateStatus(AvatarBuildStatus.partitioning);
      _emitProgress('身体分区', 0.6);

      // Step 5: 身体分区
      final textures = await _partitionEngine.partition(
        source: image,
        rgba: rgba,
        mask: segmentationResult.mask,
        joints: joints,
        width: preprocessResult.width,
        height: preprocessResult.height,
        config: _config,
      );

      _emitProgress('生成结果', 0.9);

      // Step 6: 构建结果
      final buildTimeMs = DateTime.now().millisecondsSinceEpoch - startTime;
      final overallQuality = _computeOverallQuality(textures, joints);

      final result = AvatarBuildResult.success(
        textures: textures,
        sourceSize: Size(preprocessResult.width.toDouble(), preprocessResult.height.toDouble()),
        buildTimeMs: buildTimeMs,
        overallQuality: overallQuality,
      );

      _updateStatus(AvatarBuildStatus.success);
      _emitProgress('完成', 1.0);

      return result;
    } catch (e) {
      _updateStatus(AvatarBuildStatus.failed);
      return _createErrorResult('构建异常: $e', startTime);
    }
  }

  /// 验证图片
  Future<AvatarValidationResult> validateImage(File imageFile) async {
    try {
      // 预处理
      final preprocessResult = await _preprocessImage(imageFile);
      if (!preprocessResult.success) {
        return AvatarValidationResult.invalid(['图像预处理失败']);
      }

      // 检测姿态
      final joints = _poseRepository.detect(
        preprocessResult.image,
        preprocessResult.width,
        preprocessResult.height,
      );

      if (joints.isEmpty) {
        return AvatarValidationResult.invalid(['未检测到人体']);
      }

      // 验证关键点
      return _validateJoints(joints);
    } catch (e) {
      return AvatarValidationResult.invalid(['验证异常: $e']);
    }
  }

  /// 缓存Avatar
  Future<String?> cacheAvatar(AvatarBuildResult result) async {
    if (!result.success) return null;

    final avatarId = DateTime.now().millisecondsSinceEpoch.toString();
    final success = await _cache.save(avatarId, result);
    return success ? avatarId : null;
  }

  /// 加载缓存的Avatar
  Future<AvatarBuildResult?> loadCachedAvatar(String avatarId) async {
    return _cache.load(avatarId);
  }

  /// 获取所有缓存的Avatar ID
  Future<List<String>> getCachedAvatarIds() async {
    return _cache.getAvatarIds();
  }

  /// 删除缓存的Avatar
  Future<bool> deleteCachedAvatar(String avatarId) async {
    return _cache.delete(avatarId);
  }

  /// 清除所有缓存
  Future<bool> clearAllCache() async {
    return _cache.clearAll();
  }

  /// 释放资源
  void dispose() {
    _statusController.close();
    _progressController.close();
  }

  // ============ 私有方法 ============

  /// 预处理图像
  Future<_PreprocessResult> _preprocessImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final originalWidth = image.width;
      final originalHeight = image.height;

      // 计算缩放
      final scale = _config.targetImageSize / math.max(originalWidth, originalHeight);
      final newWidth = (originalWidth * scale).round();
      final newHeight = (originalHeight * scale).round();

      // 缩放图像
      final resizedImage = await _resizeImage(image, newWidth, newHeight);

      // 提取RGBA
      final rgba = await _extractRGBA(resizedImage);

      return _PreprocessResult(
        success: true,
        image: resizedImage,
        rgba: rgba,
        width: newWidth,
        height: newHeight,
      );
    } catch (e) {
      return _PreprocessResult(success: false, errorMessage: '预处理失败: $e');
    }
  }

  /// 缩放图像
  Future<Image> _resizeImage(Image source, int width, int height) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..filterQuality = FilterQuality.high;

    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      paint,
    );

    final picture = recorder.endRecording();
    return picture.toImage(width, height);
  }

  /// 提取RGBA数据
  Future<List<int>> _extractRGBA(Image image) async {
    final byteData = await image.toByteData(format: ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List().toList();
  }

  /// 验证关键点
  AvatarValidationResult _validateJoints(Map<JointType, Landmark> joints) {
    final issues = <String>[];

    // 检查必需关键点
    final requiredJoints = [
      JointType.nose,
      JointType.leftShoulder,
      JointType.rightShoulder,
      JointType.leftElbow,
      JointType.rightElbow,
    ];

    final missingJoints = requiredJoints.where((j) => !joints.containsKey(j)).toList();
    if (missingJoints.isNotEmpty) {
      issues.add('关键点缺失: ${missingJoints.map((j) => j.name).join(', ')}');
    }

    // 检查置信度
    final lowConfidenceJoints = joints.entries
        .where((e) => e.value.visibility < _config.minConfidenceThreshold)
        .map((e) => e.key.name)
        .toList();

    if (lowConfidenceJoints.isNotEmpty) {
      issues.add('置信度过低: ${lowConfidenceJoints.join(', ')}');
    }

    // 检查姿势
    if (!_isPoseValid(joints)) {
      issues.add('姿势不合格：请保持正面，手臂分开');
    }

    if (issues.isNotEmpty) {
      return AvatarValidationResult(
        isValid: false,
        issues: issues,
        hasAllJoints: missingJoints.isEmpty,
        isPoseValid: issues.isEmpty,
      );
    }

    return AvatarValidationResult.valid();
  }

  /// 检查姿势是否有效
  bool _isPoseValid(Map<JointType, Landmark> joints) {
    final leftShoulder = joints[JointType.leftShoulder];
    final rightShoulder = joints[JointType.rightShoulder];
    final leftElbow = joints[JointType.leftElbow];
    final rightElbow = joints[JointType.rightElbow];

    if (leftShoulder == null || rightShoulder == null || leftElbow == null || rightElbow == null) {
      return false;
    }

    // 手臂不能交叉
    return leftElbow.x < rightElbow.x;
  }

  /// 计算整体质量
  double _computeOverallQuality(Map<BodyPart, BodyPartTexture> textures, Map<JointType, Landmark> joints) {
    if (textures.isEmpty) return 0.0;

    final completeness = textures.length / BodyPart.mainParts.length;
    final avgConfidence = joints.values.map((l) => l.visibility).reduce((a, b) => a + b) / joints.length;

    return (completeness * 0.6 + avgConfidence * 0.4).clamp(0.0, 1.0);
  }

  /// 创建错误结果
  AvatarBuildResult _createErrorResult(
    String message,
    int startTime, {
    AvatarBuildError? errorType,
  }) {
    return AvatarBuildResult.failure(
      errorMessage: message,
      errorType: errorType ?? AvatarBuildError.unknown,
      buildTimeMs: DateTime.now().millisecondsSinceEpoch - startTime,
    );
  }

  /// 更新状态
  void _updateStatus(AvatarBuildStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  /// 发送进度
  void _emitProgress(String step, double progress) {
    _progressController.add(AvatarBuildProgress(step: step, progress: progress));
  }
}

/// 构建状态
enum AvatarBuildStatus {
  idle,
  preprocessing,
  detectingPose,
  segmenting,
  partitioning,
  success,
  failed,
}

/// 构建进度
class AvatarBuildProgress {
  final String step;
  final double progress;

  const AvatarBuildProgress({required this.step, required this.progress});
}

/// 验证结果
class AvatarValidationResult {
  final bool isValid;
  final List<String> issues;
  final bool hasAllJoints;
  final bool isPoseValid;
  final AvatarBuildError? errorType;
  final String? errorMessage;

  const AvatarValidationResult({
    required this.isValid,
    this.issues = const [],
    this.hasAllJoints = false,
    this.isPoseValid = false,
    this.errorType,
    this.errorMessage,
  });

  factory AvatarValidationResult.valid() {
    return const AvatarValidationResult(isValid: true, hasAllJoints: true, isPoseValid: true);
  }

  factory AvatarValidationResult.invalid(List<String> issues, {AvatarBuildError? errorType}) {
    return AvatarValidationResult(isValid: false, issues: issues, errorType: errorType);
  }
}

/// 预处理结果
class _PreprocessResult {
  final bool success;
  final Image? image;
  final List<int>? rgba;
  final int width;
  final int height;
  final String? errorMessage;

  _PreprocessResult({
    required this.success,
    this.image,
    this.rgba,
    this.width = 0,
    this.height = 0,
    this.errorMessage,
  });
}