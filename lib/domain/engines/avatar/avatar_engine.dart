/// Avatar引擎模块
///
/// 提供Avatar生成的完整能力：
/// - 图像预处理
/// - 人体分割
/// - 身体分区裁剪
/// - 纹理绑定
library;

// 实体
export '../../entities/body_part.dart';
export '../../entities/avatar_build_result.dart';

// 几何工具
export 'capsule_geometry.dart';

// 核心引擎
export 'capsule_partition_engine.dart';
export 'body_partition_engine.dart';
export 'avatar_builder.dart';

// 调试工具
export 'debug_overlay_painter.dart';