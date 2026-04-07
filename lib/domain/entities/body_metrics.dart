/// 人体度量数据
/// 
/// 存储校准后的人体尺寸信息，用于归一化不同用户的动作幅度
class BodyMetrics {
  /// 肩宽（归一化坐标）
  final double shoulderWidth;
  
  /// 缩放因子 = 实际肩宽 / 标准肩宽
  final double scaleFactor;
  
  /// 左臂长度（归一化坐标）
  final double leftArmLength;
  
  /// 右臂长度（归一化坐标）
  final double rightArmLength;
  
  /// 校准时间戳
  final DateTime calibratedAt;

  const BodyMetrics({
    required this.shoulderWidth,
    required this.scaleFactor,
    required this.leftArmLength,
    required this.rightArmLength,
    required this.calibratedAt,
  });

  /// 标准肩宽基准值
  static const double baselineShoulderWidth = 0.35;

  /// 创建默认的人体度量
  factory BodyMetrics.defaults() {
    return BodyMetrics(
      shoulderWidth: baselineShoulderWidth,
      scaleFactor: 1.0,
      leftArmLength: 0.42, // 肩宽的约1.2倍
      rightArmLength: 0.42,
      calibratedAt: DateTime.now(),
    );
  }

  /// 从Map创建
  factory BodyMetrics.fromMap(Map<String, dynamic> map) {
    return BodyMetrics(
      shoulderWidth: (map['shoulderWidth'] as num?)?.toDouble() ?? baselineShoulderWidth,
      scaleFactor: (map['scaleFactor'] as num?)?.toDouble() ?? 1.0,
      leftArmLength: (map['leftArmLength'] as num?)?.toDouble() ?? 0.42,
      rightArmLength: (map['rightArmLength'] as num?)?.toDouble() ?? 0.42,
      calibratedAt: map['calibratedAt'] != null 
          ? DateTime.parse(map['calibratedAt'] as String)
          : DateTime.now(),
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'shoulderWidth': shoulderWidth,
      'scaleFactor': scaleFactor,
      'leftArmLength': leftArmLength,
      'rightArmLength': rightArmLength,
      'calibratedAt': calibratedAt.toIso8601String(),
    };
  }

  /// 平均臂长
  double get averageArmLength => (leftArmLength + rightArmLength) / 2;

  /// 是否有效
  bool get isValid => shoulderWidth > 0 && scaleFactor > 0;

  /// 复制并修改
  BodyMetrics copyWith({
    double? shoulderWidth,
    double? scaleFactor,
    double? leftArmLength,
    double? rightArmLength,
    DateTime? calibratedAt,
  }) {
    return BodyMetrics(
      shoulderWidth: shoulderWidth ?? this.shoulderWidth,
      scaleFactor: scaleFactor ?? this.scaleFactor,
      leftArmLength: leftArmLength ?? this.leftArmLength,
      rightArmLength: rightArmLength ?? this.rightArmLength,
      calibratedAt: calibratedAt ?? this.calibratedAt,
    );
  }

  @override
  String toString() {
    return 'BodyMetrics(shoulderWidth: ${shoulderWidth.toStringAsFixed(3)}, '
        'scaleFactor: ${scaleFactor.toStringAsFixed(3)}, '
        'leftArm: ${leftArmLength.toStringAsFixed(3)}, '
        'rightArm: ${rightArmLength.toStringAsFixed(3)})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BodyMetrics &&
        other.shoulderWidth == shoulderWidth &&
        other.scaleFactor == scaleFactor &&
        other.leftArmLength == leftArmLength &&
        other.rightArmLength == rightArmLength;
  }

  @override
  int get hashCode => Object.hash(shoulderWidth, scaleFactor, leftArmLength, rightArmLength);
}