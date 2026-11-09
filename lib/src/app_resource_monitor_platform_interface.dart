import 'dart:io' show Platform;

import 'app_resource_monitor.dart';
import 'windows/win_resource_monitor.dart';

/// The platform interface that all operating system monitors must implement.
///
/// Follows the standard platform interface pattern to decouple the public API
/// from native platform implementations and to enable mocking in tests.
abstract class AppResourceMonitorPlatform implements AppResourceMonitor {
  static AppResourceMonitorPlatform? _instance;

  /// The active platform instance.
  ///
  /// Defaults to the native monitor for the current operating system.
  /// Can be replaced with a mock or test double in unit tests:
  /// ```dart
  /// AppResourceMonitorPlatform.instance = MockResourceMonitorPlatform();
  /// ```
  static AppResourceMonitorPlatform get instance => _instance ??= createNew();

  /// Sets the active platform instance (useful for unit testing).
  static set instance(AppResourceMonitorPlatform value) {
    _instance = value;
  }

  /// Creates a new platform-specific monitor instance for the current operating system.
  static AppResourceMonitorPlatform createNew() {
    if (Platform.isWindows) return WinResourceMonitor();
    throw UnsupportedError(
      'AppResourceMonitor is not supported on ${Platform.operatingSystem}.',
    );
  }
}
