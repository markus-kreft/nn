// This widget checks if the user is logged in and routes them accordingly.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'notes_list_screen.dart';
import 'login_screen.dart';
import 'loading_screen.dart';

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  late Future<void> _authCheckFuture;

  @override
  void initState() {
    super.initState();
    // Start the auth check process and store the future.
    _authCheckFuture = _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    // Attempt to load credentials
    await authService.loadCredentials();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    // FutureBuilder waits for the async loadCredentials to complete
    return FutureBuilder(
      future: _authCheckFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }
        if (authService.isLoggedIn) {
          return const NotesListScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}