import '../../domain/entities/joint_type.dart';
import '../../domain/entities/landmark.dart';

/// 姿态检测仓库接口
abstract class PoseRepository {
  /// 检测姿态
  /// 
  /// 参数:
  /// - [image] 图像数据
  /// - [width] 图像宽度
  /// - [height] 图像高度
  /// 返回: 关键点映射
  Map<JointType, Landmark> detect(dynamic image, int width, int height);
  
  /// 是否已初始化
  bool get isInitialized;
  
  /// 初始化
  Future<void> initialize();
  
  /// 释放资源
  void dispose();
}