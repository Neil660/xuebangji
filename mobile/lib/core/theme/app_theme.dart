import 'package:flutter/material.dart';

// 主色调：蓝色系
const _primaryColor = Color(0xFF1976D2);
const _primaryLight = Color(0xFF42A5F5);
const _primaryDark = Color(0xFF0D47A1);
const _accentColor = Color(0xFF03A9F4);
const _successColor = Color(0xFF4CAF50);
const _warningColor = Color(0xFFFF9800);
const _errorColor = Color(0xFFF44336);

// 排名颜色
const rankGoldColor = Color(0xFFFFD700);
const rankSilverColor = Color(0xFFC0C0C0);
const rankBronzeColor = Color(0xFFCD7F32);

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryColor,
          brightness: Brightness.light,
          primary: _primaryColor,
          secondary: _accentColor,
          error: _errorColor,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF212121),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF212121),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _errorColor),
          ),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 14),
          bodyMedium: TextStyle(fontSize: 13),
          labelSmall: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        extensions: const [AppColors.light],
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryColor,
          brightness: Brightness.dark,
          primary: _primaryLight,
          secondary: _accentColor,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF1E1E1E),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        extensions: const [AppColors.dark],
      );
}

// 扩展颜色系统
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.warning,
    required this.timerBg,
    required this.chartLine,
  });

  final Color success;
  final Color warning;
  final Color timerBg;
  final Color chartLine;

  static const light = AppColors(
    success: _successColor,
    warning: _warningColor,
    timerBg: Color(0xFFE3F2FD),
    chartLine: _primaryColor,
  );

  static const dark = AppColors(
    success: Color(0xFF66BB6A),
    warning: Color(0xFFFFB74D),
    timerBg: Color(0xFF0D2137),
    chartLine: _primaryLight,
  );

  @override
  AppColors copyWith({Color? success, Color? warning, Color? timerBg, Color? chartLine}) {
    return AppColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      timerBg: timerBg ?? this.timerBg,
      chartLine: chartLine ?? this.chartLine,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      timerBg: Color.lerp(timerBg, other.timerBg, t)!,
      chartLine: Color.lerp(chartLine, other.chartLine, t)!,
    );
  }
}

// 主题模式 Provider（由 settings 驱动）
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('theme_mode') ?? 'system';
    state = _fromString(mode);
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  ThemeMode _fromString(String s) {
    return ThemeMode.values.firstWhere((m) => m.name == s, orElse: () => ThemeMode.system);
  }
}