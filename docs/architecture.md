# Mimo 架构设计文档

## 整体架构

Mimo 采用 **Clean Architecture** 分层设计，确保业务逻辑与UI解耦，便于测试和维护。

```
┌──────────────────────────────────────────────────────────────────┐
│                         Presentation                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐               │
│  │   Pages     │  │   Widgets   │  │   Providers │               │
│  │  (UI层)     │  │  (组件层)   │  │  (状态管理) │               │
│  └─────────────┘  └─────────────┘  └─────────────┘               │
├──────────────────────────────────────────────────────────────────┤
│                         Application                               │
│  ┌─────────────────────┐  ┌─────────────────────────┐           │
│  │   MotionPipeline    │  │  FrameProcessingService │           │
│  │   (处理管道编排)     │  │    (帧处理服务)         │           │
│  └─────────────────────┘  └─────────────────────────┘           │
├──────────────────────────────────────────────────────────────────┤
│                           Domain                                  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │ Entities │ │ Engines  │ │ Services │ │Repository│            │
│  │ (实体)   │ │ (引擎)   │ │ (服务)   │ │Interfaces│            │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘            │
├──────────────────────────────────────────────────────────────────┤
│                            Data                                   │
│  ┌─────────────────────┐  ┌─────────────────────┐               │
│  │ PoseRepositoryImpl  │  │ CameraRepositoryImpl│               │
│  │  (MediaPipe集成)    │  │   (摄像头管理)      │               │
│  └─────────────────────┘  └─────────────────────┘               │
└──────────────────────────────────────────────────────────────────┘
```

---

## 核心引擎设计

### 1. 运动处理管道 (MotionPipeline)

**职责**: 编排所有引擎，串联姿态数据处理流程

```dart
class MotionPipeline {
  final PoseRepository poseRepository;
  final ConfidenceProcessor confidenceProcessor;
  final NormalizationEngine normalizationEngine;
  final KinematicsEngine kinematicsEngine;
  final MotionFilterEngine filterEngine;
  final SemanticEngine semanticEngine;
  final PerformanceScheduler performanceScheduler;
  final AngleComputeService angleComputeService;
  
  FrameResult process({timestamp, image, width, height});
  void reset();
}
```

**处理流程**:
```
图像输入
    ↓
[PoseRepository] 姿态检测 → 33个关键点
    ↓
[ConfidenceProcessor] 置信度计算 → 平均置信度
    ↓
[NormalizationEngine] 人体归一化 → 相对坐标
    ↓
[AngleComputeService] 角度计算 → 关节角度
    ↓
[KinematicsEngine] 关节约束 → 限制角度范围
    ↓
[MotionFilterEngine] 滤波处理 → One Euro Filter
    ↓
[ConfidenceProcessor] 置信度混合 → idle插值
    ↓
[SemanticEngine] 语义识别 → 手势类型
    ↓
[PerformanceScheduler] 性能调度 → FPS监控
    ↓
FrameResult 输出
```

---

### 2. One Euro Filter (运动滤波)

**职责**: 平滑运动数据，减少抖动同时保持低延迟

```dart
class OneEuroFilter {
  // 参数
  final double minCutoff;   // 最小截止频率 (默认: 1.0)
  final double beta;        // 速度系数 (默认: 0.007)
  final double dCutoff;     // 导数截止频率 (默认: 1.0)
  
  double filter(double value, int timestamp);
}
```

**原理**: 
- 速度越快，截止频率越高，响应越灵敏
- 速度慢时，截止频率低，更平滑
- 适用于实时动捕场景

---

### 3. 置信度处理器 (ConfidenceProcessor)

**职责**: 处理关键点置信度，平滑低置信度区域

```dart
class ConfidenceProcessor {
  // 计算平均置信度
  static double averageConfidence(List<double> confidences);
  
  // 置信度混合（trackedAngle与idleAngle插值）
  double blend({
    required double trackedAngle,
    required double idleAngle,
    required double confidence,
  });
}
```

**混合公式**:
```
blendedAngle = trackedAngle * confidence + idleAngle * (1 - confidence)
```

---

### 4. 关节约束引擎 (KinematicsEngine)

**职责**: 应用关节生理约束，防止不合理角度

```dart
class KinematicsEngine {
  // 关节约束配置
  final Map<JointType, JointConstraint> constraints;
  
  Map<JointType, double> apply(Map<JointType, double> angles);
  void reset();
}

class JointConstraint {
  final double minAngle;  // 最小角度
  final double maxAngle;  // 最大角度
  final double stiffness; // 约束刚度
}
```

**约束范围示例**:
| 关节 | 最小角度 | 最大角度 |
|:---|:---:|:---:|
| 肩部 | -180° | 180° |
| 肘部 | 0° | 150° |
| 踝部 | -45° | 45° |

---

### 5. 人体归一化引擎 (NormalizationEngine)

**职责**: 将关键点坐标转换为相对坐标系

```dart
class NormalizationEngine {
  // 归一化到以肩宽为基准的坐标系
  Map<JointType, Landmark> normalize(Map<JointType, Landmark> joints);
}
```

**归一化步骤**:
1. 计算肩宽（两肩距离）
2. 以脊柱中点为原点
3. 所有坐标除以肩宽

---

### 6. 校准引擎 (CalibrationEngine)

**职责**: T-Pose校准，记录用户身体比例

```dart
class CalibrationEngine {
  CalibrationResult calibrate(Map<JointType, Landmark> tPoseJoints);
  bool validate(Map<JointType, Landmark> joints);
}

class CalibrationResult {
  final double shoulderWidth;
  final double armLength;
  final double torsoLength;
  final double legLength;
}
```

---

### 7. 语义引擎 (SemanticEngine)

**职责**: 识别动作语义，检测手势

```dart
class SemanticEngine {
  GestureType detect(Map<JointType, Landmark> joints);
  void reset();
}
```

**支持手势**:
| 手势 | 识别条件 |
|:---|:---|
| T-Pose | 双臂侧平举，与身体成90° |
| 举手 | 任一手高于头顶 |
| 挥手 | 手部快速左右移动 |
| 耸肩 | 肩部明显上下移动 |

---

### 8. 性能调度器 (PerformanceScheduler)

**职责**: 根据性能动态调整处理策略

```dart
class PerformanceScheduler {
  void update({required double fps, required double latencyMs});
  PerformanceStrategy getStrategy();
}

enum PerformanceStrategy {
  normal,      // 正常处理
  reduced,     // 降低帧率
  minimal,     // 最小处理
}
```

---

## 服务层设计

### 1. 角度计算服务 (AngleComputeService)

```dart
class AngleComputeService {
  // 计算各关节角度
  Map<JointType, double> compute(Map<JointType, Landmark> joints);
  void reset();
}
```

**计算方式**: 使用向量夹角公式
```
angle = atan2(cross(a,b), dot(a,b))
```

---

### 2. Rive骨骼控制器 (RiveBoneController)

```dart
class RiveBoneController {
  // 驱动Rive骨骼
  void drive(Map<JointType, double> angles);
  void setIdle();
  void reset();
}
```

---

### 3. 音效服务 (SoundService)

```dart
class SoundService {
  Future<void> initialize();
  Future<void> playGestureSound(GestureType gesture);
  void setVolume(double volume);
  void setMuted(bool muted);
  void dispose();
}
```

---

### 4. 角色状态机 (AvatarStateMachine)

```dart
enum AvatarState {
  idle,          // 待机
  calibrating,   // 校准中
  tracking,      // 追踪
  lowConfidence, // 低置信度
  paused,        // 暂停
}

class AvatarStateMachine {
  AvatarState processFrame({
    required bool hasPose,
    required double confidence,
    required bool isPaused,
    required bool isCalibrating,
  });
}
```

---

### 5. 性能监控 (PerformanceMonitor)

```dart
class PerformanceMonitor {
  void startMonitoring();
  void recordFrame(int processingTimeMs);
  void recordFps(double fps);
  PerformanceState get currentState;
  DegradationSuggestion getDegradationSuggestion();
}
```

---

### 6. 埋点服务 (AnalyticsService)

```dart
class AnalyticsService {
  Future<void> initialize();
  Future<void> logEvent(AnalyticsEventType type, {properties});
  Future<void> logAppLaunch();
  Future<void> logCalibrationResult(bool success);
  Future<void> logGestureDetected(String gesture);
  Future<void> endSession();
}
```

---

## 数据层设计

### 1. 姿态仓库实现 (PoseRepositoryImpl)

```dart
class PoseRepositoryImpl implements PoseRepository {
  final PoseDetector _poseDetector;
  
  Map<JointType, Landmark> detect(dynamic image, int width, int height);
}
```

**关键转换**: CameraImage → InputImage
- NV21格式：直接使用平面数据
- YUV420格式：组合Y/U/V平面
- BGRA8888格式：iOS默认格式

---

### 2. 摄像头仓库实现 (CameraRepositoryImpl)

```dart
class CameraRepositoryImpl implements CameraRepository {
  List<CameraDescription> getAvailableCameras();
  Future<void> initialize(CameraDescription camera);
  Stream<CameraImage> getImageStream();
  Future<void> switchCamera();
  Future<void> dispose();
}
```

---

## 状态管理 (Riverpod)

```dart
// 核心Providers
final cameraRepositoryProvider = Provider<CameraRepository>();
final poseRepositoryProvider = Provider<PoseRepository>();
final motionPipelineProvider = Provider<MotionPipeline>();

// 状态Providers
final isCalibratingProvider = StateProvider<bool>();
final isTrackingProvider = StateProvider<bool>();
final currentFpsProvider = StateProvider<double>();
final avatarStateProvider = StateProvider<AvatarState>();

// 服务Providers
final soundServiceProvider = Provider<SoundService>();
final performanceMonitorProvider = Provider<PerformanceMonitor>();
final analyticsServiceProvider = Provider<AnalyticsService>();
```

---

## UI层设计

### 主页面 (HomePage)

```
┌────────────────────────────────────┐
│  ┌─────────────┬──────────────┐   │
│  │  摄像头预览 │   Rive角色   │   │
│  │             │              │   │
│  │  [安全框]   │   [动画]     │   │
│  └─────────────┴──────────────┘   │
│                                   │
│  ┌────────────────────────────┐   │
│  │   FPS: 28  |  置信度: 92% │   │
│  └────────────────────────────┘   │
│                                   │
│  ┌──────┬──────┬──────┬──────┐   │
│  │ 暂停 │ 切换 │ 静音 │ 校准 │   │
│  └──────┴──────┴──────┴──────┘   │
└────────────────────────────────────┘
```

---

## 扩展指南

### 添加新手势

1. 在 `gesture_type.dart` 添加枚举值
2. 在 `semantic_engine.dart` 添加检测逻辑
3. 在 `sound_service.dart` 添加音效映射

### 添加新引擎

1. 创建 `lib/domain/engines/xxx/xxx_engine.dart`
2. 在 `MotionPipeline` 中集成
3. 在 `providers.dart` 添加Provider

### 自定义Rive角色

1. 创建Rive文件，骨骼命名遵循约定
2. 放入 `assets/rive/mimo_character.riv`
3. 更新 `rive_bone_controller.dart` 骨骼映射