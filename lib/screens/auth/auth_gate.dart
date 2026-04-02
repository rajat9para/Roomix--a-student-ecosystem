import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:roomix/screens/admin/admin_dashboard_screen.dart';
import 'package:roomix/screens/auth/login_screen.dart';
import 'package:roomix/screens/home/home_screen.dart';
import 'package:roomix/screens/owner/owner_dashboard_screen.dart';
import 'package:roomix/screens/splash_screen.dart';

/// Single authority for auth-driven navigation.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  bool _showSplash = true;
  bool _splashTimerDone = false;
  String? _profileLoadRequestedForUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Keep splash on cold launch for a short minimum time.
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _splashTimerDone = true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;

    // Never re-show splash when app resumes.
    setState(() {
      _showSplash = false;
      _splashTimerDone = true;
    });
  }

  void _triggerProfileLoadIfNeeded(AuthProvider auth) {
    final uid = auth.firebaseUser?.uid;
    if (uid == null) return;
    if (_profileLoadRequestedForUid == uid) return;

    _profileLoadRequestedForUid = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AuthProvider>();
      if (provider.currentUser == null && provider.firebaseUser?.uid == uid) {
        provider.fetchProfile().catchError((_) {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.initialized && _showSplash) {
          return const SplashScreen();
        }

        if (_showSplash && !_splashTimerDone) {
          return const SplashScreen();
        }

        if (_showSplash) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _showSplash = false);
          });
          return const SplashScreen();
        }

        if (!auth.isAuthenticated) {
          _profileLoadRequestedForUid = null;
          return const LoginScreen();
        }

        if (auth.currentUser == null) {
          _triggerProfileLoadIfNeeded(auth);
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        _profileLoadRequestedForUid = null;
        final role = auth.currentUser!.role.trim().toLowerCase();
        debugPrint('🚦 AuthGate: Routing user "${auth.currentUser!.name}" with role="$role"');
        if (role == 'admin') {
          debugPrint('🚦 AuthGate: → AdminDashboardScreen');
          return const AdminDashboardScreen();
        }
        if (role == 'owner') {
          debugPrint('🚦 AuthGate: → OwnerDashboardScreen');
          return const OwnerDashboardScreen();
        }
        debugPrint('🚦 AuthGate: → HomeScreen (student)');
        return const HomeScreen();
      },
    );
  }
}
