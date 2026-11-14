# app_resource_monitor

A lightweight Dart package to monitor your app's own **CPU**, **GPU**, and **RAM** usage; windows only for now.

Calls Windows `kernel32.dll` and `pdh.dll` via `dart:ffi`.

---

## Features

* **CPU:** CPU utilization percentages.
* **GPU:**
  * **Usage:** GPU utilization percentages.
  * **VRAM:** Dedicated VRAM usage.
  * **Shared:** Shared system memory (RAM) used by the GPU.
* **RAM:**
  * **Private:** Physical memory used exclusively by your app.
  * **RSS:** Physical memory used by your app and shared system DLLs that your app uses.
  * **Committed:** Virtual memory allocated by the OS for your app.
* **`ResourceSnapshot` & `stream()`:** Point-in-time snapshots and reactive streaming.

---

## Usage

* **`AppResourceMonitor.instance`**: Shared singleton for app-wide use (overlays, status bars, loggers).
* **`AppResourceMonitor()`**: Dedicated instance for isolated use cases:
  * **Background Isolates:** Dart isolates do not share memory, so each isolate needs its own instance.
  * **Independent polling:** Prevents two features polling at different rates from skewing each other's CPU/GPU baselines.
  * **Benchmarking:** Measure resource spikes for a specific task or function.

### 1. Snapshot (`snapshot()`)

Captures a snapshot of all current metrics:

```dart
import 'package:app_resource_monitor/app_resource_monitor.dart';

void main() {
  final snapshot = AppResourceMonitor.snapshot();

  print('CPU  : ${snapshot.cpuUsagePercent.toStringAsFixed(1)}%');
  print('GPU  : ${snapshot.gpu != null ? "${snapshot.gpu!.usagePercent.toStringAsFixed(1)}%" : "N/A"}');
  print('VRAM : ${snapshot.gpu.vram?.format() ?? "N/A"}');
  print('RAM  : ${snapshot.memory.private.format()} (${snapshot.memory.usagePercent.toStringAsFixed(1)}%)');
  print('RSS  : ${snapshot.memory.rss.format()}');
}
```

### 2. Reactive Streaming (`stream()`)

Stream updates directly to UI widgets or telemetry listeners (ideal for Flutter `StreamBuilder`):

```dart
import 'package:app_resource_monitor/app_resource_monitor.dart';

void main() async {
  // Listen to periodic resource updates:
  final subscription = AppResourceMonitor.stream(
    interval: const Duration(seconds: 1),
  ).listen((snapshot) {
    print(
      'CPU: ${snapshot.cpuUsagePercent.toStringAsFixed(1)}% | '
      'VRAM: ${snapshot.gpu.vram?.format() ?? "N/A"} | '
      'RAM: ${snapshot.memory.private.format()}',
    );
  });

  // Cancel when done:
  // await subscription.cancel();
}
```

### 3. Direct Single-Metric Access

If you only need a single metric without allocating a snapshot:

```dart
final monitor = AppResourceMonitor.instance;

// Format into auto-scaled human-readable text:
print('Private RAM  : ${monitor.privateRam.format()}');
print('VRAM         : ${monitor.gpu.vram.format()}');
print('System RAM   : ${monitor.totalSystemRam.format()}');

// Or get direct numerical values:
print('RAM in MB    : ${monitor.privateRam.mb.toStringAsFixed(1)} MB');
print('VRAM in MB   : ${monitor.gpu.vram.mb.toStringAsFixed(1)} MB');
print('System in GB : ${monitor.totalSystemRam.gb.toStringAsFixed(1)} GB');
print('Raw Bytes    : ${monitor.privateRam.bytes} B');
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
    expect(AppResourceMonitor.snapshot().cpu, equals(25.0));
  });
}
```
