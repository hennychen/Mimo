import 'dart:ui';

import 'package:flutter/material.dart';

/// Rive Avatar模板配置
///
/// 定义Rive文件中需要包含的骨骼结构和Image节点配置
/// 在Rive编辑器中创建角色模板时需要遵循此规范
class RiveAvatarTemplate {
  /// 模板文件路径
  static const String templatePath = 'assets/rive/avatar_template.riv';

  /// 骨骼层级结构
  static const List<BoneDefinition> boneHierarchy = [
    BoneDefinition(
      name: 'root',
      type: BoneType.root,
      children: [
        BoneDefinition(name: 'torso', type: BoneType.body),
        BoneDefinition(
          name: 'head',
          type: BoneType.head,
          pivotOffset: Offset(0.5, 0.9),
        ),
        BoneDefinition(
          name: 'upper_arm_L',
          type: BoneType.upperArm,
          pivotOffset: Offset(0.1, 0.5),
          children: [
            BoneDefinition(
              name: 'lower_arm_L',
              type: BoneType.lowerArm,
              pivotOffset: Offset(0.1, 0.5),
              children: [
                BoneDefinition(name: 'hand_L', type: BoneType.hand),
              ],
            ),
          ],
        ),
        BoneDefinition(
          name: 'upper_arm_R',
          type: BoneType.upperArm,
          pivotOffset: Offset(0.9, 0.5),
          children: [
            BoneDefinition(
              name: 'lower_arm_R',
              type: BoneType.lowerArm,
              pivotOffset: Offset(0.9, 0.5),
              children: [
                BoneDefinition(name: 'hand_R', type: BoneType.hand),
              ],
            ),
          ],
        ),
      ],
    ),
  ];

  /// Image节点配置
  static const List<ImageNodeConfig> imageNodes = [
    ImageNodeConfig(
      nodeName: 'torso_image',
      targetBone: 'torso',
      placeholderColor: Color(0xFF9E9E9E),
      width: 120,
      height: 150,
    ),
    ImageNodeConfig(
      nodeName: 'head_image',
      targetBone: 'head',
      placeholderColor: Color(0xFFBDBDBD),
      width: 80,
      height: 80,
    ),
    ImageNodeConfig(
      nodeName: 'upper_arm_L_image',
      targetBone: 'upper_arm_L',
      placeholderColor: Color(0xFFE0E0E0),
      width: 60,
      height: 25,
    ),
    ImageNodeConfig(
      nodeName: 'lower_arm_L_image',
      targetBone: 'lower_arm_L',
      placeholderColor: Color(0xFFE0E0E0),
      width: 50,
      height: 20,
    ),
    ImageNodeConfig(
      nodeName: 'hand_L_image',
      targetBone: 'hand_L',
      placeholderColor: Color(0xFFF5F5F5),
      width: 30,
      height: 25,
    ),
    ImageNodeConfig(
      nodeName: 'upper_arm_R_image',
      targetBone: 'upper_arm_R',
      placeholderColor: Color(0xFFE0E0E0),
      width: 60,
      height: 25,
    ),
    ImageNodeConfig(
      nodeName: 'lower_arm_R_image',
      targetBone: 'lower_arm_R',
      placeholderColor: Color(0xFFE0E0E0),
      width: 50,
      height: 20,
    ),
    ImageNodeConfig(
      nodeName: 'hand_R_image',
      targetBone: 'hand_R',
      placeholderColor: Color(0xFFF5F5F5),
      width: 30,
      height: 25,
    ),
  ];

  /// 动画配置
  static const List<AnimationConfig> animations = [
    AnimationConfig(name: 'idle', durationMs: 2000, loop: true),
    AnimationConfig(name: 'wave', durationMs: 1500, loop: false),
    AnimationConfig(name: 't_pose', durationMs: 500, loop: false),
  ];

  /// 状态机配置
  static const StateMachineConfig stateMachine = StateMachineConfig(
    name: 'avatar_state',
    inputs: ['gesture', 'speed'],
    states: ['idle', 'active', 'gesture'],
  );
}

/// 骨骼类型
enum BoneType {
  root,
  body,
  head,
  upperArm,
  lowerArm,
  hand,
}

/// 骨骼定义
class BoneDefinition {
  final String name;
  final BoneType type;
  final Offset pivotOffset;
  final List<BoneDefinition> children;

  const BoneDefinition({
    required this.name,
    required this.type,
    this.pivotOffset = const Offset(0.5, 0.5),
    this.children = const [],
  });
}

/// Image节点配置
class ImageNodeConfig {
  final String nodeName;
  final String targetBone;
  final Color placeholderColor;
  final double width;
  final double height;

  const ImageNodeConfig({
    required this.nodeName,
    required this.targetBone,
    required this.placeholderColor,
    required this.width,
    required this.height,
  });
}

/// 动画配置
class AnimationConfig {
  final String name;
  final int durationMs;
  final bool loop;

  const AnimationConfig({
    required this.name,
    required this.durationMs,
    required this.loop,
  });
}

/// 状态机配置
class StateMachineConfig {
  final String name;
  final List<String> inputs;
  final List<String> states;

  const StateMachineConfig({
    required this.name,
    required this.inputs,
    required this.states,
  });
}

/// Rive模板创建指南
///
/// 在Rive编辑器中按以下步骤创建Avatar模板：
///
/// 1. 创建骨骼层级
///    - 根据boneHierarchy定义的结构创建骨骼
///    - 确保骨骼命名完全匹配（区分大小写）
///
/// 2. 设置骨骼Pivot
///    - upper_arm: Pivot在shoulder位置 (0.1, 0.5)
///    - lower_arm: Pivot在elbow位置 (0.1, 0.5)
///    - head: Pivot在neck位置 (0.5, 0.9)
///
/// 3. 创建Image节点
///    - 每个骨骼绑定一个Image节点
///    - 节点命名遵循 {bone_name}_image 格式
///    - 设置占位颜色便于调试
///
/// 4. 设置父子关系
///    - Image节点作为对应骨骼的子节点
///    - 骨骼层级遵循boneHierarchy结构
///
/// 5. 创建动画
///    - idle: 呼吸动画，循环播放
///    - wave: 挥手动画，一次性播放
///    - t_pose: T-Pose姿势校准
///
/// 6. 创建状态机（可选）
///    - 定义gesture输入控制手势动画
///    - 定义speed输入控制动画速度
class RiveTemplateGuide {
  /// 获取创建指南文本
  static String get creationGuide => '''
# Rive Avatar模板创建指南

## 1. 骨骼结构

```
root
├── torso
│   └── torso_image (Image)
├── head
│   └── head_image (Image)
├── upper_arm_L
│   ├── upper_arm_L_image (Image)
│   └── lower_arm_L
│       ├── lower_arm_L_image (Image)
│       └── hand_L
│           └── hand_L_image (Image)
└── upper_arm_R
    ├── upper_arm_R_image (Image)
    └── lower_arm_R
        ├── lower_arm_R_image (Image)
        └── hand_R
            └── hand_R_image (Image)
```

## 2. Pivot位置设置

| 骨骼 | Pivot X | Pivot Y | 说明 |
|------|---------|---------|------|
| upper_arm_L | 0.1 | 0.5 | 左肩关节 |
| lower_arm_L | 0.1 | 0.5 | 左肘关节 |
| upper_arm_R | 0.9 | 0.5 | 右肩关节 |
| lower_arm_R | 0.9 | 0.5 | 右肘关节 |
| head | 0.5 | 0.9 | 颈部位置 |

## 3. 导出设置

- 格式: .riv
- 文件名: avatar_template.riv
- 存放路径: assets/rive/
''';
}