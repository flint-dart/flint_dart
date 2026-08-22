enum ToastPlacement { topRight, topCenter, bottomRight, bottomCenter }

/// Server-safe ToastService stub for SSR / VM environments.
class ToastService {
  const ToastService();

  void info(
    String title, {
    String? message,
    Duration duration = const Duration(seconds: 3),
    ToastPlacement placement = ToastPlacement.topRight,
  }) {}

  void success(
    String title, {
    String? message,
    Duration duration = const Duration(seconds: 3),
    ToastPlacement placement = ToastPlacement.topRight,
  }) {}

  void warning(
    String title, {
    String? message,
    Duration duration = const Duration(seconds: 4),
    ToastPlacement placement = ToastPlacement.topRight,
  }) {}

  void error(
    String title, {
    String? message,
    Duration duration = const Duration(seconds: 5),
    ToastPlacement placement = ToastPlacement.topRight,
  }) {}
}

const toast = ToastService();
