import 'package:app_resource_monitor/app_resource_monitor.dart';

void main() async {
  // 1. Point-in-Time Snapshot (AppResourceMonitor.snapshot())
  // Captures an immutable snapshot of all metrics (CPU, GPU, RAM) at this moment.
  // Backed by the shared process-wide singleton instance.
  print('=== 1. Point-in-Time Snapshot (AppResourceMonitor.snapshot()) ===');
  final snapshot = AppResourceMonitor.snapshot();
  print('Total System RAM : ${snapshot.memory.totalSystem.format()}');
  print(
    'Private RAM      : ${snapshot.memory.private.format()} '
    '(${snapshot.memory.usagePercent.toStringAsFixed(1)}% of system RAM)',
  );
  print('Working Set (RSS): ${snapshot.memory.rss.format()}');
  print('Committed Memory : ${snapshot.memory.committed.format()}');
  print('CPU Usage        : ${snapshot.cpuUsagePercent.toStringAsFixed(1)}%');
  print(
    'GPU Usage        : '
    '${snapshot.gpu != null ? "${snapshot.gpu!.usagePercent.toStringAsFixed(1)}%" : "N/A"}',
  );
  print(
    'GPU VRAM         : '
    '${snapshot.gpu != null ? snapshot.gpu!.vram.format() : "N/A"} '
    '(Shared: ${snapshot.gpu?.shared.format() ?? "N/A"})\n',
  );

  // 2. Direct Single-Metric Access (AppResourceMonitor.instance)
  // If you only need a specific metric directly without allocating a snapshot:
  print('=== 2. Direct Singleton Access (AppResourceMonitor.instance) ===');
  final instance = AppResourceMonitor.instance;
  print('Private RAM      : ${instance.private.format()}');
  print('Dedicated VRAM   : ${instance.gpuVram.format()}\n');

  // 3. Reactive Streaming (AppResourceMonitor.stream())
  // Stream continuous snapshots directly to UI widgets (e.g. Flutter StreamBuilder)
  // or telemetry listeners.
  print('=== 3. Reactive Streaming (AppResourceMonitor.stream()) ===');
  var streamCount = 0;
  await for (final snapshot in AppResourceMonitor.stream(
    interval: const Duration(milliseconds: 500),
  ).take(4)) {
    streamCount++;
    final gpuStr = snapshot.gpu != null
        ? '${snapshot.gpu!.usagePercent.toStringAsFixed(1)}%'
        : 'N/A';
    final vramStr = snapshot.gpu?.vram.format() ?? 'N/A';
    print(
      '#$streamCount | '
      'CPU: ${snapshot.cpuUsagePercent.toStringAsFixed(1).padLeft(5)}% | '
      'GPU: ${gpuStr.padLeft(5)} | '
      'VRAM: ${vramStr.padLeft(8)} | '
      'RAM: ${snapshot.memory.private.format().padLeft(8)} '
      '(${snapshot.memory.usagePercent.toStringAsFixed(1)}%)',
    );
  }
  print('');

  // 4. Dedicated Instance (AppResourceMonitor())
  // Use a dedicated instance when you need:
  // - Isolated benchmarking for a specific task (independent baseline)
  // - Code running in a background Dart Isolate
  // - Independent polling rates (avoids baseline collisions)
  // - Explicit lifecycle control with dispose()
  print('=== 4. Dedicated Instance & Benchmarking (AppResourceMonitor()) ===');
  final monitor = AppResourceMonitor();

  // Reset baseline right before starting the task
  monitor.resetBaseline();

  // Simulate a quick task
  final list = List<int>.generate(1000000, (i) => i * 2);
  final sum = list.fold<int>(0, (prev, elem) => prev + (elem % 10));

  final benchmark = monitor.snapshot();
  print('Workload finished: sum modulo = $sum');
  print('Dedicated CPU    : ${benchmark.cpuUsagePercent.toStringAsFixed(1)}%');
  print('Dedicated RAM    : ${benchmark.memory.private.format()}');

  // Explicitly release native resources immediately
  monitor.dispose();
  print('Dedicated monitor disposed cleanly.');
}
