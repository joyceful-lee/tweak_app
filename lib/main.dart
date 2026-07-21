import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tweak_app/app_theme.dart';

// screen routes
import 'config/supabase_config.dart';
import 'screens/dish_list.dart';
import 'screens/login_screen.dart';
import 'screens/reset_password_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final StreamSubscription<AuthState> _authSubscription;
  bool _isShowingRecovery = false;

  @override
  void initState() {
    super.initState();

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _showPasswordRecovery();
      }
    });
  }

  void _showPasswordRecovery() {
    if (_isShowingRecovery) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPasswordRecovery();
      });
      return;
    }

    _isShowingRecovery = true;
    navigator
        .push(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        )
        .whenComplete(() => _isShowingRecovery = false);
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Tweak',
      theme: ThemeData(
        colorScheme: earthyLightScheme,
        useMaterial3: true,
        fontFamily: 'Nunito',
        appBarTheme: AppBarTheme(
          titleTextStyle: TextStyle(
            fontFamily: 'Noot',
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: earthyLightScheme.tertiary,
          ),
          backgroundColor: earthyLightScheme.inverseSurface,
          foregroundColor: earthyLightScheme.onInverseSurface,
          centerTitle: false,
          elevation: 0,
        ),

        cardTheme: CardThemeData(
          color: earthyLightScheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return earthyLightScheme.tertiary.withValues(alpha:0.5);
              }
              return earthyLightScheme.primary;
            }),
            foregroundColor: WidgetStateProperty.all(earthyLightScheme.onPrimary),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.all(earthyLightScheme.secondary),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: earthyLightScheme.surface,
          labelStyle: TextStyle(color: earthyLightScheme.onSurface.withValues(alpha:0.75)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: earthyLightScheme.tertiary),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: earthyLightScheme.primary, width: 2),
          ),
        ),

        chipTheme: ChipThemeData(
          backgroundColor: earthyLightScheme.tertiary.withValues(alpha:0.45),
          labelStyle: TextStyle(color: earthyLightScheme.onSurface),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),

        snackBarTheme: SnackBarThemeData(
          backgroundColor: earthyLightScheme.inverseSurface,
          contentTextStyle: TextStyle(color: earthyLightScheme.onInverseSurface),
        ),
      ),
      home: const AuthGate(),
      routes: {
        '/dish-list': (_) => const DishListScreen(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return auth.currentSession == null
            ? const LoginScreen()
            : const DishListScreen();
      },
    );
  }
}
