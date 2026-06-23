import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── 自定义语义色 ──────────────────────────────────────
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceDim,
    required this.onBackground,
    required this.onBackgroundMid,
    required this.onBackgroundLight,
    required this.primary,
    required this.primaryMuted,
    required this.divider,
    required this.inputFill,
    required this.cardShadow,
    required this.outline,
    required this.hint,
    required this.dialogBackground,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceDim;
  final Color onBackground;
  final Color onBackgroundMid;
  final Color onBackgroundLight;
  final Color primary;
  final Color primaryMuted;
  final Color divider;
  final Color inputFill;
  final Color cardShadow;
  final Color outline;
  final Color hint;
  final Color dialogBackground;

  // ── 亮色方案 ──
  static const light = AppColors(
    background: Color(0xFFF8FAF6),
    surface: Colors.white,
    surfaceAlt: Color(0xFFF2F7F7),
    surfaceDim: Color(0xFFE0F2EF),
    onBackground: Color(0xFF16211F),
    onBackgroundMid: Color(0xFF65736F),
    onBackgroundLight: Color(0xFF8B9A94),
    primary: Color(0xFF167C80),
    primaryMuted: Color(0xFFC4E5E0),
    divider: Color(0xFFE9EFEC),
    inputFill: Colors.white,
    cardShadow: Color(0x1A53615D),
    outline: Color(0xFFE1E8E4),
    hint: Color(0xFF9AA6A1),
    dialogBackground: Colors.white,
  );

  // ── 暗色方案 ──
  static const dark = AppColors(
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    surfaceAlt: Color(0xFF252525),
    surfaceDim: Color(0xFF2A2A2A),
    onBackground: Color(0xFFE8E8E8),
    onBackgroundMid: Color(0xFFA0A0A0),
    onBackgroundLight: Color(0xFF707070),
    primary: Color(0xFF4ECDC4),
    primaryMuted: Color(0xFF1A3A3A),
    divider: Color(0xFF333333),
    inputFill: Color(0xFF2A2A2A),
    cardShadow: Colors.transparent,
    outline: Color(0xFF3A3A3A),
    hint: Color(0xFF707070),
    dialogBackground: Color(0xFF1E1E1E),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceDim,
    Color? onBackground,
    Color? onBackgroundMid,
    Color? onBackgroundLight,
    Color? primary,
    Color? primaryMuted,
    Color? divider,
    Color? inputFill,
    Color? cardShadow,
    Color? outline,
    Color? hint,
    Color? dialogBackground,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceDim: surfaceDim ?? this.surfaceDim,
      onBackground: onBackground ?? this.onBackground,
      onBackgroundMid: onBackgroundMid ?? this.onBackgroundMid,
      onBackgroundLight: onBackgroundLight ?? this.onBackgroundLight,
      primary: primary ?? this.primary,
      primaryMuted: primaryMuted ?? this.primaryMuted,
      divider: divider ?? this.divider,
      inputFill: inputFill ?? this.inputFill,
      cardShadow: cardShadow ?? this.cardShadow,
      outline: outline ?? this.outline,
      hint: hint ?? this.hint,
      dialogBackground: dialogBackground ?? this.dialogBackground,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceDim: Color.lerp(surfaceDim, other.surfaceDim, t)!,
      onBackground: Color.lerp(onBackground, other.onBackground, t)!,
      onBackgroundMid: Color.lerp(onBackgroundMid, other.onBackgroundMid, t)!,
      onBackgroundLight: Color.lerp(onBackgroundLight, other.onBackgroundLight, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryMuted: Color.lerp(primaryMuted, other.primaryMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      hint: Color.lerp(hint, other.hint, t)!,
      dialogBackground: Color.lerp(dialogBackground, other.dialogBackground, t)!,
    );
  }
}

// ── 便捷扩展 ──
extension AppColorsExtension on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

// ── 主题工厂 ──
class AppTheme {
  AppTheme._();

  // ── 亮色主题 ──
  static ThemeData light() {
    const colors = AppColors.light;
    return _buildTheme(colors, Brightness.light);
  }

  // ── 暗色主题 ──
  static ThemeData dark() {
    const colors = AppColors.dark;
    return _buildTheme(colors, Brightness.dark);
  }

  static ThemeData _buildTheme(AppColors colors, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    // 深色模式用低饱和度的青色作为种子色，避免按钮/FAB过亮刺眼
    final seedColor = isDark ? const Color(0xFF2B9E96) : colors.primary;

    return ThemeData(
      fontFamily: 'NotoSansSC',
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
        surface: colors.surface,
      ),
      scaffoldBackgroundColor: colors.background,
      useMaterial3: true,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        elevation: 0,
        titleTextStyle: TextStyle(
          color: colors.onBackground,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 0.8,
        shadowColor: colors.cardShadow,
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputFill,
        errorStyle: const TextStyle(color: Color(0xFFE2554F)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colors.primary.withValues(alpha: 0.2), width: 1),
        ),
        hintStyle: TextStyle(color: colors.hint),
        labelStyle: TextStyle(color: colors.onBackgroundMid),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          side: BorderSide(color: colors.outline),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: colors.primaryMuted,
      ),
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.dialogBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.dialogBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primaryMuted;
          }
          return null;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary;
          }
          return null;
        }),
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(color: colors.onBackground),
        titleMedium: TextStyle(color: colors.onBackground),
        titleSmall: TextStyle(color: colors.onBackground),
        bodyLarge: TextStyle(color: colors.onBackground),
        bodyMedium: TextStyle(color: colors.onBackground),
        bodySmall: TextStyle(color: colors.onBackgroundMid),
        labelLarge: TextStyle(color: colors.onBackgroundMid),
        labelMedium: TextStyle(color: colors.onBackgroundMid),
        labelSmall: TextStyle(color: colors.onBackgroundMid),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.onBackgroundMid,
        ),
      ),
    );
  }
}
