import 'package:audioplayers/audioplayers.dart';
import '../entities/gesture_type.dart';

/// 音效服务
/// 
/// 管理手势触发的音效播放
class SoundService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  /// 音效是否已初始化
  bool _isInitialized = false;
  
  /// 音量
  double _volume = 1.0;
  
  /// 是否静音
  bool _isMuted = false;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 当前音量
  double get volume => _volume;
  
  /// 是否静音
  bool get isMuted => _isMuted;

  /// 初始化音效服务
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // 设置音量
    await _audioPlayer.setVolume(_volume);
    
    _isInitialized = true;
  }

  /// 播放手势音效
  Future<void> playGestureSound(GestureType gesture) async {
    if (!_isInitialized || _isMuted) return;
    
    final soundPath = _getSoundPath(gesture);
    if (soundPath == null) return;
    
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(soundPath));
    } catch (e) {
      // 音效文件可能不存在，静默失败
      print('Sound playback failed: $e');
    }
  }

  /// 播放指定音效
  Future<void> playSound(String soundName) async {
    if (!_isInitialized || _isMuted) return;
    
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/$soundName.mp3'));
    } catch (e) {
      print('Sound playback failed: $e');
    }
  }

  /// 获取手势对应的音效路径
  String? _getSoundPath(GestureType gesture) {
    return 'sounds/${gesture.soundName}.mp3';
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(_volume);
  }

  /// 静音/取消静音
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _audioPlayer.setVolume(_isMuted ? 0.0 : _volume);
  }

  /// 设置静音状态
  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    await _audioPlayer.setVolume(_isMuted ? 0.0 : _volume);
  }

  /// 停止播放
  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  /// 释放资源
  void dispose() {
    _audioPlayer.dispose();
    _isInitialized = false;
  }
}

/// 音效类型枚举
enum SoundType {
  /// 举手
  handRaise('raise_hand'),
  
  /// 挥手
  wave('wave'),
  
  /// 拍手
  clap('clap'),
  
  /// 双手高举
  handsUp('hands_up'),
  
  /// 双手张开
  armsOpen('arms_open'),
  
  /// 校准成功
  calibrationSuccess('calibration_success'),
  
  /// 校准失败
  calibrationFailed('calibration_failed'),
  
  /// 按钮点击
  buttonClick('button_click');

  final String fileName;
  const SoundType(this.fileName);
}