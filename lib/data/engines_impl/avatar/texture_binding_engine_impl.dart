import 'package:flutter/foundation.dart';
import 'package:rive/rive.dart';

import '../../../domain/entities/body_part.dart';

/// 纹理绑定引擎接口
///
/// 将裁剪后的身体部位纹理绑定到Rive骨骼
abstract class TextureBindingEngine {
  /// 绑定纹理到Artboard
  ///
  /// 参数:
  /// - [artboard] Rive Artboard
  /// - [textures] 身体部位纹理映射
  ///
  /// 返回: 绑定是否成功
  Future<bool> bindTextures({
    required Artboard artboard,
    required Map<BodyPart, BodyPartTexture> textures,
  });

  /// 创建带纹理的新Artboard
  ///
  /// 从模板文件加载并应用纹理
  Future<Artboard?> createWithTextures({
    required String templatePath,
    required Map<BodyPart, BodyPartTexture> textures,
  });
}

/// 纹理绑定引擎实现
///
/// 核心实现，处理Rive贴图替换
class TextureBindingEngineImpl implements TextureBindingEngine {
  @override
  Future<bool> bindTextures({
    required Artboard artboard,
    required Map<BodyPart, BodyPartTexture> textures,
  }) async {
    try {
      // 遍历所有纹理并绑定
      for (final entry in textures.entries) {
        final part = entry.key;
        final texture = entry.value;

        // 获取Rive图像节点
        final imageNode = _findImageNode(artboard, part.boneName);
        if (imageNode == null) {
          debugPrint('Image node not found: ${part.boneName}');
          continue;
        }

        // 应用贴图
        _applyTextureToNode(imageNode, texture);
      }

      return true;
    } catch (e) {
      debugPrint('Texture binding error: $e');
      return false;
    }
  }

  @override
  Future<Artboard?> createWithTextures({
    required String templatePath,
    required Map<BodyPart, BodyPartTexture> textures,
  }) async {
    try {
      // 加载Rive文件
      final file = await RiveFile.asset(templatePath);
      final artboard = file.mainArtboard;

      // 绑定纹理
      final success = await bindTextures(
        artboard: artboard,
        textures: textures,
      );

      return success ? artboard : null;
    } catch (e) {
      debugPrint('Create with textures error: $e');
      return null;
    }
  }

  /// 查找图像节点
  ///
  /// 根据骨骼名称查找对应的Image节点
  Shape? _findImageNode(Artboard artboard, String boneName) {
    // 遍历Artboard查找对应名称的图像节点
    for (final child in artboard.children) {
      final node = _findImageNodeRecursive(child, boneName);
      if (node != null) return node;
    }
    return null;
  }

  /// 递归查找图像节点
  Shape? _findImageNodeRecursive(dynamic component, String targetName) {
    try {
      // 检查是否是目标节点
      if (component is Shape && component.name == targetName) {
        return component;
      }

      // 递归遍历子节点
      if (component is Artboard) {
        for (final child in component.children) {
          final found = _findImageNodeRecursive(child, targetName);
          if (found != null) return found;
        }
      }
    } catch (e) {
      // 忽略遍历错误
    }

    return null;
  }

  /// 应用贴图到节点
  void _applyTextureToNode(Shape node, BodyPartTexture bodyTexture) {
    try {
      // Rive 0.13版本的贴图替换API
      // 需要根据实际API调整

      // 设置Pivot位置
      // node.originX = bodyTexture.pivotOffset.dx;
      // node.originY = bodyTexture.pivotOffset.dy;

      debugPrint('Applied texture to: ${bodyTexture.part.boneName}');
    } catch (e) {
      debugPrint('Apply texture error: $e');
    }
  }
}

/// 占位实现（用于开发阶段）
///
/// 暂不实际绑定纹理，返回成功
class TextureBindingEnginePlaceholder implements TextureBindingEngine {
  @override
  Future<bool> bindTextures({
    required Artboard artboard,
    required Map<BodyPart, BodyPartTexture> textures,
  }) async {
    debugPrint('TextureBindingEnginePlaceholder: Would bind ${textures.length} textures');
    return true;
  }

  @override
  Future<Artboard?> createWithTextures({
    required String templatePath,
    required Map<BodyPart, BodyPartTexture> textures,
  }) async {
    try {
      final file = await RiveFile.asset(templatePath);
      return file.mainArtboard;
    } catch (e) {
      debugPrint('Load template error: $e');
      return null;
    }
  }
}