import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:roomix/screens/auth/login_screen.dart';
import 'package:roomix/screens/home/home_screen.dart';
import 'package:roomix/screens/splash_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {

        /// while firebase checking saved login
        if (auth.isLoading) {
          return const SplashScreen();
        }

        /// user NOT logged in
        if (!auth.isAuthenticated) {
          return const LoginScreen();
        }

        /// user logged in
        return const HomeScreen();
      },
    );
  }
}