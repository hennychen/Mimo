import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart';

import '../../domain/entities/avatar_build_result.dart';
import '../../domain/engines/avatar/avatar_builder.dart';
import '../../data/engines_impl/avatar/segmentation_engine_impl.dart';
import '../../data/engines_impl/avatar/texture_binding_engine_impl.dart';
import '../../data/services/avatar_cache_service.dart';
import 'providers.dart';

/// Avatar构建状态
enum AvatarBuildStatus {
  /// 空闲
  idle,

  /// 验证中
  validating,

  /// 构建中
  building,

  /// 成功
  success,

  /// 失败
  failed,
}

/// Avatar状态
class AvatarState {
  /// 构建状态
  final AvatarBuildStatus status;

  /// 构建结果
  final AvatarBuildResult? result;

  /// Rive Artboard
  final Artboard? artboard;

  /// 错误信息
  final String? errorMessage;

  /// 进度（0-1）
  final double progress;

  /// 当前步骤描述
  final String? currentStep;

  const AvatarState({
    this.status = AvatarBuildStatus.idle,
    this.result,
    this.artboard,
    this.errorMessage,
    this.progress = 0.0,
    this.currentStep,
  });

  /// 是否正在加载
  bool get isLoading => status == AvatarBuildStatus.validating || 
      status == AvatarBuildStatus.building;

  /// 是否有可用的Avatar
  bool get hasAvatar => result != null && result!.success;

  AvatarState copyWith({
    AvatarBuildStatus? status,
    AvatarBuildResult? result,
    Artboard? artboard,
    String? errorMessage,
    double? progress,
    String? currentStep,
  }) {
    return AvatarState(
      status: status ?? this.status,
      result: result ?? this.result,
      artboard: artboard ?? this.artboard,
      errorMessage: errorMessage ?? this.errorMessage,
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
    );
  }
}

/// Avatar构建器Provider
final avatarBuilderProvider = Provider<AvatarBuilder>((ref) {
  final poseRepository = ref.watch(poseRepositoryProvider);

  return AvatarBuilderImpl(
    poseRepository: poseRepository,
    segmentationEngine: SegmentationEngineFallback(), // 使用fallback直到真正集成
    config: const AvatarBuildConfig(
      targetImageSize: 512,
      maxPartSize: 256,
      enableBoneWeight: true,
    ),
  );
});

/// Avatar缓存Provider
final avatarCacheProvider = Provider<AvatarCache>((ref) {
  return AvatarCache();
});

/// 纹理绑定引擎Provider
final textureBindingEngineProvider = Provider<TextureBindingEngine>((ref) {
  return TextureBindingEnginePlaceholder();
});

/// Avatar状态Provider
final avatarStateProvider = StateNotifierProvider<AvatarNotifier, AvatarState>((ref) {
  return AvatarNotifier(
    builder: ref.watch(avatarBuilderProvider),
    cache: ref.watch(avatarCacheProvider),
    textureBinding: ref.watch(textureBindingEngineProvider),
  );
});

/// 当前选中的Avatar ID Provider
final currentAvatarIdProvider = StateProvider<String?>((ref) {
  return null;
});

/// Avatar通知器
class AvatarNotifier extends StateNotifier<AvatarState> {
  final AvatarBuilder _builder;
  final AvatarCache _cache;
  final TextureBindingEngine _textureBinding;

  AvatarNotifier({
    required AvatarBuilder builder,
    required AvatarCache cache,
    required TextureBindingEngine textureBinding,
  })  : _builder = builder,
        _cache = cache,
        _textureBinding = textureBinding,
        super(const AvatarState());

  /// 从图片构建Avatar
  Future<void> buildFromFile(File image) async {
    state = AvatarState(
      status: AvatarBuildStatus.building,
      progress: 0.0,
      currentStep: '预处理图像',
    );

    try {
      // 构建Avatar
      final result = await _builder.build(image);

      if (result.success) {
        state = state.copyWith(
          status: AvatarBuildStatus.success,
          result: result,
          progress: 1.0,
          currentStep: '构建完成',
        );

        // 缓存结果
        final avatarId = DateTime.now().millisecondsSinceEpoch.toString();
        await _cache.save(avatarId, result);
      } else {
        state = state.copyWith(
          status: AvatarBuildStatus.failed,
          errorMessage: result.errorMessage,
          progress: 0.0,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AvatarBuildStatus.failed,
        errorMessage: '构建异常: $e',
        progress: 0.0,
      );
    }
  }

  /// 验证图片
  Future<AvatarValidationResult> validateImage(File image) async {
    state = state.copyWith(status: AvatarBuildStatus.validating);
    final result = await _builder.validate(image);
    state = state.copyWith(status: AvatarBuildStatus.idle);
    return result;
  }

  /// 加载缓存的Avatar
  Future<void> loadFromCache(String avatarId) async {
    state = state.copyWith(
      status: AvatarBuildStatus.building,
      currentStep: '加载缓存',
    );

    try {
      final result = await _cache.load(avatarId);

      if (result != null && result.success) {
        state = state.copyWith(
          status: AvatarBuildStatus.success,
          result: result,
          progress: 1.0,
        );
      } else {
        state = state.copyWith(
          status: AvatarBuildStatus.failed,
          errorMessage: '缓存加载失败',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AvatarBuildStatus.failed,
        errorMessage: '加载缓存异常: $e',
      );
    }
  }

  /// 绑定纹理到Rive Artboard
  Future<void> bindToArtboard(Artboard artboard) async {
    if (state.result == null || !state.result!.success) return;

    state = state.copyWith(
      currentStep: '绑定纹理',
    );

    final success = await _textureBinding.bindTextures(
      artboard: artboard,
      textures: state.result!.textures,
    );

    if (success) {
      state = state.copyWith(
        artboard: artboard,
        currentStep: '绑定完成',
      );
    }
  }

  /// 清除当前Avatar
  void clear() {
    state = const AvatarState();
  }

  /// 重置状态
  void reset() {
    state = const AvatarState(status: AvatarBuildStatus.idle);
  }
}

/// 需要导入 PoseRepository Provider
/// 这个文件需要放在正确的位置，并确保导入路径正确