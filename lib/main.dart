import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/auth_service.dart';
import 'providers/notes_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/notes_list_screen.dart';
import 'screens/login_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/auth_check.dart';
import 'services/theme_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider allows us to provide multiple objects to the widget tree.
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<ThemeService>(create: (_) => ThemeService()),
        ChangeNotifierProxyProvider<ThemeService, ThemeProvider>(
          create: (context) => ThemeProvider(
            Provider.of<ThemeService>(context, listen: false),
          ),
          update: (context, themeService, previous) =>
              ThemeProvider(themeService),
        ),
        ChangeNotifierProxyProvider<AuthService, NotesProvider>(
          create: (context) => NotesProvider(
            Provider.of<AuthService>(context, listen: false),
          ),
          update: (context, authService, previousNotesProvider) =>
              previousNotesProvider!..updateAuth(authService),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Nextcloud Notes',
            theme: ThemeData(
              brightness: Brightness.light,
              primarySwatch: Colors.blue,
              visualDensity: VisualDensity.adaptivePlatformDensity,
              textTheme: GoogleFonts.latoTextTheme(
                ThemeData(brightness: Brightness.light).textTheme,
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primarySwatch: Colors.blue,
              scaffoldBackgroundColor: Colors.black, // OLED Black
              visualDensity: VisualDensity.adaptivePlatformDensity,
              textTheme: GoogleFonts.latoTextTheme(
                 ThemeData(brightness: Brightness.dark).textTheme,
              ),
            ),
            themeMode: themeProvider.themeMode,
            home: const AuthCheck(),
          );
        },
      ),
    );
  }
}