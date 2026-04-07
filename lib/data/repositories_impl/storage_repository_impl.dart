import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/body_metrics.dart';
import '../../domain/repositories/storage_repository.dart';

/// 存储仓库实现
class StorageRepositoryImpl implements StorageRepository {
  static const String _calibrationKey = 'calibration_data';
  static const String _settingsPrefix = 'setting_';

  /// 保存校准数据
  @override
  Future<void> saveCalibration(BodyMetrics metrics) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_calibrationKey, jsonEncode(metrics.toMap()));
  }

  /// 加载校准数据
  @override
  Future<BodyMetrics?> loadCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_calibrationKey);
    
    if (jsonString == null) return null;
    
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return BodyMetrics.fromMap(map);
    } catch (e) {
      return null;
    }
  }

  /// 清除校准数据
  @override
  Future<void> clearCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_calibrationKey);
  }

  /// 保存用户设置
  @override
  Future<void> saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    final fullKey = '$_settingsPrefix$key';
    
    if (value is bool) {
      await prefs.setBool(fullKey, value);
    } else if (value is int) {
      await prefs.setInt(fullKey, value);
    } else if (value is double) {
      await prefs.setDouble(fullKey, value);
    } else if (value is String) {
      await prefs.setString(fullKey, value);
    } else {
      await prefs.setString(fullKey, jsonEncode(value));
    }
  }

  /// 加载用户设置
  @override
  Future<T?> loadSetting<T>(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final fullKey = '$_settingsPrefix$key';

    if (T == bool) {
      return prefs.getBool(fullKey) as T?;
    } else if (T == int) {
      return prefs.getInt(fullKey) as T?;
    } else if (T == double) {
      return prefs.getDouble(fullKey) as T?;
    } else if (T == String) {
      return prefs.getString(fullKey) as T?;
    }

    final jsonString = prefs.getString(fullKey);
    if (jsonString == null) return null;

    try {
      return jsonDecode(jsonString) as T?;
    } catch (e) {
      return null;
    }
  }

  /// 获取double类型设置
  Future<double?> getDouble(String key) async {
    return loadSetting<double>(key);
  }

  /// 获取bool类型设置
  Future<bool?> getBool(String key) async {
    return loadSetting<bool>(key);
  }

  /// 获取int类型设置
  Future<int?> getInt(String key) async {
    return loadSetting<int>(key);
  }

  /// 设置double类型值
  Future<void> setDouble(String key, double value) async {
    await saveSetting(key, value);
  }

  /// 设置bool类型值
  Future<void> setBool(String key, bool value) async {
    await saveSetting(key, value);
  }

  /// 设置int类型值
  Future<void> setInt(String key, int value) async {
    await saveSetting(key, value);
  }
}