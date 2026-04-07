/// 手势类型枚举
/// 
/// 定义Mimo可识别的动作手势，用于触发音效、表情等互动反馈
enum GestureType {
  /// 无手势
  none(
    '无',
    'none',
    '没有检测到有效手势',
  ),
  
  /// 待机状态
  idle(
    '待机',
    'idle',
    '默认待机状态',
  ),
  
  /// T-Pose姿势
  tPose(
    'T-Pose',
    't_pose',
    '双臂侧平举的校准姿势',
  ),
  
  /// 举手 - 手腕高于肩膀
  handRaise(
    '举手',
    'raise_hand',
    '当手举过头顶时触发',
  ),
  
  /// 双手张开 - 双腕距离大于阈值
  armsOpen(
    '双手张开',
    'arms_open',
    '当双臂向两侧张开时触发',
  ),
  
  /// 挥手 - x方向周期变化
  wave(
    '挥手',
    'wave',
    '当手在水平方向来回摆动时触发',
  ),
  
  /// 拍手 - 双手靠近
  clap(
    '拍手',
    'clap',
    '当双手靠近时触发',
  ),
  
  /// 双手高举 - 双手都在头顶
  handsUp(
    '双手高举',
    'hands_up',
    '当双手都举过头顶时触发',
  );

  /// 中文名称
  final String label;
  
  /// 音效文件名（不含扩展名）
  final String soundName;
  
  /// 触发条件描述
  final String description;

  const GestureType(this.label, this.soundName, this.description);

  /// 从名称获取GestureType
  static GestureType? fromName(String name) {
    for (final type in GestureType.values) {
      if (type.name == name) {
        return type;
      }
    }
    return null;
  }
}