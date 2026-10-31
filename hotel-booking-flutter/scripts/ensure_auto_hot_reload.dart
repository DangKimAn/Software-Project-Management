import 'dart:io';

/// Ensures `scripts/auto_hot_reload.ps1` is running in the background.
/// Invoked automatically by Android Studio's `Before launch` step on `main.dart`.
Future<void> main() async {
  if (!Platform.isWindows) {
    return;
  }

  final File scriptFile = File.fromUri(Platform.script);
  final Directory projectRoot = scriptFile.parent.parent;
  final String sep = Platform.pathSeparator;
  final String psScriptPath =
      '${projectRoot.path}${sep}scripts${sep}auto_hot_reload.ps1';
  final File pidFile = File(
    '${projectRoot.path}$sep.dart_tool${sep}auto_hot_reload.pid',
  );

  if (!File(psScriptPath).existsSync()) {
    stderr.writeln('auto_hot_reload.ps1 not found at $psScriptPath');
    return;
  }

  // Fast-path (~30ms): check if watcher PowerShell PID is already alive.
  if (pidFile.existsSync()) {
    final int? existingPid = int.tryParse(pidFile.readAsStringSync().trim());
    if (existingPid != null && existingPid > 0) {
      final ProcessResult check = await Process.run(
        'tasklist.exe',
        <String>['/FI', 'PID eq $existingPid', '/FO', 'CSV', '/NH'],
      );
      final String out = '${check.stdout}'.toLowerCase();
      if (out.contains('powershell') && out.contains('"$existingPid"')) {
        stdout.writeln(
          'Auto Hot Reload watcher is already running (PID $existingPid).',
        );
        return;
      }
    }
  }

  // Cold-start (~700ms): spawn hidden background watcher via Start-Process.
  final ProcessResult result = await Process.run(
    'powershell.exe',
    <String>[
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      psScriptPath,
      '-EnsureRunning',
    ],
    workingDirectory: projectRoot.path,
  );

  final String out = '${result.stdout}'.trim();
  if (out.isNotEmpty) {
    stdout.writeln(out);
  }
}
