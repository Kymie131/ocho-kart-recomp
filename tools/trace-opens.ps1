# Trace every guest file open with its call stack, highlighting audio/video.
#
# Runs the game under LLDB with a Python breakpoint on NtCreateFile_entry that
# prints the requested path and the recompiled guest backtrace, then continues.
# Output goes to a log file so you do not have to copy it by hand.
#
# This answers "what does the title actually ask the filesystem for, and from
# where" without stepping manually.
#
# Usage:
#   powershell -File tools/trace-opens.ps1
#   powershell -File tools/trace-opens.ps1 -Max 600 -Every
#   powershell -File tools/trace-opens.ps1 -TimeoutSec 240 -Out C:\temp\opens.log
#
# -Every prints every open; without it, only paths matching audio/video/.xxx.
# It stops after -Max opens (LLDB quits) or after -TimeoutSec, and always kills
# the debuggee so no stray game/LLDB keeps holding the GPU.

param(
    [string]$Dump = "C:/Users/israe/ocho_dump",
    [string]$ProjectDir = "$env:ProgramData\rextools\proj-ocho-kart",
    [string]$Lldb = "C:\Program Files\LLVM\bin\lldb.exe",
    [string]$Out = "",
    [int]$Max = 300,
    [int]$TimeoutSec = 300,
    [switch]$Every
)

$ErrorActionPreference = 'Stop'

$exe = Join-Path $ProjectDir 'out\build\win-amd64\ocho_kart.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "not built yet: $exe" }
if (-not (Test-Path -LiteralPath $Lldb)) { throw "lldb not found: $Lldb" }
if (-not $Out) { $Out = Join-Path $env:TEMP 'ocho-opens.log' }

# Make sure nothing else is running (two instances fight over D3D12).
Get-Process -Name ocho_kart,lldb,lldb-server -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue

# PowerShell 5.1 + LLDB mangle -o arguments with quotes/spaces; the repo path has
# a space, so stage both files in a space-free temp folder.
$py = Join-Path $env:TEMP 'ocho_opens.py'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'debug-audio\opens.py') -Destination $py -Force

$everyFlag = if ($Every) { 1 } else { 0 }
$cmd = Join-Path $env:TEMP 'ocho_trace.lldb'
$lines = @(
    'settings set target.env-vars REX_LAUNCHER_SKIP=true',
    "settings set -- target.run-args --game_data_root $Dump --gpu_plugin xenos --user_language 5",
    "command script import $py",
    "script import ocho_opens; ocho_opens._state['max']=$Max; ocho_opens._state['every']=$everyFlag",
    'breakpoint set -n NtCreateFile_entry',
    'breakpoint command add -F ocho_opens.on_open 1',
    'run',
    'quit'
)
Set-Content -LiteralPath $cmd -Value $lines -Encoding ASCII

Write-Output "exe: $exe"
Write-Output "log: $Out"
Write-Output "max opens: $Max (every=$([bool]$Every)); timeout: ${TimeoutSec}s"

Remove-Item -LiteralPath $Out -Force -ErrorAction SilentlyContinue
$proc = Start-Process -FilePath $Lldb `
    -ArgumentList @('-b', '-o', ('"command source ' + $cmd + '"'), $exe) `
    -RedirectStandardOutput $Out -RedirectStandardError "$Out.err" -NoNewWindow -PassThru
try {
    if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
        Write-Output "timeout; stopping debuggee"
    }
} finally {
    Get-Process -Name ocho_kart,lldb,lldb-server -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
}
Write-Output "done. Inspect: $Out"
Get-Content -LiteralPath $Out -Tail 60 -ErrorAction SilentlyContinue
