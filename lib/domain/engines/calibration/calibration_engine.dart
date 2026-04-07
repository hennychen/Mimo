import 'dart:math' as math;
import '../../entities/body_metrics.dart';
import '../../entities/joint_type.dart';
import '../../entities/landmark.dart';
import '../../../core/constants/app_constants.dart';

/// 校准状态
enum CalibrationStatus {
  /// 等待开始
  waiting,

  /// 检测中（检测人体）
  detecting,

  /// 检测到T-Pose
  tPoseDetected,

  /// 进行中（正在校准）
  calibrating,

  /// 进行中
  inProgress,

  /// 检测到T-Pose，正在验证
  verifying,

  /// 成功
  success,

  /// 失败
  failed,
}

/// 校准结果
class CalibrationResult {
  /// 状态
  final CalibrationStatus status;
  
  /// 人体度量数据
  final BodyMetrics? metrics;
  
  /// 错误信息
  final String? errorMessage;
  
  /// 耗时（毫秒）
  final int durationMs;

  const CalibrationResult({
    required this.status,
    this.metrics,
    this.errorMessage,
    this.durationMs = 0,
  });

  /// 是否成功
  bool get isSuccess => status == CalibrationStatus.success;
}

/// 校准引擎
/// 
/// 处理T-Pose校准流程，计算人体度量数据
class CalibrationEngine {
  /// 校准状态
  CalibrationStatus _status = CalibrationStatus.waiting;
  
  /// 开始时间
  DateTime? _startTime;
  
  /// 检测到T-Pose的连续帧数
  int _tPoseDetectedFrames = 0;
  
  /// 所需的连续T-Pose帧数
  final int requiredTPoseFrames;
  
  /// T-Pose手臂角度阈值（度）
  final double armAngleThreshold;
  
  /// 超时时间（秒）
  final int timeoutSeconds;
  
  /// 上一次检测到的关键点（用于校准）
  // ignore: unused_field
  Map<JointType, Landmark>? _lastValidJoints;

  CalibrationEngine({
    this.requiredTPoseFrames = AppConstants.calibrationHoldFrames,
    this.armAngleThreshold = AppConstants.calibrationArmAngleThreshold,
    this.timeoutSeconds = AppConstants.calibrationTimeoutSeconds,
  });

  /// 当前状态
  CalibrationStatus get status => _status;
  
  /// 是否正在校准
  bool get isCalibrating => _status == CalibrationStatus.inProgress || 
                             _status == CalibrationStatus.verifying;
  
  /// 已用时间（秒）
  int get elapsedSeconds {
    if (_startTime == null) return 0;
    return DateTime.now().difference(_startTime!).inSeconds;
  }
  
  /// 是否超时
  bool get isTimeout => elapsedSeconds >= timeoutSeconds;

  /// 开始校准
  void start() {
    _status = CalibrationStatus.inProgress;
    _startTime = DateTime.now();
    _tPoseDetectedFrames = 0;
    _lastValidJoints = null;
  }

  /// 处理帧
  /// 
  /// 参数:
  /// - [joints] 检测到的关键点
  /// 返回: 校准结果
  CalibrationResult processFrame(Map<JointType, Landmark> joints) {
    if (_status == CalibrationStatus.success || _status == CalibrationStatus.failed) {
      return CalibrationResult(status: _status);
    }
    
    // 检查超时
    if (isTimeout) {
      _status = CalibrationStatus.failed;
      return CalibrationResult(
        status: CalibrationStatus.failed,
        errorMessage: '校准超时，请确保光线充足并站在相机前方',
        durationMs: elapsedSeconds * 1000,
      );
    }
    
    // 检查是否有足够的关键点
    if (!_hasRequiredJoints(joints)) {
      return CalibrationResult(
        status: CalibrationStatus.inProgress,
        errorMessage: '请确保上半身完全在画面中',
      );
    }
    
    // 检查T-Pose
    final isTPose = _checkTPose(joints);
    
    if (isTPose) {
      _tPoseDetectedFrames++;
      _lastValidJoints = joints;
      
      _status = CalibrationStatus.verifying;
      
      if (_tPoseDetectedFrames >= requiredTPoseFrames) {
        // 校准成功
        final metrics = _calculateMetrics(joints);
        _status = CalibrationStatus.success;
        
        return CalibrationResult(
          status: CalibrationStatus.success,
          metrics: metrics,
          durationMs: elapsedSeconds * 1000,
        );
      }
      
      return CalibrationResult(
        status: CalibrationStatus.verifying,
        errorMessage: '保持姿势 ${requiredTPoseFrames - _tPoseDetectedFrames} 帧',
      );
    } else {
      _tPoseDetectedFrames = 0;
      _status = CalibrationStatus.inProgress;
      
      return CalibrationResult(
        status: CalibrationStatus.inProgress,
        errorMessage: '请站成T-Pose姿势（双臂侧平举）',
      );
    }
  }

  /// 检查是否有必需的关键点
  bool _hasRequiredJoints(Map<JointType, Landmark> joints) {
    final required = [
      JointType.leftShoulder,
      JointType.rightShoulder,
      JointType.leftElbow,
      JointType.rightElbow,
    ];
    
    for (final joint in required) {
      final landmark = joints[joint];
      if (landmark == null || landmark.visibility < 0.5) {
        return false;
      }
    }
    
    return true;
  }

  /// 检查是否是T-Pose
  bool _checkTPose(Map<JointType, Landmark> joints) {
    final leftShoulder = joints[JointType.leftShoulder]!;
    final leftElbow = joints[JointType.leftElbow]!;
    final rightShoulder = joints[JointType.rightShoulder]!;
    final rightElbow = joints[JointType.rightElbow]!;
    
    // 计算左臂角度
    final leftArmAngle = _calculateArmAngle(leftShoulder, leftElbow);
    
    // 计算右臂角度
    final rightArmAngle = _calculateArmAngle(rightShoulder, rightElbow);
    
    // 阈值（弧度）
    final threshold = armAngleThreshold * math.pi / 180.0;
    
    // 检查手臂是否水平伸展
    // 水平方向角度约为0或π
    final leftHorizontal = leftArmAngle.abs() < threshold || 
                          (leftArmAngle - math.pi).abs() < threshold ||
                          (leftArmAngle + math.pi).abs() < threshold;
    
    final rightHorizontal = rightArmAngle.abs() < threshold ||
                           (rightArmAngle - math.pi).abs() < threshold ||
                           (rightArmAngle + math.pi).abs() < threshold;
    
    // 检查肘部是否伸展（手腕位置检查）
    final leftWrist = joints[JointType.leftWrist];
    final rightWrist = joints[JointType.rightWrist];
    
    bool elbowsExtended = true;
    if (leftWrist != null && leftWrist.visibility > 0.5) {
      final leftElbowExtended = (leftWrist.y - leftElbow.y).abs() < 0.1;
      elbowsExtended = elbowsExtended && leftElbowExtended;
    }
    if (rightWrist != null && rightWrist.visibility > 0.5) {
      final rightElbowExtended = (rightWrist.y - rightElbow.y).abs() < 0.1;
      elbowsExtended = elbowsExtended && rightElbowExtended;
    }
    
    return leftHorizontal && rightHorizontal && elbowsExtended;
  }

  /// 计算手臂角度
  double _calculateArmAngle(Landmark shoulder, Landmark elbow) {
    return math.atan2(elbow.y - shoulder.y, elbow.x - shoulder.x);
  }

  /// 计算人体度量数据
  BodyMetrics _calculateMetrics(Map<JointType, Landmark> joints) {
    final leftShoulder = joints[JointType.leftShoulder]!;
    final rightShoulder = joints[JointType.rightShoulder]!;
    
    // 肩宽
    final shoulderWidth = _distance(leftShoulder, rightShoulder);
    
    // 缩放因子
    final scaleFactor = shoulderWidth / BodyMetrics.baselineShoulderWidth;
    
    // 臂长
    double leftArmLength = 0.0;
    double rightArmLength = 0.0;
    
    final leftElbow = joints[JointType.leftElbow];
    final leftWrist = joints[JointType.leftWrist];
    final rightElbow = joints[JointType.rightElbow];
    final rightWrist = joints[JointType.rightWrist];
    
    if (leftElbow != null) {
      leftArmLength = _distance(leftShoulder, leftElbow);
      if (leftWrist != null) {
        leftArmLength += _distance(leftElbow, leftWrist);
      }
    }
    
    if (rightElbow != null) {
      rightArmLength = _distance(rightShoulder, rightElbow);
      if (rightWrist != null) {
        rightArmLength += _distance(rightElbow, rightWrist);
      }
    }
    
    return BodyMetrics(
      shoulderWidth: shoulderWidth,
      scaleFactor: scaleFactor.clamp(0.5, 2.0),
      leftArmLength: leftArmLength,
      rightArmLength: rightArmLength,
      calibratedAt: DateTime.now(),
    );
  }

  /// 计算两点距离
  double _distance(Landmark a, Landmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// 重置
  void reset() {
    _status = CalibrationStatus.waiting;
    _startTime = null;
    _tPoseDetectedFrames = 0;
    _lastValidJoints = null;
  }
}