# Mimo（米莫）项目需求文档（正式版 v1.0）

> 本文档整合了前期所有产品定义、技术方案、风险分析及扩展建议，形成可直接指导开发团队进行 MVP 迭代的完整需求基线。

---

## 1. 产品概述

### 1.1 产品定位
**Mimo** 是一款基于 AI 视觉识别的实时 2D 动捕互动工具。用户通过手机摄像头做出肢体动作，Mimo 角色会实时同步模仿，带来“人动，图动”的趣味交互体验。

### 1.2 目标用户
- **儿童及家庭用户**（5～12 岁儿童及其家长）：娱乐、模仿游戏。
- **短视频创作者**：生成趣味动捕视频用于社交分享。
- **康复/教育轻度使用者**：肩颈活动、体感教学。

### 1.3 核心价值
- **零门槛**：仅需手机摄像头，无需穿戴设备。
- **实时反馈**：动作同步延迟 < 120ms。
- **角色生动**：卡通角色自带情感化反应。
- **隐私安全**：所有计算本地完成，不上传视频数据。

### 1.4 MVP 成功标准
- 在 iPhone 11 / 小米 11 等中端机型上，连续运行 30 分钟不降频。
- 端到端延迟 ≤ 120ms（P90）。
- 10 名内部测试者中 8 人认为“反应跟手，不僵硬”。
- 单次交互平均时长 ≥ 90 秒。
- 校准成功率 ≥ 95%（正常光照条件下）。

---

## 2. 功能需求

### 2.1 MVP 必须实现（P0）

| 编号 | 功能模块 | 详细描述 | 验收标准 |
| :--- | :--- | :--- | :--- |
| **F01** | 摄像头采集 | 实时预览摄像头画面（前置摄像头），支持 16:9 / 4:3 自适应。 | 画面流畅，无卡顿，可切换前后摄像头（可选）。 |
| **F02** | 姿态识别 | 基于 MediaPipe 识别上半身 33 个关键点（重点关注肩、肘、腕、躯干）。 | 在正常光照下，关键点识别成功率 > 90%。 |
| **F03** | T-Pose 校准 | 引导用户站成 T-Pose，系统自动采集基准角度和肩宽。 | 提供可视化人形引导，校准过程 < 5 秒，失败时自动重试。 |
| **F04** | 角度驱动 | 将关键点转化为关节旋转角，驱动 Rive 角色骨骼（左/右大臂、小臂、头部）。 | 角色动作与真人动作方向一致，无反向弯曲。 |
| **F05** | 基础平滑 | 采用 One Euro Filter 对角度进行滤波，消除高频抖动。 | 静止时角色手臂无明显抖动。 |
| **F06** | 置信度处理 | 关键点置信度 < 0.5 时，冻结对应关节；连续 10 帧丢失则进入待机动画。 | 手部移出画面时角色手臂不会抽搐。 |
| **F07** | 待机动画 | 当无动作或关键点丢失时，角色播放预设 idle 动画（眨眼、轻微晃动）。 | idle 动画循环流畅，恢复动作时立即退出。 |
| **F08** | 安全操作区 | 预览画面中显示半透明矩形框，用户需将上半身置于框内。移出时暂停驱动并提示。 | 出框后动作映射停止，回到框内自动恢复。 |
| **F09** | 性能降级 | 设备发热 > 45°C 时自动降低推理频率至 15 FPS；空闲 30 秒降至 5 FPS；空闲 2 分钟释放摄像头。 | 长时间运行不烫手，应用不崩溃。 |
| **F10** | 基础埋点 | 记录 session_start/end、calibration_success、overheat_warning 等事件。 | 埋点数据可导出至分析平台。 |

### 2.2 MVP 强烈建议实现（P1）

| 编号 | 功能 | 说明 |
| :--- | :--- | :--- |
| **F11** | 动作回放分享 | 录制 10 秒动捕过程，生成 GIF 或 MP4，可保存本地或分享到社交 App。 |
| **F12** | 简单音效反馈 | 特定动作（如举手、拍手）触发“咻”、“鼓掌”等音效。 |
| **F13** | 角色表情同步 | 利用 MediaPipe Face Landmarks 检测张嘴、眨眼，同步驱动角色面部。 |
| **F14** | 校准失败自动重试 | 检测到 T-Pose 不合格（夹角 < 60°）时，重置倒计时并语音提示。 |

### 2.3 后续版本规划（v1.1 ~ v2.0）

| 功能 | 优先级 | 预计版本 |
| :--- | :--- | :--- |
| 自定义角色映射（AI 自动 + 手动） | 高 | v1.1 |
| 角色商城（付费/免费角色、道具） | 高 | v1.2 |
| 动作模因挑战赛（社交互动） | 中 | v1.3 |
| 音量驱动缩放（喊叫变大） | 低 | v1.4 |
| 多人派对模式（蓝牙联机） | 中 | v2.0 |
| 开发者 API（WebSocket 控制） | 低 | v2.0 |

> **关于自定义角色映射**：经过可行性分析，该功能开发工作量约为 8~12 人天，且对普通用户理解门槛较高。**不纳入 MVP**，但在 v1.1 中作为核心卖点推出。

---

## 3. 非功能需求

### 3.1 性能指标

| 指标 | 目标值 | 测量方式 |
| :--- | :--- | :--- |
| 端到端延迟 | ≤ 120ms (P90) | 高速摄像或代码埋点 |
| 推理帧率 | 20~30 FPS（可降级至 15） | 日志统计 |
| 渲染帧率 | 60 FPS（插值） | Flutter 性能面板 |
| CPU 占用 | ≤ 40%（中端机） | Android Profiler |
| 内存占用 | ≤ 300MB（运行 30 分钟后） | 内存监测 |
| 电池消耗 | ≤ 20% / 小时（4000mAh） | 真实设备实测 |

### 3.2 鲁棒性要求

- **关键点丢失**：单点丢失时保持上一帧角度，多点丢失时进入 idle 状态。
- **自遮挡**：手臂与躯干重叠时，优先信任肘部角度，避免突变。
- **弱光环境**：提示用户增加光线，识别率下降时不崩溃。
- **多人场景**：只追踪距离画面中心最近的人体骨架。

### 3.3 兼容性

- **操作系统**：iOS 12+，Android 8+（要求支持 Camera2 API）。
- **设备**：至少 2GB RAM，主频 ≥ 1.8GHz。
- **分辨率**：支持 640x480 到 1920x1080 自动降采样。

### 3.4 隐私与安全

- 所有摄像头数据**仅在本地处理**，绝不传输到任何服务器。
- 首次启动必须弹出隐私说明，用户同意后方可启用摄像头。
- 应用退到后台时立即释放摄像头资源。
- 不得在用户未授权情况下访问相册、麦克风等其他权限。

### 3.5 可维护性

- 姿态识别模块设计为可插拔（便于后续替换模型）。
- 关键点索引使用配置文件，支持远程热更新（仅更新索引映射）。
- 埋点日志以 JSON 格式存储，可定期清理。

---

## 4. 技术架构

### 4.1 技术栈

| 层级 | 技术选型 | 说明 |
| :--- | :--- | :--- |
| 开发框架 | Flutter 3.x | 跨平台，Rive 运行时支持好 |
| 姿态识别 | `google_ml_kit` 或 `mediapipe_flutter` | MediaPipe Pose 任务 |
| 渲染引擎 | Rive 2.0 (`.riv`) | 矢量动画，性能优异 |
| 摄像头 | `camera` 插件 | 支持预览、分辨率调节 |
| 平滑算法 | One Euro Filter | 低延迟抗抖动 |
| 本地存储 | `shared_preferences` + 文件 | 校准参数、用户配置 |
| 埋点 | 自建 + `sqflite` 缓存 | 批量上报或导出 |

### 4.2 逻辑架构图

```text
[摄像头采集] 
    ↓
[MediaPipe 推理] (20~30 FPS)
    ↓
[置信度滤波] → 丢失处理
    ↓
[坐标系转换 & 角度计算] (基于 T-Pose 校准偏移)
    ↓
[One Euro 平滑滤波]
    ↓
[Rive 渲染引擎] (60 FPS 插值)
    ↓
[UI 叠加层] (安全框、提示语)
```

### 4.3 数据流设计

- **每帧推理数据**：33 个关键点 (x, y, visibility) + 时间戳。
- **角度计算**：`atan2(dy, dx)` 后减去初始偏移，限制范围。
- **映射表**（硬编码，v1.0）：
  ```json
  {
    "left_shoulder": 11, "left_elbow": 13, "left_wrist": 15,
    "right_shoulder": 12, "right_elbow": 14, "right_wrist": 16,
    "nose": 0
  }
  ```
- **待机动画触发**：当所有上肢关键点平均置信度 < 0.4 且持续 0.5 秒，发送 `idle` 信号到 Rive 状态机。

### 4.4 关键算法伪代码

```dart
// 角度驱动流程
double computeJointAngle(Landmark a, Landmark b, double offsetAngle) {
  double raw = atan2(b.y - a.y, b.x - a.x);
  double calibrated = raw - offsetAngle;
  return clamp(calibrated, -PI, PI);
}

// 置信度滤波
double filteredAngle = confidence > 0.6 ? newAngle : 
                      (confidence > 0.3 ? lerp(lastAngle, newAngle, 0.3) : lastAngle);
```

---

## 5. 数据设计（埋点）

### 5.1 事件定义

| 事件名 | 触发时机 | 字段 |
| :--- | :--- | :--- |
| `app_start` | 应用冷启动 | `timestamp`, `device_model`, `os_version` |
| `camera_granted` | 用户授权摄像头 | `result` (success/denied) |
| `calibration_start` | 开始校准 | - |
| `calibration_success` | 校准成功 | `duration_ms`, `shoulder_width` |
| `calibration_fail` | 校准失败 | `reason` (timeout/bad_pose) |
| `pose_track_start` | 首次成功驱动角色 | `inference_fps`, `latency_ms` |
| `jitter_event` | 角度突变 > 60° 且置信度 > 0.7 | `joint`, `delta_angle` |
| `overheat_warning` | 温度 > 45°C | `temperature`, `uptime_sec` |
| `session_end` | 应用退后台/关闭 | `duration_sec`, `total_frames` |

### 5.2 本地存储结构

```json
{
  "calibration_data": {
    "left_shoulder_angle": 0.12,
    "right_shoulder_angle": -0.08,
    "shoulder_width": 0.35,
    "timestamp": 1690000000
  },
  "user_settings": {
    "sound_enabled": true,
    "preferred_camera": "front",
    "performance_profile": "auto"
  }
}
```

---

## 6. UI/UX 设计要点

### 6.1 主界面布局
- **顶部**：角色名称、设置按钮、电量/温度提示。
- **中央**：Rive 角色动画区域（占屏幕 60%）。
- **底部**：摄像头预览窗口（占 30%），叠加半透明安全框。
- **悬浮**：校准提示、动作反馈气泡。

### 6.2 校准引导流程
1. 首次启动自动进入校准界面。
2. 显示半透明人形轮廓 + “请站成 T-Pose” 文字 + 倒计时动画。
3. 检测到双臂与躯干夹角 > 60° 且持续 1 秒 → 自动完成。
4. 成功 → 震动 + 绿色对勾 → 进入主界面。
5. 失败（30 秒未成功）→ 提示“请面对光线充足的地方”并重试。

### 6.3 异常提示（非模态）
- 移出安全区：“请回到框内” + 边框变红。
- 光线不足：“环境太暗，效果可能不佳”。
- 多人入镜：“请确保只有你一人在画面中”。

---

## 7. 开发里程碑（6 周 MVP 计划）

| 阶段 | 时长 | 任务 | 产出 |
| :--- | :--- | :--- | :--- |
| **第 1 周** | 5 天 | 环境搭建，Rive 集成，基础 Camera 预览 | 可显示角色、预览摄像头的空应用 |
| **第 2 周** | 5 天 | 集成 MediaPipe，打印关键点坐标 | 实时输出肩、肘坐标到控制台 |
| **第 3 周** | 5 天 | 实现角度计算与 Rive 驱动（硬编码映射） | 抬起左手 → 角色左臂抬起（无滤波） |
| **第 4 周** | 5 天 | 增加 T-Pose 校准、One Euro 滤波、置信度处理 | 动作平滑，校准流程完整 |
| **第 5 周** | 5 天 | 性能优化（降采样、热管理）、安全区、待机动画 | 中低端机稳定 20 FPS |
| **第 6 周** | 5 天 | 埋点、分享功能、音效、内部测试与 bug 修复 | 可发布的 MVP 内测版 |

---

## 8. 风险与应对措施

| 风险 | 概率 | 影响 | 缓解措施 |
| :--- | :--- | :--- | :--- |
| MediaPipe 延迟 > 120ms | 中 | 高 | 提前低端机实测，采用推理降采样+插值，目标放宽至 150ms 也可接受。 |
| 自遮挡导致手臂乱晃 | 高 | 中 | 增加置信度滤波 + 角度变化限制（单帧变化 < 30°）。 |
| 校准失败率过高 | 中 | 高 | 设计动画引导 + 自动检测成功，提供跳过校准使用默认参数。 |
| iOS 内存泄漏 | 低 | 中 | 每周 profile 测试，使用 `leak_tracker`。 |
| 儿童隐私合规 | 中 | 高 | 明确不收集任何个人信息，不上传数据，加入家长控制说明。 |
| 角色驱动过于僵硬 | 中 | 中 | 增加 Rive 状态机中的 secondary motion（如衣服飘动）。 |

---

## 9. 验收标准（MVP 通过条件）

### 9.1 功能完整性
- [ ] 所有 P0 功能均实现且通过测试。
- [ ] 校准成功率 ≥ 95%（20 次测试，不同光照、不同用户）。
- [ ] 连续运行 30 分钟无崩溃、无 ANR。

### 9.2 性能指标
- [ ] 端到端延迟 ≤ 120ms（P90，iPhone 11 测试）。
- [ ] 低端机（红米 9A）推理帧率 ≥ 15 FPS，无明显卡顿。
- [ ] 运行 30 分钟后，温度上升 ≤ 15°C（从室温 25°C 起）。

### 9.3 用户体验
- [ ] 5 名外部测试者（非技术）能够无需指导完成校准并正常互动。
- [ ] 80% 测试者认为“角色反应自然，不感到延迟”。

---

## 10. 附录

### 10.1 参考资料
- MediaPipe Pose Landmarks: [Google Docs](https://developers.google.com/mediapipe/solutions/vision/pose_landmarker)
- One Euro Filter 论文: [Link](https://cristal.univ-lille.fr/~casiez/1euro/)
- Rive Flutter 运行时: [pub.dev](https://pub.dev/packages/rive)

### 10.2 术语表
| 术语 | 解释 |
| :--- | :--- |
| T-Pose | 双臂侧平举的标准站姿，用于校准初始角度。 |
| 关键点丢失 | MediaPipe 输出的 visibility 低于阈值。 |
| 端到端延迟 | 从真实动作发生到角色动作渲染完成的耗时。 |
| 降采样 | 降低 AI 推理的帧率以减少计算负载。 |

### 10.3 文档版本
- v1.0 (2025-04-03): 初始正式版，用于开发启动。

---

整体来看，这份 PRD 已经达到了**可以直接驱动 MVP 开发**的成熟度，结构清晰、指标明确、技术路径可落地，属于**“中高级产品+技术融合文档”**水平。

但如果目标是：
👉 **降低实现风险 + 提升真实用户体验 + 为后续扩展留好接口**
那么仍然有一些**关键隐患和可优化点**需要补充或修正。

我按“严重性 + 影响开发/体验程度”给你做一个**系统性审查**👇

---

# 一、核心结论（先说重点）

这份方案目前的问题不是“缺”，而是：

> ⚠️ **对“真实世界复杂性”低估了一点，对“稳定性工程”描述还不够深入**

具体集中在 4 个方面：

1. **动作驱动模型过于理想化（容易抖、飘、假）**
2. **校准机制不够鲁棒（不同体型/姿态差异）**
3. **缺少“动作语义层”（导致体验单薄）**
4. **性能控制策略偏被动（容易卡顿或发热突发）**

---

# 二、逐模块问题分析 + 修改建议

---

## 1️⃣ 姿态识别 → 角度驱动（核心问题）

### ❗问题 1：直接用 atan2 做角度驱动 → 会出现“机械感 + 抖动”

当前方案：

```dart
atan2(b.y - a.y, b.x - a.x)
```

👉 问题：

* 对噪声非常敏感（尤其 wrist）
* 无法表达“人体运动惯性”
* 左右翻转、镜像容易出错
* 手臂会“抖 + 折 + 突跳”

---

### ✅ 建议：增加一层“运动学抽象层”（非常关键）

在角度计算之后，加一层：

```text
原始角度
   ↓
生物力学约束（限幅 + 关节合理区间）
   ↓
速度限制（Δ角度/帧）
   ↓
惯性模拟（低通 + 延迟补偿）
   ↓
输出角度
```

---

### ✅ 建议新增模块（P0 → 必须补）

**F15：关节运动约束系统**

| 功能     | 描述            |
| ------ | ------------- |
| 角度限制   | 肘关节只能 0°~150° |
| 单帧变化限制 | Δ角 ≤ 25°      |
| 速度平滑   | 避免突然加速        |
| 左右对称校验 | 防止反向弯曲        |

👉 否则你会看到：

> “手臂像橡皮筋一样乱甩” ❌

---

## 2️⃣ T-Pose 校准（隐含高风险）

### ❗问题 2：只校准“角度偏移”是不够的

当前：

* 只记录 shoulder angle / width

👉 实际问题：

不同用户：

* 手臂长度不同
* 肩宽比例不同
* 摄像头距离不同

👉 会导致：

* 同样动作 → 角色幅度不一致
* 小孩 vs 成人 → 完全不同体验

---

### ✅ 建议：升级为“归一化人体模型”

增加：

```text
scale_factor = shoulder_width / 标准模型宽度
```

并用于：

* 手臂长度缩放
* 动作幅度归一化

---

### ✅ 建议新增：

**F16：人体尺度归一化（必须）**

否则：

> 同一个动作，有人举手 30°，有人 80° ❌

---

## 3️⃣ 置信度处理（当前策略不够自然）

### ❗问题 3：直接 freeze 会“卡住感明显”

当前：

```text
confidence < 0.5 → freeze
```

👉 用户体验：

* 手一离开 → 突然停住
* 回来 → 突然跳变

---

### ✅ 建议：改为“渐隐控制”（重要）

```text
低置信度 →
  → 权重逐渐降低
  → 向 idle pose 插值
```

---

### ✅ 新策略：

```dart
angle = lerp(idleAngle, trackedAngle, confidence)
```

👉 效果：

* 更自然
* 不突兀

---

## 4️⃣ 平滑算法（One Euro 不够）

### ❗问题 4：One Euro Filter 单独使用不够

问题：

* 快速动作 → 延迟
* 慢动作 → 抖动

---

### ✅ 建议：组合滤波（关键优化）

```text
One Euro（抗抖）
+ Velocity Filter（速度平滑）
+ Dead Zone（微小变化忽略）
```

---

### ✅ 增加：

**F17：动态滤波参数调节**

```text
低速 → 强滤波
高速 → 弱滤波
```

👉 这会极大提升“跟手感”

---

## 5️⃣ 动作语义层（体验差异关键）

### ❗问题 5：当前完全是“骨骼驱动”，缺少“动作理解”

👉 结果：

* 好玩，但很快无聊
* 没有反馈

---

### ✅ 建议（P1，但非常重要）：

增加“动作识别层”

例如：

| 动作   | 触发        |
| ---- | --------- |
| 举手   | 左腕高于肩     |
| 双手张开 | 双腕距离 > 阈值 |
| 挥手   | x方向周期变化   |

---

### 🎯 新模块：

**F18：动作语义识别引擎**

用于：

* 音效触发
* 表情触发
* 游戏玩法

👉 这是“产品从 demo → 产品”的关键

---

## 6️⃣ 性能策略（当前是被动的）

### ❗问题 6：只在“过热后降级”，太晚了

当前：

* > 45°C 才降级

👉 实际：

* 已经开始卡顿了

---

### ✅ 建议：主动调度（非常关键）

新增：

```text
输入指标：
- FPS
- 推理耗时
- 温度趋势（不是绝对值）

输出：
- 分辨率
- 推理频率
- 模型复杂度
```

---

### 🎯 新模块：

**F19：自适应性能调度器（建议 P0）**

---

## 7️⃣ 多人/背景干扰（漏项）

### ❗问题 7：只说“选最近的人”，但不够

现实问题：

* 背景有人走动
* 镜子反射
* 电视画面

---

### ✅ 建议：

增加：

* tracking ID 稳定性判断
* 骨架连续性（帧间一致）

---

## 8️⃣ Rive 驱动层（潜在限制）

### ❗问题 8：未定义“骨骼绑定规范”

风险：

* 美术和工程理解不一致
* 后期换角色困难

---

### ✅ 必须补：

**Rive 骨骼命名规范（强制）**

```text
upper_arm_L
lower_arm_L
upper_arm_R
...
```

👉 否则 v1.1 自定义角色会爆炸

---

## 9️⃣ 埋点（略偏“技术日志”，不够产品）

### ❗问题 9：缺少用户行为数据

建议增加：

| 事件                      | 用途      |
| ----------------------- | ------- |
| interaction_duration    | 用户沉浸度   |
| gesture_count           | 活跃度     |
| calibration_retry_count | UX 问题定位 |

---

# 三、你这个方案的“隐藏天花板”

如果不改，上限是：

> 🎯 一个“好玩的技术 demo”

如果补上我说的这些：

> 🚀 可以成为“有产品生命力的互动引擎”

---

# 四、建议优先级（非常重要）

### 🔴 必须在 MVP 前补（否则体验不达标）

* F15 关节约束系统
* F16 人体归一化
* 渐进式置信度控制
* 基础动作语义（至少 2 个）

---

### 🟡 强烈建议（决定“好不好玩”）

* 动态滤波
* 性能调度器
* 动作识别

---

### 🟢 可以后续

* 多人模式
* 商城
* API

---

# 五、总结一句话评价

这份方案已经：

> ✅ **工程上可实现**

但还需要升级为：

> ⚠️ **“在真实环境下稳定好用” + “用户觉得好玩”**

---

如果你下一步要做 TDD，我可以帮你把这些补充点直接转成：

👉 **可开发级别的模块设计（类图 + 接口 + 数据结构）**
很好，这一步我们直接把你缺的“关键能力”落到**可编码级别设计**。我会按**模块 → 类图 → 接口 → 数据结构 → 关键流程**给你整理，开发可以直接开干。

---

# 一、整体新增模块架构（补强版）

在你原有 pipeline 中插入这些模块：

```text
Camera
  ↓
PoseDetector
  ↓
ConfidenceProcessor（升级）
  ↓
KinematicsEngine（新增）
  ↓
NormalizationEngine（新增）
  ↓
MotionFilterEngine（升级）
  ↓
SemanticEngine（新增）
  ↓
PerformanceScheduler（新增）
  ↓
RiveController
```

---

# 二、模块 1：KinematicsEngine（关节约束系统）

## 🎯 目标

解决：

* 抖动
* 反向弯曲
* 非人体动作

---

## 2.1 类图

```text
+----------------------+
| JointConstraint      |
+----------------------+
| minAngle: double     |
| maxAngle: double     |
| maxDeltaPerFrame     |
+----------------------+

+----------------------+
| JointState           |
+----------------------+
| currentAngle         |
| lastAngle            |
| velocity             |
+----------------------+

+----------------------+
| KinematicsEngine     |
+----------------------+
| constraints: Map     |
| states: Map          |
+----------------------+
| updateJoint()        |
| applyConstraints()   |
| limitVelocity()      |
+----------------------+
```

---

## 2.2 数据结构

```dart
enum JointType {
  leftShoulder,
  leftElbow,
  rightShoulder,
  rightElbow,
  head
}

class JointConstraint {
  final double minAngle;
  final double maxAngle;
  final double maxDeltaPerFrame;

  JointConstraint({
    required this.minAngle,
    required this.maxAngle,
    required this.maxDeltaPerFrame,
  });
}

class JointState {
  double currentAngle;
  double lastAngle;
  double velocity;

  JointState(this.currentAngle, this.lastAngle, this.velocity);
}
```

---

## 2.3 核心接口

```dart
class KinematicsEngine {
  final Map<JointType, JointConstraint> constraints;
  final Map<JointType, JointState> states;

  double updateJoint(JointType joint, double rawAngle) {
    final state = states[joint]!;
    final constraint = constraints[joint]!;

    double constrained = _applyAngleLimit(rawAngle, constraint);
    double smoothed = _limitDelta(constrained, state, constraint);

    state.velocity = smoothed - state.currentAngle;
    state.lastAngle = state.currentAngle;
    state.currentAngle = smoothed;

    return smoothed;
  }
}
```

---

## 2.4 核心逻辑

```dart
double _limitDelta(double target, JointState state, JointConstraint c) {
  double delta = target - state.currentAngle;
  if (delta.abs() > c.maxDeltaPerFrame) {
    delta = c.maxDeltaPerFrame * delta.sign;
  }
  return state.currentAngle + delta;
}
```

---

# 三、模块 2：NormalizationEngine（人体归一化）

## 🎯 目标

解决：

* 不同身材 → 动作幅度不一致

---

## 3.1 类图

```text
+----------------------+
| BodyMetrics          |
+----------------------+
| shoulderWidth        |
| armLength            |
| scaleFactor          |
+----------------------+

+----------------------+
| NormalizationEngine  |
+----------------------+
| calibrate()          |
| normalizeAngle()     |
| normalizePosition()  |
+----------------------+
```

---

## 3.2 数据结构

```dart
class BodyMetrics {
  final double shoulderWidth;
  final double armLength;
  final double scaleFactor;

  BodyMetrics({
    required this.shoulderWidth,
    required this.armLength,
    required this.scaleFactor,
  });
}
```

---

## 3.3 接口

```dart
class NormalizationEngine {
  late BodyMetrics metrics;

  void calibrate(Landmark lShoulder, Landmark rShoulder) {
    double width = _distance(lShoulder, rShoulder);

    metrics = BodyMetrics(
      shoulderWidth: width,
      armLength: width * 1.2,
      scaleFactor: width / 0.35, // 标准肩宽
    );
  }

  double normalizeAngle(double angle) {
    return angle * metrics.scaleFactor;
  }
}
```

---

# 四、模块 3：ConfidenceProcessor（升级版）

## 🎯 目标

替代“freeze” → 平滑过渡

---

## 4.1 类图

```text
+--------------------------+
| ConfidenceProcessor      |
+--------------------------+
| thresholdHigh            |
| thresholdLow             |
+--------------------------+
| blendAngle()             |
+--------------------------+
```

---

## 4.2 接口

```dart
class ConfidenceProcessor {
  double blendAngle({
    required double trackedAngle,
    required double idleAngle,
    required double confidence,
  }) {
    double weight;

    if (confidence > 0.6) {
      weight = 1.0;
    } else if (confidence > 0.3) {
      weight = (confidence - 0.3) / 0.3;
    } else {
      weight = 0.0;
    }

    return lerpDouble(idleAngle, trackedAngle, weight)!;
  }
}
```

---

# 五、模块 4：MotionFilterEngine（组合滤波）

## 🎯 目标

解决：

* 抖动 vs 延迟矛盾

---

## 5.1 类图

```text
+----------------------+
| MotionFilterEngine   |
+----------------------+
| oneEuroFilter        |
| velocityFilter       |
| deadZoneThreshold    |
+----------------------+
| filter()             |
+----------------------+
```

---

## 5.2 接口

```dart
class MotionFilterEngine {
  double filter(double value, double lastValue) {
    if ((value - lastValue).abs() < 0.01) {
      return lastValue; // dead zone
    }

    double euro = oneEuroFilter(value);
    return _velocitySmooth(euro, lastValue);
  }
}
```

---

# 六、模块 5：SemanticEngine（动作语义引擎）

## 🎯 目标

让产品“有玩法”

---

## 6.1 类图

```text
+----------------------+
| GestureType (enum)   |
+----------------------+
| handRaise            |
| wave                 |
| armsOpen             |
+----------------------+

+----------------------+
| SemanticEngine       |
+----------------------+
| detect()             |
| _detectWave()        |
| _detectRaise()       |
+----------------------+
```

---

## 6.2 数据结构

```dart
enum GestureType {
  handRaise,
  wave,
  armsOpen,
}
```

---

## 6.3 接口

```dart
class SemanticEngine {
  GestureType? detect(Map<JointType, Landmark> joints) {
    if (_isHandRaised(joints)) return GestureType.handRaise;
    if (_isArmsOpen(joints)) return GestureType.armsOpen;
    if (_isWaving(joints)) return GestureType.wave;
    return null;
  }
}
```

---

## 6.4 示例逻辑

```dart
bool _isHandRaised(Map<JointType, Landmark> j) {
  return j[JointType.leftWrist]!.y <
         j[JointType.leftShoulder]!.y;
}
```

---

# 七、模块 6：PerformanceScheduler（性能调度）

## 🎯 目标

避免卡顿/发热

---

## 7.1 类图

```text
+----------------------+
| PerformanceState     |
+----------------------+
| fps                  |
| temperature          |
| latency              |
+----------------------+

+----------------------+
| PerformanceScheduler |
+----------------------+
| adjustStrategy()     |
+----------------------+
```

---

## 7.2 接口

```dart
class PerformanceScheduler {
  void adjust(PerformanceState state) {
    if (state.temperature > 42) {
      _reduceFPS();
    } else if (state.latency > 120) {
      _reduceResolution();
    } else {
      _increaseQuality();
    }
  }
}
```

---

# 八、模块 7：RiveController（标准化驱动层）

## 🎯 目标

统一骨骼接口（为 v1.1 做准备）

---

## 8.1 类图

```text
+----------------------+
| RiveController       |
+----------------------+
| setJointAngle()      |
| triggerAnimation()   |
| setExpression()      |
+----------------------+
```

---

## 8.2 接口

```dart
class RiveController {
  void setJointAngle(String boneName, double angle);

  void trigger(String stateMachineInput);

  void setExpression(String key, double value);
}
```

---

## 8.3 骨骼规范（必须固定）

```text
upper_arm_L
lower_arm_L
upper_arm_R
lower_arm_R
head
```

---

# 九、主流程（最终运行链路）

```dart
void processFrame(FrameData frame) {
  final landmarks = poseDetector.detect(frame);

  final confidenceProcessed = confidenceProcessor.process(landmarks);

  final normalized = normalizationEngine.normalize(landmarks);

  final angles = angleComputer.compute(normalized);

  final constrained = kinematicsEngine.apply(angles);

  final filtered = motionFilter.filter(constrained);

  final gesture = semanticEngine.detect(landmarks);

  performanceScheduler.adjust(currentState);

  riveController.render(filtered, gesture);
}
```

---

# 十、总结（给你一个判断标准）

如果你实现了这些模块：

✅ 动作稳定（不抖）
✅ 动作自然（不假）
✅ 用户差异消除
✅ 有互动反馈

那么你的产品就从：

> 🎯 “AI demo”

升级为：

> 🚀 “可玩的实时互动引擎”

---

 好，这一步我直接给你一个**可落地的 Flutter 工程结构（生产级）**，已经把你前面所有模块设计（姿态、滤波、语义、性能等）全部映射进去，目标是：

> ✅ 开箱就能开发
> ✅ 易扩展（v1.1 自定义角色）
> ✅ 易维护（模块解耦）

---

# 一、整体架构原则（先统一认知）

采用：

```text
Clean Architecture + Feature Modularization + Real-time Pipeline
```

分为 4 层：

```text
presentation（UI层）
application（流程编排层）
domain（核心算法层）
data（外部依赖层）
```

---

# 二、完整工程目录结构

```text
lib/
│
├── main.dart
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── dependency_injection.dart
│
├── core/                      # 全局通用能力
│   ├── constants/
│   ├── utils/
│   ├── extensions/
│   ├── logging/
│   └── config/
│
├── domain/                    # ⭐核心算法层（纯逻辑）
│   ├── entities/
│   │   ├── joint.dart
│   │   ├── landmark.dart
│   │   ├── body_metrics.dart
│   │   └── gesture.dart
│   │
│   ├── enums/
│   │   ├── joint_type.dart
│   │   └── gesture_type.dart
│   │
│   ├── engines/              # ⭐核心引擎（重点）
│   │   ├── kinematics/
│   │   │   └── kinematics_engine.dart
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
│   │       └── performance_scheduler.dart
│   │
│   ├── services/             # 无状态业务逻辑
│   │   ├── angle_compute_service.dart
│   │   └── pose_mapping_service.dart
│   │
│   └── repositories/         # 抽象接口
│       ├── pose_repository.dart
│       ├── camera_repository.dart
│       └── storage_repository.dart
│
├── data/                     # ⭐外部实现层
│   ├── datasources/
│   │   ├── camera/
│   │   │   └── camera_datasource.dart
│   │   │
│   │   ├── pose/
│   │   │   └── mediapipe_datasource.dart
│   │   │
│   │   ├── storage/
│   │   │   └── local_storage_datasource.dart
│   │   │
│   │   └── analytics/
│   │       └── analytics_datasource.dart
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
├── application/              # ⭐流程编排层（关键）
│   ├── pipeline/
│   │   └── motion_pipeline.dart
│   │
│   ├── usecases/
│   │   ├── process_frame_usecase.dart
│   │   ├── calibrate_usecase.dart
│   │   └── detect_gesture_usecase.dart
│   │
│   └── state/
│       ├── app_state.dart
│       └── session_state.dart
│
├── presentation/             # ⭐UI层
│   ├── pages/
│   │   ├── home/
│   │   │   ├── home_page.dart
│   │   │   └── home_view_model.dart
│   │   │
│   │   ├── calibration/
│   │   │   ├── calibration_page.dart
│   │   │   └── calibration_view_model.dart
│   │   │
│   │   └── camera/
│   │       └── camera_preview_widget.dart
│   │
│   ├── widgets/
│   │   ├── safety_frame.dart
│   │   ├── avatar_view.dart
│   │   └── overlay_hint.dart
│   │
│   └── controllers/
│       └── rive_controller.dart
│
└── assets/
    ├── rive/
    │   └── mimo_character.riv
    └── sounds/
```

---

# 三、关键模块拆解（开发重点）

---

## 1️⃣ motion_pipeline.dart（核心大脑）

📍位置：

```
application/pipeline/motion_pipeline.dart
```

---

### 核心职责

👉 串联所有引擎（你最关键的一层）

---

### 接口

```dart
class MotionPipeline {
  final PoseRepository poseRepo;

  final ConfidenceProcessor confidenceProcessor;
  final NormalizationEngine normalizationEngine;
  final KinematicsEngine kinematicsEngine;
  final MotionFilterEngine filterEngine;
  final SemanticEngine semanticEngine;
  final PerformanceScheduler scheduler;

  FrameResult process(FrameData frame) {
    final landmarks = poseRepo.detect(frame);

    final normalized = normalizationEngine.normalize(landmarks);

    final angles = _computeAngles(normalized);

    final constrained = _applyKinematics(angles);

    final filtered = _filter(constrained);

    final gesture = semanticEngine.detect(landmarks);

    scheduler.adjust(_collectPerfState());

    return FrameResult(filtered, gesture);
  }
}
```

---

## 2️⃣ process_frame_usecase.dart

📍位置：

```
application/usecases/process_frame_usecase.dart
```

---

```dart
class ProcessFrameUseCase {
  final MotionPipeline pipeline;

  FrameResult execute(FrameData frame) {
    return pipeline.process(frame);
  }
}
```

---

## 3️⃣ RiveController（UI桥接）

📍位置：

```
presentation/controllers/rive_controller.dart
```

---

```dart
class RiveAvatarController {
  void applyFrame(FrameResult result) {
    result.jointAngles.forEach((joint, angle) {
      setJointAngle(joint.name, angle);
    });

    if (result.gesture != null) {
      trigger(result.gesture!.name);
    }
  }
}
```

---

# 四、数据结构统一定义（必须统一）

---

## FrameResult

```dart
class FrameResult {
  final Map<JointType, double> jointAngles;
  final GestureType? gesture;

  FrameResult(this.jointAngles, this.gesture);
}
```

---

## FrameData

```dart
class FrameData {
  final int timestamp;
  final dynamic image; // camera frame

  FrameData(this.timestamp, this.image);
}
```

---

# 五、依赖注入（DI）

📍位置：

```
app/dependency_injection.dart
```

---

```dart
final getIt = GetIt.instance;

void setupDI() {
  // engines
  getIt.registerSingleton(KinematicsEngine());
  getIt.registerSingleton(NormalizationEngine());
  getIt.registerSingleton(MotionFilterEngine());
  getIt.registerSingleton(ConfidenceProcessor());
  getIt.registerSingleton(SemanticEngine());
  getIt.registerSingleton(PerformanceScheduler());

  // pipeline
  getIt.registerSingleton(MotionPipeline(
    poseRepo: getIt(),
    confidenceProcessor: getIt(),
    normalizationEngine: getIt(),
    kinematicsEngine: getIt(),
    filterEngine: getIt(),
    semanticEngine: getIt(),
    scheduler: getIt(),
  ));
}
```

---

# 六、线程模型（非常关键 ⚠️）

你必须这样做：

```text
UI线程（Flutter）
   ↓
Isolate（AI推理 + pipeline）
   ↓
UI线程（渲染）
```

---

## 推荐实现

```dart
compute(processFrameInIsolate, frameData);
```

---

# 七、开发顺序（避免翻车）

### 第一步（骨架）

* camera preview
* rive 渲染
* 空 pipeline

---

### 第二步（打通）

* mediapipe → landmark
* 打印坐标

---

### 第三步（驱动）

* angle → rive 骨骼

---

### 第四步（稳定）

* kinematics
* filter
* confidence

---

### 第五步（体验）

* semantic
* 音效
* idle

---

# 八、你这个架构的优势

实现后你会得到：

✅ 模块完全解耦（可以替换 MediaPipe）
✅ 支持多人/新模型扩展
✅ v1.1 自定义角色几乎不用重构
✅ 性能可控（pipeline集中管理）

---

# 九、一句话总结

这个工程结构本质是：

> 🎯 **把“AI实时动捕”拆成一个可维护的实时数据处理引擎**

---

# 如果你下一步继续

我建议你直接做这两个（我可以继续帮你）：

### 👉 1. 输出「完整 TDD 文档（接口 + 类图 UML）」

### 👉 2. 给你「可运行 Flutter Demo骨架代码（含 pipeline stub）」

直接说一句：
👉 “给我 Demo骨架” 或 “继续 TDD”
下面是基于你当前 PRD + 我们补强方案整理的 **完整 TDD（Technical Design Document）v1.0**。
目标是：**开发可直接对照实现，无需再做架构决策**。

---

# 🧠 Mimo 技术设计文档（TDD v1.0）

---

# 1. 设计目标

## 1.1 核心目标

构建一个：

```text
低延迟（<120ms）+ 高稳定 + 可扩展 的实时人体驱动引擎
```

---

## 1.2 设计原则

| 原则    | 说明        |
| ----- | --------- |
| 单向数据流 | 避免状态混乱    |
| 引擎解耦  | 每个模块可独立替换 |
| 无状态优先 | 减少 bug    |
| 实时优先  | 每帧 O(1)   |
| 可降级   | 性能优先      |

---

# 2. 系统总体架构

---

## 2.1 运行时架构图（核心）

```text
Camera Frame
   ↓
PoseDetector（MediaPipe）
   ↓
ConfidenceProcessor
   ↓
NormalizationEngine
   ↓
AngleComputeService
   ↓
KinematicsEngine
   ↓
MotionFilterEngine
   ↓
SemanticEngine
   ↓
PerformanceScheduler
   ↓
RiveController
```

---

## 2.2 线程模型

```text
Main Thread (UI)
   ├── Rive 渲染
   └── UI 更新

Isolate Thread
   ├── Pose 推理
   └── Motion Pipeline（全部引擎）
```

---

# 3. 核心数据结构定义（统一标准）

---

## 3.1 Landmark

```dart
class Landmark {
  final double x; // 0~1
  final double y;
  final double z;
  final double visibility;

  Landmark(this.x, this.y, this.z, this.visibility);
}
```

---

## 3.2 JointType

```dart
enum JointType {
  leftShoulder,
  leftElbow,
  leftWrist,
  rightShoulder,
  rightElbow,
  rightWrist,
  head
}
```

---

## 3.3 FrameData

```dart
class FrameData {
  final int timestamp;
  final dynamic image;

  FrameData(this.timestamp, this.image);
}
```

---

## 3.4 FrameResult

```dart
class FrameResult {
  final Map<JointType, double> jointAngles;
  final GestureType? gesture;

  FrameResult(this.jointAngles, this.gesture);
}
```

---

## 3.5 BodyMetrics

```dart
class BodyMetrics {
  final double shoulderWidth;
  final double scaleFactor;

  BodyMetrics({
    required this.shoulderWidth,
    required this.scaleFactor,
  });
}
```

---

# 4. 模块设计（逐个可实现）

---

# 4.1 PoseRepository（接口）

```dart
abstract class PoseRepository {
  Map<JointType, Landmark> detect(FrameData frame);
}
```

---

# 4.2 ConfidenceProcessor

## UML

```text
+--------------------------+
| ConfidenceProcessor      |
+--------------------------+
| blendAngle()             |
+--------------------------+
```

---

## 接口

```dart
class ConfidenceProcessor {
  double blend({
    required double tracked,
    required double idle,
    required double confidence,
  });
}
```

---

## 行为

```text
confidence > 0.6 → 100% tracking
0.3~0.6 → 线性过渡
<0.3 → idle
```

---

# 4.3 NormalizationEngine

---

## UML

```text
+----------------------+
| NormalizationEngine  |
+----------------------+
| calibrate()          |
| normalize()          |
+----------------------+
```

---

## 接口

```dart
class NormalizationEngine {
  BodyMetrics? metrics;

  void calibrate(Map<JointType, Landmark> joints);

  Map<JointType, Landmark> normalize(
    Map<JointType, Landmark> joints
  );
}
```

---

## 核心逻辑

```text
scale = shoulderWidth / baseline
所有坐标按 scale 归一化
```

---

# 4.4 AngleComputeService

---

## UML

```text
+--------------------------+
| AngleComputeService      |
+--------------------------+
| computeAngles()          |
+--------------------------+
```

---

## 接口

```dart
class AngleComputeService {
  Map<JointType, double> compute(
    Map<JointType, Landmark> joints
  );
}
```

---

## 核心公式

```text
angle = atan2(dy, dx)
```

---

# 4.5 KinematicsEngine（关键）

---

## UML

```text
+----------------------+
| KinematicsEngine     |
+----------------------+
| constraints          |
| states               |
+----------------------+
| apply()              |
+----------------------+
```

---

## 接口

```dart
class KinematicsEngine {
  Map<JointType, double> apply(
    Map<JointType, double> angles
  );
}
```

---

## 规则

| 规则   | 示例        |
| ---- | --------- |
| 角度限制 | 肘 0°~150° |
| Δ限制  | 每帧 ≤ 25°  |
| 防反向  | 不允许跨象限跳变  |

---

# 4.6 MotionFilterEngine

---

## UML

```text
+----------------------+
| MotionFilterEngine   |
+----------------------+
| filter()             |
+----------------------+
```

---

## 接口

```dart
class MotionFilterEngine {
  Map<JointType, double> filter(
    Map<JointType, double> angles
  );
}
```

---

## 策略

```text
OneEuro + VelocitySmooth + DeadZone
```

---

# 4.7 SemanticEngine

---

## UML

```text
+----------------------+
| SemanticEngine       |
+----------------------+
| detect()             |
+----------------------+
```

---

## 接口

```dart
class SemanticEngine {
  GestureType? detect(
    Map<JointType, Landmark> joints
  );
}
```

---

## 动作规则（MVP）

| 动作 | 规则                   |
| -- | -------------------- |
| 举手 | wrist.y < shoulder.y |
| 张开 | 双腕距离 > 阈值            |
| 挥手 | x 方向周期变化             |

---

# 4.8 PerformanceScheduler

---

## UML

```text
+----------------------+
| PerformanceScheduler |
+----------------------+
| adjust()             |
+----------------------+
```

---

## 接口

```dart
class PerformanceScheduler {
  void adjust(PerformanceState state);
}
```

---

## 输入

```dart
class PerformanceState {
  final double fps;
  final double latency;
  final double temperature;
}
```

---

## 策略

```text
高温 → 降 FPS
高延迟 → 降分辨率
低负载 → 提升质量
```

---

# 4.9 MotionPipeline（核心编排）

---

## UML（关键）

```text
+----------------------------------+
| MotionPipeline                   |
+----------------------------------+
| process(frame)                   |
+----------------------------------+
        ↓
 Pose → Normalize → Angle → Kinematics
        ↓
 Filter → Semantic → Scheduler
```

---

## 接口

```dart
class MotionPipeline {
  FrameResult process(FrameData frame);
}
```

---

## 完整流程（伪代码）

```dart
FrameResult process(FrameData frame) {
  final joints = pose.detect(frame);

  final normalized = normalization.normalize(joints);

  final angles = angleService.compute(normalized);

  final constrained = kinematics.apply(angles);

  final filtered = filter.filter(constrained);

  final gesture = semantic.detect(joints);

  scheduler.adjust(currentState);

  return FrameResult(filtered, gesture);
}
```

---

# 4.10 RiveController

---

## 接口

```dart
class RiveController {
  void setJointAngle(String bone, double angle);
  void trigger(String animation);
}
```

---

## 绑定规范（必须）

```text
upper_arm_L
lower_arm_L
upper_arm_R
lower_arm_R
head
```

---

# 5. UseCase 层

---

## ProcessFrameUseCase

```dart
class ProcessFrameUseCase {
  final MotionPipeline pipeline;

  FrameResult execute(FrameData frame);
}
```

---

## CalibrateUseCase

```dart
class CalibrateUseCase {
  void execute(Map<JointType, Landmark> joints);
}
```

---

# 6. 状态管理

---

## SessionState

```dart
class SessionState {
  bool isTracking;
  bool isCalibrated;
  int frameCount;
}
```

---

# 7. 性能约束（必须实现）

---

## 每帧复杂度

```text
O(关节数) ≈ O(10)
```

---

## 内存策略

* 不创建新对象（复用 Map）
* 避免 GC 抖动

---

## 延迟预算

| 阶段       | 时间   |
| -------- | ---- |
| 推理       | 40ms |
| pipeline | 10ms |
| 渲染       | 16ms |

---

# 8. 异常处理策略

---

## 关键点丢失

```text
1帧丢失 → 使用上一帧
连续10帧 → idle
```

---

## 抖动异常

```text
Δ角度 > 60° → clamp
```

---

## 无人检测

```text
进入 idle 状态机
```

---

# 9. 可扩展设计（v1.1 预留）

---

## 支持新模型

```text
PoseRepository 可替换
```

---

## 自定义角色

```text
RiveController 抽象骨骼层
```

---

## 插件化引擎

```text
MotionPipeline 可插拔 engine
```

---

# 🔟 最终总结

这个 TDD 已经定义了：

✅ 所有核心类
✅ 所有接口
✅ 数据结构统一标准
✅ 引擎职责清晰
✅ 可直接编码

---

