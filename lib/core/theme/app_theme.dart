import 'package:flutter/material.dart';

import '../../features/iam/domain/user.dart';

/// Approved mobile identity. Clinical colors retain their web meaning.
class AppTheme {
  AppTheme._();

  /// Primary brand teal — `#0f766e` is the single most-used hex in the
  /// Angular app's CSS (buttons, eyebrows, active nav, SBAR letters, links).
  static const Color primary = Color(0xFF0F766E);
  static const Color primaryDark = Color(0xFF115E59);
  static const Color evergreen = Color(0xFF123B37);
  static const Color primaryAlt = Color(0xFF0D9488);
  static const Color primarySurface = Color(0xFFE6FFFB);

  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textHeading = Color(0xFF142C30);
  static const Color textMuted = Color(0xFF53666F);
  static const Color textFaint = Color(0xFF94A3B8);

  static const Color surface = Color(0xFFF8FAFC);
  static const Color surfaceAlt = Color(0xFFF1F5F9);
  // Fine, muted outlines: visible on white without harsh dark frames.
  static const Color border = Color(0xFFE0E7ED);
  static const Color borderAlt = Color(0xFFBBC8D2);

  // Light layout with accents derived from the authenticated role.
  static ThemeData light({ViewMode role = ViewMode.nurse}) {
    final palette = RoleAppearance.forRole(role);
    return _base(_scheme(palette), palette);
  }

  static ColorScheme _scheme(RoleAppearance palette) {
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: Brightness.light,
    );
    return scheme.copyWith(
      primary: palette.accent,
      primaryContainer: palette.soft,
      onPrimaryContainer: palette.accent,
      secondary: palette.accent,
      surface: Colors.white,
      surfaceContainerHighest: surfaceAlt,
      onSurface: textPrimary,
      outline: borderAlt,
      outlineVariant: border,
      error: ClinicalColors.dangerText,
    );
  }

  static ThemeData _base(ColorScheme scheme, RoleAppearance palette) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      extensions: [palette],
      textTheme: ThemeData.light().textTheme
          .apply(bodyColor: textPrimary, displayColor: textHeading)
          .copyWith(
            bodyLarge: const TextStyle(
              fontSize: 16,
              height: 1.45,
              color: textPrimary,
            ),
            bodyMedium: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: textPrimary,
            ),
            bodySmall: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: textMuted,
            ),
            labelLarge: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            headlineSmall: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: textHeading,
            ),
            titleLarge: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textHeading,
            ),
            titleMedium: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textHeading,
            ),
          )
          .apply(fontFamily: 'Roboto'),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.header,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderAlt),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderAlt),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textMuted),
        floatingLabelStyle: TextStyle(color: scheme.primary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        constraints: BoxConstraints(maxWidth: 720),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        titleTextStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: textHeading,
        ),
        subtitleTextStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          height: 1.5,
          color: textMuted,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: palette.soft,
        height: 76,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : textMuted,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        labelStyle: const TextStyle(
          fontFamily: 'Roboto',
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: const BorderSide(color: border),
      ),
    );
  }
}

/// Brand accents stay separate from clinical status colors.
class RoleAppearance extends ThemeExtension<RoleAppearance> {
  const RoleAppearance({
    required this.accent,
    required this.header,
    required this.soft,
  });
  final Color accent;
  final Color header;
  final Color soft;

  static RoleAppearance forRole(ViewMode role) => switch (role) {
    ViewMode.doctor => const RoleAppearance(
      accent: Color(0xFF1D4ED8),
      header: Color(0xFF17395C),
      soft: Color(0xFFE8F0FF),
    ),
    ViewMode.admin => const RoleAppearance(
      accent: Color(0xFF85621D),
      header: Color(0xFF45371C),
      soft: Color(0xFFFFF3D6),
    ),
    _ => const RoleAppearance(
      accent: AppTheme.primary,
      header: AppTheme.evergreen,
      soft: Color(0xFFE6F5F1),
    ),
  };

  @override
  RoleAppearance copyWith({Color? accent, Color? header, Color? soft}) =>
      RoleAppearance(
        accent: accent ?? this.accent,
        header: header ?? this.header,
        soft: soft ?? this.soft,
      );

  @override
  RoleAppearance lerp(covariant RoleAppearance? other, double t) =>
      other == null
      ? this
      : RoleAppearance(
          accent: Color.lerp(accent, other.accent, t)!,
          header: Color.lerp(header, other.header, t)!,
          soft: Color.lerp(soft, other.soft, t)!,
        );
}

/// A background/foreground pair for a status pill or badge.
class ChipPalette {
  const ChipPalette(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

/// Clinical severity retains its meaning independently of the role theme.
/// The approved mobile design uses a neutral OPEN pill so an active alert
/// cannot look critical solely because of its workflow state.
class ClinicalColors {
  ClinicalColors._();

  static const Color dangerText = Color(0xFFDC2626);

  // Patient status — patient-list.css [data-status="..."]
  static const ChipPalette patientStable = ChipPalette(
    Color(0xFFECFDF5),
    Color(0xFF059669),
  );
  static const ChipPalette patientObservation = ChipPalette(
    Color(0xFFFEF3C7),
    Color(0xFFD97706),
  );
  static const ChipPalette patientUnstable = ChipPalette(
    Color(0xFFFEE2E2),
    Color(0xFFDC2626),
  );
  static const ChipPalette patientCritical = ChipPalette(
    Color(0xFFFECACA),
    Color(0xFF991B1B),
  );
  static const ChipPalette patientDischarged = ChipPalette(
    Color(0xFFF1F5F9),
    Color(0xFF64748B),
  );

  static ChipPalette patientStatus(String status) => switch (status) {
    'Estable' || 'STABLE' => patientStable,
    'En observación' || 'OBSERVATION' => patientObservation,
    'Inestable' || 'UNSTABLE' => patientUnstable,
    'Crítico' || 'CRITICAL' => patientCritical,
    'Alta' || 'DISCHARGED' => patientDischarged,
    _ => patientDischarged,
  };

  // Vital sign risk — patient-monitoring.css .risk-*
  static const ChipPalette riskLow = ChipPalette(
    Color(0xFFDCFCE7),
    Color(0xFF15803D),
  );
  static const ChipPalette riskMedium = ChipPalette(
    Color(0xFFFEF3C7),
    Color(0xFFB45309),
  );
  static const ChipPalette riskHigh = ChipPalette(
    Color(0xFFFFEDD5),
    Color(0xFFC2410C),
  );
  static const ChipPalette riskCritical = ChipPalette(
    Color(0xFFFEE2E2),
    Color(0xFFDC2626),
  );
  static const ChipPalette riskUnassessed = ChipPalette(
    Color(0xFFF1F5F9),
    Color(0xFF475569),
  );

  static ChipPalette risk(String level) => switch (level) {
    'LOW' => riskLow,
    'MEDIUM' => riskMedium,
    'HIGH' => riskHigh,
    'CRITICAL' => riskCritical,
    _ => riskUnassessed,
  };

  // Alert severity — alert-list.css .tag-crit / .tag-mod
  static const ChipPalette severityCritical = ChipPalette(
    Color(0xFFFEE2E2),
    Color(0xFFDC2626),
  );
  static const ChipPalette severityModerate = ChipPalette(
    Color(0xFFFEF3C7),
    Color(0xFFD97706),
  );

  static ChipPalette severity(String value) => switch (value) {
    'CRITICAL' => riskCritical,
    'HIGH' => riskHigh,
    'LOW' => riskLow,
    'MEDIUM' || 'MODERATE' => riskMedium,
    _ => riskUnassessed,
  };

  // Workflow status stays separate from the severity rail and severity pill.
  static const ChipPalette alertOpen = ChipPalette(
    Color(0xFFF1F5F9),
    Color(0xFF475569),
  );
  static const ChipPalette alertAttended = ChipPalette(
    Color(0xFFFEF3C7),
    Color(0xFF92400E),
  );
  static const ChipPalette alertClosed = ChipPalette(
    Color(0xFFDCFCE7),
    Color(0xFF166534),
  );

  static ChipPalette alertStatus(String status) => switch (status) {
    'OPEN' => alertOpen,
    'ATTENDED' => alertAttended,
    'CLOSED' => alertClosed,
    _ => alertOpen,
  };

  // SBAR handover status — sbar-list.css .status-*
  static const ChipPalette sbarPending = ChipPalette(
    Color(0xFFFEF3C7),
    Color(0xFFB45309),
  );
  static const ChipPalette sbarAcknowledged = ChipPalette(
    Color(0xFFDCFCE7),
    Color(0xFF15803D),
  );
  static const ChipPalette sbarCompleted = ChipPalette(
    Color(0xFFDBEAFE),
    Color(0xFF2563EB),
  );
  static const ChipPalette sbarCancelled = ChipPalette(
    Color(0xFFFEE2E2),
    Color(0xFFDC2626),
  );

  static ChipPalette sbarStatus(String status) => switch (status) {
    'PENDING' => sbarPending,
    'ACKNOWLEDGED' => sbarAcknowledged,
    'COMPLETED' => sbarCompleted,
    'CANCELLED' => sbarCancelled,
    _ => sbarPending,
  };
}
