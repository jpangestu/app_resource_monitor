## 0.1.0

- Initial release for Windows via `dart:ffi`.
- Real-time in-process **CPU** and **GPU** usage percentages.
- **RAM metrics**: Private RAM, Working Set (RSS), and Committed memory.
- `MemorySize` extension type with auto-formatting (`.format()`) and unit getters (`.mb`, `.gb`).
- Shared singleton (`AppResourceMonitor.instance`) and dedicated instances (`AppResourceMonitor()`).
- Mockable `AppResourceMonitorPlatform` interface for unit tests.
