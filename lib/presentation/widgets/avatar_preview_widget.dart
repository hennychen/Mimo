import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/providers/avatar_providers.dart';
import '../../domain/entities/avatar_build_result.dart';
import '../../domain/entities/body_part.dart';

/// Avatar预览组件
///
/// 显示生成的Avatar并提供交互
class AvatarPreviewWidget extends ConsumerWidget {
  const AvatarPreviewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarState = ref.watch(avatarStateProvider);

    return Column(
      children: [
        // 状态指示器
        _buildStatusBar(avatarState),

        const SizedBox(height: 16),

        // Avatar预览区域
        Expanded(
          child: _buildPreviewArea(context, ref, avatarState),
        ),

        const SizedBox(height: 16),

        // 操作按钮
        _buildActionButtons(context, ref, avatarState),
      ],
    );
  }

  /// 构建状态栏
  Widget _buildStatusBar(AvatarState state) {
    String statusText;
    Color statusColor;

    switch (state.status) {
      case AvatarBuildStatus.idle:
        statusText = '请选择图片';
        statusColor = Colors.grey;
      case AvatarBuildStatus.validating:
        statusText = '验证中...';
        statusColor = Colors.orange;
      case AvatarBuildStatus.building:
        statusText = state.currentStep ?? '构建中...';
        statusColor = Colors.blue;
      case AvatarBuildStatus.success:
        statusText = '构建成功';
        statusColor = Colors.green;
      case AvatarBuildStatus.failed:
        statusText = state.errorMessage ?? '构建失败';
        statusColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _getStatusIcon(state.status),
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w500),
            ),
          ),
          if (state.isLoading)
            SizedBox(
              width: 100,
              child: LinearProgressIndicator(
                value: state.progress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
        ],
      ),
    );
  }

  /// 获取状态图标
  IconData _getStatusIcon(AvatarBuildStatus status) {
    switch (status) {
      case AvatarBuildStatus.idle:
        return Icons.image_outlined;
      case AvatarBuildStatus.validating:
        return Icons.search;
      case AvatarBuildStatus.building:
        return Icons.build;
      case AvatarBuildStatus.success:
        return Icons.check_circle;
      case AvatarBuildStatus.failed:
        return Icons.error;
    }
  }

  /// 构建预览区域
  Widget _buildPreviewArea(
    BuildContext context,
    WidgetRef ref,
    AvatarState state,
  ) {
    if (state.result == null || !state.result!.success) {
      return _buildEmptyState(context);
    }

    return _buildAvatarPreview(context, state.result!);
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_add_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              '创建你的专属角色',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '上传一张正面照片即可开始',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建Avatar预览
  Widget _buildAvatarPreview(BuildContext context, AvatarBuildResult result) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // 部位选择
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildPartSelector(result),
          ),

          // 分割线
          const Divider(height: 1),

          // 预览网格
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.all(8),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: BodyPart.mainParts.map((part) {
                return _buildPartCard(context, result, part);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建部位选择器
  Widget _buildPartSelector(AvatarBuildResult result) {
    final hasAllParts = result.hasAllRequiredParts();
    final missingParts = result.getMissingParts();

    return Row(
      children: [
        Icon(
          hasAllParts ? Icons.check_circle : Icons.warning,
          color: hasAllParts ? Colors.green : Colors.orange,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          '质量评分: ${(result.overallQuality * 100).toStringAsFixed(0)}%',
          style: const TextStyle(fontSize: 12),
        ),
        const Spacer(),
        if (missingParts.isNotEmpty)
          Text(
            '缺失: ${missingParts.map((p) => p.boneName).join(', ')}',
            style: const TextStyle(fontSize: 10, color: Colors.orange),
          ),
      ],
    );
  }

  /// 构建部位卡片
  Widget _buildPartCard(
    BuildContext context,
    AvatarBuildResult result,
    BodyPart part,
  ) {
    final texture = result.getTexture(part);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: texture != null
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 部位图标或预览
          Expanded(
            child: texture != null
                ? _buildTexturePreview(texture)
                : Icon(
                    Icons.broken_image,
                    size: 32,
                    color: Theme.of(context).colorScheme.error,
                  ),
          ),

          // 部位名称
          Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              part.boneName,
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建纹理预览
  Widget _buildTexturePreview(BodyPartTexture texture) {
    // 由于ui.Image不能直接显示，这里使用占位符
    // 实际实现需要将Image转换为可显示的Widget
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Icon(
          Icons.image,
          size: 24,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    AvatarState state,
  ) {
    return Row(
      children: [
        // 从相册选择
        Expanded(
          child: ElevatedButton.icon(
            onPressed: state.isLoading
                ? null
                : () => _pickImage(context, ref, ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('相册'),
          ),
        ),

        const SizedBox(width: 16),

        // 拍照
        Expanded(
          child: ElevatedButton.icon(
            onPressed: state.isLoading
                ? null
                : () => _pickImage(context, ref, ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('拍照'),
          ),
        ),
      ],
    );
  }

  /// 选择图片
  Future<void> _pickImage(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
  ) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );

    if (image != null) {
      final file = File(image.path);
      final notifier = ref.read(avatarStateProvider.notifier);

      // 先验证
      final validation = await notifier.validateImage(file);
      if (!validation.isValid) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(validation.issues.join('\n')),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 构建Avatar
      await notifier.buildFromFile(file);
    }
  }
}

/// Avatar调试面板
///
/// 用于调试模式下的可视化
class AvatarDebugPanel extends ConsumerWidget {
  const AvatarDebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarState = ref.watch(avatarStateProvider);
    final result = avatarState.result;

    if (result == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('暂无数据'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '调试信息',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            _buildInfoRow('状态', avatarState.status.name),
            _buildInfoRow('成功', result.success.toString()),
            _buildInfoRow('部位数', result.textures.length.toString()),
            _buildInfoRow('质量', '${(result.overallQuality * 100).toStringAsFixed(1)}%'),
            _buildInfoRow('耗时', '${result.buildTimeMs}ms'),
            _buildInfoRow('原图尺寸', '${result.sourceSize.width.toInt()}x${result.sourceSize.height.toInt()}'),
            if (result.errorMessage != null)
              _buildInfoRow('错误', result.errorMessage!, isError: true),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isError ? Colors.red : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}