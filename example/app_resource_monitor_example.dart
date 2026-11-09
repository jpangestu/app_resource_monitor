import 'dart:async';

import 'package:app_resource_monitor/app_resource_monitor.dart';

void main() async {
  // 1. AppResourceMonitor.instance (Shared Singleton)
  // Use this for 90% of use cases (app-wide performance overlays, single loggers).
  final instance = AppResourceMonitor.instance;

  print('=== 1. App Resource Snapshot (AppResourceMonitor.instance) ===');
  print('Total System RAM : ${instance.totalSystemRam.format()}');
  print(
    'Private RAM      : ${instance.private.format()} '
    '(${instance.memoryUsagePercent.toStringAsFixed(1)}% of system RAM)',
  );
  print('Working Set (RSS): ${instance.rss.format()}');
  print('Committed Memory : ${instance.committed.format()}');
  print('CPU Usage        : ${instance.cpuUsagePercent.toStringAsFixed(1)}%');
  print('GPU Usage        : ${instance.gpuUsagePercent.toStringAsFixed(1)}%\n');

  // 2. AppResourceMonitor() (Dedicated Instance)
  // Use this when you need:
  // - An independent sampling window (avoids baseline collisions between multiple pollers)
  // - Isolated benchmarking for a specific function or task
  // - Code running in a background Dart Isolate
  // - Explicit lifecycle control with dispose()
  print('=== 2. Dedicated Monitor Streaming (AppResourceMonitor()) ===');
  final monitor = AppResourceMonitor();

  var sampleCount = 0;
  Timer.periodic(const Duration(milliseconds: 500), (timer) {
    sampleCount++;
    print(
      '#$sampleCount | '
      'CPU: ${monitor.cpuUsagePercent.toStringAsFixed(1).padLeft(5)}% | '
      'GPU: ${monitor.gpuUsagePercent.toStringAsFixed(1).padLeft(5)}% | '
      'RAM: ${monitor.private.format().padLeft(8)} '
      '(${monitor.memoryUsagePercent.toStringAsFixed(1)}%)',
    );

    // Stop after 6 samples (3 seconds) for this example
    if (sampleCount >= 6) {
      timer.cancel();
      // (Optional) Release resources immediately
      // If not set explicitly, Dart Garbage Collector will dispose it for you later on
      monitor.dispose();
      print('\nDedicated monitor disposed.');
    }
  });
}
