import 'dart:io';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/body_part.dart';
import '../../domain/entities/avatar_build_result.dart';

/// Avatar缓存管理器
///
/// 负责持久化存储生成的Avatar，避免重复生成
class AvatarCache {
  /// 缓存目录名
  static const String _cacheDirName = 'avatar_cache';

  /// 元数据文件名
  static const String _metadataFileName = 'metadata.json';

  /// 缓存目录路径
  String? _cachePath;

  /// 获取缓存目录路径
  Future<String> get cachePath async {
    if (_cachePath != null) return _cachePath!;

    final appDir = await getApplicationDocumentsDirectory();
    _cachePath = p.join(appDir.path, _cacheDirName);

    // 确保目录存在
    final dir = Directory(_cachePath!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return _cachePath!;
  }

  /// 保存Avatar到缓存
  ///
  /// 参数:
  /// - [avatarId] Avatar唯一标识
  /// - [result] Avatar构建结果
  ///
  /// 返回: 是否保存成功
  Future<bool> save(String avatarId, AvatarBuildResult result) async {
    try {
      final basePath = await cachePath;
      final avatarDir = p.join(basePath, avatarId);

      // 创建Avatar目录
      final dir = Directory(avatarDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 保存元数据
      final metadata = _createMetadata(result);
      final metadataFile = File(p.join(avatarDir, _metadataFileName));
      await metadataFile.writeAsString(jsonEncode(metadata));

      // 保存各部位纹理
      for (final entry in result.textures.entries) {
        final part = entry.key;
        final texture = entry.value;

        // 保存图像为PNG
        final imageFile = File(p.join(avatarDir, '${part.boneName}.png'));
        await _saveImage(texture.image, imageFile);

        // 保存纹理元数据
        final textureMeta = {
          'sourceRect': {
            'left': texture.sourceRect.left,
            'top': texture.sourceRect.top,
            'right': texture.sourceRect.right,
            'bottom': texture.sourceRect.bottom,
          },
          'pivotOffset': {
            'dx': texture.pivotOffset.dx,
            'dy': texture.pivotOffset.dy,
          },
          'qualityScore': texture.qualityScore,
        };
        final metaFile = File(p.join(avatarDir, '${part.boneName}.meta.json'));
        await metaFile.writeAsString(jsonEncode(textureMeta));
      }

      debugPrint('Avatar saved to cache: $avatarId');
      return true;
    } catch (e) {
      debugPrint('Failed to save avatar to cache: $e');
      return false;
    }
  }

  /// 从缓存加载Avatar
  ///
  /// 参数:
  /// - [avatarId] Avatar唯一标识
  ///
  /// 返回: Avatar构建结果（如果存在）
  Future<AvatarBuildResult?> load(String avatarId) async {
    try {
      final basePath = await cachePath;
      final avatarDir = p.join(basePath, avatarId);

      final dir = Directory(avatarDir);
      if (!await dir.exists()) {
        return null;
      }

      // 读取元数据
      final metadataFile = File(p.join(avatarDir, _metadataFileName));
      if (!await metadataFile.exists()) {
        return null;
      }
      final metadata = jsonDecode(await metadataFile.readAsString());

      // 加载各部位纹理
      final textures = <BodyPart, BodyPartTexture>{};

      for (final part in BodyPart.mainParts) {
        final imageFile = File(p.join(avatarDir, '${part.boneName}.png'));
        final metaFile = File(p.join(avatarDir, '${part.boneName}.meta.json'));

        if (!await imageFile.exists() || !await metaFile.exists()) {
          continue;
        }

        // 加载图像
        final image = await _loadImage(imageFile);
        if (image == null) continue;

        // 加载元数据
        final textureMeta = jsonDecode(await metaFile.readAsString());
        final sourceRect = Rect.fromLTRB(
          textureMeta['sourceRect']['left'],
          textureMeta['sourceRect']['top'],
          textureMeta['sourceRect']['right'],
          textureMeta['sourceRect']['bottom'],
        );
        final pivotOffset = Offset(
          textureMeta['pivotOffset']['dx'],
          textureMeta['pivotOffset']['dy'],
        );

        textures[part] = BodyPartTexture(
          part: part,
          image: image,
          sourceRect: sourceRect,
          pivotOffset: pivotOffset,
          qualityScore: textureMeta['qualityScore'],
        );
      }

      return AvatarBuildResult.success(
        textures: textures,
        sourceSize: Size(
          metadata['sourceWidth'],
          metadata['sourceHeight'],
        ),
        overallQuality: metadata['overallQuality'],
      );
    } catch (e) {
      debugPrint('Failed to load avatar from cache: $e');
      return null;
    }
  }

  /// 检查Avatar是否存在
  Future<bool> exists(String avatarId) async {
    final basePath = await cachePath;
    final avatarDir = Directory(p.join(basePath, avatarId));
    return avatarDir.exists();
  }

  /// 删除缓存的Avatar
  Future<bool> delete(String avatarId) async {
    try {
      final basePath = await cachePath;
      final avatarDir = Directory(p.join(basePath, avatarId));

      if (await avatarDir.exists()) {
        await avatarDir.delete(recursive: true);
      }

      debugPrint('Avatar deleted from cache: $avatarId');
      return true;
    } catch (e) {
      debugPrint('Failed to delete avatar from cache: $e');
      return false;
    }
  }

  /// 清除所有缓存
  Future<bool> clearAll() async {
    try {
      final basePath = await cachePath;
      final cacheDir = Directory(basePath);

      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }

      debugPrint('All avatar cache cleared');
      return true;
    } catch (e) {
      debugPrint('Failed to clear avatar cache: $e');
      return false;
    }
  }

  /// 获取缓存大小（字节）
  Future<int> getCacheSize() async {
    try {
      final basePath = await cachePath;
      final cacheDir = Directory(basePath);

      if (!await cacheDir.exists()) {
        return 0;
      }

      int size = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          size += await entity.length();
        }
      }

      return size;
    } catch (e) {
      debugPrint('Failed to get cache size: $e');
      return 0;
    }
  }

  /// 获取所有缓存的Avatar ID列表
  Future<List<String>> getAvatarIds() async {
    try {
      final basePath = await cachePath;
      final cacheDir = Directory(basePath);

      if (!await cacheDir.exists()) {
        return [];
      }

      final ids = <String>[];
      await for (final entity in cacheDir.list()) {
        if (entity is Directory) {
          ids.add(p.basename(entity.path));
        }
      }

      return ids;
    } catch (e) {
      debugPrint('Failed to get avatar ids: $e');
      return [];
    }
  }

  /// 创建元数据
  Map<String, dynamic> _createMetadata(AvatarBuildResult result) {
    return {
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'sourceWidth': result.sourceSize.width,
      'sourceHeight': result.sourceSize.height,
      'overallQuality': result.overallQuality,
      'parts': result.textures.keys.map((p) => p.boneName).toList(),
    };
  }

  /// 保存图像到文件
  Future<void> _saveImage(Image image, File file) async {
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    if (byteData != null) {
      await file.writeAsBytes(byteData.buffer.asUint8List());
    }
  }

  /// 从文件加载图像
  Future<Image?> _loadImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('Failed to load image: $e');
      return null;
    }
  }
}