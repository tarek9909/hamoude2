import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'screens/navigation_shell.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StorefrontTemplateApp());
}

class StorefrontTemplateApp extends StatelessWidget {
  const StorefrontTemplateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: appState.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightThemeFor(appState.branding),
            home: const NavigationShell(),
          );
        },
      ),
    );
  }
}
