# LLDB Python helper: print the guest path and call stack of every file open,
# highlighting audio/video. Loaded by tools/trace-opens.ps1.
import sys

import lldb

# Guest memory arena is mapped at host base 0x100000000, so guest G -> host base+G.
GUEST_BASE = 0x100000000
# X_OBJECT_ATTRIBUTES: +0 root_directory, +4 name_ptr (PANSI_STRING)
# X_ANSI_STRING:       +0 length (u16), +2 max (u16), +4 pointer (u32)
KEYS = (".fsb", "fmod", ".fev", ".bik", ".xxx", "movies", "sonido", "audio", "sound")
_state = {"n": 0, "max": 300, "every": False}


def _read(proc, addr, size, err):
    return proc.ReadMemory(addr, size, err)


def _guest_string(proc, obj_guest):
    err = lldb.SBError()
    name_ptr = proc.ReadUnsignedFromMemory(GUEST_BASE + obj_guest + 4, 4, err)
    if not err.Success() or not name_ptr:
        return ""
    sp = GUEST_BASE + name_ptr
    length = proc.ReadUnsignedFromMemory(sp, 2, err)
    sptr = proc.ReadUnsignedFromMemory(sp + 4, 4, err)
    if not err.Success() or not (0 < length < 1024) or not sptr:
        return ""
    data = proc.ReadMemory(GUEST_BASE + sptr, length, err)
    if not err.Success() or not data:
        return ""
    return data.decode("latin-1", "replace").rstrip("\x00")


def on_open(frame, bp_loc, internal_dict):
    st = _state
    st["n"] += 1
    proc = frame.GetThread().GetProcess()
    path = ""
    try:
        # x64 arg3 (object_attrs) is r8; if it was clobbered, fall back to the variable.
        obj = frame.FindRegister("r8").GetValueAsUnsigned()
        var = frame.FindVariable("object_attrs")
        if (not obj) and var and var.IsValid():
            obj = var.GetValueAsUnsigned()
        path = _guest_string(proc, obj & 0xFFFFFFFF)
    except Exception as exc:  # noqa: BLE001
        path = "<error: %s>" % exc

    low = path.lower()
    if st["every"] or any(k in low for k in KEYS):
        print("[open %d] %s" % (st["n"], path))
        f = frame
        depth = 0
        while f.IsValid() and depth < 20:
            name = f.GetFunctionName() or "?"
            print("    #%d %s" % (depth, name))
            f = f.GetParentFrame()
            depth += 1
        sys.stdout.flush()

    if st["n"] >= st["max"]:
        return True  # stop at the breakpoint so the command file can quit
    return False  # continue