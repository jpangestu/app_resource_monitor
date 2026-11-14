import 'package:app_resource_monitor/app_resource_monitor.dart';

void main() async {
  print('Listening to resource metrics stream (sampling every 500ms)...\n');

  var snapshotCount = 0;

  // Stream continuous point-in-time ResourceSnapshots.
  // Ideal for Flutter StreamBuilder, performance HUDs, or background telemetry.
  await for (final snapshot in AppResourceMonitor.stream(
    interval: const Duration(milliseconds: 100),
  ).take(1000)) {
    snapshotCount++;

    final cpu = '${snapshot.cpuUsagePercent.toStringAsFixed(1)}%'.padLeft(6);
    final gpu = (snapshot.gpu != null
            ? '${snapshot.gpu!.usagePercent.toStringAsFixed(1)}%'
            : 'N/A')
        .padLeft(6);
    final vram = (snapshot.gpu?.vram.format() ?? 'N/A').padLeft(9);
    final privateRam = snapshot.memory.private.format().padLeft(9);
    final ramPercent =
        '(${snapshot.memory.usagePercent.toStringAsFixed(1)}%)'.padLeft(7);
    final rss = snapshot.memory.rss.format().padLeft(9);

    print(
      '#${snapshotCount.toString().padLeft(2)} | '
      'CPU: $cpu | '
      'GPU: $gpu | '
      'VRAM: $vram | '
      'RAM: $privateRam $ramPercent | '
      'RSS: $rss',
    );
  }

  print('\nStream finished successfully.');
}
