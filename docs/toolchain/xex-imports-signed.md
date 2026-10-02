# default.xex — signed kernel/XAM import table

Method: XexTool-RE IDC dump of the retail XEX (decrypted basefile stays outside the repo). Ordinal→name from xbox360-emu `docs/kernel/ordinals/{xboxkrnl,xam}.ord` (retail numbering = Xenia). OpenXDK `.def` is a different devkit numbering — do not mix.

## XEX identity

| Field | Value |
|---|---|
| PE name | ChavoKartGame-Xbox360-Shipping.pe |
| Load address | 0x82000000 |
| Entry point | 0x830DB568 |
| Image size | 0x1DB0000 |
| Title ID | 475807D7 (GX-2007) |
| Media ID | 54100DF5A90E3F8825BB13DB5C2EDD6 |
| Encryption | Retail, Encrypted, Not-Compressed |
| Import libraries | xboxkrnl.exe + xam.xex, both v2.0.21250.0 (min 2.0.16202.0) |
| Build filetime | 2013-11-28 |

## Summary

| Lib | Func | Data | Signed |
|---|---|---|---|
| xboxkrnl.exe | 176 | 13 | 189 |
| xam.xex | 118 | 0 | 118 |
| **Total** | **294** | **13** | **307** |

## xboxkrnl.exe imports (signed)

| Ordinal | Name | Kind | IAT slot | Thunk stub |
|---|---|---|---|---|
| 1 | `DbgBreakPoint` | func | 0x82000928 | 0x834DAD64 |
| 3 | `DbgPrint` | func | 0x82000940 | 0x834DADA4 |
| 9 | `ExAllocatePool` | func | 0x82000910 | 0x834DAD04 |
| 10 | `ExAllocatePoolWithTag` | func | 0x82000AC4 | 0x834DB354 |
| 11 | `ExAllocatePoolTypeWithTag` | func | 0x820009A0 | 0x834DAF14 |
| 13 | `ExCreateThread` | func | 0x82000984 | 0x834DAEA4 |
| 14 | `ExEventObjectType` | data | 0x8200087C | -- |
| 15 | `ExFreePool` | func | 0x8200090C | 0x834DACF4 |
| 16 | `ExGetXConfigSetting` | func | 0x820007EC | 0x834DA8C4 |
| 21 | `ExRegisterTitleTerminateNotification` | func | 0x82000828 | 0x834DA9B4 |
| 25 | `ExTerminateThread` | func | 0x82000960 | 0x834DAE14 |
| 27 | `ExThreadObjectType` | data | 0x82000864 | -- |
| 33 | `FscSetCacheElementCount` | func | 0x82000918 | 0x834DAD24 |
| 40 | `HalReturnToFirmware` | func | 0x820009E8 | 0x834DB034 |
| 43 | `InterlockedFlushSList` | func | 0x820009F4 | 0x834DB064 |
| 44 | `InterlockedPopEntrySList` | func | 0x820009F0 | 0x834DB054 |
| 52 | `IoCheckShareAccess` | func | 0x820009BC | 0x834DAF84 |
| 53 | `IoCompleteRequest` | func | 0x820009A4 | 0x834DAF24 |
| 55 | `IoCreateDevice` | func | 0x82000994 | 0x834DAEE4 |
| 57 | `IoDeleteDevice` | func | 0x82000998 | 0x834DAEF4 |
| 59 | `IoDismountVolume` | func | 0x820009D8 | 0x834DAFF4 |
| 60 | `IoDismountVolumeByFileHandle` | func | 0x820009EC | 0x834DB044 |
| 65 | `IoInvalidDeviceRequest` | func | 0x82000988 | 0x834DAEB4 |
| 69 | `IoRemoveShareAccess` | func | 0x820009C4 | 0x834DAFA4 |
| 71 | `IoSetShareAccess` | func | 0x820009C0 | 0x834DAF94 |
| 77 | `KeAcquireSpinLockAtRaisedIrql` | func | 0x82000A1C | 0x834DB0E4 |
| 82 | `KeBugCheck` | func | 0x82000844 | 0x834DAA24 |
| 83 | `KeBugCheckEx` | func | 0x82000958 | 0x834DADF4 |
| 89 | `KeDebugMonitorData` | data | 0x82000874 | -- |
| 90 | `KeDelayExecutionThread` | func | 0x82000878 | 0x834DAAD4 |
| 93 | `KeEnableFpuExceptions` | func | 0x8200083C | 0x834DAA04 |
| 95 | `KeEnterCriticalRegion` | func | 0x8200082C | 0x834DA9C4 |
| 102 | `KeGetCurrentProcessType` | func | 0x820007F4 | 0x834DA8E4 |
| 107 | `KeLockL2` | func | 0x82000A40 | 0x834DB164 |
| 108 | `KeUnlockL2` | func | 0x82000A44 | 0x834DB174 |
| 109 | `KeInitializeApc` | func | 0x82000AC0 | 0x834DB344 |
| 111 | `KeInitializeDpc` | func | 0x82000A3C | 0x834DB154 |
| 122 | `KeInsertQueueApc` | func | 0x82000AC8 | 0x834DB364 |
| 123 | `KeInsertQueueDpc` | func | 0x82000A10 | 0x834DB0B4 |
| 125 | `KeLeaveCriticalRegion` | func | 0x82000824 | 0x834DA9A4 |
| 129 | `KeQueryBasePriorityThread` | func | 0x82000868 | 0x834DAAA4 |
| 131 | `KeQueryPerformanceFrequency` | func | 0x82000810 | 0x834DA954 |
| 132 | `KeQuerySystemTime` | func | 0x82000914 | 0x834DAD14 |
| 137 | `KeReleaseSpinLockFromRaisedIrql` | func | 0x82000A0C | 0x834DB0A4 |
| 143 | `KeResetEvent` | func | 0x820009E4 | 0x834DB024 |
| 151 | `KeSetAffinityThread` | func | 0x82000870 | 0x834DAAC4 |
| 153 | `KeSetBasePriorityThread` | func | 0x8200085C | 0x834DAA84 |
| 154 | `KeSetCurrentProcessType` | func | 0x82000A38 | 0x834DB144 |
| 157 | `KeSetEvent` | func | 0x82000814 | 0x834DA964 |
| 173 | `KeTimeStampBundle` | data | 0x82000950 | -- |
| 175 | `KeWaitForMultipleObjects` | func | 0x82000818 | 0x834DA974 |
| 176 | `KeWaitForSingleObject` | func | 0x8200099C | 0x834DAF04 |
| 177 | `KfAcquireSpinLock` | func | 0x820009B0 | 0x834DAF54 |
| 180 | `KfReleaseSpinLock` | func | 0x820009AC | 0x834DAF44 |
| 186 | `MmAllocatePhysicalMemoryEx` | func | 0x820008F4 | 0x834DAC94 |
| 189 | `MmFreePhysicalMemory` | func | 0x82000900 | 0x834DACC4 |
| 190 | `MmGetPhysicalAddress` | func | 0x82000800 | 0x834DA914 |
| 194 | `MmMapIoSpace` | func | 0x82000804 | 0x834DA924 |
| 196 | `MmQueryAddressProtect` | func | 0x820008A4 | 0x834DAB74 |
| 197 | `MmQueryAllocationSize` | func | 0x820008F8 | 0x834DACA4 |
| 199 | `MmSetAddressProtect` | func | 0x820008FC | 0x834DACB4 |
| 204 | `NtAllocateVirtualMemory` | func | 0x82000908 | 0x834DACE4 |
| 205 | `NtCancelTimer` | func | 0x82000930 | 0x834DAD84 |
| 206 | `NtClearEvent` | func | 0x8200089C | 0x834DAB54 |
| 207 | `NtClose` | func | 0x820008BC | 0x834DABC4 |
| 209 | `NtCreateEvent` | func | 0x82000894 | 0x834DAB34 |
| 210 | `NtCreateFile` | func | 0x820008E0 | 0x834DAC44 |
| 212 | `NtCreateMutant` | func | 0x82000948 | 0x834DADC4 |
| 213 | `NtCreateSemaphore` | func | 0x82000888 | 0x834DAB04 |
| 215 | `NtCreateTimer` | func | 0x82000938 | 0x834DAD94 |
| 217 | `NtDeviceIoControlFile` | func | 0x820008DC | 0x834DAC34 |
| 218 | `NtDuplicateObject` | func | 0x82000980 | 0x834DAE94 |
| 219 | `NtFlushBuffersFile` | func | 0x82000970 | 0x834DAE54 |
| 220 | `NtFreeVirtualMemory` | func | 0x820008F0 | 0x834DAC84 |
| 223 | `NtOpenFile` | func | 0x820008CC | 0x834DAC04 |
| 226 | `NtPulseEvent` | func | 0x82000884 | 0x834DAAF4 |
| 228 | `NtQueryDirectoryFile` | func | 0x82000974 | 0x834DAE64 |
| 231 | `NtQueryFullAttributesFile` | func | 0x820008EC | 0x834DAC74 |
| 232 | `NtQueryInformationFile` | func | 0x820008D0 | 0x834DAC14 |
| 238 | `NtQueryVirtualMemory` | func | 0x820008A8 | 0x834DAB84 |
| 239 | `NtQueryVolumeInformationFile` | func | 0x820008C8 | 0x834DABF4 |
| 240 | `NtReadFile` | func | 0x8200097C | 0x834DAE84 |
| 241 | `NtReadFileScatter` | func | 0x82000978 | 0x834DAE74 |
| 242 | `NtReleaseMutant` | func | 0x8200094C | 0x834DADD4 |
| 243 | `NtReleaseSemaphore` | func | 0x8200088C | 0x834DAB14 |
| 245 | `NtResumeThread` | func | 0x820008A0 | 0x834DAB64 |
| 246 | `NtSetEvent` | func | 0x82000898 | 0x834DAB44 |
| 247 | `NtSetInformationFile` | func | 0x820008B0 | 0x834DABA4 |
| 250 | `NtSetTimerEx` | func | 0x8200092C | 0x834DAD74 |
| 252 | `NtSuspendThread` | func | 0x8200086C | 0x834DAAB4 |
| 253 | `NtWaitForSingleObjectEx` | func | 0x820008C0 | 0x834DABD4 |
| 254 | `NtWaitForMultipleObjectsEx` | func | 0x82000890 | 0x834DAB24 |
| 255 | `NtWriteFile` | func | 0x820008C4 | 0x834DABE4 |
| 256 | `NtWriteFileGather` | func | 0x820009A8 | 0x834DAF34 |
| 257 | `NtYieldExecution` | func | 0x82000ACC | 0x834DB374 |
| 259 | `ObCreateSymbolicLink` | func | 0x820009DC | 0x834DB004 |
| 260 | `ObDeleteSymbolicLink` | func | 0x820009E0 | 0x834DB014 |
| 261 | `ObDereferenceObject` | func | 0x820007E8 | 0x834DA8B4 |
| 265 | `ObIsTitleObject` | func | 0x820009B8 | 0x834DAF74 |
| 271 | `ObReferenceObject` | func | 0x82000990 | 0x834DAED4 |
| 272 | `ObReferenceObjectByHandle` | func | 0x82000860 | 0x834DAA94 |
| 281 | `RtlCaptureContext` | func | 0x82000848 | 0x834DAA34 |
| 283 | `RtlCompareMemoryUlong` | func | 0x8200095C | 0x834DAE04 |
| 285 | `RtlCompareStringN` | func | 0x820008B8 | 0x834DABB4 |
| 293 | `RtlEnterCriticalSection` | func | 0x82000AB4 | 0x834DA124 |
| 294 | `RtlFillMemoryUlong` | func | 0x82000954 | 0x834DADE4 |
| 295 | `RtlFreeAnsiString` | func | 0x82000964 | 0x834DAE24 |
| 299 | `RtlImageXexHeaderField` | func | 0x820008D4 | 0x834DAC24 |
| 300 | `RtlInitAnsiString` | func | 0x82000880 | 0x834DAAE4 |
| 301 | `RtlInitUnicodeString` | func | 0x8200096C | 0x834DAE44 |
| 302 | `RtlInitializeCriticalSection` | func | 0x82000AA4 | 0x834DA154 |
| 303 | `RtlInitializeCriticalSectionAndSpinCount` | func | 0x82000838 | 0x834DA9F4 |
| 304 | `RtlLeaveCriticalSection` | func | 0x82000AA8 | 0x834DA144 |
| 307 | `RtlMultiByteToUnicodeN` | func | 0x82000850 | 0x834DAA54 |
| 309 | `RtlNtStatusToDosError` | func | 0x8200084C | 0x834DAA44 |
| 310 | `RtlRaiseException` | func | 0x82000858 | 0x834DAA74 |
| 314 | `_snprintf` | func | 0x820008E8 | 0x834DAC64 |
| 315 | `sprintf` | func | 0x82000A30 | 0x834DB124 |
| 319 | `RtlTimeFieldsToTime` | func | 0x820008AC | 0x834DAB94 |
| 320 | `RtlTimeToTimeFields` | func | 0x82000904 | 0x834DACD4 |
| 321 | `RtlTryEnterCriticalSection` | func | 0x82000AAC | 0x834DA134 |
| 322 | `RtlUnicodeStringToAnsiString` | func | 0x82000968 | 0x834DAE34 |
| 323 | `RtlUnicodeToMultiByteN` | func | 0x82000854 | 0x834DAA64 |
| 327 | `RtlUnwind` | func | 0x82000840 | 0x834DAA14 |
| 329 | `RtlUpcaseUnicodeChar` | func | 0x820009B4 | 0x834DAF64 |
| 333 | `_vsnprintf` | func | 0x82000944 | 0x834DADB4 |
| 338 | `KeTlsAlloc` | func | 0x82000AA0 | 0x834DA164 |
| 339 | `KeTlsFree` | func | 0x820007DC | 0x834DA194 |
| 340 | `KeTlsGetValue` | func | 0x82000A9C | 0x834DA174 |
| 341 | `KeTlsSetValue` | func | 0x820007E0 | 0x834DA184 |
| 342 | `XboxHardwareInfo` | data | 0x820008B4 | -- |
| 344 | `XboxKrnlVersion` | data | 0x82000934 | -- |
| 402 | `XeCryptSha` | func | 0x8200098C | 0x834DAEC4 |
| 403 | `XexExecutableModuleHandle` | data | 0x820008D8 | -- |
| 404 | `XexCheckExecutablePrivilege` | func | 0x820007F0 | 0x834DA8D4 |
| 405 | `XexGetModuleHandle` | func | 0x820007E4 | 0x834DA8A4 |
| 406 | `XexGetModuleSection` | func | 0x82000924 | 0x834DAD54 |
| 407 | `XexGetProcedureAddress` | func | 0x82000AB0 | 0x834DA894 |
| 409 | `XexLoadImage` | func | 0x82000920 | 0x834DAD44 |
| 411 | `XexLoadImageHeaders` | func | 0x820008E4 | 0x834DAC54 |
| 417 | `XexUnloadImage` | func | 0x8200091C | 0x834DAD34 |
| 421 | `__C_specific_handler` | func | 0x820007F8 | 0x834DA8F4 |
| 430 | `ExLoadedCommandLine` | data | 0x8200093C | -- |
| 433 | `VdCallGraphicsNotificationRoutines` | func | 0x82000A58 | 0x834DB1B4 |
| 436 | `VdEnableDisableClockGating` | func | 0x82000A2C | 0x834DB114 |
| 438 | `VdEnableRingBufferRPtrWriteBack` | func | 0x82000A14 | 0x834DB0C4 |
| 441 | `VdGetCurrentDisplayGamma` | func | 0x82000A34 | 0x834DB134 |
| 442 | `VdGetCurrentDisplayInformation` | func | 0x82000A5C | 0x834DB1C4 |
| 445 | `VdGetSystemCommandBuffer` | func | 0x82000A24 | 0x834DB104 |
| 446 | `VdGlobalDevice` | data | 0x820009F8 | -- |
| 447 | `VdGlobalXamDevice` | data | 0x820009FC | -- |
| 448 | `VdGpuClockInMHz` | data | 0x82000A54 | -- |
| 449 | `VdHSIOCalibrationLock` | data | 0x82000A80 | -- |
| 450 | `VdInitializeEngines` | func | 0x82000A6C | 0x834DB204 |
| 451 | `VdInitializeRingBuffer` | func | 0x82000A18 | 0x834DB0D4 |
| 453 | `VdInitializeScalerCommandBuffer` | func | 0x82000A4C | 0x834DB194 |
| 454 | `VdIsHSIOTrainingSucceeded` | func | 0x82000A70 | 0x834DB214 |
| 455 | `VdPersistDisplay` | func | 0x82000A00 | 0x834DB074 |
| 457 | `VdQueryVideoFlags` | func | 0x82000A50 | 0x834DB1A4 |
| 458 | `VdQueryVideoMode` | func | 0x82000A48 | 0x834DB184 |
| 467 | `VdSetDisplayMode` | func | 0x82000A60 | 0x834DB1D4 |
| 468 | `VdSetDisplayModeOverride` | func | 0x82000A68 | 0x834DB1F4 |
| 469 | `VdSetGraphicsInterruptCallback` | func | 0x82000A64 | 0x834DB1E4 |
| 473 | `VdSetSystemCommandBufferGpuIdentifierAddress` | func | 0x82000A04 | 0x834DB084 |
| 476 | `VdShutdownEngines` | func | 0x82000A74 | 0x834DB224 |
| 479 | `KiApcNormalRoutineNop` | func | 0x82000A08 | 0x834DB094 |
| 499 | `XAudioRegisterRenderDriverClient` | func | 0x82000830 | 0x834DA9D4 |
| 500 | `XAudioUnregisterRenderDriverClient` | func | 0x82000820 | 0x834DA994 |
| 501 | `XAudioSubmitRenderDriverFrame` | func | 0x8200081C | 0x834DA984 |
| 504 | `XAudioGetVoiceCategoryVolume` | func | 0x820007FC | 0x834DA904 |
| 511 | `XAudioGetSpeakerConfig` | func | 0x82000834 | 0x834DA9E4 |
| 548 | `XMACreateContext` | func | 0x82000808 | 0x834DA934 |
| 550 | `XMAReleaseContext` | func | 0x8200080C | 0x834DA944 |
| 598 | `XeKeysConsolePrivateKeySign` | func | 0x820009D4 | 0x834DAFE4 |
| 599 | `XeKeysConsoleSignatureVerification` | func | 0x820009D0 | 0x834DAFD4 |
| 601 | `StfsCreateDevice` | func | 0x820009CC | 0x834DAFC4 |
| 602 | `StfsControlDevice` | func | 0x820009C8 | 0x834DAFB4 |
| 603 | `VdSwap` | func | 0x82000A20 | 0x834DB0F4 |
| 614 | `KeCertMonitorData` | data | 0x82000A28 | -- |
| 617 | `VdRetrainEDRAM` | func | 0x82000A78 | 0x834DB234 |
| 618 | `VdRetrainEDRAMWorker` | func | 0x82000A7C | 0x834DB244 |
| 689 | `MicDeviceRequest` | func | 0x82000ABC | 0x834DB334 |
| 737 | `RmcDeviceRequest` | func | 0x82000AB8 | 0x834DB324 |
| 845 | `XAudioEnableDucker` | func | 0x82000A88 | 0x834DB264 |
| 848 | `XAudioGetDuckerLevel` | func | 0x82000A84 | 0x834DB254 |
| 849 | `XAudioGetDuckerThreshold` | func | 0x82000A98 | 0x834DB2A4 |
| 851 | `XAudioGetDuckerAttackTime` | func | 0x82000A90 | 0x834DB284 |
| 853 | `XAudioGetDuckerReleaseTime` | func | 0x82000A8C | 0x834DB274 |
| 855 | `XAudioGetDuckerHoldTime` | func | 0x82000A94 | 0x834DB294 |

## xam.xex imports (signed)

| Ordinal | Name | Kind | IAT slot | Thunk stub |
|---|---|---|---|---|
| 1 | `NetDll_WSAStartup` | func | 0x82000638 | 0x834DA204 |
| 2 | `NetDll_WSACleanup` | func | 0x82000640 | 0x834DA224 |
| 3 | `NetDll_socket` | func | 0x82000644 | 0x834DA234 |
| 4 | `NetDll_closesocket` | func | 0x82000648 | 0x834DA244 |
| 5 | `NetDll_shutdown` | func | 0x8200064C | 0x834DA254 |
| 6 | `NetDll_ioctlsocket` | func | 0x82000650 | 0x834DA264 |
| 7 | `NetDll_setsockopt` | func | 0x82000654 | 0x834DA274 |
| 8 | `NetDll_getsockopt` | func | 0x82000658 | 0x834DA284 |
| 9 | `NetDll_getsockname` | func | 0x8200065C | 0x834DA294 |
| 11 | `NetDll_bind` | func | 0x82000660 | 0x834DA2A4 |
| 12 | `NetDll_connect` | func | 0x82000664 | 0x834DA2B4 |
| 13 | `NetDll_listen` | func | 0x82000668 | 0x834DA2C4 |
| 14 | `NetDll_accept` | func | 0x8200066C | 0x834DA2D4 |
| 15 | `NetDll_select` | func | 0x82000670 | 0x834DA2E4 |
| 18 | `NetDll_recv` | func | 0x82000674 | 0x834DA2F4 |
| 20 | `NetDll_recvfrom` | func | 0x82000678 | 0x834DA304 |
| 22 | `NetDll_send` | func | 0x8200067C | 0x834DA314 |
| 24 | `NetDll_sendto` | func | 0x82000680 | 0x834DA324 |
| 26 | `NetDll_inet_addr` | func | 0x82000684 | 0x834DA334 |
| 27 | `NetDll_WSAGetLastError` | func | 0x82000688 | 0x834DA344 |
| 28 | `NetDll_WSASetLastError` | func | 0x8200068C | 0x834DA354 |
| 29 | `NetDll_WSACreateEvent` | func | 0x82000690 | 0x834DA364 |
| 34 | `NetDll___WSAFDIsSet` | func | 0x82000694 | 0x834DA374 |
| 51 | `NetDll_XNetStartup` | func | 0x82000698 | 0x834DA384 |
| 52 | `NetDll_XNetCleanup` | func | 0x8200069C | 0x834DA394 |
| 53 | `NetDll_XNetRandom` | func | 0x820006A0 | 0x834DA3A4 |
| 55 | `NetDll_XNetRegisterKey` | func | 0x820006A4 | 0x834DA3B4 |
| 56 | `NetDll_XNetUnregisterKey` | func | 0x820006A8 | 0x834DA3C4 |
| 57 | `NetDll_XNetXnAddrToInAddr` | func | 0x820006AC | 0x834DA3D4 |
| 58 | `NetDll_XNetServerToInAddr` | func | 0x820006B0 | 0x834DA3E4 |
| 60 | `NetDll_XNetInAddrToXnAddr` | func | 0x820006B4 | 0x834DA3F4 |
| 63 | `NetDll_XNetUnregisterInAddr` | func | 0x820006B8 | 0x834DA404 |
| 65 | `NetDll_XNetConnect` | func | 0x820006BC | 0x834DA414 |
| 67 | `NetDll_XNetDnsLookup` | func | 0x820006C0 | 0x834DA424 |
| 68 | `NetDll_XNetDnsRelease` | func | 0x820006C4 | 0x834DA434 |
| 69 | `NetDll_XNetQosListen` | func | 0x820006C8 | 0x834DA444 |
| 70 | `NetDll_XNetQosLookup` | func | 0x820006CC | 0x834DA454 |
| 72 | `NetDll_XNetQosRelease` | func | 0x820006D0 | 0x834DA464 |
| 73 | `NetDll_XNetGetTitleXnAddr` | func | 0x820006D4 | 0x834DA474 |
| 75 | `NetDll_XNetGetEthernetLinkStatus` | func | 0x820006D8 | 0x834DA484 |
| 77 | `NetDll_XNetQosGetListenStats` | func | 0x820006DC | 0x834DA494 |
| 84 | `NetDll_XNetSetSystemLinkPort` | func | 0x820006E0 | 0x834DA4A4 |
| 310 | `XNetLogonGetTitleID` | func | 0x820006F8 | 0x834DA504 |
| 400 | `XamInputGetCapabilities` | func | 0x8200077C | 0x834DA714 |
| 401 | `XamInputGetState` | func | 0x82000780 | 0x834DA724 |
| 402 | `XamInputSetState` | func | 0x82000784 | 0x834DA734 |
| 420 | `_XamLoaderLaunchTitle__YAXPBDK_Z` | func | 0x820007C4 | 0x834DA834 |
| 423 | `_XamLoaderGetLaunchDataSize__YAKPAK_Z` | func | 0x82000624 | 0x834DA1B4 |
| 424 | `_XamLoaderGetLaunchData__YAKPAXK_Z` | func | 0x82000628 | 0x834DA1C4 |
| 425 | `_XamLoaderTerminateTitle__YAXXZ` | func | 0x820007D0 | 0x834DA864 |
| 431 | `XamTaskSchedule` | func | 0x82000790 | 0x834DA764 |
| 433 | `XamTaskCloseHandle` | func | 0x8200061C | 0x834DA884 |
| 435 | `XamTaskShouldExit` | func | 0x820007D4 | 0x834DA874 |
| 490 | `XamAlloc` | func | 0x820006EC | 0x834DA4D4 |
| 492 | `XamFree` | func | 0x820006E4 | 0x834DA4B4 |
| 500 | `XMsgInProcessCall` | func | 0x820006E8 | 0x834DA4C4 |
| 501 | `XMsgCompleteIORequest` | func | 0x82000794 | 0x834DA774 |
| 503 | `XMsgStartIORequest` | func | 0x820006F0 | 0x834DA4E4 |
| 504 | `XMsgCancelIORequest` | func | 0x82000604 | 0x834DB2F4 |
| 507 | `XamGetOverlappedResult` | func | 0x8200078C | 0x834DA754 |
| 508 | `XMsgStartIORequestEx` | func | 0x8200071C | 0x834DA594 |
| 520 | `XamUserGetDeviceContext` | func | 0x82000610 | 0x834DB2C4 |
| 522 | `XamUserGetXUID` | func | 0x820006F4 | 0x834DA4F4 |
| 526 | `XamUserGetName` | func | 0x82000798 | 0x834DA784 |
| 528 | `XamUserGetSigninState` | func | 0x82000714 | 0x834DA574 |
| 530 | `XamUserCheckPrivilege` | func | 0x82000718 | 0x834DA584 |
| 531 | `XamUserAreUsersFriends` | func | 0x8200079C | 0x834DA794 |
| 537 | `XamUserReadProfileSettings` | func | 0x82000704 | 0x834DA534 |
| 538 | `XamUserWriteProfileSettings` | func | 0x82000708 | 0x834DA544 |
| 551 | `XamUserGetSigninInfo` | func | 0x820007C0 | 0x834DA824 |
| 590 | `XamCreateEnumeratorHandle` | func | 0x82000710 | 0x834DA564 |
| 591 | `XamGetPrivateEnumStructureFromHandle` | func | 0x8200070C | 0x834DA554 |
| 592 | `XamEnumerate` | func | 0x820007B8 | 0x834DA804 |
| 601 | `XamContentCreateEx` | func | 0x82000720 | 0x834DA5A4 |
| 602 | `XamContentClose` | func | 0x82000728 | 0x834DA5C4 |
| 603 | `XamContentDelete` | func | 0x82000724 | 0x834DA5B4 |
| 604 | `XamContentCreateEnumerator` | func | 0x82000734 | 0x834DA5F4 |
| 606 | `XamContentGetDeviceData` | func | 0x8200073C | 0x834DA614 |
| 610 | `XamContentGetCreator` | func | 0x8200072C | 0x834DA5D4 |
| 613 | `XamContentGetDeviceState` | func | 0x82000738 | 0x834DA604 |
| 614 | `XamContentGetLicenseMask` | func | 0x82000730 | 0x834DA5E4 |
| 640 | `XamGetExecutionId` | func | 0x82000788 | 0x834DA744 |
| 642 | `XamGetSystemVersion` | func | 0x8200063C | 0x834DA214 |
| 650 | `XamNotifyCreateListener` | func | 0x820007BC | 0x834DA814 |
| 651 | `XNotifyGetNext` | func | 0x82000630 | 0x834DA1E4 |
| 652 | `XNotifyPositionUI` | func | 0x8200062C | 0x834DA1D4 |
| 700 | `XamShowSigninUI` | func | 0x82000740 | 0x834DA624 |
| 703 | `XamShowFriendsUI` | func | 0x82000744 | 0x834DA634 |
| 704 | `XamShowMessagesUI` | func | 0x8200074C | 0x834DA654 |
| 705 | `XamShowKeyboardUI` | func | 0x82000750 | 0x834DA664 |
| 706 | `XamShowQuickChatUI` | func | 0x82000754 | 0x834DA674 |
| 709 | `XamShowAchievementsUI` | func | 0x8200075C | 0x834DA694 |
| 710 | `XamShowPlayerReviewUI` | func | 0x82000760 | 0x834DA6A4 |
| 711 | `XamShowMarketplaceUI` | func | 0x82000764 | 0x834DA6B4 |
| 712 | `XamShowPlayersUI` | func | 0x82000748 | 0x834DA644 |
| 715 | `XamShowDeviceSelectorUI` | func | 0x82000768 | 0x834DA6C4 |
| 716 | `XamShowMessageComposeUI` | func | 0x8200076C | 0x834DA6D4 |
| 717 | `XamShowGameInviteUI` | func | 0x82000770 | 0x834DA6E4 |
| 718 | `XamShowFriendRequestUI` | func | 0x82000774 | 0x834DA6F4 |
| 725 | `XamShowGamerCardUIForXUID` | func | 0x82000758 | 0x834DA684 |
| 729 | `XamShowDirtyDiscErrorUI` | func | 0x82000778 | 0x834DA704 |
| 732 | `XamShowMessageBoxUIEx` | func | 0x820007C8 | 0x834DA844 |
| 741 | `XamShowCustomMessageComposeUI` | func | 0x820007B0 | 0x834DA7E4 |
| 742 | `_XamShowCustomPlayerListUI__YAKKKPB_W0PBEKPBUXPLAYERLIST_USER__GPBUXPLAYERLIST_BUTTON__3PAUXPLAYERLIST_RESULT__PAU_XOVERLAPPED___Z` | func | 0x820007B4 | 0x834DA7F4 |
| 750 | `XamUserCreateAchievementEnumerator` | func | 0x820007AC | 0x834DA7D4 |
| 752 | `XamWriteGamerTile` | func | 0x820007A8 | 0x834DA7C4 |
| 757 | `XamReadTileToTexture` | func | 0x820007A4 | 0x834DA7B4 |
| 759 | `XamUserCreateStatsEnumerator` | func | 0x820007A0 | 0x834DA7A4 |
| 780 | `XamVoiceCreate` | func | 0x82000600 | 0x834DB314 |
| 781 | `XamVoiceHeadsetPresent` | func | 0x8200060C | 0x834DB2D4 |
| 782 | `XamVoiceSubmitPacket` | func | 0x82000618 | 0x834DB304 |
| 783 | `XamVoiceClose` | func | 0x82000608 | 0x834DB2E4 |
| 790 | `XamSessionCreateHandle` | func | 0x82000700 | 0x834DA524 |
| 791 | `XamSessionRefObjByHandle` | func | 0x820006FC | 0x834DA514 |
| 971 | `XGetAVPack` | func | 0x820007CC | 0x834DA854 |
| 972 | `XGetGameRegion` | func | 0x82000634 | 0x834DA1F4 |
| 977 | `XGetVideoMode` | func | 0x82000620 | 0x834DA1A4 |
| 1175 | `XamVoiceIsActiveProcess` | func | 0x82000614 | 0x834DB2B4 |

## Non-import call targets (ReXGlue unresolved)

These addresses are **not** in the import table. Basefile bytes (load 0x82000000): vtable thunks, short stubs, branch stubs, mid-function fragments in `.text`.

| Address | First word (BE) | Class |
|---|---|---|
| 0x82E4D8D8 | 0x4BFFFA18 | `b` into other code |
| 0x82FB2774 | 0x38600000 | stub `li r3,0; blr` |
| 0x82FB277C | 0xC00B001C | stub float copy |
| 0x82FBFBC0 | 0x81630000 | vtable thunk +0x28 |
| 0x82FBFBC8 | 0x7D6903A6 | tail of prior thunk + next prologue |
| 0x82FBFC38 | 0x81630000 | vtable thunk +0x38 |
| 0x82FBFCB8 | 0x3B9C0001 | mid-function loop |
| 0x82FBFCE8 | 0x81630000 | vtable thunk +0x44 |
| 0x82FBFCF8 | 0x81630000 | vtable thunk +0x48 |
| 0x82FBFCFC | 0x816B0048 | mid-thunk |
| 0x82FBFD08 | 0x81630000 | vtable thunk +0x4C |
| 0x82FBFD18 | 0x81630000 | vtable thunk +0x50 |
| 0x82FBFD28 | 0x81630000 | vtable thunk +0x58 |
| 0x82FBFDA8 | 0x9163004C | mid-function stores |
| 0x82FCB148 | 0x2B050000 | stub return 0x25 |
| 0x82FD097C | 0x38600000 | stub `li r3,0; blr` |
| 0x82FD0A94 | 0x38600000 | stub `li r3,0; blr` |
| 0x832C3910 | 0x3D60820D | FP load |
| 0x832D9690 | 0x81030000 | `lwz` chain |
| 0x82B90068 | 0x4BFFC4E0 | branch stub |
| 0x82E514C8 | 0x4BFE7940 | branch stub |

### Manifest

Declare the non-import call targets in `tools/config/ocho_kart_manifest.toml` under `[entrypoint.functions]`. v0.10.0 ignores a top-level `[functions]` table (`ManifestConfig::Load` only calls `LoadFromTable` on `[entrypoint]`). Do not name those entries `imp_xboxkrnl_*` — kernel imports are resolved by ExportResolver from the IAT above.

### Shims

Phase 5 implements the subset this title reaches at runtime. Priority list: `docs/kernel-shims.md`.

