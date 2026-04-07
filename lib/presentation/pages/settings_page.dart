import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/providers.dart';

/// 设置页面
/// 
/// 用于调整应用参数和偏好设置
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // 滤波参数
  double _minCutoff = 1.0;
  double _beta = 0.0;
  double _dCutoff = 1.0;
  
  // 关节约束参数
  double _maxAngleDelta = 30.0;
  
  // 性能参数
  bool _highPerformanceMode = false;
  int _targetFps = 30;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = ref.read(storageRepositoryProvider);
    
    final minCutoff = await storage.getDouble('filter_min_cutoff');
    final beta = await storage.getDouble('filter_beta');
    final dCutoff = await storage.getDouble('filter_d_cutoff');
    final maxDelta = await storage.getDouble('kinematics_max_delta');
    final highPerf = await storage.getBool('high_performance_mode');
    
    setState(() {
      if (minCutoff != null) _minCutoff = minCutoff;
      if (beta != null) _beta = beta;
      if (dCutoff != null) _dCutoff = dCutoff;
      if (maxDelta != null) _maxAngleDelta = maxDelta;
      if (highPerf != null) _highPerformanceMode = highPerf;
    });
  }

  Future<void> _saveSettings() async {
    final storage = ref.read(storageRepositoryProvider);
    
    await storage.setDouble('filter_min_cutoff', _minCutoff);
    await storage.setDouble('filter_beta', _beta);
    await storage.setDouble('filter_d_cutoff', _dCutoff);
    await storage.setDouble('kinematics_max_delta', _maxAngleDelta);
    await storage.setBool('high_performance_mode', _highPerformanceMode);
    
    // 重新创建滤波引擎以应用新参数
    // ref.invalidate(motionFilterEngineProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              _saveSettings();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('设置已保存')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 滤波参数部分
          _buildSectionHeader('滤波参数 (One Euro Filter)'),
          _buildSliderSetting(
            '最小截止频率 (minCutoff)',
            _minCutoff,
            0.1,
            5.0,
            (value) => setState(() => _minCutoff = value),
            '值越小，平滑度越高，但延迟越大',
          ),
          _buildSliderSetting(
            '速度灵敏度 (beta)',
            _beta,
            0.0,
            1.0,
            (value) => setState(() => _beta = value),
            '值越大，快速运动时响应越灵敏',
          ),
          _buildSliderSetting(
            '导数截止频率 (dCutoff)',
            _dCutoff,
            0.1,
            5.0,
            (value) => setState(() => _dCutoff = value),
            '影响速度估计的平滑度',
          ),
          
          const Divider(height: 32),
          
          // 关节约束部分
          _buildSectionHeader('关节约束'),
          _buildSliderSetting(
            '最大角度变化 (度/帧)',
            _maxAngleDelta,
            5.0,
            60.0,
            (value) => setState(() => _maxAngleDelta = value),
            '限制每帧最大角度变化，防止突变',
          ),
          
          const Divider(height: 32),
          
          // 性能部分
          _buildSectionHeader('性能设置'),
          _buildToggleSetting(
            '高性能模式',
            _highPerformanceMode,
            (value) => setState(() => _highPerformanceMode = value),
            '启用后降低滤波强度以获得更快响应',
          ),
          if (_highPerformanceMode)
            _buildSliderSetting(
              '目标FPS',
              _targetFps.toDouble(),
              15.0,
              60.0,
              (value) => setState(() => _targetFps = value.round()),
              '调整帧处理频率',
            ),
          
          const Divider(height: 32),
          
          // 重置按钮
          ElevatedButton.icon(
            onPressed: _resetToDefaults,
            icon: const Icon(Icons.restore),
            label: const Text('重置为默认值'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 重新校准按钮
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed('/calibration');
            },
            icon: const Icon(Icons.accessibility_new),
            label: const Text('重新校准'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSliderSetting(
    String title,
    double value,
    double min,
    double max,
    Function(double) onChanged,
    String description,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title),
                Text(
                  value.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: ((max - min) * 10).round(),
              onChanged: onChanged,
            ),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleSetting(
    String title,
    bool value,
    Function(bool) onChanged,
    String description,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  void _resetToDefaults() {
    setState(() {
      _minCutoff = 1.0;
      _beta = 0.0;
      _dCutoff = 1.0;
      _maxAngleDelta = 30.0;
      _highPerformanceMode = false;
      _targetFps = 30;
    });
    _saveSettings();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已重置为默认值')),
    );
  }
}