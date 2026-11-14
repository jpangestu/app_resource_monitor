import 'app_resource_monitor.dart';

/// An immutable snapshot of app resource usage.
final class ResourceSnapshot {
  /// The timestamp when this snapshot was captured.
  final DateTime timestamp;

  /// CPU utilization percentage (0.0 to 100.0).
  final double cpuUsagePercent;

  /// GPU metrics (utilization, dedicated VRAM, and shared memory), or `null` if unsupported.
  final GpuSnapshot? gpu;

  /// RAM metrics (private, rss, committed).
  final MemorySnapshot memory;

  const ResourceSnapshot({
    required this.timestamp,
    required this.cpuUsagePercent,
    this.gpu,
    required this.memory,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResourceSnapshot &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          cpuUsagePercent == other.cpuUsagePercent &&
          gpu == other.gpu &&
          memory == other.memory;

  @override
  int get hashCode => Object.hash(
        timestamp,
        cpuUsagePercent,
        gpu,
        memory,
      );

  @override
  String toString() =>
      'ResourceSnapshot(cpu: ${cpuUsagePercent.toStringAsFixed(1)}%, '
      'gpu: ${gpu != null ? "${gpu!.usagePercent.toStringAsFixed(1)}%" : "N/A"}, '
      'vram: ${gpu != null ? gpu!.vram.format() : "N/A"}, '
      'memory: ${memory.private.format()})';
}

/// An immutable snapshot of GPU compute and video memory metrics for this process.
final class GpuSnapshot {
  /// GPU compute engine utilization percentage (0.0 to 100.0).
  final double usagePercent;

  /// Dedicated video memory (VRAM) used by your app.
  final MemorySize vram;

  /// Shared system RAM allocated for GPU resources used by your app
  /// (e.g. on integrated GPUs or VRAM overflow).
  final MemorySize shared;

  const GpuSnapshot({
    required this.usagePercent,
    required this.vram,
    required this.shared,
  });

  /// Total GPU memory usage (vram + shared).
  MemorySize get total => MemorySize(vram.bytes + shared.bytes);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GpuSnapshot &&
          runtimeType == other.runtimeType &&
          usagePercent == other.usagePercent &&
          vram == other.vram &&
          shared == other.shared;

  @override
  int get hashCode => Object.hash(usagePercent, vram, shared);

  @override
  String toString() =>
      'GpuSnapshot(usagePercent: ${usagePercent.toStringAsFixed(1)}%, '
      'dedicated: ${vram.format()}, shared: ${shared.format()})';
}

/// An immutable snapshot of RAM metrics.
final class MemorySnapshot {
  /// Active private physical RAM used exclusively by your app (Windows Task Manager "Memory").
  final MemorySize private;

  /// Total physical RAM used by your app and the shared libraries that your app uses.
  final MemorySize rss;

  /// Virtual memory committed by the OS memory manager for this process.
  final MemorySize committed;

  /// Total physical RAM installed on the machine.
  final MemorySize totalSystem;

  const MemorySnapshot({
    required this.private,
    required this.rss,
    required this.committed,
    required this.totalSystem,
  });

  /// Percentage of total system RAM used by your app's active private memory (0.0 to 100.0).
  double get usagePercent {
    if (totalSystem.bytes <= 0) return 0.0;
    return ((private.bytes / totalSystem.bytes) * 100.0).clamp(0.0, 100.0);
  }

  /// Percentage of total system RAM represented by your app's committed memory (0.0 to 100.0).
  double get committedUsagePercent {
    if (totalSystem.bytes <= 0) return 0.0;
    return ((committed.bytes / totalSystem.bytes) * 100.0).clamp(0.0, 100.0);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemorySnapshot &&
          runtimeType == other.runtimeType &&
          private == other.private &&
          rss == other.rss &&
          committed == other.committed &&
          totalSystem == other.totalSystem;

  @override
  int get hashCode => Object.hash(private, rss, committed, totalSystem);

  @override
  String toString() => 'MemorySnapshot(private: ${private.format()}, '
      'rss: ${rss.format()}, '
      'committed: ${committed.format()}, '
      'system: ${totalSystem.format()})';
}
