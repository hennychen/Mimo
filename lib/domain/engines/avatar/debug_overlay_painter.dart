import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../entities/joint_type.dart';
import '../../entities/landmark.dart';
import '../../entities/body_part.dart';
import 'capsule_geometry.dart';

/// 调试可视化配置
class DebugOverlayConfig {
  /// 是否显示骨骼点
  final bool showJoints;

  /// 是否显示胶囊区域
  final bool showCapsules;

  /// 是否显示BoundingBox
  final bool showBoundingBoxes;

  /// 是否显示Mask叠加
  final bool showMaskOverlay;

  /// 是否显示部位标签
  final bool showLabels;

  /// 骨骼点颜色
  final Color jointColor;

  /// 胶囊边界颜色
  final Color capsuleColor;

  /// BoundingBox颜色
  final Color bboxColor;

  /// Mask叠加颜色
  final Color maskOverlayColor;

  const DebugOverlayConfig({
    this.showJoints = true,
    this.showCapsules = true,
    this.showBoundingBoxes = true,
    this.showMaskOverlay = false,
    this.showLabels = true,
    this.jointColor = Colors.red,
    this.capsuleColor = Colors.blue,
    this.bboxColor = Colors.green,
    this.maskOverlayColor = Colors.yellow,
  });

  /// 默认配置
  static const DebugOverlayConfig defaultConfig = DebugOverlayConfig();

  /// 详细配置（显示所有）
  static const DebugOverlayConfig detailed = DebugOverlayConfig(
    showJoints: true,
    showCapsules: true,
    showBoundingBoxes: true,
    showMaskOverlay: true,
    showLabels: true,
  );

  /// 简化配置（只显示骨骼）
  static const DebugOverlayConfig simple = DebugOverlayConfig(
    showJoints: true,
    showCapsules: false,
    showBoundingBoxes: false,
    showMaskOverlay: false,
    showLabels: true,
  );
}

/// 调试可视化Painter
///
/// 绘制骨骼点、胶囊区域、BoundingBox等调试信息
class DebugOverlayPainter extends CustomPainter {
  /// 关节点映射（像素坐标）
  final Map<JointType, Offset> joints;

  /// 胶囊几何列表
  final List<CapsuleGeometry> capsules;

  /// BoundingBox列表
  final List<Rect> boundingBoxes;

  /// 身体部位标签映射
  final Map<BodyPart, Rect> partRegions;

  /// Mask数据（可选）
  final Uint8List? mask;

  /// Mask尺寸
  final int maskWidth;
  final int maskHeight;

  /// 调试配置
  final DebugOverlayConfig config;

  DebugOverlayPainter({
    required this.joints,
    this.capsules = const [],
    this.boundingBoxes = const [],
    this.partRegions = const {},
    this.mask,
    this.maskWidth = 0,
    this.maskHeight = 0,
    this.config = DebugOverlayConfig.defaultConfig,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 绘制Mask叠加
    if (config.showMaskOverlay && mask != null) {
      _drawMaskOverlay(canvas, size);
    }

    // 2. 绘制BoundingBox
    if (config.showBoundingBoxes) {
      _drawBoundingBoxes(canvas);
    }

    // 3. 绘制胶囊区域
    if (config.showCapsules) {
      _drawCapsules(canvas);
    }

    // 4. 绘制骨骼点
    if (config.showJoints) {
      _drawJoints(canvas);
    }

    // 5. 绘制部位标签
    if (config.showLabels) {
      _drawLabels(canvas);
    }
  }

  /// 绘制骨骼点
  void _drawJoints(Canvas canvas) {
    final paint = Paint()
      ..color = config.jointColor
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // 绘制骨骼连接线
    final linePaint = Paint()
      ..color = config.jointColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // 左臂连线
    _drawBoneLine(canvas, linePaint, JointType.leftShoulder, JointType.leftElbow);
    _drawBoneLine(canvas, linePaint, JointType.leftElbow, JointType.leftWrist);

    // 右臂连线
    _drawBoneLine(canvas, linePaint, JointType.rightShoulder, JointType.rightElbow);
    _drawBoneLine(canvas, linePaint, JointType.rightElbow, JointType.rightWrist);

    // 肩线
    _drawBoneLine(canvas, linePaint, JointType.leftShoulder, JointType.rightShoulder);

    // 绘制关节点
    for (final entry in joints.entries) {
      final point = entry.value;

      // 外圈（白色描边）
      canvas.drawCircle(point, 6, strokePaint);
      // 内圈（彩色填充）
      canvas.drawCircle(point, 5, paint);

      // 绘制关节名称
      final textPainter = TextPainter(
        text: TextSpan(
          text: entry.key.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, point + const Offset(8, -8));
    }
  }

  /// 绘制骨骼连接线
  void _drawBoneLine(
    Canvas canvas,
    Paint paint,
    JointType from,
    JointType to,
  ) {
    final fromPoint = joints[from];
    final toPoint = joints[to];
    if (fromPoint != null && toPoint != null) {
      canvas.drawLine(fromPoint, toPoint, paint);
    }
  }

  /// 绘制胶囊区域
  void _drawCapsules(Canvas canvas) {
    final fillPaint = Paint()
      ..color = config.capsuleColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = config.capsuleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final capsule in capsules) {
      _drawCapsule(canvas, capsule, fillPaint, strokePaint);
    }
  }

  /// 绘制单个胶囊
  void _drawCapsule(
    Canvas canvas,
    CapsuleGeometry capsule,
    Paint fillPaint,
    Paint strokePaint,
  ) {
    final a = capsule.jointA;
    final b = capsule.jointB;
    final r = capsule.radius;

    if (a == b) {
      // 圆形（头部）
      canvas.drawCircle(a, r, fillPaint);
      canvas.drawCircle(a, r, strokePaint);
    } else {
      // 胶囊形
      final path = _createCapsulePath(a, b, r);
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);
    }
  }

  /// 创建胶囊形Path
  Path _createCapsulePath(Offset a, Offset b, double radius) {
    final path = Path();
    final direction = (b - a);
    final length = direction.distance;

    if (length == 0) {
      path.addOval(Rect.fromCircle(center: a, radius: radius));
      return path;
    }

    final unitDir = Offset(direction.dx / length, direction.dy / length);
    final perpDir = Offset(-unitDir.dy, unitDir.dx);

    // 计算胶囊端点
    final a1 = a + perpDir * radius;
    final a2 = a - perpDir * radius;
    final b1 = b + perpDir * radius;
    final b2 = b - perpDir * radius;

    path.moveTo(a1.dx, a1.dy);
    path.lineTo(b1.dx, b1.dy);

    // B端半圆
    path.arcToPoint(
      b2,
      radius: Radius.circular(radius),
      rotation: 0,
      largeArc: false,
      clockwise: false,
    );

    path.lineTo(a2.dx, a2.dy);

    // A端半圆
    path.arcToPoint(
      a1,
      radius: Radius.circular(radius),
      rotation: 0,
      largeArc: false,
      clockwise: false,
    );

    path.close();
    return path;
  }

  /// 绘制BoundingBox
  void _drawBoundingBoxes(Canvas canvas) {
    final paint = Paint()
      ..color = config.bboxColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final rect in boundingBoxes) {
      canvas.drawRect(rect, paint);

      // 绘制尺寸信息
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${rect.width.toInt()}x${rect.height.toInt()}',
          style: TextStyle(
            color: config.bboxColor,
            fontSize: 8,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, rect.topLeft + const Offset(2, -12));
    }
  }

  /// 绘制部位标签
  void _drawLabels(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.purple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final entry in partRegions.entries) {
      final rect = entry.value;
      final label = entry.key.boneName;

      canvas.drawRect(rect, paint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: _getPartColor(entry.key),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, rect.topLeft + const Offset(4, 4));
    }
  }

  /// 获取部位颜色
  Color _getPartColor(BodyPart part) {
    switch (part) {
      case BodyPart.head:
        return Colors.orange;
      case BodyPart.torso:
        return Colors.purple;
      case BodyPart.upperArmL:
      case BodyPart.lowerArmL:
        return Colors.blue;
      case BodyPart.upperArmR:
      case BodyPart.lowerArmR:
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  /// 绘制Mask叠加
  void _drawMaskOverlay(Canvas canvas, Size size) {
    if (mask == null || maskWidth == 0 || maskHeight == 0) return;

    // 创建Mask可视化图像
    final maskImageData = Uint8List(maskWidth * maskHeight * 4);
    for (int i = 0; i < mask!.length; i++) {
      final maskValue = mask![i];
      maskImageData[i * 4] = config.maskOverlayColor.red.toInt();
      maskImageData[i * 4 + 1] = config.maskOverlayColor.green.toInt();
      maskImageData[i * 4 + 2] = config.maskOverlayColor.blue.toInt();
      maskImageData[i * 4 + 3] = (maskValue * 0.3).toInt(); // 半透明
    }

    // 解码并绘制（需要在异步中完成，这里简化处理）
    // 实际使用时需要预先解码为Image
  }

  @override
  bool shouldRepaint(covariant DebugOverlayPainter oldDelegate) {
    // 比较关键数据是否有变化
    if (joints.length != oldDelegate.joints.length) return true;
    if (capsules.length != oldDelegate.capsules.length) return true;
    if (boundingBoxes.length != oldDelegate.boundingBoxes.length) return true;

    // 比较关节位置
    for (final entry in joints.entries) {
      final oldPoint = oldDelegate.joints[entry.key];
      if (oldPoint == null || (entry.value - oldPoint).distance > 1) {
        return true;
      }
    }

    return false;
  }
}

/// 调试Overlay Widget
///
/// 用于在图像上叠加调试信息
class DebugOverlayWidget extends StatelessWidget {
  /// 底层图像
  final Image underlyingImage;

  /// 关节点（归一化坐标）
  final Map<JointType, Landmark> joints;

  /// 胶囊几何列表
  final List<CapsuleGeometry> capsules;

  /// 调试配置
  final DebugOverlayConfig config;

  /// 图像尺寸
  final Size imageSize;

  const DebugOverlayWidget({
    super.key,
    required this.underlyingImage,
    required this.joints,
    this.capsules = const [],
    this.config = DebugOverlayConfig.defaultConfig,
    this.imageSize = Size.zero,
  });

  @override
  Widget build(BuildContext context) {
    // 将归一化关节坐标转换为像素坐标
    final pixelJoints = <JointType, Offset>{};
    for (final entry in joints.entries) {
      pixelJoints[entry.key] = Offset(
        entry.value.x * imageSize.width,
        entry.value.y * imageSize.height,
      );
    }

    // 计算BoundingBoxes
    final boundingBoxes = capsules
        .map((c) => c.computeBoundingBox(
              imageSize.width.toInt(),
              imageSize.height.toInt(),
            ))
        .toList();

    return CustomPaint(
      painter: DebugOverlayPainter(
        joints: pixelJoints,
        capsules: capsules,
        boundingBoxes: boundingBoxes,
        config: config,
      ),
      child: Container(), // 底层图像由外部提供
    );
  }
}