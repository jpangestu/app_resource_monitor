import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:app_resource_monitor/app_resource_monitor.dart';

Future<void> main() async {
  // 1. Create the resource monitor instance
  final monitor = AppResourceMonitor();

  print('=== Current Process & System Resources ===');
  print('Total System RAM : ${monitor.totalSystemRamMb.toStringAsFixed(0)} MB');
  print(
    'Private RAM      : ${monitor.privateMb.toStringAsFixed(1)} MB '
    '(${monitor.memoryUsagePercent.toStringAsFixed(1)}% of system RAM)',
  );
  print('RSS (Working Set): ${monitor.rssMb.toStringAsFixed(1)} MB');
  print('Committed Virtual: ${monitor.committedMb.toStringAsFixed(1)} MB');
  print('CPU Usage        : ${monitor.cpuUsagePercent.toStringAsFixed(1)}%');
  print('GPU Usage        : ${monitor.gpuUsagePercent.toStringAsFixed(1)}%\n');

  // 2. Stream metrics periodically (e.g. for a UI overlay, telemetry, or HUD)
  print('=== Streaming Resource Usage (every 500ms) ===');
  final stream = Stream.periodic(
    const Duration(milliseconds: 500),
    (_) => (
      cpu: monitor.cpuUsagePercent,
      gpu: monitor.gpuUsagePercent,
      ramMb: monitor.privateMb,
      ramPct: monitor.memoryUsagePercent,
    ),
  );

  final subscription = stream.listen((metrics) {
    print(
      'CPU: ${metrics.cpu.toStringAsFixed(1).padLeft(5)}% | '
      'GPU: ${metrics.gpu.toStringAsFixed(1).padLeft(5)}% | '
      'Private RAM: ${metrics.ramMb.toStringAsFixed(1).padLeft(6)} MB '
      '(${metrics.ramPct.toStringAsFixed(1)}%)',
    );
  });

  // 3. Simulate a brief workload (allocating heap memory and running CPU calculations)
  print('\n>>> Simulating active workload for 3 seconds...');
  final allocatedBuffers = <Uint8List>[];
  final workloadTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
    // Allocate 2 MB of heap memory per tick and touch pages so they enter Private Working Set
    final buffer = Uint8List(2 * 1024 * 1024);
    for (int i = 0; i < buffer.length; i += 4096) {
      buffer[i] = i & 0xFF;
    }
    allocatedBuffers.add(buffer);

    // Burn ~25ms of CPU time
    final sw = Stopwatch()..start();
    double sink = 0;
    while (sw.elapsedMilliseconds < 25) {
      sink += math.sqrt(sw.elapsedMicroseconds.toDouble());
    }
    if (sink < 0) print(sink);
  });

  await Future<void>.delayed(const Duration(seconds: 3));

  // 4. Stop workload, clear memory buffers, and reset baseline
  workloadTimer.cancel();
  allocatedBuffers.clear();
  monitor.resetBaseline();
  print('>>> Workload stopped & baseline reset.\n');

  await Future<void>.delayed(const Duration(seconds: 2));

  // 5. Clean up stream subscription and free native FFI handles
  await subscription.cancel();
  monitor.dispose();
  print('Monitor disposed.');
}
