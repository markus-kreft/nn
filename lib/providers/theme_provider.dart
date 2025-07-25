import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class ThemeProvider with ChangeNotifier {
  final ThemeService _themeService;
  ThemeMode _themeMode = ThemeMode.system; // Provide a default value
  double _fontSize = 14.0; // Default font size

  ThemeProvider(this._themeService) {
    _loadPreferences();
  }

  ThemeMode get themeMode => _themeMode;
  double get fontSize => _fontSize;

  void _loadPreferences() async {
    _themeMode = await _themeService.getThemeMode();
    _fontSize = await _themeService.getFontSize();
    notifyListeners();
  }

  void setTheme(ThemeMode themeMode) async {
    _themeMode = themeMode;
    await _themeService.setThemeMode(themeMode);
    notifyListeners();
  }

  void setFontSize(double size) async {
    _fontSize = size;
    await _themeService.setFontSize(size);
    notifyListeners();
  }
}