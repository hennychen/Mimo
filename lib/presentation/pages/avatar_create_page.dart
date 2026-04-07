import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/providers/avatar_providers.dart';
import '../../domain/entities/avatar_build_result.dart';
import '../../domain/entities/body_part.dart';

/// Avatar创建页面
///
/// 用户上传照片并生成个性化角色的页面
class AvatarCreatePage extends ConsumerStatefulWidget {
  const AvatarCreatePage({super.key});

  @override
  ConsumerState<AvatarCreatePage> createState() => _AvatarCreatePageState();
}

class _AvatarCreatePageState extends ConsumerState<AvatarCreatePage> {
  /// 选中的图片
  File? _selectedImage;

  /// 图片选择器
  final _imagePicker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final avatarState = ref.watch(avatarStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('创建角色'),
        centerTitle: true,
        actions: [
          if (avatarState.hasAvatar)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () => _saveAvatar(),
              tooltip: '保存角色',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 图片选择区域
            _buildImageSelector(context),

            const SizedBox(height: 24),

            // 状态显示
            if (avatarState.isLoading) _buildProgressIndicator(avatarState),

            // 错误显示
            if (avatarState.status == AvatarBuildStatus.failed)
              _buildErrorCard(context, avatarState.errorMessage ?? '未知错误'),

            // 结果显示
            if (avatarState.hasAvatar) _buildResultPreview(context, avatarState.result!),

            const SizedBox(height: 24),

            // 操作按钮
            _buildActionButtons(context, avatarState),
          ],
        ),
      ),
    );
  }

  /// 构建图片选择器
  Widget _buildImageSelector(BuildContext context) {
    return GestureDetector(
      onTap: () => _showImageSourceDialog(context),
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: _selectedImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                    ),
                    // 更换图片按钮
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Material(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: () => _showImageSourceDialog(context),
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.edit, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '点击选择照片',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '支持相册选择或相机拍摄',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 16),
                  // 提示信息
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '正面照、手臂分开效果最佳',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// 构建进度指示器
  Widget _buildProgressIndicator(AvatarState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: state.progress,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.currentStep ?? '处理中...',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: state.progress),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建错误卡片
  Widget _buildErrorCard(BuildContext context, String errorMessage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建结果预览
  Widget _buildResultPreview(BuildContext context, AvatarBuildResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '生成成功',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              // 质量评分
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getQualityColor(result.overallQuality).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '质量 ${(result.overallQuality * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: _getQualityColor(result.overallQuality),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),

          // 部位预览网格
          Text(
            '身体部位 (${result.textures.length}/${BodyPart.mainParts.length})',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: BodyPart.mainParts.map((part) {
              final hasTexture = result.textures.containsKey(part);
              return _buildPartChip(context, part, hasTexture);
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 构建部位芯片
  Widget _buildPartChip(BuildContext context, BodyPart part, bool hasTexture) {
    return Container(
      decoration: BoxDecoration(
        color: hasTexture
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasTexture
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasTexture ? Icons.check : Icons.close,
            size: 16,
            color: hasTexture
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 4),
          Text(
            _getPartShortName(part),
            style: TextStyle(
              fontSize: 10,
              color: hasTexture
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  /// 获取部位简称
  String _getPartShortName(BodyPart part) {
    switch (part) {
      case BodyPart.head:
        return '头部';
      case BodyPart.torso:
        return '躯干';
      case BodyPart.upperArmL:
        return '左上臂';
      case BodyPart.lowerArmL:
        return '左下臂';
      case BodyPart.upperArmR:
        return '右上臂';
      case BodyPart.lowerArmR:
        return '右下臂';
      default:
        return part.boneName;
    }
  }

  /// 获取质量颜色
  Color _getQualityColor(double quality) {
    if (quality >= 0.8) return Colors.green;
    if (quality >= 0.6) return Colors.orange;
    return Colors.red;
  }

  /// 构建操作按钮
  Widget _buildActionButtons(BuildContext context, AvatarState state) {
    final isLoading = state.isLoading;

    return Column(
      children: [
        // 主要按钮
        ElevatedButton.icon(
          onPressed: _selectedImage == null || isLoading ? null : () => _buildAvatar(),
          icon: isLoading
              ? Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(right: 8),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(state.hasAvatar ? '重新生成' : '生成角色'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 次要按钮
        if (state.hasAvatar) ...[
          OutlinedButton.icon(
            onPressed: () => _previewAvatar(),
            icon: const Icon(Icons.play_arrow),
            label: const Text('预览效果'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 显示图片来源对话框
  Future<void> _showImageSourceDialog(BuildContext context) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择图片来源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      await _pickImage(source);
    }
  }

  /// 选择图片
  Future<void> _pickImage(ImageSource source) async {
    final image = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });

      // 重置之前的构建状态
      ref.read(avatarStateProvider.notifier).reset();
    }
  }

  /// 构建Avatar
  Future<void> _buildAvatar() async {
    if (_selectedImage == null) return;

    final notifier = ref.read(avatarStateProvider.notifier);
    await notifier.buildFromFile(_selectedImage!);
  }

  /// 保存Avatar
  Future<void> _saveAvatar() async {
    // TODO: 实现保存逻辑
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('角色已保存')),
      );
    }
  }

  /// 预览Avatar
  void _previewAvatar() {
    // TODO: 导航到预览页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AvatarPreviewPage(),
      ),
    );
  }
}

/// Avatar预览页面
///
/// 展示生成的角色效果
class AvatarPreviewPage extends ConsumerWidget {
  const AvatarPreviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarState = ref.watch(avatarStateProvider);
    final result = avatarState.result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('角色预览'),
      ),
      body: result == null
          ? const Center(child: Text('暂无角色数据'))
          : _buildPreviewContent(context, result),
    );
  }

  Widget _buildPreviewContent(BuildContext context, AvatarBuildResult result) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 占位预览
          Container(
            width: 200,
            height: 300,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person,
                  size: 80,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  '角色预览',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${result.textures.length} 个部位',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check),
            label: const Text('使用此角色'),
          ),
        ],
      ),
    );
  }
}