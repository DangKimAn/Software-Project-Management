# Auto Hot Reload Watcher for Flutter (Android Studio / Antigravity / VS Code)
# Watches lib/**/*.dart for changes and automatically triggers Hot Reload ('r')
# on any running `flutter run` process, while keeping `adb reverse tcp:7000 tcp:7000` active.

param([int]$FlutterProcessId = 0, [int]$WebPort = 0)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$libPath = Join-Path $projectRoot "lib"
$adbExe = Join-Path $env:LOCALAPPDATA "Android\sdk\platform-tools\adb.exe"

$code = @"
using System;
using System.Runtime.InteropServices;

public class FlutterConsoleInjector {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool FreeConsole();

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool AttachConsole(uint dwProcessId);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr CreateFile(
        string lpFileName, uint dwDesiredAccess, uint dwShareMode,
        IntPtr lpSecurityAttributes, uint dwCreationDisposition,
        uint dwFlagsAndAttributes, IntPtr hTemplateFile);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hObject);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool WriteConsoleInput(
        IntPtr hConsoleInput, INPUT_RECORD[] lpBuffer, uint nLength, out uint lpNumberOfEventsWritten);

    [StructLayout(LayoutKind.Explicit)]
    public struct INPUT_RECORD {
        [FieldOffset(0)] public ushort EventType;
        [FieldOffset(4)] public KEY_EVENT_RECORD KeyEvent;
    }

    [StructLayout(LayoutKind.Explicit, CharSet = CharSet.Unicode)]
    public struct KEY_EVENT_RECORD {
        [FieldOffset(0)] public int bKeyDown;
        [FieldOffset(4)] public ushort wRepeatCount;
        [FieldOffset(6)] public ushort wVirtualKeyCode;
        [FieldOffset(8)] public ushort wVirtualScanCode;
        [FieldOffset(10)] public char UnicodeChar;
        [FieldOffset(12)] public uint dwControlKeyState;
    }

    public static bool SendKey(uint pid, char ch) {
        FreeConsole();
        if (!AttachConsole(pid)) return false;
        IntPtr hIn = CreateFile("CONIN$", 0x80000000U | 0x40000000U, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
        if (hIn == IntPtr.Zero || hIn == (IntPtr)(-1)) {
            FreeConsole();
            return false;
        }
        INPUT_RECORD[] recs = new INPUT_RECORD[2];
        recs[0].EventType = 1;
        recs[0].KeyEvent.bKeyDown = 1;
        recs[0].KeyEvent.wRepeatCount = 1;
        recs[0].KeyEvent.UnicodeChar = ch;
        recs[1].EventType = 1;
        recs[1].KeyEvent.bKeyDown = 0;
        recs[1].KeyEvent.wRepeatCount = 1;
        recs[1].KeyEvent.UnicodeChar = ch;
        uint written;
        bool ok = WriteConsoleInput(hIn, recs, 2, out written);
        CloseHandle(hIn);
        FreeConsole();
        return ok;
    }
}
"@

Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue

function Invoke-FlutterHotReload {
    if (Test-Path $adbExe) {
        $devs = & $adbExe devices | Select-String '\tdevice$' | ForEach-Object { ($_ -split '\t')[0].Trim() }
        foreach ($d in $devs) {
            if ($d) { & $adbExe -s $d reverse tcp:7000 tcp:7000 | Out-Null }
        }
    }
    $targetProcessId = $FlutterProcessId
    if ($WebPort -gt 0) {
        $listener = Get-NetTCPConnection -State Listen -LocalPort $WebPort -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $listener) { return }
        $targetProcessId = $listener.OwningProcess
    }
    $procs = Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '^dart(vm)?\.exe$' -and $_.CommandLine -match 'flutter_tools\.snapshot.*run' -and
        ($targetProcessId -eq 0 -or $_.ProcessId -eq $targetProcessId)
    }
    foreach ($p in $procs) {
        if ([FlutterConsoleInjector]::SendKey([uint32]$p.ProcessId, [char]'r')) {
            Write-Output "$(Get-Date -Format s) Hot reload requested for Flutter PID $($p.ProcessId)."
        } else {
            Write-Warning "Cannot send hot reload to Flutter PID $($p.ProcessId). Start Flutter in an interactive terminal."
        }
    }
}

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $libPath
$watcher.Filter = "*.dart"
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, LastWrite, Size'
$watcher.EnableRaisingEvents = $true

$lastReload = [DateTime]::MinValue
Write-Output "Watching $libPath for Dart changes."
Invoke-FlutterHotReload

while ($true) {
    $result = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 2000)
    if (-not $result.TimedOut) {
        # Debounce rapid multi-file saves (wait 350ms for editor writes to settle)
        Start-Sleep -Milliseconds 350
        while (-not ($watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 100)).TimedOut) {}
        $now = [DateTime]::UtcNow
        if (($now - $lastReload).TotalMilliseconds -ge 500) {
            $lastReload = $now
            Invoke-FlutterHotReload
        }
    }
}

