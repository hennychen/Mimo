import 'dart:ui';
import 'dart:async';
import 'dart:typed_data';

import '../../entities/joint_type.dart';
import '../../entities/landmark.dart';
import '../../entities/body_part.dart';
import '../../entities/avatar_build_result.dart';
import 'capsule_geometry.dart';
import 'capsule_partition_engine.dart';

/// 身体分区引擎接口
///
/// 定义将人体图像分割为各部位的核心接口
abstract class BodyPartitionEngine {
  /// 分割人体图像
  ///
  /// 参数:
  /// - [source] 原始图像
  /// - [rgba] 图像像素数据
  /// - [mask] 人体分割mask（可选）
  /// - [joints] 关节关键点映射
  /// - [width] 图像宽度
  /// - [height] 图像高度
  /// - [config] 构建配置
  ///
  /// 返回: 各身体部位的纹理映射
  Future<Map<BodyPart, BodyPartTexture>> partition({
    required Image source,
    required Uint8List rgba,
    required Uint8List? mask,
    required Map<JointType, Landmark> joints,
    required int width,
    required int height,
    AvatarBuildConfig config = const AvatarBuildConfig(),
  });
}

/// 身体分区引擎实现
///
/// 核心实现类，整合所有裁剪逻辑
class BodyPartitionEngineImpl implements BodyPartitionEngine {
  /// 胶囊裁剪引擎
  final CapsulePartitionEngine _capsuleEngine;

  BodyPartitionEngineImpl({
    AvatarBuildConfig config = const AvatarBuildConfig(),
  }) : _capsuleEngine = CapsulePartitionEngine(config: config);

  @override
  Future<Map<BodyPart, BodyPartTexture>> partition({
    required Image source,
    required Uint8List rgba,
    required Uint8List? mask,
    required Map<JointType, Landmark> joints,
    required int width,
    required int height,
    AvatarBuildConfig config = const AvatarBuildConfig(),
  }) async {
    final result = <BodyPart, BodyPartTexture>{};

    // 将归一化关节坐标转换为像素坐标
    final pixelJoints = _convertJointsToPixels(joints, width, height);

    // 计算肩宽（用于各部位尺寸计算）
    final shoulderWidth = _computeShoulderWidth(pixelJoints);

    // 依次处理各部位
    for (final part in BodyPart.mainParts) {
      try {
        final texture = await _processPart(
          part: part,
          source: source,
          rgba: rgba,
          mask: mask,
          pixelJoints: pixelJoints,
          shoulderWidth: shoulderWidth,
          width: width,
          height: height,
          config: config,
        );

        if (texture != null) {
          result[part] = texture;
        }
      } catch (e) {
        // 单部位失败不影响整体，继续处理其他部位
        print('Failed to process part $part: $e');
      }
    }

    return result;
  }

  /// 处理单个身体部位
  Future<BodyPartTexture?> _processPart({
    required BodyPart part,
    required Image source,
    required Uint8List rgba,
    required Uint8List? mask,
    required Map<JointType, Offset> pixelJoints,
    required double shoulderWidth,
    required int width,
    required int height,
    required AvatarBuildConfig config,
  }) async {
    switch (part) {
      case BodyPart.head:
        return _processHead(
          source: source,
          rgba: rgba,
          mask: mask,
          pixelJoints: pixelJoints,
          shoulderWidth: shoulderWidth,
          width: width,
          height: height,
          config: config,
        );

      case BodyPart.torso:
        return _processTorso(
          source: source,
          rgba: rgba,
          mask: mask,
          pixelJoints: pixelJoints,
          shoulderWidth: shoulderWidth,
          width: width,
          height: height,
          config: config,
        );

      case BodyPart.upperArmL:
      case BodyPart.upperArmR:
        return _processUpperArm(
          part: part,
          source: source,
          rgba: rgba,
          mask: mask,
          pixelJoints: pixelJoints,
          shoulderWidth: shoulderWidth,
          width: width,
          height: height,
          config: config,
        );

      case BodyPart.lowerArmL:
      case BodyPart.lowerArmR:
        return _processLowerArm(
          part: part,
          source: source,
          rgba: rgba,
          mask: mask,
          pixelJoints: pixelJoints,
          shoulderWidth: shoulderWidth,
          width: width,
          height: height,
          config: config,
        );

      default:
        return null;
    }
  }

  /// 处理头部（圆形裁剪）
  Future<BodyPartTexture?> _processHead({
    required Image source,
    required Uint8List rgba,
    required Uint8List? mask,
    required Map<JointType, Offset> pixelJoints,
    required double shoulderWidth,
    required int width,
    required int height,
    required AvatarBuildConfig config,
  }) async {
    final nose = pixelJoints[JointType.nose];
    if (nose == null) return null;

    final headRadius = shoulderWidth * 0.6;
    final geometry = CapsuleGeometry(
      jointA: nose,
      jointB: nose, // 圆形（退化胶囊）
      radius: headRadius,
    );

    final input = CapsulePartitionInput(
      image: source,
      rgba: rgba,
      width: width,
      height: height,
      geometry: geometry,
      mask: mask,
      config: config,
    );

    final image = await _capsuleEngine.cropCapsule(input);
    final bbox = geometry.computeBoundingBox(width, height);
    final pivotOffset = Offset(0.5, 0.5); // 头部Pivot在中心

    return BodyPartTexture(
      part: BodyPart.head,
      image: image,
      sourceRect: bbox,
      pivotOffset: pivotOffset,
    );
  }

  /// 处理躯干（矩形裁剪）
  Future<BodyPartTexture?> _processTorso({
    required Image source,
    required Uint8List rgba,
    required Uint8List? mask,
    required Map<JointType, Offset> pixelJoints,
    required double shoulderWidth,
    required int width,
    required int height,
    required AvatarBuildConfig config,
  }) async {
    final leftShoulder = pixelJoints[JointType.leftShoulder];
    final rightShoulder = pixelJoints[JointType.rightShoulder];
    if (leftShoulder == null || rightShoulder == null) return null;

    // 躯干使用矩形裁剪（暂不使用胶囊）
    final torsoRect = RegionBuilder.buildTorsoRegion(
      leftShoulder: leftShoulder,
      rightShoulder: rightShoulder,
      hipCenter: Offset(
        (leftShoulder.dx + rightShoulder.dx) / 2,
        height * 0.7, // 假设髋部在70%高度
      ),
      shoulderWidth: shoulderWidth,
    );

    // 裁剪躯干矩形区域
    final croppedImage = await _cropRectRegion(
      source: source,
      rgba: rgba,
      mask: mask,
      rect: torsoRect,
      width: width,
      height: height,
      config: config,
    );

    final pivotOffset = Offset(0.5, 0.3); // 躯干Pivot在上部

    return BodyPartTexture(
      part: BodyPart.torso,
      image: croppedImage,
      sourceRect: torsoRect,
      pivotOffset: pivotOffset,
    );
  }

  /// 处理上臂
  Future<BodyPartTexture?> _processUpperArm({
    required BodyPart part,
    required Image source,
    required Uint8List rgba,
    required Uint8List? mask,
    required Map<JointType, Offset> pixelJoints,
    required double shoulderWidth,
    required int width,
    required int height,
    required AvatarBuildConfig config,
  }) async {
    final isLeft = part.isLeftSide;
    final shoulderJoint = isLeft ? JointType.leftShoulder : JointType.rightShoulder;
    final elbowJoint = isLeft ? JointType.leftElbow : JointType.rightElbow;

    final shoulder = pixelJoints[shoulderJoint];
    final elbow = pixelJoints[elbowJoint];
    if (shoulder == null || elbow == null) return null;

    final armRadius = shoulderWidth * 0.25 / 2;
    final geometry = CapsuleGeometry(
      jointA: shoulder,
      jointB: elbow,
      radius: armRadius,
    );

    final input = CapsulePartitionInput(
      image: source,
      rgba: rgba,
      width: width,
      height: height,
      geometry: geometry,
      mask: mask,
      config: config,
    );

    final image = await _capsuleEngine.cropCapsule(input);
    final bbox = geometry.computeBoundingBox(width, height);
    final pivotOffset = _capsuleEngine.computePivotOffset(geometry, bbox);

    return BodyPartTexture(
      part: part,
      image: image,
      sourceRect: bbox,
      pivotOffset: pivotOffset,
    );
  }

  /// 处理下臂
  Future<BodyPartTexture?> _processLowerArm({
    required BodyPart part,
    required Image source,
    required Uint8List rgba,
    required Uint8List? mask,
    required Map<JointType, Offset> pixelJoints,
    required double shoulderWidth,
    required int width,
    required int height,
    required AvatarBuildConfig config,
  }) async {
    final isLeft = part.isLeftSide;
    final elbowJoint = isLeft ? JointType.leftElbow : JointType.rightElbow;
    final wristJoint = isLeft ? JointType.leftWrist : JointType.rightWrist;

    final elbow = pixelJoints[elbowJoint];
    final wrist = pixelJoints[wristJoint];
    if (elbow == null || wrist == null) return null;

    final armRadius = shoulderWidth * 0.2 / 2;
    final geometry = CapsuleGeometry(
      jointA: elbow,
      jointB: wrist,
      radius: armRadius,
    );

    final input = CapsulePartitionInput(
      image: source,
      rgba: rgba,
      width: width,
      height: height,
      geometry: geometry,
      mask: mask,
      config: config,
    );

    final image = await _capsuleEngine.cropCapsule(input);
    final bbox = geometry.computeBoundingBox(width, height);
    final pivotOffset = _capsuleEngine.computePivotOffset(geometry, bbox);

    return BodyPartTexture(
      part: part,
      image: image,
      sourceRect: bbox,
      pivotOffset: pivotOffset,
    );
  }

  /// 矩形区域裁剪（用于躯干）
  Future<Image> _cropRectRegion({
    required Image source,
    required Uint8List rgba,
    required Uint8List? mask,
    required Rect rect,
    required int width,
    required int height,
    required AvatarBuildConfig config,
  }) async {
    final outW = rect.width.toInt();
    final outH = rect.height.toInt();

    if (outW <= 0 || outH <= 0) {
      return _createEmptyImage(1, 1);
    }

    final outputData = Uint8List(outW * outH * 4);
    final sampleOffsets = config.sampleOffsets;
    final sampleCount = sampleOffsets.length;

    int outIdx = 0;
    for (int y = 0; y < outH; y++) {
      for (int x = 0; x < outW; x++) {
        final srcX = rect.left.toInt() + x;
        final srcY = rect.top.toInt() + y;

        double alphaAccum = 0.0;
        double rAccum = 0.0;
        double gAccum = 0.0;
        double bAccum = 0.0;

        for (final offset in sampleOffsets) {
          final sampleX = (srcX + offset.dx).clamp(0, width - 1);
          final sampleY = (srcY + offset.dy).clamp(0, height - 1);

          final srcIdx = (sampleY.toInt() * width + sampleX.toInt()) * 4;

          // Mask融合
          double alpha = 1.0;
          if (mask != null) {
            final maskIdx = sampleY.toInt() * width + sampleX.toInt();
            alpha = mask[maskIdx] / 255.0;
          }

          if (alpha > 0.01) {
            final r = rgba[srcIdx];
            final g = rgba[srcIdx + 1];
            final bb = rgba[srcIdx + 2];

            rAccum += r * alpha;
            gAccum += g * alpha;
            bAccum += bb * alpha;
            alphaAccum += alpha;
          }
        }

        if (alphaAccum > 0.01) {
          final finalAlpha = (alphaAccum / sampleCount).clamp(0.0, 1.0);
          outputData[outIdx] = (rAccum / sampleCount).round().clamp(0, 255);
          outputData[outIdx + 1] = (gAccum / sampleCount).round().clamp(0, 255);
          outputData[outIdx + 2] = (bAccum / sampleCount).round().clamp(0, 255);
          outputData[outIdx + 3] = (finalAlpha * 255).round().clamp(0, 255);
        } else {
          outputData[outIdx + 3] = 0;
        }

        outIdx += 4;
      }
    }

    return _decodeImage(outputData, outW, outH);
  }

  /// 转换关节坐标为像素坐标
  Map<JointType, Offset> _convertJointsToPixels(
    Map<JointType, Landmark> joints,
    int width,
    int height,
  ) {
    final result = <JointType, Offset>{};
    for (final entry in joints.entries) {
      final pixel = RegionBuilder.normalizedToPixel(
        Offset(entry.value.x, entry.value.y),
        width,
        height,
      );
      result[entry.key] = pixel;
    }
    return result;
  }

  /// 计算肩宽
  double _computeShoulderWidth(Map<JointType, Offset> pixelJoints) {
    final leftShoulder = pixelJoints[JointType.leftShoulder];
    final rightShoulder = pixelJoints[JointType.rightShoulder];

    if (leftShoulder == null || rightShoulder == null) {
      return 100.0; // 默认值
    }

    return RegionBuilder.computeShoulderWidth(leftShoulder, rightShoulder);
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
}