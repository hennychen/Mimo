import 'dart:ui';
import 'package:camera/camera.dart' as camera;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../domain/entities/joint_type.dart';
import '../../domain/entities/landmark.dart';
import '../../domain/repositories/pose_repository.dart';
import '../../domain/services/pose_mapping_service.dart';

/// 姿态检测仓库实现
class PoseRepositoryImpl implements PoseRepository {
  late final PoseDetector _detector;
  bool _isInitialized = false;

  PoseRepositoryImpl() {
    _detector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.accurate,
      ),
    );
  }

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    _isInitialized = true;
  }

  @override
  Map<JointType, Landmark> detect(dynamic image, int width, int height) {
    // 这里需要根据实际的图像格式进行处理
    return {};
  }

  /// 处理CameraImage（实际实现）
  /// 将CameraImage转换为InputImage并进行姿态检测
  Future<Map<JointType, Landmark>> detectFromCameraImage(
    camera.CameraImage cameraImage, {
    required int width,
    required int height,
    required int rotation,
  }) async {
    try {
      // 将CameraImage转换为InputImage
      final inputImage = _convertToInputImage(
        cameraImage,
        width: width,
        height: height,
        rotation: rotation,
      );

      if (inputImage == null) {
        return {};
      }

      // 执行姿态检测
      final poses = await _detector.processImage(inputImage);

      if (poses.isEmpty) {
        return {};
      }

      // 取第一个检测到的人体
      final pose = poses.first;
      final landmarks = _convertPoseToLandmarks(pose);

      debugPrint('✅ Pose detected! Found ${landmarks.length} landmarks');

      return landmarks;
    } catch (e) {
      debugPrint('❌ Pose detection error: $e');
      return {};
    }
  }

  /// 将CameraImage转换为InputImage
  InputImage? _convertToInputImage(
    camera.CameraImage image, {
    required int width,
    required int height,
    required int rotation,
  }) {
    try {
      // 获取旋转角度
      final inputImageRotation = _getInputImageRotation(rotation);

      // NV21格式
      if (image.format.group == camera.ImageFormatGroup.nv21) {
        final plane = image.planes[0];
        return InputImage.fromBytes(
          bytes: plane.bytes,
          metadata: InputImageMetadata(
            size: Size(width.toDouble(), height.toDouble()),
            rotation: inputImageRotation,
            format: InputImageFormat.nv21,
            bytesPerRow: plane.bytesPerRow,
          ),
        );
      }

      // YUV420格式 (Android默认)
      if (image.format.group == camera.ImageFormatGroup.yuv420) {
        // YUV420 需要转换为 NV21
        final yBuffer = image.planes[0].bytes; // Y平面
        final uBuffer = image.planes[1].bytes; // U平面
        final vBuffer = image.planes[2].bytes; // V平面

        final yBytesPerRow = image.planes[0].bytesPerRow;
        final uBytesPerRow = image.planes[1].bytesPerRow;
        final vBytesPerRow = image.planes[2].bytesPerRow;

        // NV21格式: Y + VUVU...
        final nv21Size = width * height + (width * height) ~/ 2;
        final nv21 = Uint8List(nv21Size);

        // 复制Y平面 (需要处理行填充)
        int nv21Index = 0;
        for (int row = 0; row < height; row++) {
          final yRowStart = row * yBytesPerRow;
          for (int col = 0; col < width; col++) {
            nv21[nv21Index++] = yBuffer[yRowStart + col];
          }
        }

        // NV21的UV部分: VUVU交错
        final uvHeight = height ~/ 2;
        final uvWidth = width ~/ 2;

        for (int row = 0; row < uvHeight; row++) {
          for (int col = 0; col < uvWidth; col++) {
            final uIndex = row * uBytesPerRow + col;
            final vIndex = row * vBytesPerRow + col;

            nv21[nv21Index++] = vBuffer[vIndex]; // V
            nv21[nv21Index++] = uBuffer[uIndex]; // U
          }
        }

        return InputImage.fromBytes(
          bytes: nv21,
          metadata: InputImageMetadata(
            size: Size(width.toDouble(), height.toDouble()),
            rotation: inputImageRotation,
            format: InputImageFormat.nv21,
            bytesPerRow: width, // NV21没有填充
          ),
        );
      }

      // BGRA8888格式 (iOS默认)
      if (image.format.group == camera.ImageFormatGroup.bgra8888) {
        final plane = image.planes[0];
        return InputImage.fromBytes(
          bytes: plane.bytes,
          metadata: InputImageMetadata(
            size: Size(width.toDouble(), height.toDouble()),
            rotation: inputImageRotation,
            format: InputImageFormat.bgra8888,
            bytesPerRow: plane.bytesPerRow,
          ),
        );
      }

      // 未知格式
      debugPrint('❌ Unknown image format: ${image.format.group}');
      return null;
    } catch (e) {
      debugPrint('Error converting CameraImage: $e');
      return null;
    }
  }

  /// 获取InputImageRotation
  InputImageRotation _getInputImageRotation(int rotation) {
    switch (rotation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  /// 将Pose转换为Landmark映射
  Map<JointType, Landmark> _convertPoseToLandmarks(Pose pose) {
    final result = <JointType, Landmark>{};

    for (final entry in PoseMapping.mediaPipeToJointType.entries) {
      final mediaPipeIndex = entry.key;
      final jointType = entry.value;

      // 获取对应的PoseLandmark
      final landmark = _getPoseLandmark(pose, mediaPipeIndex);
      if (landmark != null) {
        result[jointType] = Landmark(
          x: landmark.x,
          y: landmark.y,
          z: landmark.z,
          visibility: landmark.likelihood,
        );
      }
    }

    return result;
  }

  /// 获取PoseLandmark
  PoseLandmark? _getPoseLandmark(Pose pose, int mediaPipeIndex) {
    // MediaPipe索引与Google ML Kit的PoseLandmarkType对应关系
    final type = _mediaPipeToGoogleMLKitType(mediaPipeIndex);
    if (type == null) return null;

    try {
      return pose.landmarks[type];
    } catch (e) {
      return null;
    }
  }

  /// MediaPipe索引转Google ML Kit PoseLandmarkType
  PoseLandmarkType? _mediaPipeToGoogleMLKitType(int index) {
    const mapping = {
      0: PoseLandmarkType.nose,
      11: PoseLandmarkType.leftShoulder,
      12: PoseLandmarkType.rightShoulder,
      13: PoseLandmarkType.leftElbow,
      14: PoseLandmarkType.rightElbow,
      15: PoseLandmarkType.leftWrist,
      16: PoseLandmarkType.rightWrist,
    };
    return mapping[index];
  }

  @override
  void dispose() {
    _detector.close();
    _isInitialized = false;
  }
}
