/// 姿态关键点实体
/// 
/// 表示MediaPipe检测到的身体关键点，包含归一化坐标和置信度
class Landmark {
  /// x坐标 (0~1 归一化坐标)
  final double x;
  
  /// y坐标 (0~1 归一化坐标)
  final double y;
  
  /// z坐标 (深度信息，表示相对于髋部的距离)
  final double z;
  
  /// 可见度/置信度 (0~1)
  final double visibility;

  const Landmark({
    required this.x,
    required this.y,
    required this.z,
    required this.visibility,
  });

  /// 从Map创建Landmark
  factory Landmark.fromMap(Map<String, dynamic> map) {
    return Landmark(
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
      z: (map['z'] as num?)?.toDouble() ?? 0.0,
      visibility: (map['visibility'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// 复制并修改
  Landmark copyWith({
    double? x,
    double? y,
    double? z,
    double? visibility,
  }) {
    return Landmark(
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      visibility: visibility ?? this.visibility,
    );
  }

  /// 计算与另一个Landmark的距离
  double distanceTo(Landmark other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }

  /// 判断是否有效（置信度高于阈值）
  bool isValid([double threshold = 0.5]) => visibility > threshold;

  @override
  String toString() {
    return 'Landmark(x: ${x.toStringAsFixed(3)}, y: ${y.toStringAsFixed(3)}, '
        'z: ${z.toStringAsFixed(3)}, visibility: ${visibility.toStringAsFixed(3)})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Landmark &&
        other.x == x &&
        other.y == y &&
        other.z == z &&
        other.visibility == visibility;
  }

  @override
  int get hashCode => Object.hash(x, y, z, visibility);
}

/// 数学工具函数
double sqrt(double x) {
  if (x < 0) return 0;
  return x == 0 ? 0 : x.sqrt();
}

extension on double {
  double sqrt() => this > 0 ? this : 0;
}