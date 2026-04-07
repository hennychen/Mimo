import 'gesture_type.dart';
import 'joint_type.dart';

/// 帧处理结果
/// 
/// 包含经过完整pipeline处理后的关节角度和识别到的手势
class FrameResult {
  /// 各关节的角度（弧度制）
  final Map<JointType, double> jointAngles;
  
  /// 识别到的手势（可为空）
  final GestureType? gesture;
  
  /// 帧时间戳（毫秒）
  final int timestamp;
  
  /// 平均置信度
  final double confidence;

  const FrameResult({
    required this.jointAngles,
    this.gesture,
    required this.timestamp,
    this.confidence = 1.0,
  });

  /// 创建空的帧结果（用于idle状态）
  factory FrameResult.empty(int timestamp) {
    return FrameResult(
      jointAngles: {},
      gesture: null,
      timestamp: timestamp,
      confidence: 0.0,
    );
  }

  /// 获取指定关节的角度
  double? getAngle(JointType joint) => jointAngles[joint];

  /// 是否有有效的角度数据
  bool get hasValidData => jointAngles.isNotEmpty;

  /// 是否处于idle状态
  bool get isIdle => confidence < 0.3;

  /// 复制并修改
  FrameResult copyWith({
    Map<JointType, double>? jointAngles,
    GestureType? gesture,
    int? timestamp,
    double? confidence,
  }) {
    return FrameResult(
      jointAngles: jointAngles ?? this.jointAngles,
      gesture: gesture ?? this.gesture,
      timestamp: timestamp ?? this.timestamp,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  String toString() {
    return 'FrameResult(angles: ${jointAngles.length}, gesture: $gesture, '
        'confidence: ${confidence.toStringAsFixed(2)})';
  }
}

/// 帧数据
/// 
/// 原始输入帧数据
class FrameData {
  /// 时间戳（毫秒）
  final int timestamp;
  
  /// 图像数据（字节数据或CameraImage）
  final dynamic image;
  
  /// 图像宽度
  final int width;
  
  /// 图像高度
  final int height;

  const FrameData({
    required this.timestamp,
    required this.image,
    required this.width,
    required this.height,
  });

  /// 宽高比
  double get aspectRatio => width / height;
}