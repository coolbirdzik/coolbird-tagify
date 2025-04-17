import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lớp cấu hình Theme toàn cục cho ứng dụng
class AppTheme {
  // Định nghĩa các màu theo logo
  static const Color primaryBlue = Color(0xFF436E98); // Màu xanh chính từ logo
  static const Color darkBlue = Color(0xFF152C4F); // Màu xanh đậm từ logo
  static const Color lightBlue = Color(0xFF6C99C0); // Màu xanh nhạt từ logo

  // Tạo MaterialColor từ màu primaryBlue để dùng cho primarySwatch
  static MaterialColor createMaterialColor(Color color) {
    List<double> strengths = <double>[.05, .1, .2, .3, .4, .5, .6, .7, .8, .9];
    Map<int, Color> swatch = {};
    final int r = color.red, g = color.green, b = color.blue;

    for (final double strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    swatch[500] = color;
    return MaterialColor(color.value, swatch);
  }

  // Tạo swatch từ màu chính
  static final MaterialColor primarySwatch = createMaterialColor(primaryBlue);

  // Theme sáng cho ứng dụng
  static ThemeData lightTheme = ThemeData(
    primarySwatch: primarySwatch,
    primaryColor: primaryBlue,
    scaffoldBackgroundColor: Colors.white, // Pure white background
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white,
      elevation: 2,
      systemOverlayStyle: SystemUiOverlayStyle(
        // Màu trạng thái của thanh thông báo
        statusBarColor: primaryBlue, // Sử dụng cùng màu với AppBar
        statusBarIconBrightness: Brightness.light, // Biểu tượng màu trắng
        statusBarBrightness: Brightness.dark, // iOS: Text màu trắng
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white,
    ),
    cardTheme: const CardTheme(
      elevation: 2,
      color: Colors.white, // Pure white card background
    ),
    dialogBackgroundColor: Colors.white, // Pure white dialog background
    popupMenuTheme: const PopupMenuThemeData(
      color: Colors.white, // Pure white popup menu background
    ),
    colorScheme: ColorScheme.light(
      primary: primaryBlue,
      secondary: lightBlue,
      onPrimary: Colors.white,
      primaryContainer: lightBlue.withOpacity(0.3),
      surface: Colors.white,
      onSurface: darkBlue,
    ),
  );

  // Theme tối cho ứng dụng
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: primarySwatch,
    primaryColor: primaryBlue,
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryBlue,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBlue,
      foregroundColor: Colors.white,
      elevation: 3,
      systemOverlayStyle: SystemUiOverlayStyle(
        // Màu trạng thái của thanh thông báo cho theme tối
        statusBarColor: darkBlue, // Sử dụng màu xanh đậm phù hợp với theme tối
        statusBarIconBrightness: Brightness.light, // Biểu tượng màu trắng
        statusBarBrightness: Brightness.dark, // iOS: Text màu trắng
      ),
    ),
    cardTheme: CardTheme(
      color: Colors.grey[850],
      elevation: 2,
    ),
    colorScheme: ColorScheme.dark(
      primary: primaryBlue,
      secondary: lightBlue,
      onPrimary: Colors.white,
      primaryContainer: darkBlue.withOpacity(0.6),
      surface: const Color(0xFF121212),
      onSurface: Colors.white,
    ),
  );
}
