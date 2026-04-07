import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/safety_frame_overlay.dart';
import '../widgets/rive_avatar_widget.dart';
import '../pages/avatar_create_page.dart';
import '../../application/providers/providers.dart';
import '../../application/services/frame_processing_service.dart';
import '../../domain/engines/calibration/calibration_engine.dart';

/// 主页面
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  /// 帧处理服务
  FrameProcessingService? _frameProcessingService;
  
  /// 是否暂停
  bool _isPaused = false;
  
  /// 是否静音
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // 初始化音效服务
    final soundService = ref.read(soundServiceProvider);
    await soundService.initialize();
    
    // 加载校准数据
    final storageRepo = ref.read(storageRepositoryProvider);
    final metrics = await storageRepo.loadCalibration();
    if (metrics != null) {
      ref.read(bodyMetricsProvider.notifier).state = metrics;
      ref.read(normalizationEngineProvider).calibrate({});
    }
    
    // 初始化帧处理服务
    _frameProcessingService = ref.read(frameProcessingServiceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final calibrationStatus = ref.watch(calibrationStatusProvider);
    final fps = ref.watch(currentFpsProvider);
    final frameResult = ref.watch(frameResultProvider);
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 摄像头预览层
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.of(context).size.height * 0.35,
            child: const CameraPreviewWidget(),
          ),
          
          // 安全框叠加
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.of(context).size.height * 0.35,
            child: const SafetyFrameOverlay(),
          ),
          
          // Rive角色层
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: MediaQuery.of(context).size.height * 0.35,
            child: const RiveAvatarWidget(),
          ),
          
          // 顶部状态栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(fps, frameResult?.confidence ?? 0),
          ),
          
          // 底部控制面板
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomControls(),
          ),
          
          // 校准引导覆盖层
          if (calibrationStatus == CalibrationStatus.waiting ||
              calibrationStatus == CalibrationStatus.inProgress ||
              calibrationStatus == CalibrationStatus.verifying)
            _buildCalibrationOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopBar(double fps, double confidence) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.6),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 应用标题
            const Text(
              'Mimo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            // 状态指示
            Row(
              children: [
                _buildStatusChip(
                  '${fps.toStringAsFixed(0)} FPS',
                  _getFpsColor(fps),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(
                  '${(confidence * 100).toStringAsFixed(0)}%',
                  _getConfidenceColor(confidence),
                ),
                const SizedBox(width: 8),
                _buildSettingsButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getFpsColor(double fps) {
    if (fps >= 25) return Colors.green;
    if (fps >= 15) return Colors.orange;
    return Colors.red;
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.7) return Colors.green;
    if (confidence >= 0.4) return Colors.orange;
    return Colors.red;
  }

  Widget _buildSettingsButton() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar创建按钮
        IconButton(
          icon: const Icon(Icons.person_add, color: Colors.white70),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const AvatarCreatePage(),
              ),
            );
          },
          tooltip: '创建角色',
        ),
        // 设置按钮
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white70),
          onPressed: () {
            Navigator.of(context).pushNamed('/settings');
          },
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 暂停/恢复按钮
            _buildControlButton(
              icon: _isPaused ? Icons.play_arrow : Icons.pause,
              label: _isPaused ? '恢复' : '暂停',
              onPressed: _togglePause,
            ),
            
            // 切换摄像头
            _buildControlButton(
              icon: Icons.cameraswitch,
              label: '切换',
              onPressed: _switchCamera,
            ),
            
            // 静音/取消静音
            _buildControlButton(
              icon: _isMuted ? Icons.volume_off : Icons.volume_up,
              label: _isMuted ? '静音' : '音效',
              onPressed: _toggleMute,
            ),
            
            // 重新校准
            _buildControlButton(
              icon: Icons.accessibility_new,
              label: '校准',
              onPressed: _startCalibration,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibrationOverlay() {
    final calibrationStatus = ref.watch(calibrationStatusProvider);
    
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // T-Pose引导图
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white30, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(
                  Icons.accessibility_new,
                  size: 100,
                  color: Colors.white54,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 状态文字
            Text(
              _getCalibrationMessage(calibrationStatus),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '双臂侧平举，保持姿势',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            
            // 开始按钮
            if (calibrationStatus == CalibrationStatus.waiting)
              ElevatedButton(
                onPressed: _startCalibration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('开始校准'),
              ),
            
            // 校准中指示器
            if (calibrationStatus == CalibrationStatus.inProgress ||
                calibrationStatus == CalibrationStatus.verifying)
              const Column(
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    '校准中...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _getCalibrationMessage(CalibrationStatus status) {
    switch (status) {
      case CalibrationStatus.waiting:
        return '请站成T-Pose姿势';
      case CalibrationStatus.inProgress:
        return '检测中...';
      case CalibrationStatus.verifying:
        return '保持姿势';
      case CalibrationStatus.detecting:
        return '检测到人体';
      case CalibrationStatus.tPoseDetected:
        return '检测到T-Pose';
      case CalibrationStatus.calibrating:
        return '正在校准...';
      case CalibrationStatus.success:
        return '校准成功！';
      case CalibrationStatus.failed:
        return '校准失败，请重试';
    }
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
    
    if (_isPaused) {
      _frameProcessingService?.pause();
    } else {
      _frameProcessingService?.resume();
    }
  }

  Future<void> _switchCamera() async {
    final cameraRepo = ref.read(cameraRepositoryProvider);
    await cameraRepo.switchCamera();
  }

  Future<void> _toggleMute() async {
    setState(() {
      _isMuted = !_isMuted;
    });
    
    final soundService = ref.read(soundServiceProvider);
    await soundService.setMuted(_isMuted);
  }

  void _startCalibration() {
    ref.read(calibrationStatusProvider.notifier).state = CalibrationStatus.inProgress;
    _frameProcessingService?.start();
  }
}