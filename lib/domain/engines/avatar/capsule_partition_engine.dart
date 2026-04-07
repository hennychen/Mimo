import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'dart:typed_data';

import 'capsule_geometry.dart';
import '../../entities/avatar_build_result.dart';

/// 胶囊裁剪输入参数
///
/// 封装所有裁剪所需的输入数据
class CapsulePartitionInput {
  /// 原始图像
  final Image image;

  /// 图像RGBA像素数据（Uint8List格式）
  final Uint8List rgba;

  /// 图像宽度
  final int width;

  /// 图像高度
  final int height;

  /// 胶囊几何参数
  final CapsuleGeometry geometry;

  /// 人体分割mask（可选）
  final Uint8List? mask;

  /// 构建配置
  final AvatarBuildConfig config;

  CapsulePartitionInput({
    required this.image,
    required this.rgba,
    required this.width,
    required this.height,
    required this.geometry,
    this.mask,
    this.config = const AvatarBuildConfig(),
  });
}

/// 胶囊裁剪引擎
///
/// 核心模块，整合四层架构：
/// [1] RegionBuilder - 胶囊形区域 + BoundingBox裁剪
/// [2] MaskRefiner - mask + bone weight 融合
/// [3] PixelSampler - Supersampling抗锯齿
/// [4] EdgeBlender - smoothstep羽化
class CapsulePartitionEngine {
  /// 构建配置
  final AvatarBuildConfig config;

  CapsulePartitionEngine({
    this.config = const AvatarBuildConfig(),
  });

  /// 执行胶囊裁剪
  ///
  /// 返回裁剪后的图像（透明背景）
  Future<Image> cropCapsule(CapsulePartitionInput input) async {
    final geometry = input.geometry;
    final width = input.width;
    final height = input.height;

    // Step 1: 计算BoundingBox（性能关键）
    final bbox = geometry.computeBoundingBox(width, height);

    // 输出尺寸
    final outW = bbox.width.toInt();
    final outH = bbox.height.toInt();

    if (outW <= 0 || outH <= 0) {
      // 返回空白图像
      return _createEmptyImage(1, 1);
    }

    // Step 2: 创建输出像素缓冲
    final outputData = Uint8List(outW * outH * 4);

    // Step 3: 预计算常用值（减少重复计算）
    final radius = geometry.radius;
    final featherRange = radius * config.featherRatio;
    final innerRadius = radius - featherRange;

    // 获取采样偏移
    final sampleOffsets = config.sampleOffsets;
    final sampleCount = sampleOffsets.length;

    // Step 4: 遍历像素计算
    int outIdx = 0;
    for (int y = 0; y < outH; y++) {
      for (int x = 0; x < outW; x++) {
        // 计算在原图中的位置
        final srcX = bbox.left.toInt() + x;
        final srcY = bbox.top.toInt() + y;

        // Supersampling：累加多个采样点的alpha
        double alphaAccum = 0.0;
        double rAccum = 0.0;
        double gAccum = 0.0;
        double bAccum = 0.0;

        for (final offset in sampleOffsets) {
          // 采样点位置（亚像素）
          final sampleX = srcX + offset.dx;
          final sampleY = srcY + offset.dy;

          final point = Offset(sampleX, sampleY);

          // 计算到线段的距离
          final dist = geometry.distanceToSegment(point);

          // 计算最终alpha（整合capsule + feather + mask + boneWeight）
          final alpha = _computeFinalAlpha(
            point: point,
            dist: dist,
            radius: radius,
            innerRadius: innerRadius,
            featherRange: featherRange,
            geometry: geometry,
            mask: input.mask,
            maskWidth: width,
            srcX: srcX,
            srcY: srcY,
          );

          if (alpha > 0.01) {
            // 获取原图像素
            final srcIdx = (srcY * width + srcX) * 4;
            final r = input.rgba[srcIdx];
            final g = input.rgba[srcIdx + 1];
            final bb = input.rgba[srcIdx + 2];

            // 累加（预乘alpha）
            rAccum += r * alpha;
            gAccum += g * alpha;
            bAccum += bb * alpha;
            alphaAccum += alpha;
          }
        }

        // 平均采样结果
        if (alphaAccum > 0.01) {
          final finalAlpha = (alphaAccum / sampleCount).clamp(0.0, 1.0);

          // 预乘alpha输出（解决白边）
          outputData[outIdx] = (rAccum / sampleCount).round().clamp(0, 255);
          outputData[outIdx + 1] = (gAccum / sampleCount).round().clamp(0, 255);
          outputData[outIdx + 2] = (bAccum / sampleCount).round().clamp(0, 255);
          outputData[outIdx + 3] = (finalAlpha * 255).round().clamp(0, 255);
        } else {
          // 完全透明
          outputData[outIdx + 3] = 0;
        }

        outIdx += 4;
      }
    }

    // Step 5: 应用轻量羽化（可选）
    if (config.featherRatio > 0.1) {
      _applyBoxBlurAlpha(outputData, outW, outH);
    }

    // Step 6: 解码为Image
    return _decodeImage(outputData, outW, outH);
  }

  /// 计算最终Alpha（整合四层）
  ///
  /// [1] Capsule判断 + Feather
  /// [2] Mask融合
  /// [3] BoneWeight融合（解决粘连）
  double _computeFinalAlpha({
    required Offset point,
    required double dist,
    required double radius,
    required double innerRadius,
    required double featherRange,
    required CapsuleGeometry geometry,
    required Uint8List? mask,
    required int maskWidth,
    required int srcX,
    required int srcY,
  }) {
    // Layer 1: Capsule + Feather
    double capsuleAlpha;
    if (dist <= innerRadius) {
      // 内部完全透明
      capsuleAlpha = 1.0;
    } else if (dist <= radius) {
      // 羽化区域：从1到0平滑过渡
      final t = ((radius - dist) / featherRange).clamp(0.0, 1.0);
      capsuleAlpha = SmoothStep.apply(t, 0.0, 1.0);
    } else {
      // 外部完全透明
      capsuleAlpha = 0.0;
    }

    // 如果完全透明，直接返回
    if (capsuleAlpha < 0.01) return 0.0;

    // Layer 2: Mask融合（如果有）
    if (mask != null) {
      final maskIdx = (srcY * maskWidth + srcX);
      final maskValue = mask[maskIdx] / 255.0;

      // 取最小值（两者交集）
      capsuleAlpha = math.min(capsuleAlpha, maskValue);
    }

    // Layer 3: BoneWeight融合（如果启用）
    if (config.enableBoneWeight && capsuleAlpha > 0.01) {
      final boneWeight = geometry.computeBoneWeight(point, config.boneWeightDecay);
      capsuleAlpha *= boneWeight;
    }

    return capsuleAlpha.clamp(0.0, 1.0);
  }

  /// 应用轻量羽化（Box Blur）
  ///
  /// 仅对Alpha通道进行模糊，使边缘更柔和
  void _applyBoxBlurAlpha(Uint8List pixels, int width, int height) {
    final copy = Uint8List.fromList(pixels);

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        int sum = 0;

        // 3x3 kernel
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final idx = ((y + dy) * width + (x + dx)) * 4 + 3;
            sum += copy[idx];
          }
        }

        final outIdx = (y * width + x) * 4 + 3;
        pixels[outIdx] = (sum / 9).round().clamp(0, 255);
      }
    }
  }

  /// 解码像素数据为Image
  Future<Image> _decodeImage(Uint8List data, int width, int height) async {
    final completer = Completer<Image>();
    decodeImageFromPixels(
      data,
      width,
      height,
      PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  /// 创建空白图像
  Future<Image> _createEmptyImage(int width, int height) async {
    final data = Uint8List(width * height * 4);
    return _decodeImage(data, width, height);
  }

  /// 计算Pivot位置（相对于裁剪图像）
  ///
  /// 返回归一化坐标（0-1）
  Offset computePivotOffset(CapsuleGeometry geometry, Rect bbox) {
    final pivotPoint = geometry.jointA; // Pivot在起点关节
    final pivotX = (pivotPoint.dx - bbox.left) / bbox.width;
    final pivotY = (pivotPoint.dy - bbox.top) / bbox.height;
    return Offset(pivotX.clamp(0.0, 1.0), pivotY.clamp(0.0, 1.0));
  }
}

/// 扩展：提供便捷的静态方法
extension CapsulePartitionEngineExtension on CapsulePartitionEngine {
  /// 从关节位置裁剪手臂
  ///
  /// 简化调用，直接提供关节位置和半径
  Future<Image> cropArmFromJoints({
    required Image image,
    required Uint8List rgba,
    required int width,
    required int height,
    required Offset shoulder,
    required Offset elbow,
    required Offset? wrist,
    required double radius,
    Uint8List? mask,
  }) async {
    final geometry = CapsuleGeometry(
      jointA: shoulder,
      jointB: wrist ?? elbow, // 如果有手腕则裁到手腕，否则只裁上臂
      radius: radius,
    );

    final input = CapsulePartitionInput(
      image: image,
      rgba: rgba,
      width: width,
      height: height,
      geometry: geometry,
      mask: mask,
      config: config,
    );

    return cropCapsule(input);
  }
}