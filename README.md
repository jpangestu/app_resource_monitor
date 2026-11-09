# app_resource_monitor

A lightweight Dart package to monitor your app's own **CPU**, **GPU**, and **RAM** usage.

Calls Windows `kernel32.dll` and `pdh.dll` via `dart:ffi`.

---

## Features

* **CPU & GPU Usage:** Real-time percentages (0.0% – 100.0%).
* **Memory Profiling:**
  * **Private RAM:** Active memory owned exclusively by your app (matches Task Manager).
  * **Working Set (RSS):** Total physical memory including shared system DLLs.
  * **Committed Memory:** Virtual memory allocated by the OS for your app.

---

## Usage

* **`AppResourceMonitor.instance`**: Shared singleton for app-wide use (overlays, status bars, loggers).
* **`AppResourceMonitor()`**: Dedicated instance for isolated use cases:
  * **Background Isolates:** Dart isolates do not share memory, so each isolate needs its own instance.
  * **Independent polling:** Prevents two features polling at different rates from skewing each other's CPU/GPU baselines.
  * **Benchmarking:** Measure resource spikes for a specific task or function.

### One-Shot Snapshot

```dart
import 'package:app_resource_monitor/app_resource_monitor.dart';

void main() {
  final monitor = AppResourceMonitor.instance;

  print('CPU Usage   : ${monitor.cpuUsagePercent.toStringAsFixed(1)}%');
  print('GPU Usage   : ${monitor.gpuUsagePercent.toStringAsFixed(1)}%');

  // Format into auto-scaled human-readable text:
  print('Private RAM : ${monitor.privateRam.format()} (${monitor.memoryUsagePercent.toStringAsFixed(1)}%)');
  print('Working Set : ${monitor.rss.format()}');
  print('System RAM  : ${monitor.totalSystemRam.format()}');

  // Or get direct values in MB, GB, or raw bytes:
  print('RAM in MB   : ${monitor.privateRam.mb.toStringAsFixed(1)} MB');
  print('System in GB: ${monitor.totalSystemRam.gb.toStringAsFixed(1)} GB');
  print('Raw Bytes   : ${monitor.privateRam.bytes} B');
}
```

### Periodic Streaming

```dart
import 'dart:async';
import 'package:app_resource_monitor/app_resource_monitor.dart';

void main() {
  final monitor = AppResourceMonitor();

  var sampleCount = 0;
  Timer.periodic(const Duration(milliseconds: 500), (timer) {
    sampleCount++;
    print(
      'CPU: ${monitor.cpuUsagePercent.toStringAsFixed(1)}% | '
      'RAM: ${monitor.privateRam.format()} (${monitor.memoryUsagePercent.toStringAsFixed(1)}%)',
    );

    if (sampleCount >= 6) {
      timer.cancel();
      // (Optional) Release resources immediately
      // If not set explicitly, Dart Garbage Collector will dispose it for you later on
      monitor.dispose();
    }
  });
}
```

---

## Unit Testing & Mocking

Mock the platform in unit tests without invoking native FFI:

```dart
import 'package:app_resource_monitor/app_resource_monitor.dart';
import 'package:test/test.dart';

class MockPlatform extends AppResourceMonitorPlatform {
  @override
  double get cpuUsagePercent => 25.0;
  // implement other getters as needed...
}

void main() {
  test('test resource monitoring', () {
    AppResourceMonitorPlatform.instance = MockPlatform();
    expect(AppResourceMonitor.instance.cpuUsagePercent, equals(25.0));
  });
}
```
