import '../entities/joint_type.dart';

/// MediaPipe Pose关键点索引
/// 
/// MediaPipe Pose共33个关键点，这里定义Mimo使用的索引映射
class PoseMapping {
  PoseMapping._();

  /// 关键点索引映射
  static const Map<int, JointType> mediaPipeToJointType = {
    0: JointType.nose,          // nose
    11: JointType.leftShoulder, // left_shoulder
    12: JointType.rightShoulder, // right_shoulder
    13: JointType.leftElbow,    // left_elbow
    14: JointType.rightElbow,   // right_elbow
    15: JointType.leftWrist,    // left_wrist
    16: JointType.rightWrist,   // right_wrist
  };

  /// 获取Mimo支持的MediaPipe索引列表
  static List<int> get supportedIndices => mediaPipeToJointType.keys.toList();

  /// 从MediaPipe索引转换为JointType
  static JointType? toJointType(int mediaPipeIndex) {
    return mediaPipeToJointType[mediaPipeIndex];
  }

  /// 从JointType获取MediaPipe索引
  static int? toMediaPipeIndex(JointType jointType) {
    for (final entry in mediaPipeToJointType.entries) {
      if (entry.value == jointType) {
        return entry.key;
      }
    }
    return null;
  }
}