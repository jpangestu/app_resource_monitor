import 'package:app_resource_monitor/app_resource_monitor.dart';
import 'package:test/test.dart';

void main() {
  test('AppResourceMonitor provides accurate process resources', () {
    final monitor = AppResourceMonitor();

    // Verify system RAM
    expect(monitor.totalSystemRamBytes, greaterThan(0));
    expect(monitor.totalSystemRamMb, greaterThan(0.0));

    // Verify memory properties
    expect(monitor.privateBytes, greaterThan(0));
    expect(monitor.privateMb, greaterThan(0.0));
    expect(monitor.rssBytes, greaterThan(0));
    expect(monitor.rssMb, greaterThan(0.0));
    expect(monitor.committedBytes, greaterThan(0));
    expect(monitor.committedMb, greaterThan(0.0));
    expect(monitor.memoryUsagePercent, inInclusiveRange(0.0, 100.0));
    expect(monitor.committedMemoryUsagePercent, inInclusiveRange(0.0, 100.0));

    // Verify CPU & GPU percentages
    expect(monitor.cpuUsagePercent, inInclusiveRange(0.0, 100.0));
    expect(monitor.gpuUsagePercent, inInclusiveRange(0.0, 100.0));

    // Reset baseline & dispose
    monitor.resetBaseline();
    monitor.dispose();
  });
}
