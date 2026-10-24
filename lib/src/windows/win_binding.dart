// ignore_for_file: camel_case_types

import 'dart:ffi';

// ================================================================================================
// CPU
// ================================================================================================

// To get CPU usage info in windows, we need these from kernel32.dll:
// 1. GetCurrentProcess
// 2. GetProcessTimes
//    https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getprocesstimes
//    BOOL GetProcessTimes(
//      [in]  HANDLE     hProcess,
//      [out] LPFILETIME lpCreationTime,
//      [out] LPFILETIME lpExitTime,
//      [out] LPFILETIME lpKernelTime,
//      [out] LPFILETIME lpUserTime
//    );
// 3. FILETIME struct (or Uint64 pointer)
//    https://learn.microsoft.com/en-us/windows/win32/api/minwinbase/ns-minwinbase-filetime
//
// What we get from this api (that we care about) are:
// - KernelTime: Time the process spent executing in Windows kernel-mode (100-nanosecond units).
// - UserTime: Time the process spent executing application code in user-mode (100-nanosecond units).
//
// NOTE on CPU calculation:
// CPU usage is a rate of change over time:
//   DeltaProcessCpuTime = (KernelTime2 + UserTime2) - (KernelTime1 + UserTime1)
//   ElapsedRealTime     = Time2 - Time1
//   CPU %               = (DeltaProcessCpuTime / (ElapsedRealTime * LogicalCores)) * 100.0

// HANDLE GetCurrentProcess(void);
typedef GetCurrentProcessNative = IntPtr Function();
typedef GetCurrentProcessDart = int Function();

// BOOL GetProcessTimes(HANDLE hProcess, LPFILETIME lpCreationTime, LPFILETIME lpExitTime, LPFILETIME lpKernelTime, LPFILETIME lpUserTime);
typedef GetProcessTimesNative = Int32 Function(
  IntPtr hProcess,
  Pointer<Uint64> lpCreationTime,
  Pointer<Uint64> lpExitTime,
  Pointer<Uint64> lpKernelTime,
  Pointer<Uint64> lpUserTime,
);
typedef GetProcessTimesDart = int Function(
  int hProcess,
  Pointer<Uint64> lpCreationTime,
  Pointer<Uint64> lpExitTime,
  Pointer<Uint64> lpKernelTime,
  Pointer<Uint64> lpUserTime,
);

/// Represents a 64-bit value holding the number of 100-nanosecond intervals since January 1, 1601.
final class FILETIME extends Struct {
  @Uint32()
  external int dwLowDateTime;

  @Uint32()
  external int dwHighDateTime;

  /// Combines low and high 32-bit parts into a single 64-bit integer.
  int get value => (dwHighDateTime << 32) | dwLowDateTime;
}

// ================================================================================================
// Memory
// ================================================================================================

// To get memory usage info in windows, we need these from kernel32.dll:
// 1. GetProcessMemoryInfo
//    https://learn.microsoft.com/en-us/windows/win32/api/psapi/nf-psapi-getprocessmemoryinfo
//    BOOL GetProcessMemoryInfo(
//      [in]  HANDLE                   Process,
//      [out] PPROCESS_MEMORY_COUNTERS ppsmemCounters,
//      [in]  DWORD                    cb
//    );
// 2. GetCurrentProcess (already defined above)
//    https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getcurrentprocess
// 3. PROCESS_MEMORY_COUNTERS_EX2
//    https://learn.microsoft.com/en-us/windows/win32/api/psapi/ns-psapi-process_memory_counters_ex2
// 4. GlobalMemoryStatusEx
//    https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-globalmemorystatusex
//    BOOL GlobalMemoryStatusEx(
//      [in, out] LPMEMORYSTATUSEX lpBuffer
//    );
// 5. MEMORYSTATUSEX
//    https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/ns-sysinfoapi-memorystatusex
//
// What we get from this api (that we care about) are:
// - RSS (Resident Set Size / Working Set): Total physical RAM in use (includes shared DLLs).
// - Private Working Set: RAM owned exclusively by this process (Task Manager "Memory" column).
// - Committed Memory: Virtual memory committed by the OS memory manager.
// - Total Physical RAM: Total installed physical RAM on the system (ullTotalPhys).

// BOOL GetProcessMemoryInfo(HANDLE hProcess, PPROCESS_MEMORY_COUNTERS ppsmemCounters, DWORD cb);
typedef GetProcessMemoryInfoNative = Int32 Function(
  IntPtr hProcess,
  Pointer<PROCESS_MEMORY_COUNTERS_EX2> ppsmemCounters,
  Uint32 cb,
);
typedef GetProcessMemoryInfoDart = int Function(
  int hProcess,
  Pointer<PROCESS_MEMORY_COUNTERS_EX2> ppsmemCounters,
  int cb,
);

// BOOL GlobalMemoryStatusEx(LPMEMORYSTATUSEX lpBuffer);
typedef GlobalMemoryStatusExNative = Int32 Function(
  Pointer<MEMORYSTATUSEX> lpBuffer,
);
typedef GlobalMemoryStatusExDart = int Function(
  Pointer<MEMORYSTATUSEX> lpBuffer,
);

final class PROCESS_MEMORY_COUNTERS_EX2 extends Struct {
  /// Size of this struct in bytes (`sizeOf<PROCESS_MEMORY_COUNTERS_EX2>()`).
  @Uint32()
  external int cb;

  @Uint32()
  external int pageFaultCount;

  @Size()
  external int peakWorkingSetSize;

  /// RSS / Working Set Size in bytes (physical RAM, including shared libraries).
  @Size()
  external int workingSetSize;

  @Size()
  external int quotaPeakPagedPoolUsage;

  @Size()
  external int quotaPagedPoolUsage;

  @Size()
  external int quotaPeakNonPagedPoolUsage;

  @Size()
  external int quotaNonPagedPoolUsage;

  @Size()
  external int pagefileUsage;

  @Size()
  external int peakPagefileUsage;

  /// Committed memory in bytes (Private commit charge).
  @Size()
  external int privateUsage;

  /// Private Working Set Size in bytes (exclusive physical RAM, Task Manager "Memory").
  @Size()
  external int privateWorkingSetSize;

  @Uint64()
  external int sharedCommitUsage;
}

/// Contains information about the current state of both physical and virtual memory.
/// https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/ns-sysinfoapi-memorystatusex
final class MEMORYSTATUSEX extends Struct {
  /// Size of this struct in bytes (`sizeOf<MEMORYSTATUSEX>()`).
  @Uint32()
  external int dwLength;

  /// Approximate percentage of physical memory in use (0 to 100).
  @Uint32()
  external int dwMemoryLoad;

  /// Total physical RAM in bytes.
  @Uint64()
  external int ullTotalPhys;

  /// Available physical RAM in bytes.
  @Uint64()
  external int ullAvailPhys;

  /// Current committed memory limit for the system or current process in bytes.
  @Uint64()
  external int ullTotalPageFile;

  /// Maximum amount of memory the current process can commit in bytes.
  @Uint64()
  external int ullAvailPageFile;

  /// Total user-mode portion of the virtual address space in bytes.
  @Uint64()
  external int ullTotalVirtual;

  /// Unreserved and uncommitted memory in user-mode virtual address space in bytes.
  @Uint64()
  external int ullAvailVirtual;

  /// Reserved for OS internal use (always 0).
  @Uint64()
  external int ullAvailExtendedVirtual;
}

// ================================================================================================
// GPU
// ================================================================================================

// To get GPU usage info in windows, we use PDH (Performance Data Helper) from pdh.dll:
// 1. PdhOpenQueryW
//    https://learn.microsoft.com/en-us/windows/win32/api/pdh/nf-pdh-pdhopenqueryw
//    PDH_STATUS PdhOpenQueryW(
//      [in]  LPCWSTR    szDataSource,
//      [in]  DWORD_PTR  dwUserData,
//      [out] PDH_HQUERY *phQuery
//    );
// 2. PdhAddEnglishCounterW
//    https://learn.microsoft.com/en-us/windows/win32/api/pdh/nf-pdh-pdhaddenglishcounterw
//    PDH_STATUS PdhAddEnglishCounterW(
//      [in]  PDH_HQUERY   hQuery,
//      [in]  LPCWSTR      szFullCounterPath,
//      [in]  DWORD_PTR    dwUserData,
//      [out] PDH_HCOUNTER *phCounter
//    );
// 3. PdhCollectQueryData
//    https://learn.microsoft.com/en-us/windows/win32/api/pdh/nf-pdh-pdhcollectquerydata
//    PDH_STATUS PdhCollectQueryData(
//      [in, out] PDH_HQUERY hQuery
//    );
// 4. PdhGetFormattedCounterArrayW
//    https://learn.microsoft.com/en-us/windows/win32/api/pdh/nf-pdh-pdhgetformattedcounterarrayw
// 5. PdhCloseQuery
//    https://learn.microsoft.com/en-us/windows/win32/api/pdh/nf-pdh-pdhclosequery
// 6. PDH_FMT_COUNTERVALUE_ITEM_W
//    https://learn.microsoft.com/en-us/windows/win32/api/pdh/ns-pdh-pdh_fmt_countervalue_item_w
//
// What we query from PDH:
// - Wildcard Counter Path: r"\GPU Engine(pid_<PID>_*)\Utilization Percentage"
//
// What we get from this api (that we care about):
// - Utilization Percentage: Real-time GPU execution percentage across active GPU engines (3D,
//   Compute, Copy, Video).
//
// NOTE on GPU calculation:
// - A process can run workloads across multiple GPU engines simultaneously (e.g. 3D rendering +
//   copy operations).
// - Using a wildcard counter path (pid_<PID>_*) allows PdhGetFormattedCounterArrayW to return all
//   engines at once.
// - Valid items are filtered (cStatus == 0 || cStatus == 1) and their doubleValues are summed,
//   clamped to 0.0 .. 100.0%.
// - Like CPU, PDH rate counters require an initial baseline collection call before meaningful
//   percentages are emitted.

// PDH (pdh.dll) FFI Typedefs

typedef PdhOpenQueryWNative = Int32 Function(
  Pointer<NativeType> szDataSource,
  IntPtr dwUserData,
  Pointer<IntPtr> phQuery,
);
typedef PdhOpenQueryWDart = int Function(
  Pointer<NativeType> szDataSource,
  int dwUserData,
  Pointer<IntPtr> phQuery,
);

typedef PdhAddEnglishCounterWNative = Int32 Function(
  IntPtr hQuery,
  Pointer<Uint16> szFullCounterPath,
  IntPtr dwUserData,
  Pointer<IntPtr> phCounter,
);
typedef PdhAddEnglishCounterWDart = int Function(
  int hQuery,
  Pointer<Uint16> szFullCounterPath,
  int dwUserData,
  Pointer<IntPtr> phCounter,
);

typedef PdhCollectQueryDataNative = Int32 Function(IntPtr hQuery);
typedef PdhCollectQueryDataDart = int Function(int hQuery);

typedef PdhGetFormattedCounterArrayWNative = Int32 Function(
  IntPtr hCounter,
  Uint32 dwFormat,
  Pointer<Uint32> lpdwBufferSize,
  Pointer<Uint32> lpdwItemCount,
  Pointer<PDH_FMT_COUNTERVALUE_ITEM_W> itemBuffer,
);
typedef PdhGetFormattedCounterArrayWDart = int Function(
  int hCounter,
  int dwFormat,
  Pointer<Uint32> lpdwBufferSize,
  Pointer<Uint32> lpdwItemCount,
  Pointer<PDH_FMT_COUNTERVALUE_ITEM_W> itemBuffer,
);

typedef PdhCloseQueryNative = Int32 Function(IntPtr hQuery);
typedef PdhCloseQueryDart = int Function(int hQuery);

/// Counter item holding the engine instance name, status, and formatted double percentage.
final class PDH_FMT_COUNTERVALUE_ITEM_W extends Struct {
  external Pointer<Uint16> szName;

  @Uint32()
  external int cStatus;

  @Double()
  external double doubleValue;
}
