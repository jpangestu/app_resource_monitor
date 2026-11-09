import 'package:app_resource_monitor/app_resource_monitor.dart';
import 'package:test/test.dart';

final class _MockPlatformMonitor extends AppResourceMonitorPlatform {
  @override
  double get cpuUsagePercent => 42.0;

  @override
  double get gpuUsagePercent => 17.5;

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

  group('AppResourceMonitor', () {
    test('provides accurate process resources on current platform', () {
      final monitor = AppResourceMonitor();

      // Verify system RAM
      expect(monitor.totalSystemRamBytes, greaterThan(0));
      expect(monitor.totalSystemRam.format(), isNotEmpty);
      expect(monitor.totalSystemRam.gb, greaterThan(0.0));

      // Verify memory properties in bytes & MemorySize
      expect(monitor.privateBytes, greaterThan(0));
      expect(monitor.privateRam.format(), isNotEmpty);
      expect(monitor.privateRam.mb, greaterThan(0.0));

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

      // Reset baseline & dispose
      monitor.resetBaseline();
      monitor.dispose();
    });

    test('shared AppResourceMonitor.instance returns valid resources', () {
      final instance = AppResourceMonitor.instance;
      expect(instance.totalSystemRamBytes, greaterThan(0));
      expect(instance.totalSystemRam.format(), isNotEmpty);
      expect(instance.privateBytes, greaterThan(0));
      expect(instance.privateRam.format(), isNotEmpty);
      expect(instance.rss.format(), isNotEmpty);
      expect(instance.cpuUsagePercent, inInclusiveRange(0.0, 100.0));
    });

    test('supports mocking via AppResourceMonitorPlatform.instance', () {
      final defaultPlatform = AppResourceMonitorPlatform.instance;

      try {
        final mock = _MockPlatformMonitor();
        AppResourceMonitorPlatform.instance = mock;

        expect(AppResourceMonitor.instance.cpuUsagePercent, equals(42.0));
        expect(AppResourceMonitor.instance.gpuUsagePercent, equals(17.5));
        expect(
          AppResourceMonitor.instance.privateBytes,
          equals(100 * 1024 * 1024),
        );
        expect(
          AppResourceMonitor.instance.privateRam.format(),
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
      } finally {
        // Restore default platform
        AppResourceMonitorPlatform.instance = defaultPlatform;
      }
    });
  });
}
