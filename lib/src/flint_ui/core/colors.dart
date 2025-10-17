// lib/flint_ui/core/colors.dart

class FlintColors {
  // Primary colors
  static const String primary = '#007cba';
  static const String primaryDark = '#005a87';
  static const String primaryLight = '#4fa8d1';

  // Secondary colors
  static const String secondary = '#6c757d';
  static const String secondaryDark = '#545b62';
  static const String secondaryLight = '#8a939b';

  // Success colors
  static const String success = '#28a745';
  static const String successDark = '#1e7e34';
  static const String successLight = '#4caf50';

  // Danger colors
  static const String danger = '#dc3545';
  static const String dangerDark = '#bd2130';
  static const String dangerLight = '#e57373';

  // Warning colors
  static const String warning = '#ffc107';
  static const String warningDark = '#e0a800';
  static const String warningLight = '#ffd54f';

  // Info colors
  static const String info = '#17a2b8';
  static const String infoDark = '#138496';
  static const String infoLight = '#4fc3f7';

  // Neutral colors
  static const String black = '#000000';
  static const String white = '#ffffff';
  static const String transparent = 'transparent';

  // Gray scale
  static const String gray50 = '#fafafa';
  static const String gray100 = '#f5f5f5';
  static const String gray200 = '#eeeeee';
  static const String gray300 = '#e0e0e0';
  static const String gray400 = '#bdbdbd';
  static const String gray500 = '#9e9e9e';
  static const String gray600 = '#757575';
  static const String gray700 = '#616161';
  static const String gray800 = '#424242';
  static const String gray900 = '#212121';

  // Social media colors
  static const String facebook = '#1877f2';
  static const String twitter = '#1da1f2';
  static const String linkedin = '#0077b5';
  static const String instagram = '#e4405f';
  static const String youtube = '#ff0000';
  static const String github = '#333333';

  // Material Design colors
  static const String red = '#f44336';
  static const String pink = '#e91e63';
  static const String purple = '#9c27b0';
  static const String deepPurple = '#673ab7';
  static const String indigo = '#3f51b5';
  static const String blue = '#2196f3';
  static const String lightBlue = '#03a9f4';
  static const String cyan = '#00bcd4';
  static const String teal = '#009688';
  static const String green = '#4caf50';
  static const String lightGreen = '#8bc34a';
  static const String lime = '#cddc39';
  static const String yellow = '#ffeb3b';
  static const String amber = '#ffc107';
  static const String orange = '#ff9800';
  static const String deepOrange = '#ff5722';
  static const String brown = '#795548';
  static const String blueGrey = '#607d8b';

  // Utility methods
  static String withOpacity(String color, double opacity) {
    if (color.startsWith('#')) {
      final hex = color.substring(1);
      final r = int.parse(hex.substring(0, 2), radix: 16);
      final g = int.parse(hex.substring(2, 4), radix: 16);
      final b = int.parse(hex.substring(4, 6), radix: 16);
      return 'rgba($r, $g, $b, $opacity)';
    }
    return color;
  }

  static String darken(String color, [double amount = 0.1]) {
    // Simple darkening - in practice you'd want more sophisticated color manipulation
    return color; // Placeholder
  }

  static String lighten(String color, [double amount = 0.1]) {
    // Simple lightening
    return color; // Placeholder
  }

  // Color palettes for different themes
  static const Map<String, String> lightTheme = {
    'primary': primary,
    'secondary': secondary,
    'background': white,
    'surface': gray50,
    'error': danger,
    'onPrimary': white,
    'onSecondary': white,
    'onBackground': black,
    'onSurface': black,
    'onError': white,
  };

  static const Map<String, String> darkTheme = {
    'primary': primaryLight,
    'secondary': secondaryLight,
    'background': gray900,
    'surface': gray800,
    'error': dangerLight,
    'onPrimary': black,
    'onSecondary': black,
    'onBackground': white,
    'onSurface': white,
    'onError': black,
  };
}
