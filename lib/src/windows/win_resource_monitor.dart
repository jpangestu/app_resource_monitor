import 'dart:ffi';
import 'dart:io' show Platform, ProcessInfo, pid;
import 'dart:math' as math;

import 'package:app_resource_monitor/src/app_resource_monitor.dart';

import 'win_binding.dart';

// Internal Kernel32 Helpers (Memory Allocation)
typedef _LocalAllocNative = Pointer<NativeType> Function(
  Uint32 uFlags,
  IntPtr uBytes,
);
typedef _LocalAllocDart = Pointer<NativeType> Function(int uFlags, int uBytes);

typedef _LocalFreeNative = Pointer<NativeType> Function(
  Pointer<NativeType> hMem,
);
typedef _LocalFreeDart = Pointer<NativeType> Function(Pointer<NativeType> hMem);

/// Combined contiguous native buffer holding CPU times (32B) + Memory Counters (96B).
final class _CpuMemoryBuffer extends Struct {
  @Uint64()
  external int creationTime;

  @Uint64()
  external int exitTime;

  @Uint64()
  external int kernelTime;

  @Uint64()
  external int userTime;

  external PROCESS_MEMORY_COUNTERS_EX2 memCounters;
}

/// Scratch memory layout for PDH handles and array size/count outputs (24 bytes).
final class _PdhScratch extends Struct {
  @IntPtr()
  external int hQuery;

  @IntPtr()
  external int hCounter;

  @Uint32()
  external int dwBufferSize;

  @Uint32()
  external int dwItemCount;
}

/// Windows implementation of [AppResourceMonitor] using Kernel32 and PDH via `dart:ffi`.
final class WinResourceMonitor implements AppResourceMonitor, Finalizable {
  WinResourceMonitor() {
    _init();
  }

  static const int _lmemZeroInit = 0x0040;
  static const int _minSampleWindowUs = 100000; // 100 ms
  static const int _pdhFmtDouble = 0x00000200;
  static const int _pdhMoreData = 0x800007D2;
  static const int _maxGpuItemBufferBytes = 4 * 1024 * 1024; // 4 MB safety cap

  final int _processorCount = math.max(1, Platform.numberOfProcessors);
  final Stopwatch _stopwatch = Stopwatch();

  bool _initialized = false;
  int _currentProcessHandle = 0;
  int _totalSystemRamBytes = 0;

  // Kernel32 memory buffer & finalizer
  Pointer<_CpuMemoryBuffer>? _buffer;
  NativeFinalizer? _finalizer;

  // Kernel32 function pointers
  GetProcessTimesDart? _getProcessTimes;
  GetProcessMemoryInfoDart? _getProcessMemoryInfo;
  _LocalAllocDart? _localAlloc;
  _LocalFreeDart? _localFree;

  // CPU timing state
  int _lastCpuTimeUs = 0;
  int _lastCpuSampleTimeUs = 0;
  double _lastCpuUsage = 0.0;

  // GPU state (PDH)
  bool _gpuInitialized = false;
  int _lastGpuSampleTimeUs = 0;
  double _lastGpuUsage = 0.0;

  Pointer<_PdhScratch>? _gpuScratchPtr;
  final Object _gpuScratchToken = Object();

  Pointer<PDH_FMT_COUNTERVALUE_ITEM_W>? _gpuItemBuffer;
  Object _gpuItemBufferToken = Object();
  int _gpuItemBufferBytes = 65536; // 64 KB initial buffer

  PdhCollectQueryDataDart? _pdhCollectQueryData;
  PdhGetFormattedCounterArrayWDart? _pdhGetFormattedCounterArray;
  PdhCloseQueryDart? _pdhCloseQuery;

  void _init() {
    if (!Platform.isWindows) return;
    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');

      final getCurrentProcess = kernel32
          .lookupFunction<GetCurrentProcessNative, GetCurrentProcessDart>(
        'GetCurrentProcess',
      );
      _getProcessTimes =
          kernel32.lookupFunction<GetProcessTimesNative, GetProcessTimesDart>(
        'GetProcessTimes',
      );
      _getProcessMemoryInfo = kernel32.lookupFunction<
          GetProcessMemoryInfoNative,
          GetProcessMemoryInfoDart>('K32GetProcessMemoryInfo');
      final globalMemoryStatusEx = kernel32.lookupFunction<
          GlobalMemoryStatusExNative,
          GlobalMemoryStatusExDart>('GlobalMemoryStatusEx');
      final localAlloc = kernel32
          .lookupFunction<_LocalAllocNative, _LocalAllocDart>('LocalAlloc');
      final localFreePtr = kernel32.lookup<NativeFinalizerFunction>(
        'LocalFree',
      );
      final localFree =
          kernel32.lookupFunction<_LocalFreeNative, _LocalFreeDart>(
        'LocalFree',
      );

      _localAlloc = localAlloc;
      _localFree = localFree;
      _currentProcessHandle = getCurrentProcess();

      // Allocate contiguous 128-byte buffer for CPU times + Memory counters
      final bufferBytes = sizeOf<_CpuMemoryBuffer>();
      final buf = localAlloc(
        _lmemZeroInit,
        bufferBytes,
      ).cast<_CpuMemoryBuffer>();
      if (buf.address == 0) return;
      _buffer = buf;

      _finalizer = NativeFinalizer(localFreePtr)
        ..attach(this, buf.cast(), detach: this, externalSize: bufferBytes);

      // Query total physical RAM once using the memory counters region as scratch space
      final memStatusPtr = _memCountersPtr.cast<MEMORYSTATUSEX>();
      memStatusPtr.ref.dwLength = sizeOf<MEMORYSTATUSEX>();
      if (globalMemoryStatusEx(memStatusPtr) != 0) {
        _totalSystemRamBytes = memStatusPtr.ref.ullTotalPhys;
      }

      // Initialize the cb header for PROCESS_MEMORY_COUNTERS_EX2
      _memCountersPtr.ref.cb = sizeOf<PROCESS_MEMORY_COUNTERS_EX2>();

      _stopwatch.start();

      // Initialize GPU monitoring via PDH
      _initGpu();

      _initialized = true;

      if (!_resetCpu()) {
        dispose();
      }
    } catch (_) {
      dispose();
    }
  }

  void _initGpu() {
    final localAlloc = _localAlloc;
    final localFree = _localFree;
    final finalizer = _finalizer;
    if (localAlloc == null || localFree == null || finalizer == null) return;

    try {
      final pdh = DynamicLibrary.open('pdh.dll');
      final pdhOpenQuery =
          pdh.lookupFunction<PdhOpenQueryWNative, PdhOpenQueryWDart>(
        'PdhOpenQueryW',
      );
      final pdhAddEnglishCounter = pdh.lookupFunction<
          PdhAddEnglishCounterWNative,
          PdhAddEnglishCounterWDart>('PdhAddEnglishCounterW');
      _pdhCollectQueryData = pdh
          .lookupFunction<PdhCollectQueryDataNative, PdhCollectQueryDataDart>(
        'PdhCollectQueryData',
      );
      _pdhGetFormattedCounterArray = pdh.lookupFunction<
          PdhGetFormattedCounterArrayWNative,
          PdhGetFormattedCounterArrayWDart>('PdhGetFormattedCounterArrayW');
      _pdhCloseQuery =
          pdh.lookupFunction<PdhCloseQueryNative, PdhCloseQueryDart>(
        'PdhCloseQuery',
      );

      final scratchSize = sizeOf<_PdhScratch>();
      final scratch = localAlloc(
        _lmemZeroInit,
        scratchSize,
      ).cast<_PdhScratch>();
      if (scratch.address == 0) return;
      _gpuScratchPtr = scratch;
      finalizer.attach(
        this,
        scratch.cast(),
        detach: _gpuScratchToken,
        externalSize: scratchSize,
      );

      final hQueryPtr = scratch.cast<IntPtr>();
      final hCounterPtr = scratch.cast<IntPtr>() + 1;

      if (pdhOpenQuery(nullptr, 0, hQueryPtr) != 0) {
        _disposeGpu();
        return;
      }

      // WDDM counter path for the current process across all GPU engines (3D, Copy, Compute, etc.)
      final counterPath = '\\GPU Engine(pid_${pid}_*)\\Utilization Percentage';
      final pathUnits = counterPath.codeUnits;
      final pathPtr = localAlloc(
        _lmemZeroInit,
        (pathUnits.length + 1) * 2,
      ).cast<Uint16>();
      if (pathPtr.address == 0) {
        _disposeGpu();
        return;
      }

      for (int i = 0; i < pathUnits.length; i++) {
        pathPtr[i] = pathUnits[i];
      }

      final addStatus = pdhAddEnglishCounter(
        scratch.ref.hQuery,
        pathPtr,
        0,
        hCounterPtr,
      );
      localFree(pathPtr.cast());

      if (addStatus != 0) {
        _disposeGpu();
        return;
      }

      final items = localAlloc(
        _lmemZeroInit,
        _gpuItemBufferBytes,
      ).cast<PDH_FMT_COUNTERVALUE_ITEM_W>();
      if (items.address == 0) {
        _disposeGpu();
        return;
      }
      _gpuItemBuffer = items;
      finalizer.attach(
        this,
        items.cast(),
        detach: _gpuItemBufferToken,
        externalSize: _gpuItemBufferBytes,
      );

      // Prime the PDH rate counter with an initial baseline collection
      _pdhCollectQueryData!(scratch.ref.hQuery);
      _gpuInitialized = true;
    } catch (_) {
      _disposeGpu();
    }
  }

  /// Pointer to the `memCounters` struct at offset 32 bytes (`buf + 4` Uint64s).
  Pointer<PROCESS_MEMORY_COUNTERS_EX2> get _memCountersPtr =>
      (_buffer!.cast<Uint64>() + 4).cast<PROCESS_MEMORY_COUNTERS_EX2>();

  int _getCurrentCpuTimeUs() {
    final buf = _buffer;
    if (!_initialized || buf == null) return -1;

    final timesPtr = buf.cast<Uint64>();
    final result = _getProcessTimes!(
      _currentProcessHandle,
      timesPtr,
      timesPtr + 1,
      timesPtr + 2,
      timesPtr + 3,
    );
    if (result == 0) return -1;

    // Convert 100-nanosecond units to microseconds
    return (buf.ref.kernelTime + buf.ref.userTime) ~/ 10;
  }

  int _lastMemorySampleTimeUs = 0;

  bool _updateMemoryCounters() {
    if (!_initialized || _buffer == null) return false;
    final now = _stopwatch.elapsedMicroseconds;
    if (now - _lastMemorySampleTimeUs < 10000) {
      return true;
    }
    final memPtr = _memCountersPtr;
    final cbSize = sizeOf<PROCESS_MEMORY_COUNTERS_EX2>();
    memPtr.ref.cb = cbSize;
    if (_getProcessMemoryInfo!(_currentProcessHandle, memPtr, cbSize) != 0) {
      _lastMemorySampleTimeUs = now;
      return true;
    }
    return false;
  }

  bool _resetCpu() {
    if (!Platform.isWindows || !_initialized) return false;
    final currentTimeUs = _stopwatch.elapsedMicroseconds;
    final currentCpuTimeUs = _getCurrentCpuTimeUs();
    if (currentCpuTimeUs < 0) return false;

    _lastCpuSampleTimeUs = currentTimeUs;
    _lastCpuTimeUs = currentCpuTimeUs;
    return true;
  }

  void _resetGpu() {
    final scratch = _gpuScratchPtr;
    if (!_gpuInitialized || scratch == null) return;
    _pdhCollectQueryData?.call(scratch.ref.hQuery);
    _lastGpuSampleTimeUs = _stopwatch.elapsedMicroseconds;
  }

  @override
  void resetBaseline() {
    _resetCpu();
    _resetGpu();
  }

  double _getCpuUsage() {
    if (!Platform.isWindows || !_initialized) return 0.0;

    final currentTimeUs = _stopwatch.elapsedMicroseconds;
    final deltaTimeUs = currentTimeUs - _lastCpuSampleTimeUs;

    if (deltaTimeUs >= _minSampleWindowUs) {
      final currentCpuTimeUs = _getCurrentCpuTimeUs();
      if (currentCpuTimeUs < _lastCpuTimeUs) {
        return _lastCpuUsage;
      }

      final deltaCpuTimeUs = currentCpuTimeUs - _lastCpuTimeUs;
      final cpuUsage =
          (deltaCpuTimeUs / (deltaTimeUs * _processorCount)) * 100.0;

      _lastCpuTimeUs = currentCpuTimeUs;
      _lastCpuSampleTimeUs = currentTimeUs;
      _lastCpuUsage = cpuUsage.clamp(0.0, 100.0);
    }

    return _lastCpuUsage;
  }

  double _getGpuUsage() {
    if (!Platform.isWindows ||
        !_gpuInitialized ||
        _gpuScratchPtr == null ||
        _gpuItemBuffer == null) {
      return 0.0;
    }

    final currentTimeUs = _stopwatch.elapsedMicroseconds;
    if (currentTimeUs - _lastGpuSampleTimeUs < _minSampleWindowUs) {
      return _lastGpuUsage;
    }
    _lastGpuSampleTimeUs = currentTimeUs;

    final scratch = _gpuScratchPtr!;
    final hQuery = scratch.ref.hQuery;
    final hCounter = scratch.ref.hCounter;

    if (_pdhCollectQueryData!(hQuery) != 0) return _lastGpuUsage;

    // Offset of dwBufferSize is 2 IntPtrs (16 bytes on 64-bit) from the start of _PdhScratch
    final sizePtr = (scratch.cast<IntPtr>() + 2).cast<Uint32>();
    final countPtr = sizePtr + 1;

    sizePtr.value = _gpuItemBufferBytes;
    countPtr.value = 0;

    int status = _pdhGetFormattedCounterArray!(
      hCounter,
      _pdhFmtDouble,
      sizePtr,
      countPtr,
      _gpuItemBuffer!,
    );

    // Dynamically expand buffer if PDH reports PDH_MORE_DATA
    if ((status & 0xFFFFFFFF) == _pdhMoreData) {
      final requiredBytes = sizePtr.value * 2;
      if (requiredBytes > _gpuItemBufferBytes &&
          requiredBytes <= _maxGpuItemBufferBytes) {
        if (!_reallocateGpuItemBuffer(requiredBytes)) {
          return 0.0;
        }
        sizePtr.value = _gpuItemBufferBytes;
        countPtr.value = 0;
        status = _pdhGetFormattedCounterArray!(
          hCounter,
          _pdhFmtDouble,
          sizePtr,
          countPtr,
          _gpuItemBuffer!,
        );
      }
    }

    if (status != 0) {
      _lastGpuUsage = 0.0;
      return 0.0;
    }

    final itemCount = countPtr.value;
    final items = _gpuItemBuffer!;
    double totalGpu = 0.0;

    for (int i = 0; i < itemCount; i++) {
      final item = (items + i).ref;
      if (item.cStatus == 0 || item.cStatus == 1) {
        final val = item.doubleValue;
        if (!val.isNaN && val > 0.0) {
          totalGpu += val;
        }
      }
    }

    _lastGpuUsage = totalGpu.clamp(0.0, 100.0);
    return _lastGpuUsage;
  }

  bool _reallocateGpuItemBuffer(int newSizeBytes) {
    final localAlloc = _localAlloc;
    final localFree = _localFree;
    final finalizer = _finalizer;
    if (localAlloc == null || localFree == null || finalizer == null) {
      return false;
    }

    final oldBuf = _gpuItemBuffer;
    if (oldBuf != null && oldBuf.address != 0) {
      finalizer.detach(_gpuItemBufferToken);
      localFree(oldBuf.cast());
      _gpuItemBuffer = null;
    }

    final newBuf = localAlloc(
      _lmemZeroInit,
      newSizeBytes,
    ).cast<PDH_FMT_COUNTERVALUE_ITEM_W>();
    if (newBuf.address == 0) {
      _gpuInitialized = false;
      return false;
    }

    _gpuItemBuffer = newBuf;
    _gpuItemBufferBytes = newSizeBytes;
    _gpuItemBufferToken = Object();
    finalizer.attach(
      this,
      newBuf.cast(),
      detach: _gpuItemBufferToken,
      externalSize: newSizeBytes,
    );
    return true;
  }

  @override
  double get cpuUsagePercent => _getCpuUsage();

  @override
  double get gpuUsagePercent => _getGpuUsage();

  @override
  int get rssBytes {
    if (!Platform.isWindows || !_initialized) return ProcessInfo.currentRss;
    if (!_updateMemoryCounters()) return ProcessInfo.currentRss;
    return _memCountersPtr.ref.workingSetSize;
  }

  @override
  int get privateBytes {
    if (!Platform.isWindows || !_initialized) return ProcessInfo.currentRss;
    if (!_updateMemoryCounters()) return ProcessInfo.currentRss;
    return _memCountersPtr.ref.privateWorkingSetSize;
  }

  @override
  int get committedBytes {
    if (!Platform.isWindows || !_initialized) return ProcessInfo.currentRss;
    if (!_updateMemoryCounters()) return ProcessInfo.currentRss;
    return _memCountersPtr.ref.privateUsage;
  }

  @override
  int get totalSystemRamBytes => _totalSystemRamBytes;

  void _disposeGpu() {
    final finalizer = _finalizer;
    final localFree = _localFree;

    final scratch = _gpuScratchPtr;
    if (scratch != null && scratch.address != 0) {
      final hQuery = scratch.ref.hQuery;
      if (hQuery != 0) {
        _pdhCloseQuery?.call(hQuery);
        scratch.ref.hQuery = 0;
      }
      finalizer?.detach(_gpuScratchToken);
      localFree?.call(scratch.cast());
      _gpuScratchPtr = null;
    }

    final items = _gpuItemBuffer;
    if (items != null && items.address != 0) {
      finalizer?.detach(_gpuItemBufferToken);
      localFree?.call(items.cast());
      _gpuItemBuffer = null;
    }

    _gpuInitialized = false;
  }

  @override
  void dispose() {
    _disposeGpu();

    final buf = _buffer;
    if (buf != null && buf.address != 0) {
      _finalizer?.detach(this);
      _localFree?.call(buf.cast());
    }
    _buffer = null;
    _stopwatch.stop();
    _initialized = false;
  }
}
