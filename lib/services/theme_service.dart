import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _themeModeKey = 'theme_mode';
  static const String _primaryColorKey = 'primary_color';

  // Available theme colors
  static const Map<String, Color> themeColors = {
    'Purple': Color(0xFF6750A4),
    'Blue': Color(0xFF2196F3),
    'Green': Color(0xFF4CAF50),
    'Red': Color(0xFFE53935),
    'Orange': Color(0xFFFF9800),
    'Teal': Color(0xFF009688),
  };

  // Get current theme mode
  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themeModeKey) ?? true;
    return isDark ? ThemeMode.dark : ThemeMode.light;
  }

  // Set theme mode
  static Future<void> setThemeMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeModeKey, isDark);
  }

  // Get current primary color
  static Future<Color> getPrimaryColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue =
        prefs.getInt(_primaryColorKey) ?? themeColors['Purple']!.value;
    return Color(colorValue);
  }

  // Set primary color
  static Future<void> setPrimaryColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_primaryColorKey, color.value);
  }

  // Get theme data based on mode and primary color
  static Future<ThemeData> getThemeData(bool isDark, Color primaryColor) async {
    return ThemeData(
      useMaterial3: true,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: primaryColor,
              onPrimary: Colors.white,
              secondary: primaryColor.withOpacity(0.7),
              tertiary: primaryColor.withOpacity(0.5),
              surface: const Color.fromARGB(255, 42, 41, 46),
              error: const Color(0xFFB3261E),
            )
          : ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              secondary: primaryColor.withOpacity(0.7),
              tertiary: primaryColor.withOpacity(0.5),
              surface: Colors.white,
              error: const Color(0xFFB3261E),
            ),
      scaffoldBackgroundColor: isDark ? const Color(0xFF1C1B1F) : Colors.white,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isDark ? const Color.fromARGB(255, 42, 41, 46) : Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1C1B1F) : Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
      ),
    );
  }
}
