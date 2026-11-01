# Auto Hot Reload Watcher for Flutter (Android Studio / Antigravity / VS Code)
# Watches lib/**/*.dart for changes and automatically triggers Hot Reload:
# 1. Primarily via Dart VM Service WebSocket (`reloadSources` registered by Flutter Tools),
#    which works with Android Studio Run/Debug (`--machine` mode), VS Code, and CLI.
# 2. Fallback via console keystroke injection ('r') for interactive terminal sessions.

param(
    [int]$FlutterProcessId = 0,
    [int]$WebPort = 0,
    [switch]$EnsureRunning
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$libPath = Join-Path $projectRoot "lib"
$dartToolDir = Join-Path $projectRoot ".dart_tool"
$pidFile = Join-Path $dartToolDir "auto_hot_reload.pid"
$logFile = Join-Path $dartToolDir "auto_hot_reload.log"
$vmServiceFile = Join-Path $dartToolDir "vmservice_uri.txt"
$adbExe = Join-Path $env:LOCALAPPDATA "Android\sdk\platform-tools\adb.exe"

if (-not (Test-Path $dartToolDir)) {
    New-Item -ItemType Directory -Path $dartToolDir -Force | Out-Null
}

function Test-WatcherProcess([int]$ProcessIdToCheck) {
    if ($ProcessIdToCheck -le 0) { return $false }
    $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessIdToCheck" -ErrorAction SilentlyContinue
    if (-not $proc) { return $false }
    return ($proc.CommandLine -match 'auto_hot_reload\.ps1')
}

if ($EnsureRunning) {
    if (Test-Path $pidFile) {
        $existingRaw = (Get-Content $pidFile -ErrorAction SilentlyContinue | Select-Object -First 1)
        $existingPid = 0
        if ([int]::TryParse("$existingRaw".Trim(), [ref]$existingPid) -and (Test-WatcherProcess $existingPid)) {
            Write-Output "Auto Hot Reload watcher is already running (PID $existingPid)."
            exit 0
        }
    }
    $started = Start-Process -FilePath "powershell.exe" `
        -ArgumentList @("-NoProfile", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"") `
        -WorkingDirectory $projectRoot `
        -WindowStyle Hidden `
        -PassThru
    Set-Content -Path $pidFile -Value "$($started.Id)" -Encoding ascii -Force
    Write-Output "Started Auto Hot Reload watcher in background (PID $($started.Id))."
    exit 0
}

# Stop any stale watcher instance before registering current PID
if (Test-Path $pidFile) {
    $oldRaw = (Get-Content $pidFile -ErrorAction SilentlyContinue | Select-Object -First 1)
    $oldPid = 0
    if ([int]::TryParse("$oldRaw".Trim(), [ref]$oldPid) -and $oldPid -ne $PID -and (Test-WatcherProcess $oldPid)) {
        Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue
    }
}
Set-Content -Path $pidFile -Value "$PID" -Encoding ascii -Force
Set-Content -Path $logFile -Value "[$(Get-Date -Format s)] Watcher started (PID $PID), watching $libPath" -Encoding utf8 -Force

function Write-WatcherLog([string]$Message) {
    $line = "[$(Get-Date -Format s)] $Message"
    Write-Output $line
    Add-Content -Path $logFile -Value $line -Encoding utf8 -ErrorAction SilentlyContinue
}

$code = @"
using System;
using System.IO;
using System.Net.WebSockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;

public class FlutterVmServiceReloader {
    private static async Task SendTextAsync(ClientWebSocket ws, string json, CancellationToken ct) {
        byte[] bytes = Encoding.UTF8.GetBytes(json);
        await ws.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, ct).ConfigureAwait(false);
    }

    private static async Task<string> ReceiveTextAsync(ClientWebSocket ws, CancellationToken ct) {
        byte[] buffer = new byte[8192];
        using (var ms = new MemoryStream()) {
            while (true) {
                var result = await ws.ReceiveAsync(new ArraySegment<byte>(buffer), ct).ConfigureAwait(false);
                if (result.MessageType == WebSocketMessageType.Close) {
                    return null;
                }
                ms.Write(buffer, 0, result.Count);
                if (result.EndOfMessage) {
                    return Encoding.UTF8.GetString(ms.ToArray());
                }
            }
        }
    }

    private static string NormalizeWsUri(string rawUri) {
        if (string.IsNullOrWhiteSpace(rawUri)) return null;
        string u = rawUri.Trim();
        if (u.StartsWith("http://", StringComparison.OrdinalIgnoreCase)) {
            u = "ws://" + u.Substring(7);
        } else if (u.StartsWith("https://", StringComparison.OrdinalIgnoreCase)) {
            u = "wss://" + u.Substring(8);
        }
        if (!u.EndsWith("/ws", StringComparison.OrdinalIgnoreCase)) {
            u = u.TrimEnd('/') + "/ws";
        }
        return u;
    }

    private static string ExtractIsolateId(string vmJson) {
        var isolatesMatch = Regex.Match(vmJson, "(?:^|[,{])\\s*\"isolates\"\\s*:\\s*\\[(.*?)\\]", RegexOptions.Singleline);
        if (!isolatesMatch.Success) return null;
        string isolatesBody = isolatesMatch.Groups[1].Value;

        // Prefer isolate named "main"
        var objMatches = Regex.Matches(isolatesBody, "\\{[^{}]*\\}");
        foreach (Match m in objMatches) {
            string obj = m.Value;
            if (Regex.IsMatch(obj, "\"name\"\\s*:\\s*\"main\"")) {
                var idMatch = Regex.Match(obj, "\"id\"\\s*:\\s*\"([^\"]+)\"");
                if (idMatch.Success) return idMatch.Groups[1].Value;
            }
        }
        var firstId = Regex.Match(isolatesBody, "\"id\"\\s*:\\s*\"([^\"]+)\"");
        return firstId.Success ? firstId.Groups[1].Value : null;
    }

    public static string Reload(string rawUri, int timeoutMs) {
        string wsUri = NormalizeWsUri(rawUri);
        if (wsUri == null) return "DISCONNECTED:Empty URI";
        try {
            return ReloadAsync(wsUri, timeoutMs).GetAwaiter().GetResult();
        } catch (Exception ex) {
            var baseEx = ex.GetBaseException();
            if (baseEx is WebSocketException || baseEx is System.Net.Sockets.SocketException) {
                return "DISCONNECTED:" + baseEx.Message;
            }
            return "ERROR:" + baseEx.Message;
        }
    }

    private static async Task<string> ReloadAsync(string wsUri, int timeoutMs) {
        using (var cts = new CancellationTokenSource(timeoutMs))
        using (var ws = new ClientWebSocket()) {
            using (var connectCts = CancellationTokenSource.CreateLinkedTokenSource(cts.Token)) {
                connectCts.CancelAfter(Math.Min(2000, timeoutMs));
                try {
                    await ws.ConnectAsync(new Uri(wsUri), connectCts.Token).ConfigureAwait(false);
                } catch (Exception ex) {
                    return "DISCONNECTED:" + ex.GetBaseException().Message;
                }
            }

            await SendTextAsync(ws, "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"streamListen\",\"params\":{\"streamId\":\"Service\"}}", cts.Token).ConfigureAwait(false);
            await SendTextAsync(ws, "{\"jsonrpc\":\"2.0\",\"id\":\"2\",\"method\":\"getVM\",\"params\":{}}", cts.Token).ConfigureAwait(false);

            string reloadMethod = null;
            string isolateId = null;
            bool gotStreamAck = false;
            bool gotVm = false;

            while (!(gotStreamAck && gotVm)) {
                string msg = await ReceiveTextAsync(ws, cts.Token).ConfigureAwait(false);
                if (msg == null) return "DISCONNECTED:Socket closed during discovery";

                if (msg.Contains("\"ServiceRegistered\"") && Regex.IsMatch(msg, "\"service\"\\s*:\\s*\"reloadSources\"")) {
                    var eventMatch = Regex.Match(msg, "\"event\"\\s*:\\s*\\{([^{}]*)\\}");
                    string scope = eventMatch.Success ? eventMatch.Groups[1].Value : msg;
                    var methodMatch = Regex.Match(scope, "\"method\"\\s*:\\s*\"([^\"]+)\"");
                    if (methodMatch.Success) {
                        reloadMethod = methodMatch.Groups[1].Value;
                    }
                }
                if (Regex.IsMatch(msg, "\"id\"\\s*:\\s*\"1\"")) {
                    gotStreamAck = true;
                }
                if (Regex.IsMatch(msg, "\"id\"\\s*:\\s*\"2\"")) {
                    gotVm = true;
                    isolateId = ExtractIsolateId(msg);
                }
            }

            if (string.IsNullOrEmpty(isolateId)) {
                return "NO_ISOLATE:No active Dart isolate found";
            }
            if (string.IsNullOrEmpty(reloadMethod)) {
                reloadMethod = "reloadSources";
            }

            string reloadReq = "{\"jsonrpc\":\"2.0\",\"id\":\"3\",\"method\":\"" + reloadMethod + "\",\"params\":{\"isolateId\":\"" + isolateId + "\",\"force\":false,\"pause\":false}}";
            await SendTextAsync(ws, reloadReq, cts.Token).ConfigureAwait(false);

            while (true) {
                string msg = await ReceiveTextAsync(ws, cts.Token).ConfigureAwait(false);
                if (msg == null) return "DISCONNECTED:Socket closed during reload";
                if (Regex.IsMatch(msg, "\"id\"\\s*:\\s*\"3\"")) {
                    try {
                        await ws.CloseAsync(WebSocketCloseStatus.NormalClosure, "done", CancellationToken.None).ConfigureAwait(false);
                    } catch { }
                    if (Regex.IsMatch(msg, "\"error\"\\s*:")) {
                        return "ERROR:" + msg;
                    }
                    return "OK";
                }
            }
        }
    }
}

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

Add-Type -TypeDefinition $code -ReferencedAssemblies "System.dll"

$script:activeVmServices = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$script:lastAdbReverse = [DateTime]::MinValue

function Sync-VmServiceUris {
    $uriFiles = Get-ChildItem -Path $dartToolDir -Filter "vmservice_uri*.txt" -File -ErrorAction SilentlyContinue
    foreach ($f in $uriFiles) {
        $raw = Get-Content $f.FullName -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            $trimmed = $raw.Trim()
            if ($script:activeVmServices.Add($trimmed)) {
                Write-WatcherLog "Registered Flutter VM Service: $trimmed"
            }
        }
    }
}

function Ensure-AdbReverse {
    $now = [DateTime]::UtcNow
    if (($now - $script:lastAdbReverse).TotalSeconds -lt 15) { return }
    $script:lastAdbReverse = $now
    if (Test-Path $adbExe) {
        $devs = & $adbExe devices 2>$null | Select-String '\tdevice$' | ForEach-Object { ($_ -split '\t')[0].Trim() }
        foreach ($d in $devs) {
            if ($d) { & $adbExe -s $d reverse tcp:7000 tcp:7000 2>$null | Out-Null }
        }
    }
}

function Invoke-FlutterHotReload {
    Ensure-AdbReverse
    Sync-VmServiceUris

    $reloadedViaVm = $false
    if ($script:activeVmServices.Count -gt 0) {
        $urisSnapshot = @($script:activeVmServices)
        foreach ($uri in $urisSnapshot) {
            $res = [FlutterVmServiceReloader]::Reload($uri, 10000)
            if ($res -eq "OK") {
                $reloadedViaVm = $true
                Write-WatcherLog "Hot reload succeeded via VM Service ($uri)."
            } elseif ($res -like "DISCONNECTED:*") {
                [void]$script:activeVmServices.Remove($uri)
                Write-WatcherLog "Removed disconnected VM Service ($uri)."
            } else {
                Write-WatcherLog "VM Service reload note ($uri): $res"
            }
        }
    }

    if ($reloadedViaVm) { return }

    # Fallback: Interactive console keystroke injection ('r')
    $targetProcessId = $FlutterProcessId
    if ($WebPort -gt 0) {
        $listener = Get-NetTCPConnection -State Listen -LocalPort $WebPort -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $listener) { return }
        $targetProcessId = $listener.OwningProcess
    }
    $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match '^dart(vm)?\.exe$' -and $_.CommandLine -match 'flutter_tools\.snapshot.*run' -and
        $_.CommandLine -notmatch '--machine' -and
        ($targetProcessId -eq 0 -or $_.ProcessId -eq $targetProcessId)
    }
    foreach ($p in $procs) {
        if ([FlutterConsoleInjector]::SendKey([uint32]$p.ProcessId, [char]'r')) {
            Write-WatcherLog "Hot reload requested via console for Flutter PID $($p.ProcessId)."
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
Sync-VmServiceUris
Ensure-AdbReverse
Write-WatcherLog "Ready. Any .dart edit in any editor will trigger instant Hot Reload."

try {
    while ($true) {
        $result = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 1500)
        if (-not $result.TimedOut) {
            # Short debounce (180ms) so multi-file saves / auto-format settle cleanly
            Start-Sleep -Milliseconds 180
            while (-not ($watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 80)).TimedOut) {}
            $now = [DateTime]::UtcNow
            if (($now - $lastReload).TotalMilliseconds -ge 300) {
                $lastReload = $now
                Invoke-FlutterHotReload
            }
        } else {
            Sync-VmServiceUris
        }
    }
} finally {
    $watcher.Dispose()
}
