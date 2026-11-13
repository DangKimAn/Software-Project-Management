import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/providers.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/dio_client.dart';

class ChatUploadResult {
  final String uploadUrl;
  final String publicUrl;
  final String key;
  final int expiresIn;

  const ChatUploadResult({
    required this.uploadUrl,
    required this.publicUrl,
    required this.key,
    required this.expiresIn,
  });

  factory ChatUploadResult.fromJson(Map<String, dynamic> json) {
    final map = DioClient.unwrapEnvelope(json);
    final target = map is Map<String, dynamic> ? map : json;
    return ChatUploadResult(
      uploadUrl: (target['uploadUrl'] ?? '').toString(),
      publicUrl: (target['publicUrl'] ?? '').toString(),
      key: (target['key'] ?? '').toString(),
      expiresIn: (target['expiresIn'] as num?)?.toInt() ?? 300,
    );
  }
}

class ChatMediaUploadService {
  final Dio _apiDio;
  final Dio _cleanR2Dio;

  ChatMediaUploadService({
    required Dio apiDio,
    Dio? cleanR2Dio,
  })  : _apiDio = apiDio,
        _cleanR2Dio = cleanR2Dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 60),
                sendTimeout: const Duration(seconds: 60),
              ),
            );

  /// Requests a presigned URL for `folder: 'chat'` and uploads raw bytes directly
  /// to Cloudflare R2 via HTTP `PUT`.
  Future<ChatUploadResult> uploadMediaBytesToR2({
    required Uint8List bytes,
    required String filename,
    required String contentType,
    String folder = 'chat',
  }) async {
    if (bytes.isEmpty) {
      throw const ValidationFailure('Dữ liệu tệp tải lên không được để trống.');
    }

    final safeFilename = filename.trim().isNotEmpty ? filename.trim() : 'media_upload.bin';
    final safeContentType = contentType.trim().isNotEmpty ? contentType.trim().toLowerCase() : 'application/octet-stream';

    final ChatUploadResult presigned;
    try {
      final presignResponse = await _apiDio.post<Map<String, dynamic>>(
        '/api/uploads/presign',
        data: <String, dynamic>{
          'folder': folder,
          'filename': safeFilename,
          'contentType': safeContentType,
          'size': bytes.length,
        },
      );

      final body = presignResponse.data ?? const <String, dynamic>{};
      presigned = ChatUploadResult.fromJson(body);
      if (presigned.uploadUrl.isEmpty || presigned.publicUrl.isEmpty) {
        throw const ServerFailure('Không nhận được liên kết tải lên từ máy chủ.');
      }
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw DioClient.handleError(e);
    }

    try {
      final putHeaders = <String, dynamic>{
        Headers.contentTypeHeader: safeContentType,
        Headers.contentLengthHeader: bytes.length,
      };
      putHeaders.remove('Authorization');
      putHeaders.remove('authorization');

      final putResponse = await _cleanR2Dio.put<dynamic>(
        presigned.uploadUrl,
        data: bytes,
        options: Options(
          headers: putHeaders,
          responseType: ResponseType.plain,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );

      if (putResponse.statusCode == null ||
          putResponse.statusCode! < 200 ||
          putResponse.statusCode! >= 300) {
        throw const ServerFailure(
          'Tải tệp media lên Cloudflare R2 thất bại. Vui lòng thử lại.',
          code: 'R2_UPLOAD_FAILED',
        );
      }

      return presigned;
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  /// Generates valid 16-bit PCM mono 16kHz WAV audio bytes with a gentle melodic chime.
  /// Playable by any standard media player or browser.
  static Uint8List generateVoiceWavBytes({
    int durationSeconds = 2,
    int sampleRate = 16000,
  }) {
    final effectiveSeconds = durationSeconds.clamp(1, 60);
    final numSamples = effectiveSeconds * sampleRate;
    final dataSize = numSamples * 2; // 16-bit = 2 bytes per sample
    final fileSize = 36 + dataSize;

    final bytes = ByteData(44 + dataSize);

    // RIFF chunk descriptor
    bytes.setUint8(0, 0x52); // 'R'
    bytes.setUint8(1, 0x49); // 'I'
    bytes.setUint8(2, 0x46); // 'F'
    bytes.setUint8(3, 0x46); // 'F'
    bytes.setUint32(4, fileSize, Endian.little);
    bytes.setUint8(8, 0x57);  // 'W'
    bytes.setUint8(9, 0x41);  // 'A'
    bytes.setUint8(10, 0x56); // 'V'
    bytes.setUint8(11, 0x45); // 'E'

    // "fmt " sub-chunk
    bytes.setUint8(12, 0x66); // 'f'
    bytes.setUint8(13, 0x6D); // 'm'
    bytes.setUint8(14, 0x74); // 't'
    bytes.setUint8(15, 0x20); // ' '
    bytes.setUint32(16, 16, Endian.little); // Subchunk1Size for PCM
    bytes.setUint16(20, 1, Endian.little);  // AudioFormat 1 = PCM
    bytes.setUint16(22, 1, Endian.little);  // NumChannels 1 = Mono
    bytes.setUint32(24, sampleRate, Endian.little); // SampleRate
    bytes.setUint32(28, sampleRate * 2, Endian.little); // ByteRate = SampleRate * 1 channel * 2 bytes
    bytes.setUint16(32, 2, Endian.little);  // BlockAlign = 1 channel * 2 bytes
    bytes.setUint16(34, 16, Endian.little); // BitsPerSample = 16

    // "data" sub-chunk
    bytes.setUint8(36, 0x64); // 'd'
    bytes.setUint8(37, 0x61); // 'a'
    bytes.setUint8(38, 0x74); // 't'
    bytes.setUint8(39, 0x61); // 'a'
    bytes.setUint32(40, dataSize, Endian.little);

    // Generate gentle chime harmonics
    const baseFreq = 440.0; // A4 chime
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final envelope = math.exp(-2.5 * (t % 1.0)); // decaying per second
      final wave = 0.6 * math.sin(2 * math.pi * baseFreq * t) +
          0.3 * math.sin(2 * math.pi * (baseFreq * 1.5) * t);
      final sample = (wave * envelope * 16000).clamp(-32768, 32767).toInt();
      bytes.setInt16(44 + i * 2, sample, Endian.little);
    }

    return bytes.buffer.asUint8List();
  }
}

final chatMediaUploadServiceProvider = Provider<ChatMediaUploadService>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return ChatMediaUploadService(apiDio: dioClient.dio);
});
