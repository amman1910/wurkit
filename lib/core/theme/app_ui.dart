import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color navyBg = Color(0xFF0B1426);
  static const Color coralAccent = Color(0xFFE68A77);
  static const Color surface = Color(0xFF1A2847);
  static const Color lightText = Colors.white70;
  static const Color white = Colors.white;
  static const Color border = Color(0x40FFFFFF);
  static const Color darkText = Color(0xFF1F2937);
}

class AppRadius {
  static const BorderRadius button = BorderRadius.all(Radius.circular(30));
  static const BorderRadius input = BorderRadius.all(Radius.circular(12));
}

class AppSpacing {
  static const double horizontal = 30.0;
  static const double vertical = 20.0;
  static const double section = 16.0;
  static const double field = 20.0;
  static const double buttonHeight = 55.0;
  static const double small = 10.0;
}

class AppTextStyles {
  static TextStyle heading({
    Color color = AppColors.coralAccent,
    double fontSize = 48,
  }) {
    return GoogleFonts.nunito(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
    );
  }

  static const TextStyle body = TextStyle(
    color: AppColors.lightText,
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle label = TextStyle(
    color: AppColors.lightText,
    fontSize: 14,
  );

  static const TextStyle hint = TextStyle(color: Color(0x80FFFFFF));

  static const TextStyle input = TextStyle(color: Colors.white, fontSize: 16);

  static TextStyle buttonLabel({
    Color color = AppColors.navyBg,
    double fontSize = 16,
  }) {
    return GoogleFonts.nunito(
      color: color,
      fontWeight: FontWeight.bold,
      fontSize: fontSize,
    );
  }

  static const TextStyle textButton = TextStyle(
    color: AppColors.lightText,
    fontSize: 14,
  );
}

class AppInputDecorations {
  static InputDecoration authField({
    required String label,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      labelText: label,
      labelStyle: AppTextStyles.label,
      hintStyle: AppTextStyles.hint,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: const BorderSide(color: AppColors.coralAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 14.0,
      ),
      suffixIcon: suffixIcon,
    );
  }
}

class AppButtonStyles {
  static ButtonStyle primary({
    Color backgroundColor = AppColors.coralAccent,
    Color? foregroundColor,
    Color disabledBackgroundColor = Colors.grey,
    Color? disabledForegroundColor,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      disabledBackgroundColor: disabledBackgroundColor,
      disabledForegroundColor: disabledForegroundColor,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
    );
  }

  static ButtonStyle secondaryOutline({
    Color borderColor = AppColors.coralAccent,
  }) {
    return OutlinedButton.styleFrom(
      backgroundColor: Colors.transparent,
      side: BorderSide(color: borderColor, width: 2),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
    );
  }

  static ButtonStyle whiteFilled({
    Color backgroundColor = Colors.white,
    Color disabledBackgroundColor = Colors.grey,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      disabledBackgroundColor: disabledBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
    );
  }

  static ButtonStyle text({Color foregroundColor = AppColors.lightText}) {
    return TextButton.styleFrom(
      foregroundColor: foregroundColor,
      padding: EdgeInsets.zero,
    );
  }
}
