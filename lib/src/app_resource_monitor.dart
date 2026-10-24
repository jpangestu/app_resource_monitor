import 'dart:io' show Platform;

import 'windows/win_resource_monitor.dart';

/// Cross-platform interface for monitoring current process CPU, GPU, and memory usage.
abstract interface class AppResourceMonitor {
  /// Creates the platform-specific resource monitor for the current operating system.
  factory AppResourceMonitor() {
    if (Platform.isWindows) return WinResourceMonitor();
    throw UnsupportedError(
      'AppResourceMonitor is only supported on Windows.',
    );
  }

  double get cpuUsagePercent;

  double get gpuUsagePercent;

  /// Resident Set Size / Working Set in bytes (includes shared OS libraries).
  int get rssBytes;

  /// Active private physical RAM in bytes owned exclusively by this process.
  /// Matches Windows Task Manager's default "Memory" column.
  int get privateBytes;

  /// Committed virtual memory in bytes (Private commit charge).
  int get committedBytes;

  /// Total physical RAM installed on the machine in bytes.
  int get totalSystemRamBytes;

  /// Resets the differential baseline for CPU and GPU usage calculation.
  void resetBaseline();

  /// Releases native FFI memory and OS handles immediately.
  void dispose();
}

/// Convenience conversions and calculations on [AppResourceMonitor].
extension AppResourceMonitorConversions on AppResourceMonitor {
  /// Resident Set Size / Working Set in megabytes.
  double get rssMb => rssBytes / (1024 * 1024);

  /// Active private physical RAM in megabytes.
  double get privateMb => privateBytes / (1024 * 1024);

  /// Committed virtual memory in megabytes.
  double get committedMb => committedBytes / (1024 * 1024);

  /// Total physical RAM installed on the machine in megabytes.
  double get totalSystemRamMb => totalSystemRamBytes / (1024 * 1024);

  /// Percentage of total system RAM used by this process's active private memory (0.0 to 100.0).
  double get memoryUsagePercent {
    if (totalSystemRamBytes <= 0) return 0.0;
    return ((privateBytes / totalSystemRamBytes) * 100.0).clamp(0.0, 100.0);
  }

  /// Percentage of total system RAM represented by this process's committed memory (0.0 to 100.0).
  double get committedMemoryUsagePercent {
    if (totalSystemRamBytes <= 0) return 0.0;
    return ((committedBytes / totalSystemRamBytes) * 100.0).clamp(0.0, 100.0);
  }
}
