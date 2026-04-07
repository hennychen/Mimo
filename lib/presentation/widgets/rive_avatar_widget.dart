import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart';

import '../../domain/entities/body_metrics.dart';
import '../../domain/entities/frame_result.dart';
import '../../domain/entities/gesture_type.dart';
import '../../domain/entities/joint_type.dart';
import '../../domain/services/rive_bone_controller.dart';
import '../../application/providers/providers.dart';

/// Rive角色渲染Widget
/// 
/// 显示Rive动画角色并根据姿态数据驱动骨骼
class RiveAvatarWidget extends ConsumerStatefulWidget {
  const RiveAvatarWidget({super.key});

  @override
  ConsumerState<RiveAvatarWidget> createState() => _RiveAvatarWidgetState();
}

class _RiveAvatarWidgetState extends ConsumerState<RiveAvatarWidget> {
  /// Rive文件加载器
  Artboard? _artboard;
  
  /// 骨骼控制器
  RiveBoneController? _boneController;
  
  /// 动画控制器
  CustomAnimationController? _animationController;
  
  /// 是否正在加载
  bool _isLoading = true;
  
  /// 加载错误信息
  String? _errorMessage;
  
  /// 当前手势
  GestureType _currentGesture = GestureType.none;
  
  /// 平滑后的角度值
  final Map<String, double> _smoothedAngles = {};
  
  /// 平滑因子
  static const double _smoothingFactor = 0.3;

  @override
  void initState() {
    super.initState();
    _initializeSoundService();
    _loadRiveFile();
  }

  /// 初始化音效服务
  Future<void> _initializeSoundService() async {
    final soundService = ref.read(soundServiceProvider);
    await soundService.initialize();
  }

  /// 加载Rive文件
  Future<void> _loadRiveFile() async {
    try {
      // 尝试加载实际的Rive文件
      // 如果文件不存在，使用占位符
      final file = await RiveFile.asset('assets/rive/mimo_character.riv');
      _artboard = file.mainArtboard;
      
      // 初始化骨骼控制器
      _boneController = RiveBoneController();
      await _boneController!.initialize(_artboard!);
      
      // 初始化动画控制器
      _animationController = CustomAnimationController();
      
      // 尝试播放idle动画
      try {
        _animationController!.playAnimation(_artboard!, 'idle');
      } catch (e) {
        // 忽略动画不存在的情况
        debugPrint('Idle animation not found: $e');
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load Rive file: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '无法加载角色动画';
      });
    }
  }

  @override
  void dispose() {
    _boneController?.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 监听帧处理服务的结果
    ref.listen<FrameResult?>(frameResultProvider, (previous, next) {
      if (next != null) {
        _onFrameResult(next);
      }
    });

    // 监听校准数据
    ref.listen<BodyMetrics?>(bodyMetricsProvider, (previous, next) {
      if (next != null && previous == null) {
        // 校准完成，可以开始追踪
        _onCalibrationComplete(next);
      }
    });

    return Container(
      color: Colors.transparent,
      child: Center(
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingIndicator();
    }
    
    if (_errorMessage != null) {
      return _buildErrorPlaceholder();
    }
    
    if (_artboard != null) {
      return Rive(
        artboard: _artboard!,
        fit: BoxFit.contain,
      );
    }
    
    // 占位符（当Rive文件不可用时）
    return _buildPlaceholderCharacter();
  }

  /// 加载指示器
  Widget _buildLoadingIndicator() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: Colors.white),
        SizedBox(height: 16),
        Text(
          '正在加载角色...',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  /// 错误占位符
  Widget _buildErrorPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.error_outline,
          color: Colors.redAccent,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          _errorMessage ?? '加载失败',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  /// 占位符角色（当Rive文件不可用时显示）
  Widget _buildPlaceholderCharacter() {
    return Consumer(
      builder: (context, ref, child) {
        final frameResult = ref.watch(frameResultProvider);
        final angles = frameResult?.jointAngles ?? {};
        
        return CustomPaint(
          size: const Size(300, 400),
          painter: PlaceholderCharacterPainter(
            angles: angles,
            gesture: _currentGesture,
          ),
        );
      },
    );
  }

  /// 处理帧结果
  void _onFrameResult(FrameResult result) {
    if (_boneController == null || !_boneController!.isInitialized) return;
    
    // 平滑处理角度
    final smoothedAngles = _smoothAngles(result.jointAngles);
    
    // 应用到骨骼
    for (final entry in smoothedAngles.entries) {
      _boneController!.applyJointAngle(entry.key, entry.value);
    }
    
    // 处理手势变化
    final newGesture = result.gesture ?? GestureType.none;
    if (newGesture != _currentGesture) {
      _onGestureChanged(newGesture);
    }
    
    // 通知更新
    setState(() {});
  }

  /// 平滑角度
  Map<String, double> _smoothAngles(Map<JointType, double> angles) {
    final result = <String, double>{};
    
    for (final entry in angles.entries) {
      final jointName = entry.key.riveBoneName;
      final targetAngle = entry.value;
      
      final previousAngle = _smoothedAngles[jointName] ?? targetAngle;
      final smoothedAngle = previousAngle + (targetAngle - previousAngle) * _smoothingFactor;
      
      _smoothedAngles[jointName] = smoothedAngle;
      result[jointName] = smoothedAngle;
    }
    
    return result;
  }

  /// 手势变化处理
  void _onGestureChanged(GestureType newGesture) {
    final previousGesture = _currentGesture;
    _currentGesture = newGesture;
    
    // 播放手势音效
    _playGestureSound(newGesture);
    
    // 根据手势触发动画
    if (_artboard != null && _animationController != null) {
      switch (newGesture) {
        case GestureType.wave:
          _animationController!.playAnimation(_artboard!, 'wave');
          break;
        case GestureType.handsUp:
          _animationController!.playAnimation(_artboard!, 'hands_up');
          break;
        case GestureType.tPose:
          _animationController!.playAnimation(_artboard!, 't_pose');
          break;
        case GestureType.idle:
          _animationController!.playAnimation(_artboard!, 'idle');
          break;
        default:
          break;
      }
    }
    
    debugPrint('Gesture changed: $previousGesture -> $newGesture');
  }
  
  /// 播放手势音效
  void _playGestureSound(GestureType gesture) {
    // 只对特定手势播放音效
    switch (gesture) {
      case GestureType.wave:
      case GestureType.handsUp:
      case GestureType.clap:
      case GestureType.handRaise:
      case GestureType.armsOpen:
        final soundService = ref.read(soundServiceProvider);
        soundService.playGestureSound(gesture);
        break;
      default:
        break;
    }
  }

  /// 校准完成处理
  void _onCalibrationComplete(BodyMetrics metrics) {
    debugPrint('Calibration complete: ${metrics.shoulderWidth}');
    
    // 可以根据校准数据调整角色的比例
    // _artboard?.scale = metrics.scaleFactor;
  }
}

/// 占位符角色绘制器
/// 
/// 当Rive文件不可用时，绘制一个简单的骨骼人形
class PlaceholderCharacterPainter extends CustomPainter {
  final Map<JointType, double> angles;
  final GestureType gesture;

  PlaceholderCharacterPainter({
    required this.angles,
    required this.gesture,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // 绘制身体
    final bodyPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    final jointPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    
    // 计算关节位置
    final neckPos = Offset(center.dx, center.dy - 80);
    final shoulderWidth = 80.0;
    
    // 绘制头部
    canvas.drawCircle(Offset(neckPos.dx, neckPos.dy - 40), 25, bodyPaint);
    
    // 绘制身体
    canvas.drawLine(neckPos, Offset(center.dx, center.dy + 50), bodyPaint);
    
    // 获取手臂角度
    final leftUpperArmAngle = (angles[JointType.leftShoulder] ?? 0) * math.pi / 180;
    final leftLowerArmAngle = (angles[JointType.leftElbow] ?? 0) * math.pi / 180;
    final rightUpperArmAngle = (angles[JointType.rightShoulder] ?? 0) * math.pi / 180;
    final rightLowerArmAngle = (angles[JointType.rightElbow] ?? 0) * math.pi / 180;
    
    // 左肩位置
    final leftShoulderPos = Offset(center.dx - shoulderWidth / 2, neckPos.dy + 20);
    // 右肩位置
    final rightShoulderPos = Offset(center.dx + shoulderWidth / 2, neckPos.dy + 20);
    
    // 计算手臂位置（上臂长度50，前臂长度45）
    const upperArmLength = 50.0;
    const lowerArmLength = 45.0;
    
    // 左臂
    final leftElbowPos = Offset(
      leftShoulderPos.dx + upperArmLength * math.cos(leftUpperArmAngle - math.pi / 2),
      leftShoulderPos.dy + upperArmLength * math.sin(leftUpperArmAngle - math.pi / 2),
    );
    final leftWristPos = Offset(
      leftElbowPos.dx + lowerArmLength * math.cos(leftLowerArmAngle - math.pi / 2),
      leftElbowPos.dy + lowerArmLength * math.sin(leftLowerArmAngle - math.pi / 2),
    );
    
    // 右臂
    final rightElbowPos = Offset(
      rightShoulderPos.dx + upperArmLength * math.cos(rightUpperArmAngle - math.pi / 2),
      rightShoulderPos.dy + upperArmLength * math.sin(rightUpperArmAngle - math.pi / 2),
    );
    final rightWristPos = Offset(
      rightElbowPos.dx + lowerArmLength * math.cos(rightLowerArmAngle - math.pi / 2),
      rightElbowPos.dy + lowerArmLength * math.sin(rightLowerArmAngle - math.pi / 2),
    );
    
    // 绘制手臂
    canvas.drawLine(leftShoulderPos, leftElbowPos, bodyPaint);
    canvas.drawLine(leftElbowPos, leftWristPos, bodyPaint);
    canvas.drawLine(rightShoulderPos, rightElbowPos, bodyPaint);
    canvas.drawLine(rightElbowPos, rightWristPos, bodyPaint);
    
    // 绘制关节点
    canvas.drawCircle(leftShoulderPos, 8, jointPaint);
    canvas.drawCircle(leftElbowPos, 6, jointPaint);
    canvas.drawCircle(leftWristPos, 5, jointPaint);
    canvas.drawCircle(rightShoulderPos, 8, jointPaint);
    canvas.drawCircle(rightElbowPos, 6, jointPaint);
    canvas.drawCircle(rightWristPos, 5, jointPaint);
    
    // 绘制腿部
    final hipPos = Offset(center.dx, center.dy + 50);
    canvas.drawLine(hipPos, Offset(center.dx - 30, center.dy + 130), bodyPaint);
    canvas.drawLine(hipPos, Offset(center.dx + 30, center.dy + 130), bodyPaint);
    
    // 根据手势改变颜色
    if (gesture != GestureType.none && gesture != GestureType.idle) {
      final gesturePaint = Paint()
        ..color = Colors.green.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 150, gesturePaint);
    }
  }

  @override
  bool shouldRepaint(covariant PlaceholderCharacterPainter oldDelegate) {
    // 当角度或手势变化时重绘
    if (gesture != oldDelegate.gesture) return true;
    if (angles.length != oldDelegate.angles.length) return true;
    for (final entry in angles.entries) {
      if (oldDelegate.angles[entry.key] != entry.value) return true;
    }
    return false;
  }
}