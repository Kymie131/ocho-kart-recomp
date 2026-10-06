# Launch the recompiled game under LLDB with audio breakpoints preloaded.
#
# The recompiled guest functions are real host functions, so the exe PDB
# resolves them by name (sub_XXXX). Breakpoints on the runtime DLL (e.g.
# NtCreateFile_entry) resolve once the DLL loads (pending breakpoints default).
#
# Usage:
#   powershell -File tools/debug-audio.ps1
#   powershell -File tools/debug-audio.ps1 -Dump "D:/Games/EL CHAVO KART"
#
# At the (lldb) prompt:  run   -> stops at the first breakpoint.
# Then: bt / register read / thread list / image lookup -n sub_XXXX / c.

param(
    # Junction without spaces (the real dump has "EL CHAVO KART"); avoids
    # argument-quoting trouble across PowerShell -> lldb. Created with:
    #   New-Item -ItemType Junction -Path C:\Users\israe\ocho_dump -Target "<dump>"
    [string]$Dump = "C:/Users/israe/ocho_dump",
    [string]$ProjectDir = "$env:ProgramData\rextools\proj-ocho-kart",
    [string]$Lldb = "C:\Program Files\LLVM\bin\lldb.exe",
    [string]$CmdFile
)

$ErrorActionPreference = 'Stop'
$exe = Join-Path $ProjectDir 'out\build\win-amd64\ocho_kart.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "not built yet: $exe" }
if (-not (Test-Path -LiteralPath $Lldb)) { throw "lldb not found: $Lldb" }
if (-not $CmdFile) { $CmdFile = Join-Path $PSScriptRoot 'debug-audio\audio.lldb' }

$env:REX_LAUNCHER_SKIP = 'true'

# PowerShell 5.1 + LLDB mangle `-o` arguments that contain embedded quotes or
# spaces. The command file lives under the repo path ("Recomvo Kart") which has a
# space, so source a copy from a space-free location instead.
$CmdSafe = Join-Path $env:TEMP 'ocho_audio.lldb'
Copy-Item -LiteralPath $CmdFile -Destination $CmdSafe -Force

Write-Output "exe:      $exe"
Write-Output "dump:     $Dump"
Write-Output "cmd file: $CmdFile"
Write-Output "At the (lldb) prompt type:  run"

# No embedded quotes and no spaces in any -o payload (the dump path is the
# space-free junction). `settings set --` stops lldb from parsing the leading
# --game_data_root etc. as options to `settings set`.
& $Lldb $exe `
    -o "settings set target.env-vars REX_LAUNCHER_SKIP=true" `
    -o "settings set -- target.run-args --game_data_root $Dump --gpu_plugin xenos --user_language 5" `
    -o "command source $CmdSafe"
