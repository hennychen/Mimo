import 'package:rive/rive.dart';

/// Rive骨骼绑定配置
class RiveBoneBinding {
  /// 骨骼名称
  final String boneName;
  
  /// 旋转轴 ('x', 'y', 'z')
  final String rotationAxis;
  
  /// 角度偏移（度）
  final double angleOffset;
  
  /// 角度缩放因子
  final double angleScale;
  
  /// 是否反向
  final bool invert;

  const RiveBoneBinding({
    required this.boneName,
    this.rotationAxis = 'z',
    this.angleOffset = 0.0,
    this.angleScale = 1.0,
    this.invert = false,
  });
}

/// Rive骨骼控制器
/// 
/// 管理Rive动画角色的骨骼驱动
class RiveBoneController {
  /// Rive Artboard
  Artboard? _artboard;
  
  /// 骨骼映射
  final Map<String, dynamic> _bones = {};
  
  /// 骨骼绑定配置
  final Map<String, RiveBoneBinding> _bindings = {};
  
  /// 是否已初始化
  bool _isInitialized = false;
  
  /// 默认骨骼绑定配置
  static const Map<String, RiveBoneBinding> defaultBindings = {
    'upper_arm_L': RiveBoneBinding(boneName: 'upper_arm_L', angleOffset: -90),
    'lower_arm_L': RiveBoneBinding(boneName: 'lower_arm_L', angleOffset: 0),
    'hand_L': RiveBoneBinding(boneName: 'hand_L', angleOffset: 0),
    'upper_arm_R': RiveBoneBinding(boneName: 'upper_arm_R', angleOffset: 90, invert: true),
    'lower_arm_R': RiveBoneBinding(boneName: 'lower_arm_R', angleOffset: 0, invert: true),
    'hand_R': RiveBoneBinding(boneName: 'hand_R', angleOffset: 0, invert: true),
    'head': RiveBoneBinding(boneName: 'head', angleOffset: 0),
  };

  /// 是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 获取Artboard
  Artboard? get artboard => _artboard;

  /// 初始化控制器
  /// 
  /// 从Rive文件加载Artboard并绑定骨骼
  Future<void> initialize(Artboard artboard) async {
    _artboard = artboard;
    
    // 应用默认绑定
    for (final entry in defaultBindings.entries) {
      _bindings[entry.key] = entry.value;
    }
    
    _isInitialized = true;
  }

  /// 注册骨骼绑定
  void registerBinding(String jointName, RiveBoneBinding binding) {
    _bindings[jointName] = binding;
  }

  /// 应用关节角度
  /// 
  /// [jointName] 关节名称（对应JointType.riveBoneName）
  /// [angleDegrees] 角度（度）
  void applyJointAngle(String jointName, double angleDegrees) {
    if (!_isInitialized || _artboard == null) return;
    
    final binding = _bindings[jointName];
    if (binding == null) return;
    
    // 计算最终角度
    var finalAngle = (angleDegrees + binding.angleOffset) * binding.angleScale;
    if (binding.invert) {
      finalAngle = -finalAngle;
    }
    
    // 注意: 实际骨骼操作需要根据Rive文件的具体结构来实现
    // 这里提供一个占位实现，实际使用时需要：
    // 1. 从Artboard获取骨骼组件
    // 2. 应用旋转
    
    // 可以使用artboard.getComponentByName()来获取骨骼
    // 然后设置其rotation属性
  }

  /// 批量应用关节角度
  void applyJointAngles(Map<String, double> angles) {
    for (final entry in angles.entries) {
      applyJointAngle(entry.key, entry.value);
    }
  }

  /// 重置所有骨骼到默认姿态
  void resetToDefault() {
    // 重置逻辑
  }

  /// 获取骨骼名称列表
  List<String> getBoneNames() {
    return _bones.keys.toList();
  }

  /// 检查骨骼是否存在
  bool hasBone(String boneName) {
    return _bones.containsKey(boneName);
  }

  /// 释放资源
  void dispose() {
    _bones.clear();
    _bindings.clear();
    _artboard = null;
    _isInitialized = false;
  }
}

/// 自定义动画控制器
/// 
/// 提供动画状态管理
class CustomAnimationController {
  /// SimpleAnimation控制器
  SimpleAnimation? _simpleAnimation;
  
  /// 当前动画名称
  String? _currentAnimation;
  
  /// 是否正在播放
  bool _isPlaying = false;

  /// 当前动画名称
  String? get currentAnimation => _currentAnimation;
  
  /// 是否正在播放
  bool get isPlaying => _isPlaying;

  /// 播放简单动画
  void playAnimation(Artboard artboard, String animationName) {
    _simpleAnimation?.isActive = false;
    
    _simpleAnimation = SimpleAnimation(animationName);
    artboard.addController(_simpleAnimation!);
    
    _currentAnimation = animationName;
    _isPlaying = true;
  }

  /// 停止当前动画
  void stop() {
    _simpleAnimation?.isActive = false;
    _isPlaying = false;
  }

  /// 暂停
  void pause() {
    _simpleAnimation?.isActive = false;
    _isPlaying = false;
  }

  /// 恢复
  void resume() {
    if (_simpleAnimation != null) {
      _simpleAnimation!.isActive = true;
      _isPlaying = true;
    }
  }

  /// 释放资源
  void dispose() {
    _simpleAnimation?.isActive = false;
    _simpleAnimation = null;
    _isPlaying = false;
  }
}