import 'package:app_resource_monitor/app_resource_monitor.dart';
import 'package:test/test.dart';

final class _MockPlatformMonitor extends AppResourceMonitorPlatform {
  @override
  double get cpuUsagePercent => 42.0;

  @override
  double get gpuUsagePercent => 17.5;

  @override
  int get gpuVramBytes => 64 * 1024 * 1024; // 64 MB

  @override
  int get gpuSharedBytes => 32 * 1024 * 1024; // 32 MB

  @override
  int get privateBytes => 100 * 1024 * 1024; // 100 MB

  @override
  int get rssBytes => 150 * 1024 * 1024; // 150 MB

  @override
  int get committedBytes => 120 * 1024 * 1024; // 120 MB

  @override
  int get totalSystemRamBytes => 1024 * 1024 * 1024 * 16; // 16 GB

  @override
  void resetBaseline() {}

  @override
  void dispose() {}
}

void main() {
  group('MemorySize (Extension Type)', () {
    test('calculates correct conversions and formats', () {
      const size = MemorySize(1024 * 1024 * 512); // 512 MB
      expect(size.bytes, equals(536870912));
      expect(size.kb, equals(524288.0));
      expect(size.mb, equals(512.0));
      expect(size.gb, equals(0.5));
      expect(size.format(), equals('512.0 MB'));
      expect(size.format(decimals: 0), equals('512 MB'));
      expect(size.format(decimals: 2), equals('512.00 MB'));
    });

    test('formats across different scales in binary 1024 units', () {
      expect(const MemorySize(0).format(), equals('0 B'));
      expect(const MemorySize(500).format(), equals('500 B'));
      expect(const MemorySize(1024 * 25).format(), equals('25.0 KB'));
      expect(const MemorySize(1024 * 1024 * 150).format(), equals('150.0 MB'));
      expect(
        const MemorySize(1024 * 1024 * 1024 * 16).format(),
        equals('16.0 GB'),
      );
    });
  });

  group('ResourceSnapshot, MemorySnapshot & GpuSnapshot', () {
    test('creates models with accurate metrics and percentages', () {
      final now = DateTime.now();
      final memory = MemorySnapshot(
        private: const MemorySize(1024 * 1024 * 100),
        rss: const MemorySize(1024 * 1024 * 150),
        committed: const MemorySize(1024 * 1024 * 120),
        totalSystem: const MemorySize(1024 * 1024 * 1024 * 16),
      );
      const gpu = GpuSnapshot(
        usagePercent: 12.0,
        vram: MemorySize(1024 * 1024 * 64),
        shared: MemorySize(1024 * 1024 * 32),
      );

      final snapshot = ResourceSnapshot(
        timestamp: now,
        cpuUsagePercent: 25.5,
        gpu: gpu,
        memory: memory,
      );

      // Verify ResourceSnapshot properties
      expect(snapshot.timestamp, equals(now));
      expect(snapshot.cpuUsagePercent, equals(25.5));
      expect(snapshot.gpu?.usagePercent, equals(12.0));
      expect(snapshot.gpu?.vram.mb, equals(64.0));
      expect(snapshot.gpu?.shared.mb, equals(32.0));
      expect(snapshot.gpu?.total.mb, equals(96.0));
      expect(snapshot.toString(), contains('cpu: 25.5%'));
      expect(snapshot.toString(), contains('gpu: 12.0%'));
      expect(snapshot.toString(), contains('vram: 64.0 MB'));

      // Verify MemorySnapshot properties & percentages
      expect(memory.private.mb, equals(100.0));
      expect(memory.rss.mb, equals(150.0));
      expect(memory.committed.mb, equals(120.0));
      expect(memory.totalSystem.gb, equals(16.0));
      expect(memory.usagePercent, closeTo(0.61, 0.01));
      expect(memory.committedUsagePercent, closeTo(0.73, 0.01));
      expect(memory.toString(), contains('private: 100.0 MB'));

      // Value equality
      final sameSnapshot = ResourceSnapshot(
        timestamp: now,
        cpuUsagePercent: 25.5,
        gpu: gpu,
        memory: memory,
      );
      expect(snapshot, equals(sameSnapshot));
      expect(snapshot.hashCode, equals(sameSnapshot.hashCode));
    });

    test('handles null GPU gracefully', () {
      final snapshot = ResourceSnapshot(
        timestamp: DateTime.now(),
        cpuUsagePercent: 5.0,
        gpu: null,
        memory: const MemorySnapshot(
          private: MemorySize(0),
          rss: MemorySize(0),
          committed: MemorySize(0),
          totalSystem: MemorySize(0),
        ),
      );

      expect(snapshot.gpu, isNull);
      expect(snapshot.toString(), contains('gpu: N/A'));
      expect(snapshot.toString(), contains('vram: N/A'));
      expect(snapshot.memory.usagePercent, equals(0.0));
    });
  });

  group('AppResourceMonitor', () {
    test('provides accurate process resources on current platform', () {
      final monitor = AppResourceMonitor();

      // Verify system RAM
      expect(monitor.totalSystemRamBytes, greaterThan(0));
      expect(monitor.totalSystemRam.format(), isNotEmpty);
      expect(monitor.totalSystemRam.gb, greaterThan(0.0));

      // Verify memory properties in bytes & MemorySize
      expect(monitor.privateBytes, greaterThan(0));
      expect(monitor.private.format(), isNotEmpty);
      expect(monitor.private.mb, greaterThan(0.0));

      expect(monitor.rssBytes, greaterThan(0));
      expect(monitor.rss.format(), isNotEmpty);
      expect(monitor.rss.mb, greaterThan(0.0));

      expect(monitor.committedBytes, greaterThan(0));
      expect(monitor.committed.format(), isNotEmpty);

      // Verify percentages
      expect(monitor.memoryUsagePercent, inInclusiveRange(0.0, 100.0));
      expect(monitor.committedMemoryUsagePercent, inInclusiveRange(0.0, 100.0));

      // Verify CPU & GPU percentages
      expect(monitor.cpuUsagePercent, inInclusiveRange(0.0, 100.0));
      expect(monitor.gpuUsagePercent, inInclusiveRange(0.0, 100.0));

      // Verify VRAM getters
      expect(monitor.gpuVramBytes, greaterThanOrEqualTo(0));
      expect(monitor.gpuVram.bytes, greaterThanOrEqualTo(0));
      expect(monitor.gpuSharedBytes, greaterThanOrEqualTo(0));
      expect(monitor.gpuShared.bytes, greaterThanOrEqualTo(0));

      // Verify snapshot() snapshot
      final snapshot = monitor.snapshot();
      expect(snapshot.cpuUsagePercent, inInclusiveRange(0.0, 100.0));
      expect(snapshot.gpu?.usagePercent, inInclusiveRange(0.0, 100.0));
      expect(snapshot.memory.private.bytes, greaterThan(0));
      expect(snapshot.memory.totalSystem.bytes, greaterThan(0));

      // Reset baseline & dispose
      monitor.resetBaseline();
      monitor.dispose();
    });

    test('shared AppResourceMonitor.instance returns valid resources', () {
      final instance = AppResourceMonitor.instance;
      expect(instance.totalSystemRamBytes, greaterThan(0));
      expect(instance.totalSystemRam.format(), isNotEmpty);
      expect(instance.privateBytes, greaterThan(0));
      expect(instance.private.format(), isNotEmpty);
      expect(instance.rss.format(), isNotEmpty);
      expect(instance.cpuUsagePercent, inInclusiveRange(0.0, 100.0));

      // Verify static AppResourceMonitor.snapshot()
      final snapshot = AppResourceMonitor.snapshot();
      expect(snapshot.memory.private.bytes, greaterThan(0));
    });

    test('stream emits snapshots periodically and immediately by default',
        () async {
      final snapshots = await AppResourceMonitor.stream(
        interval: const Duration(milliseconds: 50),
      ).take(3).toList();

      expect(snapshots.length, equals(3));
      for (final snapshot in snapshots) {
        expect(snapshot.memory.totalSystem.bytes, greaterThan(0));
      }
    });

    test('stream with emitImmediately: false waits for interval', () async {
      final stopwatch = Stopwatch()..start();
      final snapshots = await AppResourceMonitor.stream(
        interval: const Duration(milliseconds: 60),
        emitImmediately: false,
      ).take(1).toList();

      stopwatch.stop();
      expect(snapshots.length, equals(1));
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(45));
    });

    test('supports mocking via AppResourceMonitorPlatform.instance', () {
      final defaultPlatform = AppResourceMonitorPlatform.instance;

      try {
        final mock = _MockPlatformMonitor();
        AppResourceMonitorPlatform.instance = mock;

        expect(AppResourceMonitor.instance.cpuUsagePercent, equals(42.0));
        expect(AppResourceMonitor.instance.gpuUsagePercent, equals(17.5));
        expect(
          AppResourceMonitor.instance.gpuVramBytes,
          equals(64 * 1024 * 1024),
        );
        expect(
          AppResourceMonitor.instance.gpuSharedBytes,
          equals(32 * 1024 * 1024),
        );
        expect(
          AppResourceMonitor.instance.gpuShared.format(),
          equals('32.0 MB'),
        );
        expect(
          AppResourceMonitor.instance.privateBytes,
          equals(100 * 1024 * 1024),
        );
        expect(
          AppResourceMonitor.instance.private.format(),
          equals('100.0 MB'),
        );
        expect(
          AppResourceMonitor.instance.rss.format(),
          equals('150.0 MB'),
        );
        expect(
          AppResourceMonitor.instance.committed.format(),
          equals('120.0 MB'),
        );
        expect(
          AppResourceMonitor.instance.totalSystemRam.format(),
          equals('16.0 GB'),
        );
        expect(
          AppResourceMonitor.instance.totalSystemRam.gb,
          equals(16.0),
        );
        expect(
          AppResourceMonitor.instance.memoryUsagePercent,
          closeTo(0.61, 0.01),
        );

        final snapshot = AppResourceMonitor.snapshot();
        expect(snapshot.cpuUsagePercent, equals(42.0));
        expect(snapshot.gpu?.usagePercent, equals(17.5));
        expect(snapshot.gpu?.vram.mb, equals(64.0));
        expect(snapshot.gpu?.shared.mb, equals(32.0));
        expect(snapshot.gpu?.total.mb, equals(96.0));
        expect(snapshot.memory.private.mb, equals(100.0));
        expect(snapshot.memory.totalSystem.gb, equals(16.0));
      } finally {
        // Restore default platform
        AppResourceMonitorPlatform.instance = defaultPlatform;
      }
    });
  });
}
