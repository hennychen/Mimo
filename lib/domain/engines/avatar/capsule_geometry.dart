import 'dart:ui';
import 'dart:math' as math;

/// 胶囊形几何计算工具
///
/// 提供胶囊形区域的几何计算，用于肢体裁剪
class CapsuleGeometry {
  /// 起点（关节A）
  final Offset jointA;
  
  /// 终点（关节B）
  final Offset jointB;
  
  /// 胶囊半径
  final double radius;

  CapsuleGeometry({
    required this.jointA,
    required this.jointB,
    required this.radius,
  });

  /// 计算线段向量
  Offset get segmentVector => jointB - jointA;

  /// 计算线段长度
  double get segmentLength => segmentVector.distance;

  /// 计算线段长度的平方（避免sqrt）
  double get segmentLengthSquared {
    final v = segmentVector;
    return v.dx * v.dx + v.dy * v.dy;
  }

  /// 计算线段方向单位向量
  Offset get direction {
    final len = segmentLength;
    if (len == 0) return Offset.zero;
    return Offset(segmentVector.dx / len, segmentVector.dy / len);
  }

  /// 计算垂直于线段的单位向量
  Offset get perpendicular {
    final d = direction;
    return Offset(-d.dy, d.dx);
  }

  /// 计算点到线段的最短距离
  ///
  /// 使用投影计算，返回点到线段上最近点的距离
  double distanceToSegment(Offset point) {
    final ab = segmentVector;
    final ap = point - jointA;

    final abLenSq = segmentLengthSquared;
    if (abLenSq == 0) {
      // 两点重合，直接返回到A点的距离
      return ap.distance;
    }

    // 计算投影比例 t = (ap · ab) / |ab|^2
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLenSq;

    // t限制在[0, 1]范围内，确保最近点在线段上
    final tClamped = t.clamp(0.0, 1.0);

    // 计算线段上最近点
    final closest = Offset(
      jointA.dx + ab.dx * tClamped,
      jointA.dy + ab.dy * tClamped,
    );

    // 返回到最近点的距离
    return (point - closest).distance;
  }

  /// 判断点是否在胶囊形内部
  bool isInsideCapsule(Offset point) {
    return distanceToSegment(point) <= radius;
  }

  /// 计算胶囊形的外接矩形（用于性能优化）
  ///
  /// 只处理胶囊形覆盖的区域，减少90%计算量
  Rect computeBoundingBox(int imageWidth, int imageHeight) {
    final left = (math.min(jointA.dx, jointB.dx) - radius).clamp(0.0, imageWidth.toDouble());
    final right = (math.max(jointA.dx, jointB.dx) + radius).clamp(0.0, imageWidth.toDouble());
    final top = (math.min(jointA.dy, jointB.dy) - radius).clamp(0.0, imageHeight.toDouble());
    final bottom = (math.max(jointA.dy, jointB.dy) + radius).clamp(0.0, imageHeight.toDouble());

    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// 计算Bone Weight（距离衰减权重）
  ///
  /// 用于解决手臂与躯干的粘连问题
  /// 距离越远权重越低（指数衰减）
  double computeBoneWeight(Offset point, double decayFactor) {
    final dist = distanceToSegment(point);
    // 指数衰减：exp(-dist * decay)
    return math.exp(-dist * decayFactor);
  }

  /// 计算点到线段上最近点的位置（归一化，0-1）
  double getProjectionT(Offset point) {
    final ab = segmentVector;
    final ap = point - jointA;

    final abLenSq = segmentLengthSquared;
    if (abLenSq == 0) return 0.0;

    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLenSq;
    return t.clamp(0.0, 1.0);
  }

  /// 获取线段上指定比例位置的点
  Offset getPointAtT(double t) {
    final clampedT = t.clamp(0.0, 1.0);
    return Offset(
      jointA.dx + segmentVector.dx * clampedT,
      jointA.dy + segmentVector.dy * clampedT,
    );
  }
}

/// 区域构建器
///
/// 根据关节位置和身体比例计算各部位的裁剪区域
class RegionBuilder {
  /// 构建头部区域
  ///
  /// 以nose为中心，半径为shoulderWidth * 0.6
  static CapsuleGeometry buildHeadRegion({
    required Offset nose,
    required double shoulderWidth,
  }) {
    final headRadius = shoulderWidth * 0.6;
    // 头部使用圆形（退化胶囊：两点相同）
    return CapsuleGeometry(
      jointA: nose,
      jointB: nose,
      radius: headRadius,
    );
  }

  /// 构建躯干区域
  ///
  /// 从肩线到髋部中点
  static Rect buildTorsoRegion({
    required Offset leftShoulder,
    required Offset rightShoulder,
    required Offset hipCenter,
    required double shoulderWidth,
  }) {
    // 躯干宽度 = shoulderWidth * 1.2（略宽于肩）
    final torsoWidth = shoulderWidth * 1.2;
    
    // 计算躯干中心线
    final shoulderCenterX = (leftShoulder.dx + rightShoulder.dx) / 2;
    final shoulderTopY = math.min(leftShoulder.dy, rightShoulder.dy);
    
    // 构建躯干矩形
    final left = (shoulderCenterX - torsoWidth / 2).clamp(0.0, double.infinity);
    final right = (shoulderCenterX + torsoWidth / 2).clamp(0.0, double.infinity);
    final top = (shoulderTopY - shoulderWidth * 0.3).clamp(0.0, double.infinity);
    final bottom = hipCenter.dy + shoulderWidth * 0.2;

    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// 构建上臂区域
  ///
  /// 从肩到肘，宽度 = shoulderWidth * 0.25
  static CapsuleGeometry buildUpperArmRegion({
    required Offset shoulder,
    required Offset elbow,
    required double shoulderWidth,
  }) {
    final armRadius = shoulderWidth * 0.25 / 2;
    return CapsuleGeometry(
      jointA: shoulder,
      jointB: elbow,
      radius: armRadius,
    );
  }

  /// 构建下臂区域
  ///
  /// 从肘到腕，宽度 = shoulderWidth * 0.2
  static CapsuleGeometry buildLowerArmRegion({
    required Offset elbow,
    required Offset wrist,
    required double shoulderWidth,
  }) {
    final armRadius = shoulderWidth * 0.2 / 2;
    return CapsuleGeometry(
      jointA: elbow,
      jointB: wrist,
      radius: armRadius,
    );
  }

  /// 计算肩宽
  ///
  /// 从左肩到右肩的距离（像素坐标）
  static double computeShoulderWidth(Offset leftShoulder, Offset rightShoulder) {
    final dx = rightShoulder.dx - leftShoulder.dx;
    final dy = rightShoulder.dy - leftShoulder.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// 计算髋部中心点
  ///
  /// 从左右髋部关键点计算中心
  static Offset computeHipCenter(Offset leftHip, Offset rightHip) {
    return Offset(
      (leftHip.dx + rightHip.dx) / 2,
      (leftHip.dy + rightHip.dy) / 2,
    );
  }

  /// 将归一化坐标转换为像素坐标
  static Offset normalizedToPixel(Offset normalized, int width, int height) {
    return Offset(
      normalized.dx * width,
      normalized.dy * height,
    );
  }
}

/// Smoothstep函数
///
/// 用于边缘羽化的平滑过渡
class SmoothStep {
  /// 标准 smoothstep
  ///
  /// t = (x - edge0) / (edge1 - edge0)
  /// result = t² * (3 - 2t)
  static double apply(double x, double edge0, double edge1) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  /// 反向 smoothstep（从1到0）
  static double reverse(double x, double edge0, double edge1) {
    return 1.0 - apply(x, edge0, edge1);
  }

  /// 更平滑的 quintic smoothstep
  ///
  /// result = 6t⁵ - 15t⁴ + 10t³
  static double smoother(double x, double edge0, double edge1) {
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
  }
}