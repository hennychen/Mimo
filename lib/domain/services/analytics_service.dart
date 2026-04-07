import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 埋点事件类型
enum AnalyticsEventType {
  /// 应用启动
  appLaunch,
  
  /// 校准开始
  calibrationStart,
  
  /// 校准成功
  calibrationSuccess,
  
  /// 校准失败
  calibrationFailed,
  
  /// 手势识别
  gestureDetected,
  
  /// 相机切换
  cameraSwitch,
  
  /// 暂停
  pause,
  
  /// 恢复
  resume,
  
  /// 设置更改
  settingsChanged,
  
  /// 性能降级
  performanceDegradation,
  
  /// 会话结束
  sessionEnd,
}

/// 埋点事件
class AnalyticsEvent {
  /// 事件ID
  final String eventId;
  
  /// 事件类型
  final AnalyticsEventType eventType;
  
  /// 时间戳
  final DateTime timestamp;
  
  /// 事件属性
  final Map<String, dynamic> properties;
  
  /// 会话ID
  final String sessionId;

  const AnalyticsEvent({
    required this.eventId,
    required this.eventType,
    required this.timestamp,
    required this.properties,
    required this.sessionId,
  });

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'eventId': eventId,
      'eventType': eventType.name,
      'timestamp': timestamp.toIso8601String(),
      'properties': properties,
      'sessionId': sessionId,
    };
  }

  /// 从JSON创建
  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AnalyticsEvent(
      eventId: json['eventId'] as String,
      eventType: AnalyticsEventType.values.firstWhere(
        (e) => e.name == json['eventType'],
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      properties: Map<String, dynamic>.from(json['properties'] as Map),
      sessionId: json['sessionId'] as String,
    );
  }
}

/// 埋点服务
/// 
/// 记录用户行为和应用事件，支持离线存储
class AnalyticsService {
  /// UUID生成器
  final Uuid _uuid = const Uuid();
  
  /// SharedPreferences实例
  SharedPreferences? _prefs;
  
  /// 当前会话ID
  String? _currentSessionId;
  
  /// 会话开始时间
  DateTime? _sessionStartTime;
  
  /// 事件缓存
  final List<AnalyticsEvent> _eventCache = [];
  
  /// 最大缓存大小
  final int maxCacheSize;
  
  /// 存储键
  static const String _eventsKey = 'analytics_events';
  static const String _sessionIdKey = 'analytics_session_id';
  
  /// 是否已初始化
  bool _isInitialized = false;

  AnalyticsService({this.maxCacheSize = 100});

  /// 是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 当前会话ID
  String? get currentSessionId => _currentSessionId;
  
  /// 会话时长（秒）
  int? get sessionDuration {
    if (_sessionStartTime == null) return null;
    return DateTime.now().difference(_sessionStartTime!).inSeconds;
  }

  /// 初始化
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    
    // 加载缓存的事件
    await _loadCachedEvents();
    
    // 恢复或创建会话ID
    _currentSessionId = _prefs?.getString(_sessionIdKey);
    if (_currentSessionId == null) {
      _currentSessionId = _uuid.v4();
      await _prefs?.setString(_sessionIdKey, _currentSessionId!);
    }
    
    _sessionStartTime = DateTime.now();
    _isInitialized = true;
  }

  /// 记录事件
  Future<void> logEvent(
    AnalyticsEventType eventType, {
    Map<String, dynamic>? properties,
  }) async {
    if (!_isInitialized || _currentSessionId == null) return;
    
    final event = AnalyticsEvent(
      eventId: _uuid.v4(),
      eventType: eventType,
      timestamp: DateTime.now(),
      properties: properties ?? {},
      sessionId: _currentSessionId!,
    );
    
    _eventCache.add(event);
    
    // 超过缓存大小时移除旧事件
    if (_eventCache.length > maxCacheSize) {
      _eventCache.removeAt(0);
    }
    
    // 保存到本地
    await _saveEvents();
  }

  /// 记录应用启动
  Future<void> logAppLaunch() async {
    await logEvent(AnalyticsEventType.appLaunch, properties: {
      'platform': defaultTargetPlatform.name,
    });
  }

  /// 记录校准开始
  Future<void> logCalibrationStart() async {
    await logEvent(AnalyticsEventType.calibrationStart);
  }

  /// 记录校准结果
  Future<void> logCalibrationResult(bool success, {String? errorReason}) async {
    await logEvent(
      success ? AnalyticsEventType.calibrationSuccess : AnalyticsEventType.calibrationFailed,
      properties: {
        'success': success,
        if (errorReason != null) 'errorReason': errorReason,
      },
    );
  }

  /// 记录手势识别
  Future<void> logGestureDetected(String gestureType) async {
    await logEvent(AnalyticsEventType.gestureDetected, properties: {
      'gestureType': gestureType,
    });
  }

  /// 记录相机切换
  Future<void> logCameraSwitch() async {
    await logEvent(AnalyticsEventType.cameraSwitch);
  }

  /// 记录暂停/恢复
  Future<void> logPauseResume(bool isPaused) async {
    await logEvent(isPaused ? AnalyticsEventType.pause : AnalyticsEventType.resume);
  }

  /// 记录设置更改
  Future<void> logSettingsChanged(String settingKey, dynamic value) async {
    await logEvent(AnalyticsEventType.settingsChanged, properties: {
      'settingKey': settingKey,
      'value': value.toString(),
    });
  }

  /// 记录性能降级
  Future<void> logPerformanceDegradation(double fps, String reason) async {
    await logEvent(AnalyticsEventType.performanceDegradation, properties: {
      'fps': fps,
      'reason': reason,
    });
  }

  /// 结束会话
  Future<void> endSession() async {
    if (!_isInitialized || _currentSessionId == null) return;
    
    final duration = sessionDuration ?? 0;
    
    await logEvent(AnalyticsEventType.sessionEnd, properties: {
      'durationSeconds': duration,
    });
    
    // 生成新会话ID
    _currentSessionId = _uuid.v4();
    await _prefs?.setString(_sessionIdKey, _currentSessionId!);
    _sessionStartTime = DateTime.now();
  }

  /// 获取缓存的事件列表
  List<AnalyticsEvent> getCachedEvents() {
    return List.unmodifiable(_eventCache);
  }

  /// 清除缓存
  Future<void> clearCache() async {
    _eventCache.clear();
    await _prefs?.remove(_eventsKey);
  }

  /// 加载缓存的事件
  Future<void> _loadCachedEvents() async {
    final eventsJson = _prefs?.getString(_eventsKey);
    if (eventsJson == null) return;
    
    try {
      final List<dynamic> eventsList = jsonDecode(eventsJson);
      for (final json in eventsList) {
        _eventCache.add(AnalyticsEvent.fromJson(json));
      }
    } catch (e) {
      // 解析失败，清除缓存
      await clearCache();
    }
  }

  /// 保存事件到本地
  Future<void> _saveEvents() async {
    if (_prefs == null) return;
    
    final eventsJson = jsonEncode(
      _eventCache.map((e) => e.toJson()).toList(),
    );
    await _prefs!.setString(_eventsKey, eventsJson);
  }

  /// 释放资源
  void dispose() {
    _eventCache.clear();
    _isInitialized = false;
  }
}