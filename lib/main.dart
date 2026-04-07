import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'presentation/pages/calibration_page.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/settings_page.dart';
import 'application/providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 设置状态栏样式
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  // 启用屏幕常亮
  await WakelockPlus.enable();
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // 初始化埋点服务
    final analyticsService = ref.read(analyticsServiceProvider);
    await analyticsService.initialize();
    await analyticsService.logAppLaunch();
    
    // 启动性能监控
    final performanceMonitor = ref.read(performanceMonitorProvider);
    performanceMonitor.startMonitoring();
    
    // 初始化音效服务
    final soundService = ref.read(soundServiceProvider);
    await soundService.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        // 应用进入后台
        ref.read(analyticsServiceProvider).logPauseResume(true);
        break;
      case AppLifecycleState.resumed:
        // 应用恢复前台
        ref.read(analyticsServiceProvider).logPauseResume(false);
        break;
      case AppLifecycleState.detached:
        // 应用退出
        ref.read(analyticsServiceProvider).endSession();
        WakelockPlus.disable();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(performanceMonitorProvider).dispose();
    ref.read(soundServiceProvider).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mimo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/calibration',
      routes: {
        '/calibration': (context) => const CalibrationPage(),
        '/home': (context) => const HomePage(),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}