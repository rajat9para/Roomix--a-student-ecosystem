import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roomix/providers/auth_provider.dart';
import 'package:roomix/screens/home/home_screen.dart';
import 'package:roomix/screens/owner/owner_dashboard_screen.dart';
import 'package:roomix/screens/auth/login_screen.dart';

class RoleGate extends StatelessWidget {
  const RoleGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (!auth.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (auth.currentUser == null) {
      return const LoginScreen();
    }

    final role = auth.currentUser!.role.trim().toLowerCase();

    if (role == 'owner') {
      return const OwnerDashboardScreen();
    }

    return const HomeScreen();
  }
}
