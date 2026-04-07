# Mimo 项目实现总结

## 项目概述

**Mimo** 是一个基于 Flutter 的实时2D动捕互动工具，利用 Google ML Kit 进行姿态识别，通过 Rive 2.0 实现角色动画驱动，支持用户上传照片自动生成可驱动的Avatar角色。

### 核心功能
- 🎯 **实时姿态识别** - MediaPipe Pose Detection 检测33个关键点
- 🤖 **角色动画驱动** - Rive 2.0 骨骼动画实时跟随用户动作
- 📊 **置信度处理** - 自动平滑低置信度关键点
- 🔧 **T-Pose校准** - 一键校准用户身体比例
- 🎵 **手势音效** - 手势触发对应音效反馈
- 📈 **性能监控** - FPS、延迟实时监控与降级建议
- 🖼️ **Avatar生成** - 用户照片自动生成可驱动角色（胶囊形裁剪+骨骼绑定）

---

## 技术架构

### 技术栈
| 技术 | 版本 | 用途 |
|:---|:---:|:---|
| Flutter | 3.8+ | 跨平台UI框架 |
| Riverpod | 2.6+ | 状态管理 |
| Google ML Kit Pose | 0.11+ | 姿态检测 |
| Google ML Kit Selfie Segmentation | 0.8+ | 人体分割 |
| Rive | 0.13+ | 2D动画渲染 |
| camera | 0.11+ | 摄像头控制 |
| audioplayers | 6.0+ | 音效播放 |
| image_picker | 1.0+ | 图片选择 |
| path_provider | 2.1+ | 文件存储 |

### 架构层次

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  (home_page, calibration_page, avatar_create_page, widgets) │
├─────────────────────────────────────────────────────────────┤
│                    Application Layer                         │
│  (providers, motion_pipeline, avatar_builder_service)       │
├─────────────────────────────────────────────────────────────┤
│                      Domain Layer                            │
│  (entities, engines, services, repositories interfaces)     │
│  - Avatar引擎: BodyPartitionEngine, CapsulePartitionEngine   │
├─────────────────────────────────────────────────────────────┤
│                       Data Layer                             │
│  (repositories_impl, segmentation_engine_impl, cache_service)│
└─────────────────────────────────────────────────────────────┘
```

---

## 已实现模块

### Phase 1: 环境搭建 ✅
- Flutter 项目初始化
- Clean Architecture 目录结构
- 依赖配置 (pubspec.yaml)
- 基础 Provider 配置

### Phase 2: 姿态识别集成 ✅
| 文件 | 功能 |
|:---|:---|
| `lib/domain/entities/landmark.dart` | 关键点数据结构 |
| `lib/domain/entities/joint_type.dart` | 33个关节类型枚举 |
| `lib/domain/entities/gesture_type.dart` | 手势类型枚举 |
| `lib/data/repositories_impl/pose_repository_impl.dart` | MediaPipe Pose Detection 集成 |
| `lib/data/repositories_impl/camera_repository_impl.dart` | 摄像头管理 |

### Phase 3: 角度计算与驱动 ✅
| 文件 | 功能 |
|:---|:---|
| `lib/domain/services/angle_compute_service.dart` | 关节角度计算 |
| `lib/domain/services/pose_mapping_service.dart` | 姿态到骨骼映射 |
| `lib/domain/services/rive_bone_controller.dart` | Rive骨骼驱动控制 |
| `lib/domain/entities/body_metrics.dart` | 人体度量数据 |
| `lib/domain/entities/frame_result.dart` | 帧处理结果 |

### Phase 4: 稳定化处理 ✅
| 文件 | 功能 |
|:---|:---|
| `lib/domain/engines/filtering/one_euro_filter.dart` | One Euro Filter 实现 |
| `lib/domain/engines/filtering/motion_filter_engine.dart` | 运动滤波引擎 |
| `lib/domain/engines/confidence/confidence_processor.dart` | 置信度处理 |
| `lib/domain/engines/kinematics/kinematics_engine.dart` | 关节约束系统 |
| `lib/domain/engines/normalization/normalization_engine.dart` | 人体归一化 |
| `lib/domain/engines/calibration/calibration_engine.dart` | T-Pose校准引擎 |
| `lib/domain/engines/semantic/semantic_engine.dart` | 动作语义识别 |
| `lib/domain/engines/performance/performance_scheduler.dart` | 性能调度器 |

### Phase 5: 体验优化 ✅
| 文件 | 功能 |
|:---|:---|
| `lib/domain/services/sound_service.dart` | 手势音效服务 |
| `lib/domain/services/avatar_state_machine.dart` | 角色状态机 (idle/tracking/calibrating) |
| `lib/domain/services/performance_monitor.dart` | FPS/延迟监控 |
| `lib/domain/services/analytics_service.dart` | 埋点服务 |
| `lib/presentation/pages/home_page.dart` | 主页面交互控件 |
| `lib/presentation/widgets/rive_avatar_widget.dart` | Rive角色渲染组件 |

### Phase 6: 发布准备 ✅
| 文件 | 功能 |
|:---|:---|
| `lib/main.dart` | 应用入口、服务初始化 |
| `android/app/src/main/AndroidManifest.xml` | Android权限配置 |
| `ios/Runner/Info.plist` | iOS权限配置 |
| `pubspec.yaml` | 应用图标配置 |

### Phase 7: Avatar生成管道 ✅

#### 7.1 领域层实体
| 文件 | 功能 |
|:---|:---|
| `lib/domain/entities/body_part.dart` | 身体部位枚举(8个部位: head, torso, upperArmL/R, lowerArmL/R, handL/R) |
| `lib/domain/entities/avatar_build_result.dart` | Avatar构建结果实体(成功/失败状态、纹理映射、质量评分) |

#### 7.2 领域层引擎 - BodyPartitionEngine四层架构
| 文件 | 功能 |
|:---|:---|
| `lib/domain/engines/avatar/capsule_geometry.dart` | 胶囊几何工具：RegionBuilder(区域构建)、SmoothStep(平滑羽化)、距离计算 |
| `lib/domain/engines/avatar/capsule_partition_engine.dart` | 四层裁剪引擎：Supersampling抗锯齿 + SmoothStep羽化 + BoneWeight融合 |
| `lib/domain/engines/avatar/body_partition_engine.dart` | 身体分区主引擎：整合关节点检测与胶囊裁剪 |
| `lib/domain/engines/avatar/avatar_builder.dart` | 总入口引擎：编排预处理、分割、分区、绑定全流程 |
| `lib/domain/engines/avatar/debug_overlay_painter.dart` | 调试可视化：绘制胶囊区域、骨骼点、边界框 |

#### 7.3 数据层实现
| 文件 | 功能 |
|:---|:---|
| `lib/data/engines_impl/avatar/segmentation_engine_impl.dart` | 人体分割实现：ML Kit Selfie Segmentation + Fallback |
| `lib/data/engines_impl/avatar/texture_binding_engine_impl.dart` | 纹理绑定实现：Rive Image节点替换 |
| `lib/data/services/avatar_cache_service.dart` | 本地缓存服务：Avatar文件存取 |

#### 7.4 应用层
| 文件 | 功能 |
|:---|:---|
| `lib/application/providers/avatar_providers.dart` | Riverpod状态管理Provider |
| `lib/application/services/avatar_builder_service.dart` | 完整服务层：图片选择、姿态检测、分区、绑定、缓存 |

#### 7.5 表现层
| 文件 | 功能 |
|:---|:---|
| `lib/presentation/pages/avatar_create_page.dart` | 用户界面：图片选择、构建进度、结果预览 |
| `lib/presentation/widgets/avatar_preview_widget.dart` | 预览组件：Rive角色展示 |

#### 7.6 核心配置
| 文件 | 功能 |
|:---|:---|
| `lib/core/config/rive_avatar_template.dart` | Rive模板规范：骨骼层级、Image节点配置、Pivot位置 |

#### 7.7 单元测试
| 文件 | 测试内容 |
|:---|:---|
| `test/capsule_geometry_test.dart` | 27个测试用例：几何计算、胶囊判断、BoundingBox、BoneWeight、SmoothStep |
| `test/avatar_integration_test.dart` | 14个测试用例：T-Pose处理、羽化效果、BoneWeight融合、配置验证 |

---

## 核心引擎说明

### 1. 运动处理管道 (MotionPipeline)
```dart
FrameResult process({
  required int timestamp,
  required dynamic image,
  required int width,
  required int height,
})
```
处理流程：姿态检测 → 置信度计算 → 归一化 → 角度计算 → 关节约束 → 滤波 → 置信度混合 → 语义识别

### 2. One Euro Filter
低延迟、低抖动的信号滤波算法，适用于实时动捕场景。
- 参数：minCutoff=1.0, beta=0.007, dCutoff=1.0

### 3. 角色状态机
```
idle → calibrating → tracking → lowConfidence → paused
```
- 无检测30帧后进入 idle
- 置信度<0.4 进入 lowConfidence
- 支持 pause/resume

### 4. BodyPartitionEngine 四层架构

#### Layer 1: RegionBuilder（区域构建）
- 根据关节点构建胶囊形区域
- 计算BoundingBox优化性能（减少90%计算量）
- 支持8个身体部位的胶囊参数计算

#### Layer 2: MaskRefiner（Mask融合）
- 可选的人体分割Mask融合
- 解决手臂与躯干粘连问题
- 取最小值策略融合Capsule和Mask

#### Layer 3: PixelSampler（Supersampling抗锯齿）
- 2x2或3x3采样实现抗锯齿
- 累加多个采样点的alpha值
- 消除边缘锯齿

#### Layer 4: EdgeBlender（SmoothStep羽化）
- 平滑边缘过渡：`t² * (3 - 2t)`
- innerRadius定义完全不透明区域
- featherRange定义羽化范围
- BoneWeight指数衰减解决粘连

#### 核心公式
```dart
// SmoothStep平滑函数
double smoothstep(double t) {
  t = t.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

// BoneWeight距离衰减
double boneWeight = exp(-distance / decay);

// 最终Alpha = Capsule × Feather × Mask × BoneWeight
```

---

## 配置说明

### 权限配置
**Android (AndroidManifest.xml)**
- `android.permission.CAMERA` - 摄像头
- `android.permission.WAKE_LOCK` - 屏幕常亮

**iOS (Info.plist)**
- `NSCameraUsageDescription` - 摄像头使用说明

### 资源文件
| 目录 | 内容 |
|:---|:---|
| `assets/rive/` | Rive动画文件 (.riv) |
| `assets/sounds/` | 音效文件 (.mp3) |
| `assets/icon/` | 应用图标 |

---

## 待完成事项

1. **资源文件**
   - 添加 `assets/rive/mimo_character.riv` Rive动画
   - 添加 `assets/rive/avatar_template.riv` Avatar模板（骨骼+Image节点）
   - 添加 `assets/sounds/` 手势音效文件
   - 添加 `assets/icon/app_icon.png` 应用图标

2. **Avatar生成优化**
   - 在Rive编辑器中创建Avatar模板文件
   - 完善ML Kit Selfie Segmentation真实集成
   - 添加更多姿态支持（侧面、背面）

3. **真机测试**
   - iOS/Android 设备验证
   - 性能优化调整

4. **发布准备**
   - 生成应用图标：`flutter pub run flutter_launcher_icons`
   - 签名配置
   - App Store / Play Store 上架

---

## 文件结构总览

```
lib/
├── main.dart                          # 应用入口
├── application/
│   ├── providers/
│   │   ├── providers.dart             # Riverpod Providers
│   │   └── avatar_providers.dart       # Avatar状态管理
│   ├── pipeline/motion_pipeline.dart  # 运动处理管道
│   └── services/
│       ├── frame_processing_service.dart
│       └── avatar_builder_service.dart # Avatar构建服务
├── domain/
│   ├── entities/                      # 数据实体
│   │   ├── landmark.dart
│   │   ├── joint_type.dart
│   │   ├── gesture_type.dart
│   │   ├── body_metrics.dart
│   │   ├── frame_result.dart
│   │   ├── body_part.dart             # 身体部位枚举
│   │   └── avatar_build_result.dart   # Avatar构建结果
│   ├── engines/                       # 核心引擎
│   │   ├── filtering/
│   │   ├── confidence/
│   │   ├── kinematics/
│   │   ├── normalization/
│   │   ├── calibration/
│   │   ├── semantic/
│   │   ├── performance/
│   │   └── avatar/                    # Avatar引擎
│   │       ├── capsule_geometry.dart
│   │       ├── capsule_partition_engine.dart
│   │       ├── body_partition_engine.dart
│   │       ├── avatar_builder.dart
│   │       └── debug_overlay_painter.dart
│   ├── services/                      # 服务层
│   │   ├── angle_compute_service.dart
│   │   ├── pose_mapping_service.dart
│   │   ├── rive_bone_controller.dart
│   │   ├── sound_service.dart
│   │   ├── avatar_state_machine.dart
│   │   ├── performance_monitor.dart
│   │   └── analytics_service.dart
│   └── repositories/                  # 仓库接口
├── data/
│   ├── repositories_impl/             # 仓库实现
│   │   ├── pose_repository_impl.dart
│   │   ├── camera_repository_impl.dart
│   │   └── storage_repository_impl.dart
│   ├── engines_impl/avatar/           # Avatar引擎实现
│   │   ├── segmentation_engine_impl.dart
│   │   └── texture_binding_engine_impl.dart
│   └── services/
│       └── avatar_cache_service.dart
├── core/
│   └── config/
│       └── rive_avatar_template.dart  # Rive模板配置
├── presentation/
│   ├── pages/
│   │   ├── home_page.dart
│   │   ├── calibration_page.dart
│   │   ├── settings_page.dart
│   │   └── avatar_create_page.dart     # Avatar创建页面
│   └── widgets/
│       ├── camera_preview_widget.dart
│       ├── rive_avatar_widget.dart
│       ├── avatar_preview_widget.dart
│       └── safety_frame_overlay.dart
test/
├── capsule_geometry_test.dart         # 几何计算测试(27个用例)
└── avatar_integration_test.dart       # 集成测试(14个用例)
```

---

## 版本信息

- **版本**: 1.0.0+1
- **Flutter SDK**: ^3.8.0
- **更新日期**: 2026-04-04

### 测试覆盖
- 单元测试: 41个用例全部通过
- 代码分析: 0 errors, 0 warnings (21 info)
- 架构: Clean Architecture 四层分层