import 'package:go_router/go_router.dart';

import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/scan/scan_screen.dart';
import '../../presentation/screens/result/result_screen.dart';
import '../../presentation/screens/history/history_screen.dart';
import '../../presentation/screens/education/education_screen.dart';
import '../../data/models/detection_result.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/scan/:cancerType',
        builder: (context, state) => ScanScreen(
          cancerType: state.pathParameters['cancerType']!,
        ),
      ),
      GoRoute(
        path: '/result',
        builder: (context, state) => ResultScreen(
          result: state.extra as DetectionResult,
        ),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/education/:cancerType',
        builder: (context, state) => EducationScreen(
          cancerType: state.pathParameters['cancerType']!,
        ),
      ),
    ],
  );
}
