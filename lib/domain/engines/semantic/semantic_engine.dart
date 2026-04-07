import 'dart:math' as math;
import '../../entities/gesture_type.dart';
import '../../entities/joint_type.dart';
import '../../entities/landmark.dart';

/// 动作语义识别引擎
/// 
/// 识别特定动作手势，用于触发音效、表情等互动反馈
class SemanticEngine {
  /// 手势检测的历史记录
  final Map<GestureType, List<bool>> _gestureHistory = {};
  
  /// 挥手检测的x坐标历史
  final List<double> _waveHistoryX = [];
  
  /// 挥手检测所需的历史长度
  static const int waveHistoryLength = 30;
  
  /// 挥手周期阈值
  static const int waveCycleThreshold = 3;
  
  /// 举手检测所需的持续帧数
  static const int handRaiseFrames = 3;

  SemanticEngine() {
    // 初始化历史记录
    for (final gesture in GestureType.values) {
      _gestureHistory[gesture] = [];
    }
  }

  /// 检测手势
  GestureType? detect(Map<JointType, Landmark> joints) {
    // 检测举手
    if (_isHandRaised(joints, left: true) || _isHandRaised(joints, left: false)) {
      _recordGesture(GestureType.handRaise, true);
      if (_checkGestureStable(GestureType.handRaise)) {
        return GestureType.handRaise;
      }
    } else {
      _recordGesture(GestureType.handRaise, false);
    }

    // 检测双手张开
    if (_isArmsOpen(joints)) {
      _recordGesture(GestureType.armsOpen, true);
      if (_checkGestureStable(GestureType.armsOpen)) {
        return GestureType.armsOpen;
      }
    } else {
      _recordGesture(GestureType.armsOpen, false);
    }

    // 检测挥手
    if (_isWaving(joints)) {
      return GestureType.wave;
    }

    // 检测拍手
    if (_isClapping(joints)) {
      _recordGesture(GestureType.clap, true);
      if (_checkGestureStable(GestureType.clap)) {
        return GestureType.clap;
      }
    } else {
      _recordGesture(GestureType.clap, false);
    }

    // 检测双手高举
    if (_isHandsUp(joints)) {
      _recordGesture(GestureType.handsUp, true);
      if (_checkGestureStable(GestureType.handsUp)) {
        return GestureType.handsUp;
      }
    } else {
      _recordGesture(GestureType.handsUp, false);
    }

    return null;
  }

  /// 检测举手
  /// 
  /// 条件：手腕.y < 肩膀.y（屏幕坐标系，y轴向下）
  bool _isHandRaised(Map<JointType, Landmark> joints, {required bool left}) {
    final wrist = joints[left ? JointType.leftWrist : JointType.rightWrist];
    final shoulder = joints[left ? JointType.leftShoulder : JointType.rightShoulder];
    
    if (wrist == null || shoulder == null) return false;
    
    // 置信度检查
    if (wrist.visibility < 0.5 || shoulder.visibility < 0.5) return false;
    
    // 手腕高于肩膀（y值更小）
    return wrist.y < shoulder.y - 0.05; // 添加一个小阈值避免误触
  }

  /// 检测双手张开
  /// 
  /// 条件：双腕距离 > 阈值
  bool _isArmsOpen(Map<JointType, Landmark> joints) {
    final leftWrist = joints[JointType.leftWrist];
    final rightWrist = joints[JointType.rightWrist];
    final leftShoulder = joints[JointType.leftShoulder];
    final rightShoulder = joints[JointType.rightShoulder];
    
    if (leftWrist == null || rightWrist == null) return false;
    if (leftShoulder == null || rightShoulder == null) return false;
    
    // 置信度检查
    if (leftWrist.visibility < 0.5 || rightWrist.visibility < 0.5) return false;
    
    // 计算肩宽作为参考
    final shoulderWidth = _distance(leftShoulder, rightShoulder);
    
    // 双腕距离大于肩宽的1.5倍
    final wristDistance = _distance(leftWrist, rightWrist);
    
    return wristDistance > shoulderWidth * 1.5;
  }

  /// 检测挥手
  /// 
  /// 条件：x方向周期变化
  bool _isWaving(Map<JointType, Landmark> joints) {
    // 使用右手检测挥手
    final wrist = joints[JointType.rightWrist];
    if (wrist == null || wrist.visibility < 0.5) return false;
    
    // 记录x坐标历史
    _waveHistoryX.add(wrist.x);
    if (_waveHistoryX.length > waveHistoryLength) {
      _waveHistoryX.removeAt(0);
    }
    
    // 检测周期变化
    if (_waveHistoryX.length < waveHistoryLength) return false;
    
    // 计算峰值数量
    int peaks = 0;
    for (int i = 1; i < _waveHistoryX.length - 1; i++) {
      if (_waveHistoryX[i] > _waveHistoryX[i - 1] && 
          _waveHistoryX[i] > _waveHistoryX[i + 1]) {
        peaks++;
      }
      if (_waveHistoryX[i] < _waveHistoryX[i - 1] && 
          _waveHistoryX[i] < _waveHistoryX[i + 1]) {
        peaks++;
      }
    }
    
    return peaks >= waveCycleThreshold;
  }

  /// 检测拍手
  /// 
  /// 条件：双手靠近
  bool _isClapping(Map<JointType, Landmark> joints) {
    final leftWrist = joints[JointType.leftWrist];
    final rightWrist = joints[JointType.rightWrist];
    
    if (leftWrist == null || rightWrist == null) return false;
    
    // 置信度检查
    if (leftWrist.visibility < 0.5 || rightWrist.visibility < 0.5) return false;
    
    // 双手距离小于阈值
    final distance = _distance(leftWrist, rightWrist);
    
    return distance < 0.08; // 归一化坐标下的距离
  }

  /// 检测双手高举
  /// 
  /// 条件：双手都高于头顶
  bool _isHandsUp(Map<JointType, Landmark> joints) {
    final leftWrist = joints[JointType.leftWrist];
    final rightWrist = joints[JointType.rightWrist];
    final nose = joints[JointType.nose];
    
    if (leftWrist == null || rightWrist == null || nose == null) return false;
    
    // 置信度检查
    if (leftWrist.visibility < 0.5 || rightWrist.visibility < 0.5) return false;
    
    // 双手都高于鼻子
    return leftWrist.y < nose.y && rightWrist.y < nose.y;
  }

  /// 记录手势历史
  void _recordGesture(GestureType gesture, bool detected) {
    _gestureHistory[gesture]!.add(detected);
    if (_gestureHistory[gesture]!.length > handRaiseFrames) {
      _gestureHistory[gesture]!.removeAt(0);
    }
  }

  /// 检查手势是否稳定（连续检测到）
  bool _checkGestureStable(GestureType gesture) {
    final history = _gestureHistory[gesture]!;
    if (history.length < handRaiseFrames) return false;
    
    // 所有帧都检测到
    return history.every((detected) => detected);
  }

  /// 计算两点距离
  double _distance(Landmark a, Landmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// 重置历史
  void reset() {
    for (final gesture in GestureType.values) {
      _gestureHistory[gesture]!.clear();
    }
    _waveHistoryX.clear();
  }
}