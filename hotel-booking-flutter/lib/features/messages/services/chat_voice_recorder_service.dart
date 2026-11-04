import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordedVoiceResult {
  final Uint8List bytes;
  final String filename;
  final String contentType;
  final int durationSeconds;

  const RecordedVoiceResult({
    required this.bytes,
    required this.filename,
    required this.contentType,
    required this.durationSeconds,
  });
}

/// Cross-platform real microphone recorder (Web, Android, iOS, Desktop)
class ChatVoiceRecorderService {
  AudioRecorder? _recorder;
  AudioEncoder _activeEncoder = AudioEncoder.wav;
  bool _isRecording = false;
  DateTime? _recordStartTime;

  bool get isRecording => _isRecording;

  AudioRecorder _getRecorder() {
    return _recorder ??= AudioRecorder();
  }

  /// Checks and requests microphone permission
  Future<bool> hasPermission() async {
    try {
      final recorder = _getRecorder();
      return await recorder.hasPermission();
    } catch (e) {
      debugPrint('[ChatVoiceRecorderService] hasPermission error: $e');
      return false;
    }
  }

  /// Starts recording real microphone audio
  Future<bool> start() async {
    try {
      final recorder = _getRecorder();
      final hasPerm = await recorder.hasPermission();
      if (!hasPerm) {
        debugPrint('[ChatVoiceRecorderService] Microphone permission denied');
        return false;
      }

      if (_isRecording) {
        try {
          await recorder.cancel();
        } catch (_) {}
        _isRecording = false;
      }

      // Choose supported encoder:
      // On Web, prefer opus (MediaRecorder -> audio/webm) as it runs directly in browser
      // without needing external AudioWorklet js modules.
      if (kIsWeb) {
        if (await recorder.isEncoderSupported(AudioEncoder.opus)) {
          _activeEncoder = AudioEncoder.opus;
        } else if (await recorder.isEncoderSupported(AudioEncoder.wav)) {
          _activeEncoder = AudioEncoder.wav;
        } else {
          _activeEncoder = AudioEncoder.aacLc;
        }
      } else {
        if (await recorder.isEncoderSupported(AudioEncoder.aacLc)) {
          _activeEncoder = AudioEncoder.aacLc;
        } else if (await recorder.isEncoderSupported(AudioEncoder.wav)) {
          _activeEncoder = AudioEncoder.wav;
        } else {
          _activeEncoder = AudioEncoder.aacLc;
        }
      }

      String targetPath = '';
      if (!kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        final ext = _activeEncoder == AudioEncoder.wav
            ? 'wav'
            : (_activeEncoder == AudioEncoder.opus ? 'opus' : 'm4a');
        targetPath =
            '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.$ext';
      }

      debugPrint('[ChatVoiceRecorderService] Starting recorder: encoder=$_activeEncoder, targetPath=$targetPath');
      await recorder.start(
        RecordConfig(
          encoder: _activeEncoder,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: targetPath,
      );

      _isRecording = true;
      _recordStartTime = DateTime.now();
      debugPrint('[ChatVoiceRecorderService] Recording started successfully');
      return true;
    } catch (e, stack) {
      debugPrint('[ChatVoiceRecorderService] start error: $e\n$stack');
      _isRecording = false;
      return false;
    }
  }

  /// Stops recording and extracts real recorded audio bytes
  Future<RecordedVoiceResult?> stop() async {
    if (!_isRecording) {
      debugPrint('[ChatVoiceRecorderService] stop called but _isRecording is false');
      return null;
    }
    _isRecording = false;

    final durationSec = _recordStartTime != null
        ? DateTime.now().difference(_recordStartTime!).inSeconds
        : 1;

    try {
      final recorder = _getRecorder();
      final path = await recorder.stop();
      debugPrint('[ChatVoiceRecorderService] recorder.stop() returned: $path');
      if (path == null || path.isEmpty) {
        debugPrint('[ChatVoiceRecorderService] empty recorded path');
        return null;
      }

      Uint8List bytes;
      try {
        final xFile = XFile(path);
        bytes = await xFile.readAsBytes();
      } catch (readErr) {
        debugPrint('[ChatVoiceRecorderService] XFile read error: $readErr, trying Dio');
        final dio = Dio();
        final response = await dio.get<List<int>>(
          path,
          options: Options(responseType: ResponseType.bytes),
        );
        bytes = Uint8List.fromList(response.data!);
      }

      debugPrint('[ChatVoiceRecorderService] Extracted ${bytes.length} bytes of audio');
      if (bytes.isEmpty) return null;

      final isWav = _activeEncoder == AudioEncoder.wav || path.endsWith('.wav');
      final isOpus = _activeEncoder == AudioEncoder.opus ||
          path.endsWith('.opus') ||
          path.endsWith('.ogg') ||
          path.endsWith('.webm');
      final ext = isWav
          ? 'wav'
          : (isOpus ? (kIsWeb ? 'webm' : 'ogg') : 'm4a');
      final contentType = isWav
          ? 'audio/wav'
          : (isOpus ? (kIsWeb ? 'audio/webm' : 'audio/ogg') : 'audio/m4a');

      return RecordedVoiceResult(
        bytes: bytes,
        filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.$ext',
        contentType: contentType,
        durationSeconds: durationSec.clamp(1, 3600),
      );
    } catch (e, stack) {
      debugPrint('[ChatVoiceRecorderService] stop error: $e\n$stack');
      return null;
    }
  }

  /// Cancels and discards the active recording
  Future<void> cancel() async {
    _isRecording = false;
    try {
      final recorder = _recorder;
      if (recorder != null) {
        await recorder.cancel();
      }
    } catch (e) {
      debugPrint('[ChatVoiceRecorderService] cancel error: $e');
    }
  }

  void dispose() {
    _isRecording = false;
    try {
      _recorder?.dispose();
    } catch (_) {}
    _recorder = null;
  }
}
