/// Centralized repository for all image and icon asset paths across the application.
/// Provides a clean, type-safe single source of truth for easy expansion in the future.
class AppImages {
  AppImages._();

  // Base Path
  static const String _basePath = 'assets/images';

  // Icons
  static const String saudiRiyal = '$_basePath/saudi_riyal.png';

  // Logos & Branding
  static const String restaurantLogo = '$_basePath/rest.jpg';
}

/// Convenience class specifically for icon assets if referenced as icons.
class AppIcons {
  AppIcons._();

  static const String saudiRiyal = AppImages.saudiRiyal;
}
