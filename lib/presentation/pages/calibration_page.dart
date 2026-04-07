import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/providers.dart';
import '../../application/services/frame_processing_service.dart';
import '../../domain/engines/calibration/calibration_engine.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/safety_frame_overlay.dart';

/// 校准页面
///
/// 用于引导用户完成T-Pose校准流程
class CalibrationPage extends ConsumerStatefulWidget {
  const CalibrationPage({super.key});

  @override
  ConsumerState<CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends ConsumerState<CalibrationPage> {
  FrameProcessingService? _frameProcessingService;
  bool _isCalibrating = false;
  final String _instructionText = '请站在摄像头前，保持T-Pose姿势';
  final int _calibrationProgress = 0;

  @override
  void initState() {
    super.initState();
    _initializeFrameProcessing();
  }

  Future<void> _initializeFrameProcessing() async {
    _frameProcessingService = ref.read(frameProcessingServiceProvider);

    _frameProcessingService?.onFrameResult = (result) {
      // 处理帧结果
      setState(() {
        // 可以在这里更新实时动画状态
      });
    };

    try {
      await _frameProcessingService?.start();
      setState(() {
        _isCalibrating = true;
      });
    } catch (e) {
      print('⚠️ Camera initialization failed, showing error UI');
      setState(() {
        _isCalibrating = false;
      });

      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('相机初始化失败: $e\n应用将在有限模式下运行'),
            duration: Duration(seconds: 5),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _frameProcessingService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calibrationStatus = ref.watch(calibrationStatusProvider);
    final fps = ref.watch(currentFpsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('校准', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // 摄像头预览
          const CameraPreviewWidget(),

          // 如果相机未初始化,显示提示信息
          if (!_isCalibrating)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, size: 64, color: Colors.orange),
                    SizedBox(height: 16),
                    Text(
                      '相机不可用',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        '由于设备兼容性问题,相机功能暂时不可用。\n\n您可以:\n• 尝试其他设备\n• 使用Android模拟器\n• 继续浏览应用其他功能',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed('/home');
                      },
                      icon: Icon(Icons.arrow_forward),
                      label: Text('进入主页'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 安全框叠加层
          if (_isCalibrating) const SafetyFrameOverlay(),

          // 校准状态叠加层
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: _buildCalibrationStatus(calibrationStatus),
          ),

          // FPS指示器
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'FPS: ${fps.toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),

          // 底部指引
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomInstructions(calibrationStatus),
          ),
        ],
      ),
    );
  }

  /// 校准状态指示器
  Widget _buildCalibrationStatus(CalibrationStatus status) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case CalibrationStatus.waiting:
        statusText = '等待检测...';
        statusColor = Colors.grey;
        statusIcon = Icons.hourglass_empty;
        break;
      case CalibrationStatus.detecting:
        statusText = '检测到人体';
        statusColor = Colors.orange;
        statusIcon = Icons.person;
        break;
      case CalibrationStatus.tPoseDetected:
        statusText = '检测到T-Pose';
        statusColor = Colors.green;
        statusIcon = Icons.accessibility_new;
        break;
      case CalibrationStatus.calibrating:
        statusText = '正在校准...请保持姿势';
        statusColor = Colors.blue;
        statusIcon = Icons.sync;
        break;
      case CalibrationStatus.success:
        statusText = '校准成功！';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case CalibrationStatus.failed:
        statusText = '校准失败，请重试';
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusText = '未知状态';
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: statusColor, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, color: statusColor, size: 24),
            const SizedBox(width: 8),
            Text(
              statusText,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 底部指引
  Widget _buildBottomInstructions(CalibrationStatus status) {
    String instruction;

    switch (status) {
      case CalibrationStatus.waiting:
        instruction = '请站在摄像头前，确保全身可见';
        break;
      case CalibrationStatus.detecting:
        instruction = '请举起双臂，做出T-Pose姿势';
        break;
      case CalibrationStatus.tPoseDetected:
        instruction = '保持姿势不动，等待校准完成';
        break;
      case CalibrationStatus.calibrating:
        instruction = '校准中...请保持稳定';
        break;
      case CalibrationStatus.success:
        instruction = '校准完成！点击继续开始互动';
        break;
      case CalibrationStatus.failed:
        instruction = '校准失败。请调整姿势后重试';
        break;
      default:
        instruction = '';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度指示器
          if (status == CalibrationStatus.calibrating)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(
                value: null, // 无限进度
                backgroundColor: Colors.grey,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),

          Text(
            instruction,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),

          // 成功后显示继续按钮
          if (status == CalibrationStatus.success)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/home');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('开始互动'),
              ),
            ),

          // 失败后显示重试按钮
          if (status == CalibrationStatus.failed)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton(
                onPressed: () {
                  _retryCalibration();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('重新校准'),
              ),
            ),
        ],
      ),
    );
  }

  /// 重新校准
  void _retryCalibration() {
    ref.read(calibrationStatusProvider.notifier).state =
        CalibrationStatus.waiting;
    _frameProcessingService?.start();
  }
}
