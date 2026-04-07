
import 'package:flutter_test/flutter_test.dart';

import 'package:mimo_app/domain/engines/avatar/capsule_geometry.dart';

void main() {
  group('CapsuleGeometry', () {
    group('基本属性', () {
      test('应正确计算胶囊参数', () {
        final geometry = CapsuleGeometry(
          jointA: Offset(0, 0),
          jointB: Offset(100, 0),
          radius: 20,
        );

        expect(geometry.radius, equals(20));
        expect(geometry.segmentLength, equals(100));
        expect(geometry.segmentVector, equals(Offset(100, 0)));
      });

      test('应正确计算方向向量', () {
        final geometry = CapsuleGeometry(
          jointA: Offset(0, 0),
          jointB: Offset(100, 0),
          radius: 20,
        );

        final direction = geometry.direction;
        expect(direction.dx, closeTo(1.0, 0.001));
        expect(direction.dy, closeTo(0.0, 0.001));
      });

      test('应正确计算垂直向量', () {
        final geometry = CapsuleGeometry(
          jointA: Offset(0, 0),
          jointB: Offset(100, 0),
          radius: 20,
        );

        final perp = geometry.perpendicular;
        expect(perp.dx, closeTo(0.0, 0.001));
        expect((perp.dy).abs(), closeTo(1.0, 0.001));
      });
    });

    group('点到线段距离', () {
      test('点在线段上时距离应为0', () {
        final geometry = CapsuleGeometry(
          jointA: Offset(0, 0),
          jointB: Offset(100, 0),
          radius: 20,
        );

        expect(geometry.distanceToSegment(Offset(50, 0)), closeTo(0, 0.001));
        expect(geometry.distanceToSegment(Offset(0, 0)), closeTo(0, 0.001));
        expect(geometry.distanceToSegment(Offset(100, 0)), closeTo(0, 0.001));
      });

      test('点在线段正上方时距离应正确', () {
        final geometry = CapsuleGeometry(
          jointA: Offset(0, 0),
          jointB: Offset(100, 0),
          radius: 20,
        );

        expect(geometry.distanceToSegment(Offset(50, 30)), closeTo(30, 0.001));
        expect(geometry.distanceToSegment(Offset(50, -40)), closeTo(40, 0.001));
      });

      test('点在线段延长线外时距离应到端点', () {
        final geometry = CapsuleGeometry(
          jointA: Offset(0, 0),
          jointB: Offset(100, 0),
          radius: 20,
        );

        // 点在A端外侧（水平方向）
        expect(geometry.distanceToSegment(Offset(-50, 0)), closeTo(50, 0.001));

        // 点在B端外侧（水平方向）
        expect(geometry.distanceToSegment(Offset(150, 0)), closeTo(50, 0.001));

        // 点在A端外侧（斜向）
        // 距离 = sqrt(30^2 + 40^2) = 50
        expect(geometry.distanceToSegment(Offset(-30, 40)), closeTo(50, 0.001));

        // 点在B端外侧（斜向）
        // 距离 = sqrt(30^2 + 40^2) = 50
        expect(geometry.distanceToSegment(Offset(130, 40)), closeTo(50, 0.001));
      });

      test('斜向线段应正确计算距离', () {
        final geometry = CapsuleGeometry(
          jointA: Offset(0, 0),
          jointB: Offset(100, 100),
          radius: 20,
        );

        // 线段中点
        final midPoint = Offset(50, 50);
        expect(geometry.distanceToSegment(midPoint), closeTo(0, 0.001));

        // 垂直于线段的点
        final perpPoint = Offset(60, 40); // 中点附近的垂直点
        final dist = geometry.distanceToSegment(perpPoint);
        expect(dist, closeTo(14.14, 0.1)); // 约等于 10 * sqrt(2)
      });
    });

    group('胶囊内判断', () {
      test('内部点应返回true', () {
        final geometry = CapsuleGeometry(
          jointA: Offset(0, 0),
          jointB: Offset(100, 0),
          radius: 20,
        );

        expect(geometry.isInsideCapsule(Offset(50, 0)), isTrue);
        expect(geometry.isInsideCapsule(Offset(50, 15)), isTrue);
        expect(geometry.isInsideCapsule(Offset(0, 10)), isTrue);
        expect(geometry.isInsideCapsule(Offset(100, 19)), isTrue);
      });

      test('外部点应返回false', () {
        final geometry = CapsuleGeometry(
          jointA: Offset(0, 0),
          jointB: Offset(100, 0),
          radius: 20,
        );

        expect(geometry.isInsideCapsule(Offset(50, 25)), isFalse);
        expect(geometry.isInsideCapsule(Offset(-25, 0)), isFalse);
        expect(geometry.isInsideCapsule(Offset(125, 0)), isFalse);
      });

      test('边界点应返回true', () {
        final geometry = CapsuleGeometry(
          jointA: Offset(0, 0),
          jointB: Offset(100, 0),
          radius: 20,
        );

        expect(geometry.isInsideCapsule(Offset(50, 20)), isTrue);
        expect(geometry.isInsideCapsule(Offset(50, -20)), isTrue);
      });
    });

    group('BoundingBox计算', () {
      test('应正确计算外接矩形', () {
        final geometry = CapsuleGeometry(
          jointA: Offset(50, 50),
          jointB: Offset(150, 50),
          radius: 20,
        );

        final bbox = geometry.computeBoundingBox(200, 200);

        expect(bbox.left, equals(30)); // 50 - 20
        expect(bbox.right, equals(170)); // 150 + 20
        expect(bbox.top, equals(30)); // 50 - 20
        expect(bbox.bottom, equals(70)); // 50 + 20
      });

      test('应正确处理边界裁剪', () {
        final geometry = CapsuleGeometry(
          jointA: Offset(10, 10),
          jointB: Offset(20, 20),
          radius: 15,
        );

        final bbox = geometry.computeBoundingBox(100, 100);

        expect(bbox.left, equals(0)); // 裁剪到边界
        expect(bbox.top, equals(0)); // 裁剪到边界
      });
    });

    group('BoneWeight计算', () {
      test('中心点权重应为1', () {
        final geometry = CapsuleGeometry(
          jointA: Offset(0, 0),
          jointB: Offset(100, 0),
          radius: 20,
        );

        final weight = geometry.computeBoneWeight(Offset(50, 0), 0.05);
        expect(weight, closeTo(1.0, 0.01));
      });

      test('远离骨骼的点权重应降低', () {
        final geometry = CapsuleGeometry(
          jointA: Offset(0, 0),
          jointB: Offset(100, 0),
          radius: 20,
        );

        final nearWeight = geometry.computeBoneWeight(Offset(50, 10), 0.05);
        final farWeight = geometry.computeBoneWeight(Offset(50, 30), 0.05);

        expect(nearWeight, greaterThan(farWeight));
        expect(nearWeight, lessThanOrEqualTo(1.0));
        expect(farWeight, greaterThan(0));
      });
    });

    group('投影计算', () {
      test('应正确计算投影位置', () {
        final geometry = CapsuleGeometry(
          jointA: Offset(0, 0),
          jointB: Offset(100, 0),
          radius: 20,
        );

        // 中点
        expect(geometry.getProjectionT(Offset(50, 0)), closeTo(0.5, 0.001));
        // 起点
        expect(geometry.getProjectionT(Offset(0, 0)), closeTo(0.0, 0.001));
        // 终点
        expect(geometry.getProjectionT(Offset(100, 0)), closeTo(1.0, 0.001));
      });

      test('应正确获取指定位置的点', () {
        final geometry = CapsuleGeometry(
          jointA: Offset(0, 0),
          jointB: Offset(100, 0),
          radius: 20,
        );

        expect(geometry.getPointAtT(0.0), equals(Offset(0, 0)));
        expect(geometry.getPointAtT(0.5), equals(Offset(50, 0)));
        expect(geometry.getPointAtT(1.0), equals(Offset(100, 0)));
      });
    });

    group('退化情况', () {
      test('两点重合时应正确处理', () {
        final geometry = CapsuleGeometry(
          jointA: Offset(50, 50),
          jointB: Offset(50, 50),
          radius: 20,
        );

        expect(geometry.segmentLength, equals(0));

        // 距离应等于到圆心的距离
        expect(geometry.distanceToSegment(Offset(50, 50)), closeTo(0, 0.001));
        expect(geometry.distanceToSegment(Offset(70, 50)), closeTo(20, 0.001));
        expect(geometry.distanceToSegment(Offset(50, 80)), closeTo(30, 0.001));
      });
    });
  });

  group('RegionBuilder', () {
    group('肩宽计算', () {
      test('应正确计算水平肩宽', () {
        final leftShoulder = Offset(100, 100);
        final rightShoulder = Offset(200, 100);

        final shoulderWidth = RegionBuilder.computeShoulderWidth(
          leftShoulder,
          rightShoulder,
        );

        expect(shoulderWidth, equals(100));
      });

      test('应正确计算斜向肩宽', () {
        final leftShoulder = Offset(0, 0);
        final rightShoulder = Offset(100, 100);

        final shoulderWidth = RegionBuilder.computeShoulderWidth(
          leftShoulder,
          rightShoulder,
        );

        expect(shoulderWidth, closeTo(141.42, 0.1)); // 100 * sqrt(2)
      });
    });

    group('髋部中心计算', () {
      test('应正确计算髋部中心', () {
        final leftHip = Offset(100, 200);
        final rightHip = Offset(200, 200);

        final center = RegionBuilder.computeHipCenter(leftHip, rightHip);

        expect(center.dx, equals(150));
        expect(center.dy, equals(200));
      });
    });

    group('坐标转换', () {
      test('应正确转换归一化坐标到像素坐标', () {
        final normalized = Offset(0.5, 0.5);
        final pixel = RegionBuilder.normalizedToPixel(normalized, 200, 400);

        expect(pixel.dx, equals(100));
        expect(pixel.dy, equals(200));
      });
    });

    group('上臂区域构建', () {
      test('应正确构建上臂胶囊', () {
        final geometry = RegionBuilder.buildUpperArmRegion(
          shoulder: Offset(0, 0),
          elbow: Offset(100, 0),
          shoulderWidth: 100,
        );

        expect(geometry.radius, equals(12.5)); // 100 * 0.25 / 2
        expect(geometry.jointA, equals(Offset(0, 0)));
        expect(geometry.jointB, equals(Offset(100, 0)));
      });
    });

    group('下臂区域构建', () {
      test('应正确构建下臂胶囊', () {
        final geometry = RegionBuilder.buildLowerArmRegion(
          elbow: Offset(0, 0),
          wrist: Offset(80, 0),
          shoulderWidth: 100,
        );

        expect(geometry.radius, equals(10)); // 100 * 0.2 / 2
        expect(geometry.jointA, equals(Offset(0, 0)));
        expect(geometry.jointB, equals(Offset(80, 0)));
      });
    });

    group('头部区域构建', () {
      test('应正确构建头部圆形', () {
        final geometry = RegionBuilder.buildHeadRegion(
          nose: Offset(100, 100),
          shoulderWidth: 100,
        );

        expect(geometry.radius, equals(60)); // 100 * 0.6
        expect(geometry.jointA, equals(Offset(100, 100)));
        expect(geometry.jointB, equals(Offset(100, 100))); // 两点相同，圆形
      });
    });
  });

  group('SmoothStep', () {
    test('应正确计算smoothstep', () {
      // 边界值
      expect(SmoothStep.apply(0, 0, 1), closeTo(0, 0.001));
      expect(SmoothStep.apply(1, 0, 1), closeTo(1, 0.001));

      // 中间值
      final mid = SmoothStep.apply(0.5, 0, 1);
      expect(mid, closeTo(0.5, 0.01));

      // 验证平滑特性：在中间点斜率最大
      final nearMid1 = SmoothStep.apply(0.49, 0, 1);
      final nearMid2 = SmoothStep.apply(0.51, 0, 1);
      expect((nearMid2 - nearMid1).abs(), lessThan(0.1));
    });

    test('应正确限制范围', () {
      // 超出范围
      expect(SmoothStep.apply(-0.5, 0, 1), equals(0));
      expect(SmoothStep.apply(1.5, 0, 1), equals(1));
    });

    test('reverse应正确工作', () {
      expect(SmoothStep.reverse(0, 0, 1), equals(1));
      expect(SmoothStep.reverse(1, 0, 1), equals(0));
      expect(SmoothStep.reverse(0.5, 0, 1), closeTo(0.5, 0.01));
    });
  });
}