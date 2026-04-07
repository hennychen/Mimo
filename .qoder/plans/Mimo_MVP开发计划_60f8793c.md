# Mimo MVP 开发计划

## 一、项目概况

### 1.1 产品定位
**Mimo** 是一款基于 AI 视觉识别的实时 2D 动捕互动工具。用户通过手机摄像头做出肢体动作，Mimo 角色会实时同步模仿。

### 1.2 技术栈
- **开发框架**: Flutter 3.x
- **姿态识别**: mediapipe_flutter (MediaPipe Pose)
- **渲染引擎**: Rive 2.0
- **状态管理**: Riverpod
- **摄像头**: camera 插件
- **平滑算法**: One Euro Filter
- **本地存储**: shared_preferences + sqflite

### 1.3 MVP 成功标准
- iPhone 11 / 小米 11 等中端机型连续运行 30 分钟不降频
- 端到端延迟 ≤ 120ms (P90)
- 校准成功率 ≥ 95%
- 10 名测试者中 8 人认为"反应跟手，不僵硬"

---

## 二、核心功能范围（P0）

| 编号 | 功能模块 | 优先级 | 开发工作量 |
|:---|:---|:---|:---|
| F01 | 摄像头采集 | P0 | 2天 |
| F02 | 姿态识别 | P0 | 3天 |
| F03 | T-Pose校准 | P0 | 2天 |
| F04 | 角度驱动 | P0 | 3天 |
| F05 | 基础平滑滤波 | P0 | 2天 |
| F06 | 置信度处理 | P0 | 1天 |
| F07 | 待机动画 | P0 | 1天 |
| F08 | 安全操作区 | P0 | 1天 |
| F09 | 性能降级 | P0 | 2天 |
| F10 | 基础埋点 | P0 | 1天 |
| F15 | 关节约束系统 | P0(补强) | 2天 |
| F16 | 人体归一化 | P0(补强) | 1天 |

**MVP总工作量估算**: 约 18 工作日（单人开发）

---

## 三、工程目录结构

```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── providers.dart          # Riverpod全局Provider配置
│
├── core/
│   ├── constants/
│   │   ├── app_constants.dart
│   │   └── joint_constants.dart
│   ├── utils/
│   │   ├── math_utils.dart
│   │   └── geometry_utils.dart
│   └── config/
│   │   └── performance_config.dart
│
├── domain/                      # 核心算法层
│   ├── entities/
│   │   ├── landmark.dart
│   │   ├── joint_type.dart
│   │   ├── body_metrics.dart
│   │   ├── gesture_type.dart
│   │   └── frame_result.dart
│   │
│   ├── engines/
│   │   ├── kinematics/
│   │   │   ├── kinematics_engine.dart
│   │   │   ├── joint_constraint.dart
│   │   │   └── joint_state.dart
│   │   │
│   │   ├── normalization/
│   │   │   └── normalization_engine.dart
│   │   │
│   │   ├── filtering/
│   │   │   ├── one_euro_filter.dart
│   │   │   └── motion_filter_engine.dart
│   │   │
│   │   ├── confidence/
│   │   │   └── confidence_processor.dart
│   │   │
│   │   ├── semantic/
│   │   │   └── semantic_engine.dart
│   │   │
│   │   └── performance/
│   │   │   └── performance_scheduler.dart
│   │   │
│   │   └── calibration/
│   │   │   └── calibration_engine.dart
│   │
│   ├── services/
│   │   ├── angle_compute_service.dart
│   │   └── pose_mapping_service.dart
│   │
│   └── repositories/
│   │   ├── pose_repository.dart
│   │   ├── camera_repository.dart
│   │   └── storage_repository.dart
│
├── data/
│   ├── datasources/
│   │   ├── camera_datasource.dart
│   │   ├── mediapipe_datasource.dart
│   │   ├── local_storage_datasource.dart
│   │   └── analytics_datasource.dart
│   │
│   ├── models/
│   │   ├── landmark_model.dart
│   │   └── calibration_model.dart
│   │
│   └── repositories_impl/
│       ├── pose_repository_impl.dart
│       ├── camera_repository_impl.dart
│       └── storage_repository_impl.dart
│
├── application/
│   ├── pipeline/
│   │   └── motion_pipeline.dart
│   │
│   ├── providers/               # Riverpod Providers
│   │   ├── camera_provider.dart
│   │   ├── pose_provider.dart
│   │   ├── session_provider.dart
│   │   └── performance_provider.dart
│   │
│   └── usecases/
│       ├── process_frame_usecase.dart
│       ├── calibrate_usecase.dart
│       └── detect_gesture_usecase.dart
│
├── presentation/
│   ├── pages/
│   │   ├── home_page.dart
│   │   ├── calibration_page.dart
│   │   └── settings_page.dart
│   │
│   ├── widgets/
│   │   ├── camera_preview_widget.dart
│   │   ├── rive_avatar_widget.dart
│   │   ├── safety_frame_overlay.dart
│   │   └── calibration_guide_overlay.dart
│   │
│   └── controllers/
│       └── rive_avatar_controller.dart

assets/
├── rive/
│   └── mimo_character.riv
└── sounds/
    ├── raise_hand.mp3
    └── clap.mp3
```

---

## 四、核心模块技术设计（TDD）

### 4.1 数据结构定义

#### Landmark (关键点)
```dart
class Landmark {
  final double x;        // 0~1 归一化坐标
  final double y;
  final double z;        // 深度信息
  final double visibility;  // 置信度 0~1
  
  Landmark(this.x, this.y, this.z, this.visibility);
}
```

#### JointType (关节类型)
```dart
enum JointType {
  leftShoulder,   // MediaPipe index: 11
  leftElbow,      // MediaPipe index: 13
  leftWrist,      // MediaPipe index: 15
  rightShoulder,  // MediaPipe index: 12
  rightElbow,     // MediaPipe index: 14
  rightWrist,     // MediaPipe index: 16
  nose,           // MediaPipe index: 0
}
```

#### FrameResult (帧处理结果)
```dart
class FrameResult {
  final Map<JointType, double> jointAngles;
  final GestureType? gesture;
  final int timestamp;
  
  FrameResult(this.jointAngles, this.gesture, this.timestamp);
}
```

#### BodyMetrics (人体度量)
```dart
class BodyMetrics {
  final double shoulderWidth;
  final double scaleFactor;
  final double leftArmLength;
  final double rightArmLength;
  
  BodyMetrics({
    required this.shoulderWidth,
    required this.scaleFactor,
    required this.leftArmLength,
    required this.rightArmLength,
  });
}
```

### 4.2 KinematicsEngine (关节约束系统)

**职责**: 限制关节角度范围、防止突变、保证动作符合人体生物力学

```dart
class JointConstraint {
  final double minAngle;        // 最小角度限制
  final double maxAngle;        // 最大角度限制
  final double maxDeltaPerFrame; // 单帧最大变化量
}

class KinematicsEngine {
  final Map<JointType, JointConstraint> constraints;
  final Map<JointType, JointState> states;
  
  Map<JointType, double> apply(Map<JointType, double> rawAngles) {
    // 1. 应用角度限制
    // 2. 限制单帧变化量
    // 3. 更新状态
    // 4. 返回约束后的角度
  }
}
```

**约束参数配置**:
| 关节 | minAngle | maxAngle | maxDeltaPerFrame |
|:---|:---|:---|:---|
| leftShoulder | -180° | 180° | 25° |
| leftElbow | 0° | 150° | 25° |
| rightShoulder | -180° | 180° | 25° |
| rightElbow | 0° | 150° | 25° |

### 4.3 NormalizationEngine (人体归一化)

**职责**: 消除不同体型用户的动作幅度差异

```dart
class NormalizationEngine {
  BodyMetrics? metrics;
  static const double baselineShoulderWidth = 0.35;
  
  void calibrate(Map<JointType, Landmark> joints) {
    // 计算肩宽、臂长、缩放因子
    double shoulderWidth = distance(joints[leftShoulder], joints[rightShoulder]);
    metrics = BodyMetrics(
      shoulderWidth: shoulderWidth,
      scaleFactor: shoulderWidth / baselineShoulderWidth,
      leftArmLength: ...,
      rightArmLength: ...,
    );
  }
  
  Map<JointType, Landmark> normalize(Map<JointType, Landmark> joints) {
    // 根据scaleFactor归一化坐标
  }
}
```

### 4.4 MotionFilterEngine (组合滤波)

**职责**: 消除抖动，保持低延迟

```dart
class MotionFilterEngine {
  final OneEuroFilter oneEuroFilter;
  final double deadZoneThreshold = 0.01;  // 死区阈值
  
  Map<JointType, double> filter(Map<JointType, double> angles) {
    // 1. Dead Zone过滤微小变化
    // 2. One Euro Filter抗抖
    // 3. 速度平滑
  }
}
```

**One Euro Filter参数**:
- minCutoff: 1.0
- beta: 0.007
- dCutoff: 1.0

### 4.5 ConfidenceProcessor (置信度处理)

**职责**: 平滑过渡而非直接冻结

```dart
class ConfidenceProcessor {
  double blend({
    required double trackedAngle,
    required double idleAngle,
    required double confidence,
  }) {
    double weight;
    if (confidence > 0.6) {
      weight = 1.0;  // 完全跟踪
    } else if (confidence > 0.3) {
      weight = (confidence - 0.3) / 0.3;  // 线性过渡
    } else {
      weight = 0.0;  // 向idle姿态插值
    }
    return lerpDouble(idleAngle, trackedAngle, weight)!;
  }
}
```

### 4.6 SemanticEngine (动作语义识别)

**职责**: 识别特定动作触发音效/表情

```dart
enum GestureType {
  handRaise,    // 举手
  armsOpen,     // 双手张开
  wave,         // 挥手
}

class SemanticEngine {
  GestureType? detect(Map<JointType, Landmark> joints) {
    if (_isHandRaised(joints)) return GestureType.handRaise;
    if (_isArmsOpen(joints)) return GestureType.armsOpen;
    if (_isWaving(joints)) return GestureType.wave;
    return null;
  }
}
```

**动作检测规则**:
| 动作 | 检测条件 |
|:---|:---|
| 举手 | wrist.y < shoulder.y (持续3帧) |
| 双手张开 | 双腕距离 > 0.4 (归一化坐标) |
| 挥手 | x方向周期变化(3个周期) |

### 4.7 PerformanceScheduler (性能调度)

**职责**: 主动性能管理而非被动降级

```dart
class PerformanceState {
  final double fps;
  final double latencyMs;
  final double temperature;
}

class PerformanceScheduler {
  void adjust(PerformanceState state) {
    if (state.temperature > 42) {
      _reduceFPS();  // 降至15FPS
    } else if (state.latencyMs > 100) {
      _reduceResolution();  // 降低推理分辨率
    } else if (state.fps > 25 && state.temperature < 38) {
      _increaseQuality();  // 提升质量
    }
  }
}
```

### 4.8 MotionPipeline (核心编排)

**职责**: 串联所有引擎，管理数据流

```dart
class MotionPipeline {
  final PoseRepository poseRepo;
  final NormalizationEngine normalizationEngine;
  final ConfidenceProcessor confidenceProcessor;
  final KinematicsEngine kinematicsEngine;
  final MotionFilterEngine filterEngine;
  final SemanticEngine semanticEngine;
  final PerformanceScheduler scheduler;
  
  FrameResult process(FrameData frame) {
    // 1. 姿态检测
    final joints = poseRepo.detect(frame);
    
    // 2. 归一化
    final normalized = normalizationEngine.normalize(joints);
    
    // 3. 置信度处理
    final processed = confidenceProcessor.process(normalized);
    
    // 4. 角度计算
    final angles = AngleComputeService.compute(processed);
    
    // 5. 关节约束
    final constrained = kinematicsEngine.apply(angles);
    
    // 6. 滤波
    final filtered = filterEngine.filter(constrained);
    
    // 7. 动作语义识别
    final gesture = semanticEngine.detect(joints);
    
    // 8. 性能调度
    scheduler.adjust(_collectPerformanceState());
    
    return FrameResult(filtered, gesture, frame.timestamp);
  }
}
```

---

## 五、WBS 任务拆解

### Phase 1: 环境搭建与基础架构 (Week 1)

| 任务ID | 任务名称 | 工时 | 产出 |
|:---|:---|:---|:---|
| T1.1 | Flutter项目初始化 | 0.5天 | 空项目骨架 |
| T1.2 | 添加依赖(pubspec.yaml) | 0.5天 | camera, rive, riverpod, mediapipe_flutter, shared_preferences, sqflite |
| T1.3 | 创建工程目录结构 | 0.5天 | lib/目录结构 |
| T1.4 | 定义核心数据结构 | 1天 | Landmark, JointType, FrameResult, BodyMetrics |
| T1.5 | Rive角色资源准备 | 1天 | mimo_character.riv文件，骨骼命名规范 |
| T1.6 | Camera预览Widget | 1天 | camera_preview_widget.dart |
| T1.7 | Rive渲染Widget | 0.5天 | rive_avatar_widget.dart |

### Phase 2: 姿态识别集成 (Week 2)

| 任务ID | 任务名称 | 工时 | 产出 |
|:---|:---|:---|:---|
| T2.1 | MediaPipe DataSource | 1天 | mediapipe_datasource.dart |
| T2.2 | PoseRepository实现 | 1天 | pose_repository_impl.dart |
| T2.3 | Riverpod Provider配置 | 1天 | pose_provider.dart |
| T2.4 | 关键点索引映射 | 0.5天 | pose_mapping_service.dart |
| T2.5 | 姿态检测调试日志 | 0.5天 | 控制台输出肩肘坐标 |
| T2.6 | 线程模型实现(Isolate) | 1天 | compute()调用封装 |

### Phase 3: 角度计算与驱动 (Week 3)

| 任务ID | 任务名称 | 工时 | 产出 |
|:---|:---|:---|:---|
| T3.1 | AngleComputeService | 1天 | atan2角度计算实现 |
| T3.2 | Rive骨骼驱动接口 | 1天 | rive_avatar_controller.dart |
| T3.3 | 简单角度驱动测试 | 1天 | 抬手→角色手臂抬起 |
| T3.4 | MotionPipeline骨架 | 1天 | motion_pipeline.dart空实现 |
| T3.5 | 数据流串联 | 0.5天 | pose→angle→rive链路 |
| T3.6 | 首次端到端测试 | 0.5天 | 基础驱动验证 |

### Phase 4: 稳定化处理 (Week 4)

| 任务ID | 任务名称 | 工时 | 产出 |
|:---|:---|:---|:---|
| T4.1 | One Euro Filter实现 | 1天 | one_euro_filter.dart |
| T4.2 | MotionFilterEngine | 1天 | motion_filter_engine.dart |
| T4.3 | ConfidenceProcessor | 0.5天 | confidence_processor.dart |
| T4.4 | KinematicsEngine | 1.5天 | kinematics_engine.dart, joint_constraint.dart |
| T4.5 | NormalizationEngine | 1天 | normalization_engine.dart |
| T4.6 | T-Pose校准流程 | 1天 | calibration_engine.dart, calibration_page.dart |
| T4.7 | 校准可视化引导 | 0.5天 | calibration_guide_overlay.dart |

### Phase 5: 体验优化 (Week 5)

| 任务ID | 任务名称 | 工时 | 产出 |
|:---|:---|:---|:---|
| T5.1 | SafetyFrameOverlay | 0.5天 | 安全操作区UI |
| T5.2 | 待机动画触发 | 0.5天 | idle状态机控制 |
| T5.3 | SemanticEngine | 1天 | semantic_engine.dart |
| T5.4 | 音效资源+触发 | 0.5天 | sounds/资源, 音效播放 |
| T5.5 | PerformanceScheduler | 1天 | performance_scheduler.dart |
| T5.6 | 性能降级策略 | 0.5天 | FPS控制, 分辨率调整 |
| T5.7 | 温度监测集成 | 0.5天 | 设备温度获取 |
| T5.8 | Pipeline完整串联 | 1天 | MotionPipeline完整实现 |
| T5.9 | 埋点系统 | 0.5天 | analytics_datasource.dart |

### Phase 6: 测试与发布准备 (Week 6)

| 任务ID | 任务名称 | 工时 | 产出 |
|:---|:---|:---|:---|
| T6.1 | 性能测试(iOS) | 1天 | 延迟、FPS、温度测试 |
| T6.2 | 性能测试(Android) | 1天 | 中端机兼容性测试 |
| T6.3 | Bug修复 | 1天 | 稳定性问题修复 |
| T6.4 | 体验优化调参 | 0.5天 | 滤波参数、约束参数调优 |
| T6.5 | 内部测试(5人) | 1天 | 用户测试反馈收集 |
| T6.6 | 文档整理 | 0.5天 | 使用说明、开发日志 |
| T6.7 | 发布包构建 | 0.5天 | iOS/Android安装包 |

---

## 六、开发里程碑

| 阶段 | 时间节点 | 产出目标 | 验收标准 |
|:---|:---|:---|:---|
| Milestone 1 | Week 1结束 | 可运行空应用 | 显示Rive角色+Camera预览 |
| Milestone 2 | Week 2结束 | 姿态检测集成 | 控制台输出肩肘坐标 |
| Milestone 3 | Week 3结束 | 基础驱动 | 抬手→角色手臂抬起(无滤波) |
| Milestone 4 | Week 4结束 | 稳定化处理 | 动作平滑，校准流程完整 |
| Milestone 5 | Week 5结束 | 体验优化 | 中低端机稳定20FPS，音效触发 |
| Milestone 6 | Week 6结束 | MVP发布 | 可发布内测版 |

---

## 七、关键技术决策

### 7.1 线程模型
```
Main Thread (UI)          Isolate Thread
├── Rive渲染              ├── Pose推理
├── UI更新                ├── Motion Pipeline
└── 用户交互              └── 角度计算
```
使用 `compute()` 函数将pipeline放入Isolate执行。

### 7.2 Rive骨骼命名规范（强制）
```
upper_arm_L    # 左大臂
lower_arm_L    # 左小臂
upper_arm_R    # 右大臂
lower_arm_R    # 右小臂
head           # 头部
```

### 7.3 MediaPipe关键点索引映射
```json
{
  "left_shoulder": 11,
  "left_elbow": 13,
  "left_wrist": 15,
  "right_shoulder": 12,
  "right_elbow": 14,
  "right_wrist": 16,
  "nose": 0
}
```

---

## 八、风险与应对

| 风险 | 应对措施 |
|:---|:---|
| MediaPipe延迟>120ms | 采用推理降采样+插值，目标放宽至150ms |
| 自遮挡导致手臂乱晃 | 置信度滤波+角度变化限制(单帧<30°) |
| 校准失败率高 | 动画引导+自动检测+跳过校准默认参数 |
| 动作过于僵硬 | OneEuro参数调优+关节约束放松 |

---

## 九、下一步行动

确认计划后，我将按以下顺序开始开发：
1. 创建Flutter项目骨架
2. 定义核心数据结构
3. 实现Camera预览和Rive渲染
4. 逐步集成各模块引擎