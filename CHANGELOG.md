## 0.1.0

- Initial release for Windows via `dart:ffi`.
- **CPU** usage percentage.
- **GPU metrics**: Usage in percent, dedicated video memory (`vram`) and shared GPU memory.
- **RAM metrics**: Private RAM, Working Set (RSS), and Committed memory.
- `ResourceSnapshot`, `MemorySnapshot`, and `GpuSnapshot` models.
- Reactive `stream({Duration interval})`,
- `MemorySize` extension type with auto-formatting (`.format()`) and unit getters (`.mb`, `.gb`).
- Shared singleton (`AppResourceMonitor.instance`) and dedicated instances (`AppResourceMonitor()`).
- Mockable `AppResourceMonitorPlatform` interface for unit tests.
