import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Downloads a model from Hugging Face with an optional Bearer token, then
/// [FlutterGemma.installModel] can load the file via [fromFile].
class GemmaModelDownloader {
  GemmaModelDownloader._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(minutes: 2),
      receiveTimeout: const Duration(hours: 4),
      followRedirects: true,
      maxRedirects: 16,
      // Fail on 401/403 so callers can prompt for a Hugging Face token.
      validateStatus: (code) => code != null && code >= 200 && code < 300,
    ),
  );

  static Future<void> downloadToFile({
    required String url,
    required String filePath,
    String? bearerToken,
    required void Function(double progress) onProgress,
  }) async {
    final headers = <String, String>{};
    if (bearerToken != null && bearerToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $bearerToken';
    }

    try {
      await _dio.download(
        url,
        filePath,
        options: Options(headers: headers),
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress((received / total).clamp(0, 1));
          } else {
            onProgress(0);
          }
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        debugPrint(
            '[GemmaModelDownloader] 401 — set a Hugging Face read token in Settings/onboarding.');
      }
      rethrow;
    }
  }
}
