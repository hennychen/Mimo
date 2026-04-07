import '../../domain/entities/body_metrics.dart';

/// 存储仓库接口
abstract class StorageRepository {
  /// 保存校准数据
  Future<void> saveCalibration(BodyMetrics metrics);
  
  /// 加载校准数据
  Future<BodyMetrics?> loadCalibration();
  
  /// 清除校准数据
  Future<void> clearCalibration();
  
  /// 保存用户设置
  Future<void> saveSetting(String key, dynamic value);
  
  /// 加载用户设置
  Future<T?> loadSetting<T>(String key);
}