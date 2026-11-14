import 'dart:async';

import 'app_resource_monitor_platform_interface.dart';
import 'resource_snapshot.dart';

/// Cross-platform interface for monitoring current process CPU, GPU, and memory usage.
abstract interface class AppResourceMonitor {
  /// The shared platform instance for app-wide monitoring.
  static AppResourceMonitorPlatform get instance =>
      AppResourceMonitorPlatform.instance;

  /// Captures a snapshot of all current resource metrics from the shared [instance].
  static ResourceSnapshot snapshot() => instance.snapshot();

  /// Returns a stream of [ResourceSnapshot]s emitted at the given [interval]
  /// from the shared [instance].
  ///
  /// If [emitImmediately] is `true` (default), an initial snapshot is emitted
  /// immediately upon subscription before starting periodic emissions.
  static Stream<ResourceSnapshot> stream({
    Duration interval = const Duration(seconds: 1),
    bool emitImmediately = true,
  }) =>
      instance.stream(
        interval: interval,
        emitImmediately: emitImmediately,
      );

  /// Creates a new platform-specific resource monitor instance for the current operating system.
  factory AppResourceMonitor() => AppResourceMonitorPlatform.createNew();

  /// The percentage of total system CPU capacity consumed by this process
  /// across all logical cores over the latest sampling window (0.0 to 100.0).
  ///
  /// Matches Windows Task Manager's default CPU column.
  double get cpuUsagePercent;

  /// The percentage of total GPU capacity actively utilized by this process (0.0 to 100.0).
  ///
  /// Aggregates execution time across all GPU hardware engines (such as 3D, Compute, Copy/DMA,
  /// and Video Decode) associated with this process via Windows Performance Data Helper (PDH).
  double get gpuUsagePercent;

  /// Dedicated video memory (VRAM) used by this process.
  int get gpuVramBytes;

  /// Shared system RAM allocated for GPU resources used by this process in bytes.
  int get gpuSharedBytes;

  /// Private working set.
  /// Active private physical RAM used exclusively by this process in bytes.
  int get privateBytes;

  /// Resident Set Size/Working Set.
  /// Total physical RAM used by this process and the shared libraries that this process used in bytes.
  int get rssBytes;

  /// Virtual memory committed by the OS memory manager for this process in bytes.
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
  /// Dedicated video memory (VRAM) used by your app.
  MemorySize get gpuVram => MemorySize(gpuVramBytes);

  /// Shared system RAM allocated for GPU resources used by your app
  /// (e.g. on integrated GPUs or VRAM overflow).
  MemorySize get gpuShared => MemorySize(gpuSharedBytes);

  /// Active private physical RAM used exclusively by your app (Windows Task Manager "Memory").
  MemorySize get private => MemorySize(privateBytes);

  /// Total physical RAM used by your app and the shared libraries that your app uses.
  MemorySize get rss => MemorySize(rssBytes);

  /// Virtual memory committed by the OS memory manager for this process.
  MemorySize get committed => MemorySize(committedBytes);

  /// Total physical RAM installed on the machine.
  MemorySize get totalSystemRam => MemorySize(totalSystemRamBytes);

  /// Percentage of total system RAM used by your app's active private memory (0.0 to 100.0).
  double get memoryUsagePercent {
    if (totalSystemRamBytes <= 0) return 0.0;
    return ((privateBytes / totalSystemRamBytes) * 100.0).clamp(0.0, 100.0);
  }

  /// Percentage of total system RAM represented by your app's committed memory (0.0 to 100.0).
  double get committedMemoryUsagePercent {
    if (totalSystemRamBytes <= 0) return 0.0;
    return ((committedBytes / totalSystemRamBytes) * 100.0).clamp(0.0, 100.0);
  }

  /// Captures a snapshot of all current resource metrics.
  ResourceSnapshot snapshot() => ResourceSnapshot(
        timestamp: DateTime.now(),
        cpuUsagePercent: cpuUsagePercent,
        gpu: GpuSnapshot(
          usagePercent: gpuUsagePercent,
          vram: gpuVram,
          shared: gpuShared,
        ),
        memory: MemorySnapshot(
          private: private,
          rss: rss,
          committed: committed,
          totalSystem: totalSystemRam,
        ),
      );

  /// Returns a stream of [ResourceSnapshot]s emitted at the given [interval].
  ///
  /// If [emitImmediately] is `true` (default), the stream emits an initial snapshot
  /// immediately upon subscription before starting periodic emissions.
  Stream<ResourceSnapshot> stream({
    Duration interval = const Duration(seconds: 1),
    bool emitImmediately = true,
  }) async* {
    if (emitImmediately) {
      yield snapshot();
    }
    yield* Stream.periodic(interval, (_) => snapshot());
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
