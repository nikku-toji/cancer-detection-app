import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'data/models/scan_record.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Hive local storage
  await Hive.initFlutter();
  Hive.registerAdapter(ScanRecordAdapter());
  await Hive.openBox<ScanRecord>('scan_history');

  runApp(
    const ProviderScope(
      child: CancerDetectionApp(),
    ),
  );
}

class CancerDetectionApp extends StatelessWidget {
  const CancerDetectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Cancer Detection AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
    );
  }
}
