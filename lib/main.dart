import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'core/providers.dart';
import 'core/theme.dart';
import 'core/app_localizations.dart';
import 'core/remote_config_service.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/role_redirect.dart';
import 'features/notification/notification_service.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'core/session_timeout.dart';

/// Global navigator key — ใช้สำหรับ deep link จาก notification
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔧 B2: Disable offline persistence on Web to prevent serverTimestamp cache crash
  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  }

  // F2: Crashlytics — จับ Flutter errors + platform errors (ข้ามบน Web)
  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // F9: เริ่มระบบแจ้งเตือน
  await NotificationService.initialize();
  NotificationService.navigatorKey = navigatorKey;

  // F35: Remote Config
  await RemoteConfigService.initialize();

  runApp(
    const ProviderScope(
      child: CampusIncidentApp(),
    ),
  );
}

/// v4: เพิ่ม F33 Onboarding + F34 i18n + F35 Remote Config
class CampusIncidentApp extends ConsumerWidget {
  const CampusIncidentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'ระบบแจ้งเหตุภายในมหาวิทยาลัยเทคโนโลยีสุรนารี',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider),
      navigatorKey: navigatorKey,

      // F34: Localization support
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('th'),

      home: authState.when(
        data: (user) {
          if (user == null) return const _AuthGate();
          // Handle notification tap that opened the app from terminated state
          NotificationService.handleInitialMessage();
          return const SessionTimeoutWrapper(child: RoleRedirect());
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => const LoginScreen(),
      ),
    );
  }
}

/// F33: Auth Gate — animated splash + onboarding check
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> with SingleTickerProviderStateMixin {
  bool? _hasSeenOnboarding;
  bool _splashDone = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutBack),
    );
    _fadeController.forward();
    _initSplash();
  }

  Future<void> _initSplash() async {
    final seen = await OnboardingScreen.hasSeenOnboarding();
    // รออย่างน้อย 2 วินาทีเพื่อให้ animation เล่นจบ
    await Future.delayed(const Duration(milliseconds: 2200));
    if (mounted) {
      setState(() {
        _hasSeenOnboarding = seen;
        _splashDone = true;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Splash Screen
    if (!_splashDone) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.primaryOrange, AppTheme.secondaryOrange],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // โลโก้ fade in + scale
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/university_logo.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(Icons.shield, color: Colors.white, size: 64),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _fadeAnimation,
                child: const Text(
                  'ระบบแจ้งเหตุมหาวิทยาลัย',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Colors.white70,
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasSeenOnboarding == false) {
      return const OnboardingScreen();
    }

    return const LoginScreen();
  }
}