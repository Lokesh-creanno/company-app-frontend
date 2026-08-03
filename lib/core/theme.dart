import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  AURORA COLOUR SYSTEM
// ═══════════════════════════════════════════════════════════════════════════════
class AppColors {
  // ── Core palette (theme-independent references) ────────────────────────────
  static const primary       = Color(0xFF7C3AED); // violet-600
  static const primaryLight  = Color(0xFFA78BFA); // violet-400
  static const primaryDark   = Color(0xFF5B21B6); // violet-800
  static const secondary     = Color(0xFF06B6D4); // cyan-500
  static const accent        = Color(0xFFEC4899); // pink-500
  static const indigo        = Color(0xFF4F46E5); // indigo-600

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const success = Color(0xFF10B981); // emerald-500
  static const warning = Color(0xFFF59E0B); // amber-500
  static const error   = Color(0xFFF43F5E); // rose-500
  static const info    = Color(0xFF38BDF8); // sky-400

  // ── Light mode ────────────────────────────────────────────────────────────
  static const lightBg          = Color(0xFFF0EFFE);
  static const lightSurface     = Color(0xFFFFFFFF);
  static const lightSurfaceVar  = Color(0xFFF5F3FF);
  static const lightBorder      = Color(0xFFDDD6FE);
  static const lightTextPrimary = Color(0xFF1E1B4B);
  static const lightTextSecondary = Color(0xFF6B7280);
  static const lightTextTertiary  = Color(0xFF9CA3AF);

  // ── Dark mode (deep space) ─────────────────────────────────────────────────
  static const darkBg           = Color(0xFF070711);
  static const darkSurface      = Color(0xFF0F0F1E);
  static const darkSurfaceVar   = Color(0xFF14142A);
  static const darkBorder       = Color(0xFF2D2B55);
  static const darkBorderGlow   = Color(0xFF7C3AED);
  static const darkTextPrimary  = Color(0xFFEDE9FE);
  static const darkTextSecondary= Color(0xFF8B8BA8);
  static const darkTextTertiary = Color(0xFF4B4B6E);

  // ── Aurora orb colours ─────────────────────────────────────────────────────
  static const auroraViolet = Color(0xFF7C3AED);
  static const auroraCyan   = Color(0xFF06B6D4);
  static const auroraIndigo = Color(0xFF4F46E5);
  static const auroraPink   = Color(0xFFEC4899);
  static const auroraGreen  = Color(0xFF10B981);

  // ── Glow ──────────────────────────────────────────────────────────────────
  static const glowPrimary   = Color(0x607C3AED);
  static const glowCyan      = Color(0x5506B6D4);
  static const glowPink      = Color(0x55EC4899);
  static const glowIndigo    = Color(0x554F46E5);

  // ── Context-aware helpers (use in build methods for proper dark/light) ───────
  static Color bgOf(BuildContext ctx)            => _isDark(ctx) ? darkBg            : lightBg;
  static Color surfaceOf(BuildContext ctx)       => _isDark(ctx) ? darkSurface        : lightSurface;
  static Color surfaceVarOf(BuildContext ctx)    => _isDark(ctx) ? darkSurfaceVar     : lightSurfaceVar;
  static Color borderOf(BuildContext ctx)        => _isDark(ctx) ? darkBorder         : lightBorder;
  static Color textPrimaryOf(BuildContext ctx)   => _isDark(ctx) ? darkTextPrimary    : lightTextPrimary;
  static Color textSecondaryOf(BuildContext ctx) => _isDark(ctx) ? darkTextSecondary  : lightTextSecondary;
  static Color textTertiaryOf(BuildContext ctx)  => _isDark(ctx) ? darkTextTertiary   : lightTextTertiary;

  static bool _isDark(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;

  // ── Static const aliases (light-mode values, for const contexts) ─────────────
  // These keep legacy screens compiling without context. New code should prefer
  // the *Of(ctx) variants above for correct dark-mode colours.
  static const background     = lightBg;
  static const surface        = lightSurface;
  static const surfaceVariant = lightSurfaceVar;
  static const border         = lightBorder;
  static const textPrimary    = lightTextPrimary;
  static const textSecondary  = lightTextSecondary;
  static const textTertiary   = lightTextTertiary;
  static const borderStrong   = Color(0xFFC4B5FD);
  static const textOnPrimary  = Colors.white;

  // Static fallbacks (light mode values — used in const contexts)
  static const cardShadow     = Color(0x287C3AED);
  static const glowAccent     = Color(0x40EC4899);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  GRADIENTS
// ═══════════════════════════════════════════════════════════════════════════════
class AppGradients {
  // Aurora hero — used in headers, login panel, admin header
  static const hero = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.5, 1.0],
  );

  static const primary = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const secondary = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const aurora = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF06B6D4), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.33, 0.66, 1.0],
  );

  // Glass surface gradients
  static LinearGradient glassLight = LinearGradient(
    colors: [Colors.white.withOpacity(0.72), Colors.white.withOpacity(0.42)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient glassDark = LinearGradient(
    colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Card gradients
  static const card = LinearGradient(
    colors: [Colors.white, Color(0xFFF9F7FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cardDark = LinearGradient(
    colors: [Color(0xFF14142A), Color(0xFF0F0F1E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Semantic
  static const success = LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const warning = LinearGradient(colors: [Color(0xFFD97706), Color(0xFFF59E0B)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const error   = LinearGradient(colors: [Color(0xFFE11D48), Color(0xFFF43F5E)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const info    = LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF38BDF8)], begin: Alignment.topLeft, end: Alignment.bottomRight);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  GLASS STYLE HELPERS
// ═══════════════════════════════════════════════════════════════════════════════
class AppGlass {
  /// Standard glass box decoration — use inside BackdropFilter
  static BoxDecoration decoration({
    bool isDark = false,
    double opacity = 1.0,
    double borderRadius = 20,
    Color? borderColor,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      gradient: isDark
          ? LinearGradient(
              colors: [
                Colors.white.withOpacity(0.07 * opacity),
                Colors.white.withOpacity(0.03 * opacity),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : LinearGradient(
              colors: [
                Colors.white.withOpacity(0.80 * opacity),
                Colors.white.withOpacity(0.55 * opacity),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ??
            (isDark
                ? Colors.white.withOpacity(0.12)
                : Colors.white.withOpacity(0.6)),
        width: 1.2,
      ),
      boxShadow: shadows ??
          (isDark
              ? [
                  BoxShadow(color: AppColors.auroraViolet.withOpacity(0.15), blurRadius: 32, offset: const Offset(0, 8)),
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                ]
              : [
                  BoxShadow(color: AppColors.auroraViolet.withOpacity(0.10), blurRadius: 24, offset: const Offset(0, 6)),
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
                ]),
    );
  }

  /// Violet glow shadow for buttons / heroes
  static List<BoxShadow> violetGlow({double intensity = 0.45}) => [
    BoxShadow(color: AppColors.auroraViolet.withOpacity(intensity), blurRadius: 28, offset: const Offset(0, 8)),
    BoxShadow(color: AppColors.auroraViolet.withOpacity(intensity * 0.5), blurRadius: 8, offset: const Offset(0, 2)),
  ];

  static List<BoxShadow> cyanGlow({double intensity = 0.4}) => [
    BoxShadow(color: AppColors.auroraCyan.withOpacity(intensity), blurRadius: 28, offset: const Offset(0, 8)),
    BoxShadow(color: AppColors.auroraCyan.withOpacity(intensity * 0.4), blurRadius: 8, offset: const Offset(0, 2)),
  ];

  static List<BoxShadow> pinkGlow({double intensity = 0.35}) => [
    BoxShadow(color: AppColors.auroraPink.withOpacity(intensity), blurRadius: 28, offset: const Offset(0, 8)),
    BoxShadow(color: AppColors.auroraPink.withOpacity(intensity * 0.4), blurRadius: 8, offset: const Offset(0, 2)),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SHADOWS
// ═══════════════════════════════════════════════════════════════════════════════
class AppShadows {
  static List<BoxShadow> card = [
    const BoxShadow(color: AppColors.cardShadow, blurRadius: 20, offset: Offset(0, 4)),
    const BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static List<BoxShadow> glow(Color color, {double intensity = 0.35}) => [
    BoxShadow(color: color.withOpacity(intensity), blurRadius: 28, offset: const Offset(0, 8)),
    BoxShadow(color: color.withOpacity(intensity * 0.4), blurRadius: 8, offset: const Offset(0, 2)),
  ];

  static List<BoxShadow> primaryGlow = glow(AppColors.primary);
  static List<BoxShadow> secondaryGlow = glow(AppColors.secondary);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  RESPONSIVE
// ═══════════════════════════════════════════════════════════════════════════════
class Responsive {
  static bool isMobile(BuildContext ctx)  => MediaQuery.of(ctx).size.width < 600;
  static bool isTablet(BuildContext ctx)  => MediaQuery.of(ctx).size.width >= 600 && MediaQuery.of(ctx).size.width < 1024;
  static bool isDesktop(BuildContext ctx) => MediaQuery.of(ctx).size.width >= 1024;
  static bool isWide(BuildContext ctx)    => MediaQuery.of(ctx).size.width >= 600;

  static double contentWidth(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    if (w >= 1400) return 1200;
    if (w >= 1024) return w - 280;
    return w;
  }

  static EdgeInsets pagePadding(BuildContext ctx) {
    if (isDesktop(ctx)) return const EdgeInsets.fromLTRB(32, 24, 32, 24);
    if (isTablet(ctx))  return const EdgeInsets.fromLTRB(24, 20, 24, 20);
    return const EdgeInsets.fromLTRB(16, 16, 16, 16);
  }

  static int gridCols(BuildContext ctx) {
    if (isDesktop(ctx)) return 4;
    if (isTablet(ctx))  return 3;
    return 2;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  LIGHT THEME
// ═══════════════════════════════════════════════════════════════════════════════
class AppTheme {
  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme  => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base   = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

    final bg          = isDark ? AppColors.darkBg          : AppColors.lightBg;
    final surface     = isDark ? AppColors.darkSurface      : AppColors.lightSurface;
    final surfaceVar  = isDark ? AppColors.darkSurfaceVar   : AppColors.lightSurfaceVar;
    final border      = isDark ? AppColors.darkBorder       : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary  : AppColors.lightTextPrimary;
    final textSec     = isDark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
    final textTer     = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return base.copyWith(
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary:         AppColors.primary,
        onPrimary:       Colors.white,
        secondary:       AppColors.secondary,
        onSecondary:     Colors.white,
        tertiary:        AppColors.accent,
        onTertiary:      Colors.white,
        error:           AppColors.error,
        onError:         Colors.white,
        surface:         surface,
        onSurface:       textPrimary,
        surfaceVariant:  surfaceVar,
        onSurfaceVariant: textSec,
        outline:         border,
        background:      bg,
        onBackground:    textPrimary,
        shadow:          Colors.black,
        scrim:           Colors.black,
        inverseSurface:  isDark ? AppColors.lightSurface : AppColors.darkSurface,
        onInverseSurface: isDark ? AppColors.lightTextPrimary : AppColors.darkTextPrimary,
      ),
      scaffoldBackgroundColor: bg,

      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor:    textPrimary,
        displayColor: textPrimary,
      ),

      // ── AppBar ──────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textPrimary),
        toolbarHeight: 60,
      ),

      // ── Cards ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: surface.withOpacity(isDark ? 0.6 : 0.85),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),

      // ── Buttons ─────────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: AppColors.primary.withOpacity(0.6), width: 1.5),
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),

      // ── Inputs ──────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : AppColors.lightSurfaceVar,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.8), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        hintStyle: GoogleFonts.poppins(color: textTer, fontSize: 14),
        labelStyle: GoogleFonts.poppins(color: textSec, fontSize: 14),
        prefixIconColor: textSec,
      ),

      // ── Navigation Bar (mobile) ─────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: AppColors.primary.withOpacity(isDark ? 0.25 : 0.14),
        elevation: 0,
        height: 64,
        labelTextStyle: MaterialStateProperty.resolveWith((s) {
          if (s.contains(MaterialState.selected)) {
            return GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryLight);
          }
          return GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: textTer);
        }),
        iconTheme: MaterialStateProperty.resolveWith((s) {
          if (s.contains(MaterialState.selected)) return const IconThemeData(color: AppColors.primaryLight, size: 22);
          return IconThemeData(color: textTer, size: 22);
        }),
      ),

      // ── Navigation Rail (desktop) ───────────────────────────────────────────
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        selectedIconTheme: const IconThemeData(color: AppColors.primaryLight, size: 22),
        unselectedIconTheme: IconThemeData(color: textTer, size: 22),
        selectedLabelTextStyle: GoogleFonts.poppins(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: GoogleFonts.poppins(color: textSec, fontSize: 12, fontWeight: FontWeight.w500),
        indicatorColor: AppColors.primary.withOpacity(isDark ? 0.25 : 0.12),
        elevation: 0,
        useIndicator: true,
        minWidth: 80,
        minExtendedWidth: 220,
      ),

      // ── Divider / Dialog / Chip ─────────────────────────────────────────────
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVar,
        labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: border),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: isDark ? const Color(0xFF1A1A30) : const Color(0xFF1E1B4B),
        contentTextStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: surface,
        elevation: 0,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: border)),
        elevation: 8,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        modalBackgroundColor: surface,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: textSec,
        indicatorColor: AppColors.primary,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? AppColors.primary : Colors.grey),
        trackColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? AppColors.primary.withOpacity(0.4) : Colors.grey.withOpacity(0.3)),
      ),
    );
  }
}
