import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/notes_provider.dart';
import '../providers/theme_provider.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showThemeDialog(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                groupValue: themeProvider.themeMode,
                title: const Text('System Default'),
                onChanged: (value) {
                  themeProvider.setTheme(value!);
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                groupValue: themeProvider.themeMode,
                title: const Text('Light'),
                onChanged: (value) {
                  themeProvider.setTheme(value!);
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: themeProvider.themeMode,
                title: const Text('Dark (OLED)'),
                onChanged: (value) {
                  themeProvider.setTheme(value!);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFontSizeDialog(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose Font Size'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<double>(
                value: 12.0,
                groupValue: themeProvider.fontSize,
                title: const Text('Small'),
                onChanged: (value) {
                  themeProvider.setFontSize(value!);
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<double>(
                value: 14.0,
                groupValue: themeProvider.fontSize,
                title: const Text('Medium'),
                onChanged: (value) {
                  themeProvider.setFontSize(value!);
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<double>(
                value: 16.0,
                groupValue: themeProvider.fontSize,
                title: const Text('Large'),
                onChanged: (value) {
                  themeProvider.setFontSize(value!);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear Cache?'),
          content: const Text('This will delete all local notes and re-sync from the server. Are you sure?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () async {
                final provider = Provider.of<NotesProvider>(context, listen: false);
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close settings
                await provider.clearLocalData();
                await provider.initialize();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Theme'),
            onTap: () => _showThemeDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.format_size),
            title: const Text('Font Size'),
            onTap: () => _showFontSizeDialog(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.sync_problem),
            title: const Text('Clear Cache & Re-sync'),
            onTap: () => _showClearCacheDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await Provider.of<NotesProvider>(context, listen: false).clearLocalData();
              await Provider.of<AuthService>(context, listen: false).logout();
              
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}