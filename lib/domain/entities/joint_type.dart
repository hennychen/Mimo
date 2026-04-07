/// 关节类型枚举
/// 
/// 定义Mimo支持驱动的关节类型，与MediaPipe Pose关键点索引对应
enum JointType {
  /// 左肩 - MediaPipe index: 11
  leftShoulder(11, 'upper_arm_L'),
  
  /// 左肘 - MediaPipe index: 13
  leftElbow(13, 'lower_arm_L'),
  
  /// 左手腕 - MediaPipe index: 15
  leftWrist(15, 'hand_L'),
  
  /// 右肩 - MediaPipe index: 12
  rightShoulder(12, 'upper_arm_R'),
  
  /// 右肘 - MediaPipe index: 14
  rightElbow(14, 'lower_arm_R'),
  
  /// 右手腕 - MediaPipe index: 16
  rightWrist(16, 'hand_R'),
  
  /// 鼻子/头部 - MediaPipe index: 0
  nose(0, 'head');

  /// MediaPipe Pose关键点索引
  final int mediaPipeIndex;
  
  /// 对应的Rive骨骼名称
  final String riveBoneName;

  const JointType(this.mediaPipeIndex, this.riveBoneName);

  /// 从MediaPipe索引获取JointType
  static JointType? fromMediaPipeIndex(int index) {
    for (final type in JointType.values) {
      if (type.mediaPipeIndex == index) {
        return type;
      }
    }
    return null;
  }

  /// 获取所有上肢关节（用于驱动）
  static List<JointType> get upperBodyJoints => [
    leftShoulder,
    leftElbow,
    rightShoulder,
    rightElbow,
  ];

  /// 获取所有左侧关节
  static List<JointType> get leftSideJoints => [leftShoulder, leftElbow, leftWrist];

  /// 获取所有右侧关节
  static List<JointType> get rightSideJoints => [rightShoulder, rightElbow, rightWrist];
}

/// 关节组，用于批量操作
extension JointTypeGroup on List<JointType> {
  /// 是否包含左侧关节
  bool get hasLeftSide => any((j) => JointType.leftSideJoints.contains(j));
  
  /// 是否包含右侧关节
  bool get hasRightSide => any((j) => JointType.rightSideJoints.contains(j));
}