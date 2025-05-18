import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lớp cấu hình Theme toàn cục cho ứng dụng
class AppTheme {
  // Định nghĩa các màu theo logo
  static const Color primaryBlue = Color(0xFF436E98); // Màu xanh chính từ logo
  static const Color darkBlue = Color(0xFF152C4F); // Màu xanh đậm từ logo
  static const Color lightBlue = Color(0xFF6C99C0); // Màu xanh nhạt từ logo

  // Màu nền và màu phụ mới (nhẹ nhàng hơn)
  static const Color lightBackground = Color(0xFFF9FAFB);
  static const Color darkBackground = Color(0xFF121820);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E2530);

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

  // Theme sáng cho ứng dụng - mềm mại hơn, đơn giản hơn, ít border
  static ThemeData lightTheme = ThemeData(
    primarySwatch: primarySwatch,
    primaryColor: primaryBlue,
    scaffoldBackgroundColor: lightBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceLight,
      foregroundColor: primaryBlue,
      elevation: 0, // Không shadow
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Transparent status bar
        statusBarIconBrightness:
            Brightness.dark, // Dark icons for light background
        statusBarBrightness: Brightness.light, // iOS: dark text
      ),
      iconTheme: IconThemeData(color: primaryBlue),
      titleTextStyle: TextStyle(
          color: primaryBlue, fontSize: 18, fontWeight: FontWeight.w500),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0, // No shadow
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(color: primaryBlue.withOpacity(0.3), width: 1),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryBlue,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white,
      elevation: 2, // Minimal shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    cardTheme: CardTheme(
      elevation: 0, // No shadow
      color: surfaceLight,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surfaceLight,
      elevation: 2, // Minimal shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    dividerTheme: const DividerThemeData(
      thickness: 0.5,
      color: Color(0xFFEEEEEE),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primaryBlue.withOpacity(0.5), width: 1),
      ),
    ),
    colorScheme: ColorScheme.light(
      primary: primaryBlue,
      secondary: lightBlue,
      onPrimary: Colors.white,
      primaryContainer: lightBlue.withOpacity(0.15),
      surface: surfaceLight,
      onSurface: darkBlue,
      background: lightBackground,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: surfaceLight,
      elevation: 0, // No shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surfaceLight,
      modalBackgroundColor: surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      elevation: 0, // No shadow
    ),
    tabBarTheme: TabBarTheme(
      labelColor: primaryBlue,
      unselectedLabelColor: Colors.grey,
      indicator: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: primaryBlue,
            width: 2,
          ),
        ),
      ),
    ),
  );

  // Theme tối cho ứng dụng - mềm mại hơn, đơn giản hơn, ít border
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: primarySwatch,
    primaryColor: primaryBlue,
    scaffoldBackgroundColor: darkBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceDark,
      foregroundColor: Colors.white,
      elevation: 0, // No shadow
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Transparent status bar
        statusBarIconBrightness:
            Brightness.light, // Light icons for dark background
        statusBarBrightness: Brightness.dark, // iOS: light text
      ),
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0, // No shadow
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white,
      elevation: 2, // Minimal shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    cardTheme: CardTheme(
      elevation: 0, // No shadow
      color: surfaceDark,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surfaceDark,
      elevation: 2, // Minimal shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    dividerTheme: DividerThemeData(
      thickness: 0.5,
      color: Colors.grey.withOpacity(0.2),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: lightBlue.withOpacity(0.5), width: 1),
      ),
    ),
    colorScheme: ColorScheme.dark(
      primary: primaryBlue,
      secondary: lightBlue,
      onPrimary: Colors.white,
      primaryContainer: darkBlue.withOpacity(0.3),
      surface: surfaceDark,
      onSurface: Colors.white,
      background: darkBackground,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: surfaceDark,
      elevation: 0, // No shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surfaceDark,
      modalBackgroundColor: surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      elevation: 0, // No shadow
    ),
    tabBarTheme: TabBarTheme(
      labelColor: lightBlue,
      unselectedLabelColor: Colors.grey,
      indicator: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: lightBlue,
            width: 2,
          ),
        ),
      ),
    ),
  );
}
