import 'app_resource_monitor_platform_interface.dart';

/// Cross-platform interface for monitoring current process CPU, GPU, and memory usage.
abstract interface class AppResourceMonitor {
  /// The shared platform instance for app-wide monitoring.
  static AppResourceMonitorPlatform get instance =>
      AppResourceMonitorPlatform.instance;

  /// Creates a new platform-specific resource monitor instance for the current operating system.
  factory AppResourceMonitor() => AppResourceMonitorPlatform.createNew();

  /// The percentage of total system CPU capacity consumed by this process
  /// across all logical cores over the latest sampling window (0.0 to 100.0).
  ///
  /// Matches Windows Task Manager's default CPU column.
  double get cpuUsagePercent;

  /// The percentage of total GPU capacity actively utilized by this process (0.0 to 100.0).
  ///
  /// Aggregates execution time across all GPU hardware engines (such as 3D,
  /// Compute, Copy/DMA, and Video Decode) associated with this process via
  /// Windows Performance Data Helper (PDH). Matches Windows Task Manager's "GPU" column.
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

/// Convenience [MemorySize] wrappers and percentage calculations on [AppResourceMonitor].
extension AppResourceMonitorConversions on AppResourceMonitor {
  /// Active private physical RAM owned exclusively by this process (Task Manager "Memory").
  MemorySize get privateRam => MemorySize(privateBytes);

  /// Alias for [privateRam].
  MemorySize get private => MemorySize(privateBytes);

  /// Resident Set Size / Working Set (physical RAM including shared libraries).
  MemorySize get rss => MemorySize(rssBytes);

  /// Committed virtual memory (Private commit charge).
  MemorySize get committed => MemorySize(committedBytes);

  /// Total physical RAM installed on the machine.
  MemorySize get totalSystemRam => MemorySize(totalSystemRamBytes);

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

/// Represents a memory size in bytes with zero runtime heap overhead.
///
/// In Dart 3, this [extension type] compiles directly to a primitive 64-bit [int]
/// while providing ergonomic unit getters ([kb], [mb], [gb]) and [format].
extension type const MemorySize(int bytes) {
  /// Memory size in kilobytes (KiB: bytes / 1,024).
  double get kb => bytes / 1024.0;

  /// Memory size in megabytes (MiB: bytes / 1,048,576).
  double get mb => bytes / (1024.0 * 1024.0);

  /// Memory size in gigabytes (GiB: bytes / 1,073,741,824).
  double get gb => bytes / (1024.0 * 1024.0 * 1024.0);

  /// Formats the memory size into an auto-scaled human-readable string
  /// using binary 1,024-based units (e.g. `512 B`, `25.0 KB`, `214.2 MB`, `16.0 GB`).
  String format({int decimals = 1}) {
    if (bytes <= 0) return '0 B';
    const base = 1024.0;
    if (bytes < base) return '$bytes B';

    const suffixes = ['KB', 'MB', 'GB', 'TB', 'PB'];
    var value = bytes.toDouble();
    var suffixIndex = -1;

    while (value >= base && suffixIndex < suffixes.length - 1) {
      value /= base;
      suffixIndex++;
    }

    return '${value.toStringAsFixed(decimals)} ${suffixes[suffixIndex]}';
  }
}
