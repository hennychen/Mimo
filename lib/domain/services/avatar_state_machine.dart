/// 角色状态枚举
enum AvatarState {
  /// 待机状态 - 没有检测到人体
  idle,
  
  /// 校准中
  calibrating,
  
  /// 追踪中 - 正常跟踪人体动作
  tracking,
  
  /// 低置信度 - 部分关键点不可见
  lowConfidence,
  
  /// 暂停
  paused,
}

/// 状态转换规则
class AvatarStateMachine {
  AvatarState _currentState = AvatarState.idle;
  
  /// 置信度阈值 - 低于此值进入低置信度状态
  final double lowConfidenceThreshold;
  
  /// 无检测帧数阈值 - 超过此帧数进入待机状态
  final int noDetectionFrameThreshold;
  
  /// 连续无检测帧数
  int _noDetectionFrames = 0;
  
  /// 状态变化回调
  void Function(AvatarState oldState, AvatarState newState)? onStateChanged;

  AvatarStateMachine({
    this.lowConfidenceThreshold = 0.4,
    this.noDetectionFrameThreshold = 30,
  });

  /// 当前状态
  AvatarState get currentState => _currentState;

  /// 处理帧结果
  AvatarState processFrame({
    required bool hasPose,
    required double confidence,
    required bool isPaused,
    required bool isCalibrating,
  }) {
    // 暂停状态优先
    if (isPaused) {
      _transitionTo(AvatarState.paused);
      return _currentState;
    }
    
    // 校准状态
    if (isCalibrating) {
      _transitionTo(AvatarState.calibrating);
      return _currentState;
    }
    
    // 无姿态检测
    if (!hasPose) {
      _noDetectionFrames++;
      if (_noDetectionFrames >= noDetectionFrameThreshold) {
        _transitionTo(AvatarState.idle);
      }
      return _currentState;
    }
    
    // 重置无检测帧数
    _noDetectionFrames = 0;
    
    // 根据置信度决定状态
    if (confidence < lowConfidenceThreshold) {
      _transitionTo(AvatarState.lowConfidence);
    } else {
      _transitionTo(AvatarState.tracking);
    }
    
    return _currentState;
  }

  /// 状态转换
  void _transitionTo(AvatarState newState) {
    if (_currentState == newState) return;
    
    final oldState = _currentState;
    _currentState = newState;
    
    onStateChanged?.call(oldState, newState);
  }

  /// 强制设置状态
  void forceState(AvatarState state) {
    _transitionTo(state);
  }

  /// 重置状态机
  void reset() {
    _currentState = AvatarState.idle;
    _noDetectionFrames = 0;
  }

  /// 是否在活动状态（追踪或低置信度）
  bool get isActive => _currentState == AvatarState.tracking || 
                       _currentState == AvatarState.lowConfidence;

  /// 是否需要待机动画
  bool get needsIdleAnimation => _currentState == AvatarState.idle ||
                                  _currentState == AvatarState.paused;
}