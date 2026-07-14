import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:gym_tracker/models/app_settings.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'enums/enums.dart';
import 'theme/app_theme.dart';
import 'navigation/main_navigation_hub.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await DatabaseService.init();

  FlutterNativeSplash.remove();
  runApp(const GymTrackerApp());
}

class GymTrackerApp extends StatelessWidget {
  const GymTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: DatabaseService.settingsBox.listenable(keys: ['appSettings']),
      builder: (context, Box box, _) {
        final Map? rawSettings = box.get('appSettings') as Map?;
        final AppSettings settings = rawSettings != null ? AppSettings.fromMap(rawSettings) : const AppSettings();
        ThemeMode selectedThemeMode = settings.theme == AppThemeMode.dark ? ThemeMode.dark : ThemeMode.light;
        return MaterialApp(
          title: 'GymTracker',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: selectedThemeMode,
          home: const MainNavigationHub(),
        );
      },
    );
  }
}
