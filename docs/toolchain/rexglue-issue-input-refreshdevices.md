# InputSystem::RefreshDevices mutates shared state without holding a lock across the entry point

## Summary

`rex::input::InputSystem` rebuilds `devices_` and `device_owners_` in `RefreshDevices()` while the
XInput entry points (`GetState`, `SetState`, `GetCapabilities`, `GetKeystroke`) run on guest
threads. These methods previously took no lock around the whole body: the lock was taken and
released inside `RefreshDevices`, `DriverForDevice` and `DeviceInfoFor`, leaving a window between
`RefreshDevices()` returning and the per-device `DriverForDevice()` loop. Another guest thread can
rebuild the vectors in that window, so `DriverForDevice`/`DeviceInfoFor` can hand out or free a
`DeviceInfo` whose storage was already replaced. This corrupts the host heap.

## Reproduction

Windows 10.0.26100, RelWithDebInfo build. Full page heap traps the corruption:

```
cdb -o -cf cmds.txt ocho_kart.exe --game_data_root <dump> --gpu_plugin xenos
# cmds.txt:
#   .logopen cdb.log
#   !gflag +hpa
#   sxe -c "g" av
#   g
#   !analyze -v
#   .ecxr
#   kv
```

## Crash 1 - heap trap on free (XamInputSetState)

```
HEAP[ocho_kart.exe]: Invalid address specified to RtlFreeHeap( 00000268530F0000, 00000268F3948C50 )
std::_Destroy_range<std::allocator<rex::input::DeviceInfo>>+0x25
 -> rex::input::InputSystem::RefreshDevices+0x641
 -> rex::input::InputSystem::SetState+0xfd
 -> rex::kernel::xam::XamInputSetState_entry
 -> _imp__XamInputSetState
```

## Crash 2 - access violation (XamInputGetState)

```
rexruntimerd!std::_Destroy_range<std::allocator<rex::input::DeviceInfo>>+0x61
 -> rex::input::InputSystem::GetState+0x109
 -> rex::kernel::xam::XamInputGetState_entry
 -> _imp__XamInputGetState
```

In crash 2 the fault is `movq -0x8(%rcx), %r8` with `rcx = 0`, reading the pointer of a
`DeviceInfo` string whose data pointer is null.

## Fix

Take a single recursive mutex once at the start of each public entry point
(`GetState`, `SetState`, `GetCapabilities`, `GetKeystroke`), plus `Shutdown` and
`SetDeviceAssignment`, and hold it for the whole body. `RefreshDevices`, `DriverForDevice` and
`DeviceInfoFor` must not lock; they run with the caller's lock held. Recursive is required because
an entry point holds the lock while calling those helpers.

Diff is attached as a patch in this project; the important part:

```cpp
// input_system.h
mutable std::recursive_mutex devices_mutex_;  // guards devices_ and device_owners_

// input_system.cpp
X_RESULT InputSystem::GetState(...) {
  std::lock_guard<std::recursive_mutex> lock(devices_mutex_);
  ...  // whole body, including RefreshDevices() and DriverForDevice()
}
void InputSystem::RefreshDevices() {
  // Caller holds devices_mutex_.
}
```

## Evidence after the fix

Two consecutive long runs (150s and 200s) with the rebuilt runtime survived with no exit, no
FATAL, and no crash in the Windows Error Reporting log. Before the lock-per-entry-point design a
run died at about 71s with the access violation above.
