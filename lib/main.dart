import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'screens/navigation_shell.dart';
import 'services/storefront_api.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = StorefrontApi();
  var initialBranding = await AppState.loadCachedBranding(api.storeSlug);
  Map<String, dynamic>? initialConfig;

  if (initialBranding == null) {
    try {
      initialConfig = await api.getConfig().timeout(const Duration(seconds: 4));
      initialBranding =
          StoreBranding.fromConfig(initialConfig, fallbackSlug: api.storeSlug);
      await AppState.cacheBranding(api.storeSlug, initialBranding);
    } catch (_) {
      initialBranding = null;
    }
  }

  runApp(StorefrontTemplateApp(
    api: api,
    initialBranding: initialBranding,
    initialConfig: initialConfig,
  ));
}

class MaterialAppConfig {
  final String appName;
  final dynamic branding;

  MaterialAppConfig({required this.appName, required this.branding});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaterialAppConfig &&
          runtimeType == other.runtimeType &&
          appName == other.appName &&
          branding == other.branding;

  @override
  int get hashCode => appName.hashCode ^ branding.hashCode;
}

class StorefrontTemplateApp extends StatelessWidget {
  final StorefrontApi api;
  final StoreBranding? initialBranding;
  final Map<String, dynamic>? initialConfig;

  const StorefrontTemplateApp({
    super.key,
    required this.api,
    this.initialBranding,
    this.initialConfig,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppState(
            api: api,
            initialBranding: initialBranding,
            initialConfig: initialConfig,
          ),
        ),
      ],
      child: Selector<AppState, MaterialAppConfig>(
        selector: (context, appState) => MaterialAppConfig(
          appName: appState.appName,
          branding: appState.branding,
        ),
        builder: (context, config, _) {
          return MaterialApp(
            title: config.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightThemeFor(config.branding),
            home: const AppSplashScreen(),
          );
        },
      ),
    );
  }
}

class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({super.key});

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _showMainApp = false;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    if (!appState.isLoadingConfig && !_showMainApp && !_isTransitioning) {
      _isTransitioning = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            setState(() {
              _showMainApp = true;
            });
          }
        });
      });
    }

    if (_showMainApp) {
      return _AuthGate();
    }

    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: Image.asset(
            'assets/splash_logo.png',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Shopping is public. Account-only actions gate themselves when opened.
    return const NavigationShell();
  }
}
