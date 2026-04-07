import 'dart:ui';

/// 身体部位枚举
///
/// 定义Avatar生成时的身体分区类型
enum BodyPart {
  /// 头部
  head(
    'head',
    pivotJoint: 'neck',
    description: '头部区域，包含面部',
  ),

  /// 躯干
  torso(
    'torso',
    pivotJoint: 'spine',
    description: '躯干区域，包含胸腹部',
  ),

  /// 左上臂
  upperArmL(
    'upper_arm_L',
    pivotJoint: 'left_shoulder',
    description: '左上臂，从肩到肘',
  ),

  /// 左下臂
  lowerArmL(
    'lower_arm_L',
    pivotJoint: 'left_elbow',
    description: '左下臂，从肘到腕',
  ),

  /// 左手
  handL(
    'hand_L',
    pivotJoint: 'left_wrist',
    description: '左手区域',
  ),

  /// 右上臂
  upperArmR(
    'upper_arm_R',
    pivotJoint: 'right_shoulder',
    description: '右上臂，从肩到肘',
  ),

  /// 右下臂
  lowerArmR(
    'lower_arm_R',
    pivotJoint: 'right_elbow',
    description: '右下臂，从肘到腕',
  ),

  /// 右手
  handR(
    'hand_R',
    pivotJoint: 'right_wrist',
    description: '右手区域',
  );

  /// Rive骨骼名称
  final String boneName;

  /// Pivot关节名称（旋转中心）
  final String pivotJoint;

  /// 描述
  final String description;

  const BodyPart(
    this.boneName, {
    required this.pivotJoint,
    required this.description,
  });

  /// 获取所有手臂部位
  static List<BodyPart> get armParts => [
    upperArmL,
    lowerArmL,
    handL,
    upperArmR,
    lowerArmR,
    handR,
  ];

  /// 获取左侧手臂部位
  static List<BodyPart> get leftArmParts => [upperArmL, lowerArmL, handL];

  /// 获取右侧手臂部位
  static List<BodyPart> get rightArmParts => [upperArmR, lowerArmR, handR];

  /// 获取主要部位（不含手）
  static List<BodyPart> get mainParts => [head, torso, upperArmL, lowerArmL, upperArmR, lowerArmR];

  /// 是否是手臂部位
  bool get isArm => armParts.contains(this);

  /// 是否是左侧部位
  bool get isLeftSide => leftArmParts.contains(this);

  /// 是否是右侧部位
  bool get isRightSide => rightArmParts.contains(this);

  /// 是否需要肢体裁剪（手臂需要capsule裁剪）
  bool get needsLimbCrop => isArm;
}

/// 身体部位纹理数据
///
/// 存储裁剪后的身体部位图像和元数据
class BodyPartTexture {
  /// 部位类型
  final BodyPart part;

  /// 裁剪后的图像
  final Image image;

  /// 在原图中的位置（归一化坐标）
  final Rect sourceRect;

  /// Pivot点相对于纹理的位置（归一化，0-1）
  final Offset pivotOffset;

  /// 裁剪质量评分（0-1）
  final double qualityScore;

  const BodyPartTexture({
    required this.part,
    required this.image,
    required this.sourceRect,
    required this.pivotOffset,
    this.qualityScore = 1.0,
  });

  /// 复制并修改
  BodyPartTexture copyWith({
    BodyPart? part,
    Image? image,
    Rect? sourceRect,
    Offset? pivotOffset,
    double? qualityScore,
  }) {
    return BodyPartTexture(
      part: part ?? this.part,
      image: image ?? this.image,
      sourceRect: sourceRect ?? this.sourceRect,
      pivotOffset: pivotOffset ?? this.pivotOffset,
      qualityScore: qualityScore ?? this.qualityScore,
    );
  }
}