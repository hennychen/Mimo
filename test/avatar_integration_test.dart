import 'dart:ui';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mimo_app/domain/entities/joint_type.dart';
import 'package:mimo_app/domain/entities/landmark.dart';
import 'package:mimo_app/domain/entities/body_part.dart';
import 'package:mimo_app/domain/entities/avatar_build_result.dart';
import 'package:mimo_app/domain/engines/avatar/capsule_geometry.dart';
import 'package:mimo_app/domain/engines/avatar/capsule_partition_engine.dart';
import 'package:mimo_app/domain/engines/avatar/body_partition_engine.dart';

void main() {
  group('Avatar Integration Tests', () {
    late BodyPartitionEngine partitionEngine;

    setUpAll(() async {
      // 确保 Flutter 绑定初始化
      TestWidgetsFlutterBinding.ensureInitialized();
      partitionEngine = BodyPartitionEngineImpl(
        config: const AvatarBuildConfig(
          targetImageSize: 256,
          maxPartSize: 128,
          enableBoneWeight: true,
        ),
      );
    });

    group('BodyPartitionEngine Integration', () {
      test('应正确处理标准T-Pose姿态', () async {
        // 创建测试图像（纯色）
        final testImage = await _createTestImage(256, 256, const Color(0xFF4CAF50));
        final rgba = await _extractRGBA(testImage);

        // 创建标准T-Pose关节点（归一化坐标）
        final joints = _createTPoseJoints();

        // 执行分区
        final textures = await partitionEngine.partition(
          source: testImage,
          rgba: rgba,
          mask: null,
          joints: joints,
          width: 256,
          height: 256,
          config: const AvatarBuildConfig(),
        );

        // 验证结果
        expect(textures, isNotEmpty);
        expect(textures.containsKey(BodyPart.head), isTrue);
        expect(textures.containsKey(BodyPart.upperArmL), isTrue);
        expect(textures.containsKey(BodyPart.upperArmR), isTrue);
        expect(textures.containsKey(BodyPart.lowerArmL), isTrue);
        expect(textures.containsKey(BodyPart.lowerArmR), isTrue);
      });

      test('应正确处理手臂下垂姿态', () async {
        final testImage = await _createTestImage(256, 256, const Color(0xFF2196F3));
        final rgba = await _extractRGBA(testImage);

        // 创建手臂下垂姿态关节点
        final joints = _createArmsDownJoints();

        final textures = await partitionEngine.partition(
          source: testImage,
          rgba: rgba,
          mask: null,
          joints: joints,
          width: 256,
          height: 256,
          config: const AvatarBuildConfig(),
        );

        expect(textures, isNotEmpty);
      });

      test('应处理缺失关节点的降级', () async {
        final testImage = await _createTestImage(256, 256, const Color(0xFFFF9800));
        final rgba = await _extractRGBA(testImage);

        // 创建不完整的关节点
        final joints = {
          JointType.nose: const Landmark(x: 0.5, y: 0.2, z: 0, visibility: 0.9),
          JointType.leftShoulder: const Landmark(x: 0.3, y: 0.35, z: 0, visibility: 0.8),
          // 缺少右肩
        };

        final textures = await partitionEngine.partition(
          source: testImage,
          rgba: rgba,
          mask: null,
          joints: joints,
          width: 256,
          height: 256,
          config: const AvatarBuildConfig(),
        );

        // 即使关节点不完整，也应该能生成部分结果
        // 验证不会崩溃
        expect(textures, isA<Map<BodyPart, BodyPartTexture>>());
      });

      test('应正确应用置信度阈值', () async {
        final testImage = await _createTestImage(256, 256, const Color(0xFF9C27B0));
        final rgba = await _extractRGBA(testImage);

        // 创建低置信度的关节点
        final joints = _createTPoseJoints().map((key, value) {
          return MapEntry(key, Landmark(
            x: value.x,
            y: value.y,
            z: value.z,
            visibility: 0.3, // 低置信度
          ));
        });

        final textures = await partitionEngine.partition(
          source: testImage,
          rgba: rgba,
          mask: null,
          joints: joints,
          width: 256,
          height: 256,
          config: const AvatarBuildConfig(
            minConfidenceThreshold: 0.5,
          ),
        );

        // 应该仍然生成结果（置信度检查在更高层）
        expect(textures, isA<Map<BodyPart, BodyPartTexture>>());
      });
    });

    group('CapsulePartitionEngine Integration', () {
      test('应正确裁剪手臂区域', () async {
        final engine = CapsulePartitionEngine(
          config: const AvatarBuildConfig(
            targetImageSize: 256,
            featherRatio: 0.2,
            sampleCount: 4,
          ),
        );

        final testImage = await _createTestImage(256, 256, const Color(0xFFE91E63));
        final rgba = await _extractRGBA(testImage);

        final input = CapsulePartitionInput(
          image: testImage,
          rgba: rgba,
          width: 256,
          height: 256,
          geometry: CapsuleGeometry(
            jointA: const Offset(80, 100),
            jointB: const Offset(160, 140),
            radius: 20,
          ),
          mask: null,
          config: const AvatarBuildConfig(),
        );

        final result = await engine.cropCapsule(input);

        expect(result, isNotNull);
        expect(result.width, greaterThan(0));
        expect(result.height, greaterThan(0));
      });

      test('应正确处理羽化效果', () async {
        final engine = CapsulePartitionEngine(
          config: const AvatarBuildConfig(
            targetImageSize: 256,
            featherRatio: 0.3,
            sampleCount: 4,
          ),
        );

        final testImage = await _createTestImage(256, 256, const Color(0xFF00BCD4));
        final rgba = await _extractRGBA(testImage);

        final input = CapsulePartitionInput(
          image: testImage,
          rgba: rgba,
          width: 256,
          height: 256,
          geometry: CapsuleGeometry(
            jointA: const Offset(128, 50),
            jointB: const Offset(128, 200),
            radius: 30,
          ),
          mask: null,
          config: const AvatarBuildConfig(featherRatio: 0.3),
        );

        final result = await engine.cropCapsule(input);

        expect(result, isNotNull);
        // 验证图像尺寸
        expect(result.width, greaterThan(0));
        expect(result.height, greaterThan(0));
      });

      test('应正确处理BoneWeight融合', () async {
        final engine = CapsulePartitionEngine(
          config: const AvatarBuildConfig(
            targetImageSize: 256,
            enableBoneWeight: true,
            boneWeightDecay: 0.05,
          ),
        );

        final testImage = await _createTestImage(256, 256, const Color(0xFFFF5722));
        final rgba = await _extractRGBA(testImage);

        final input = CapsulePartitionInput(
          image: testImage,
          rgba: rgba,
          width: 256,
          height: 256,
          geometry: CapsuleGeometry(
            jointA: const Offset(50, 128),
            jointB: const Offset(200, 128),
            radius: 25,
          ),
          mask: null,
          config: const AvatarBuildConfig(enableBoneWeight: true),
        );

        final result = await engine.cropCapsule(input);

        expect(result, isNotNull);
      });
    });

    group('RegionBuilder Integration', () {
      test('应正确构建各身体部位的胶囊区域', () {
        final shoulderWidth = 80.0;
        final leftShoulder = const Offset(80, 100);
        final leftElbow = const Offset(40, 140);
        final leftWrist = const Offset(30, 180);
        final nose = const Offset(120, 60);

        // 验证上臂区域
        final upperArmL = RegionBuilder.buildUpperArmRegion(
          shoulder: leftShoulder,
          elbow: leftElbow,
          shoulderWidth: shoulderWidth,
        );
        expect(upperArmL.radius, closeTo(10, 0.1)); // 80 * 0.25 / 2
        expect(upperArmL.jointA, equals(leftShoulder));
        expect(upperArmL.jointB, equals(leftElbow));

        // 验证下臂区域
        final lowerArmL = RegionBuilder.buildLowerArmRegion(
          elbow: leftElbow,
          wrist: leftWrist,
          shoulderWidth: shoulderWidth,
        );
        expect(lowerArmL.radius, closeTo(8, 0.1)); // 80 * 0.2 / 2

        // 验证头部区域
        final head = RegionBuilder.buildHeadRegion(
          nose: nose,
          shoulderWidth: shoulderWidth,
        );
        expect(head.radius, closeTo(48, 0.1)); // 80 * 0.6
        expect(head.jointA, equals(nose));
        expect(head.jointB, equals(nose)); // 圆形
      });
    });

    group('AvatarBuildResult Tests', () {
      test('应正确创建成功结果', () {
        final textures = <BodyPart, BodyPartTexture>{};
        final result = AvatarBuildResult.success(
          textures: textures,
          sourceSize: const Size(256, 256),
          buildTimeMs: 500,
          overallQuality: 0.85,
        );

        expect(result.success, isTrue);
        expect(result.textures, equals(textures));
        expect(result.buildTimeMs, equals(500));
        expect(result.overallQuality, closeTo(0.85, 0.001));
        expect(result.errorMessage, isNull);
      });

      test('应正确创建失败结果', () {
        final result = AvatarBuildResult.failure(
          errorMessage: '测试失败',
          errorType: AvatarBuildError.missingJoints,
          buildTimeMs: 100,
        );

        expect(result.success, isFalse);
        expect(result.textures, isEmpty);
        expect(result.errorMessage, equals('测试失败'));
        expect(result.errorType, equals(AvatarBuildError.missingJoints));
      });

      test('应正确检查缺失部位', () async {
        // 创建真实的测试图像用于mock
        final testImage = await _createTestImage(80, 80, const Color(0xFFBDBDBD));

        final textures = {
          BodyPart.head: BodyPartTexture(
            part: BodyPart.head,
            image: testImage,
            sourceRect: Rect.fromLTWH(0, 0, 80, 80),
            pivotOffset: const Offset(0.5, 0.9),
          ),
        };

        final result = AvatarBuildResult.success(
          textures: textures,
          sourceSize: const Size(256, 256),
        );

        expect(result.hasAllRequiredParts(), isFalse);
        expect(result.getMissingParts(), contains(BodyPart.torso));
        expect(result.getMissingParts(), contains(BodyPart.upperArmL));
      });
    });

    group('AvatarBuildConfig Tests', () {
      test('应提供默认配置', () {
        const config = AvatarBuildConfig();

        expect(config.targetImageSize, equals(512));
        expect(config.maxPartSize, equals(256));
        expect(config.featherRatio, closeTo(0.2, 0.01));
        expect(config.sampleCount, equals(4));
        expect(config.enableBoneWeight, isTrue);
      });

      test('应正确生成采样偏移', () {
        const config = AvatarBuildConfig(sampleCount: 4);
        final offsets = config.sampleOffsets;

        expect(offsets.length, equals(4));
        expect(offsets[0], equals(const Offset(0.25, 0.25)));
        expect(offsets[3], equals(const Offset(0.75, 0.75)));
      });

      test('高质量配置应有更多采样', () {
        const config = AvatarBuildConfig.highQuality;
        final offsets = config.sampleOffsets;

        expect(config.sampleCount, equals(9));
        expect(offsets.length, equals(9));
      });
    });
  });
}

// ============ 测试辅助函数 ============

/// 创建测试图像
Future<Image> _createTestImage(int width, int height, Color color) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()..color = color;

  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    paint,
  );

  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}

/// 提取RGBA数据
Future<Uint8List> _extractRGBA(Image image) async {
  final byteData = await image.toByteData(format: ImageByteFormat.rawRgba);
  return byteData!.buffer.asUint8List();
}

/// 创建标准T-Pose关节点
Map<JointType, Landmark> _createTPoseJoints() {
  return {
    JointType.nose: const Landmark(x: 0.5, y: 0.15, z: 0, visibility: 0.95),
    JointType.leftShoulder: const Landmark(x: 0.3, y: 0.3, z: 0, visibility: 0.9),
    JointType.rightShoulder: const Landmark(x: 0.7, y: 0.3, z: 0, visibility: 0.9),
    JointType.leftElbow: const Landmark(x: 0.2, y: 0.45, z: 0, visibility: 0.85),
    JointType.rightElbow: const Landmark(x: 0.8, y: 0.45, z: 0, visibility: 0.85),
    JointType.leftWrist: const Landmark(x: 0.15, y: 0.6, z: 0, visibility: 0.8),
    JointType.rightWrist: const Landmark(x: 0.85, y: 0.6, z: 0, visibility: 0.8),
  };
}

/// 创建手臂下垂姿态关节点
Map<JointType, Landmark> _createArmsDownJoints() {
  return {
    JointType.nose: const Landmark(x: 0.5, y: 0.15, z: 0, visibility: 0.95),
    JointType.leftShoulder: const Landmark(x: 0.3, y: 0.3, z: 0, visibility: 0.9),
    JointType.rightShoulder: const Landmark(x: 0.7, y: 0.3, z: 0, visibility: 0.9),
    JointType.leftElbow: const Landmark(x: 0.28, y: 0.5, z: 0, visibility: 0.85),
    JointType.rightElbow: const Landmark(x: 0.72, y: 0.5, z: 0, visibility: 0.85),
    JointType.leftWrist: const Landmark(x: 0.27, y: 0.7, z: 0, visibility: 0.8),
    JointType.rightWrist: const Landmark(x: 0.73, y: 0.7, z: 0, visibility: 0.8),
  };
}
