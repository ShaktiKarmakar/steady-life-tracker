import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class GemmaModelDownloader {
  GemmaModelDownloader._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(minutes: 2),
      receiveTimeout: const Duration(hours: 4),
      followRedirects: true,
      maxRedirects: 16,
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

    debugPrint('[GemmaModelDownloader] Starting download: $url');
    try {
      await _dio.download(
        url,
        filePath,
        options: Options(headers: headers),
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final double progress = (received / total).clamp(0, 1);
            onProgress(progress);
            if (received % (total ~/ 10) < 1024 * 1024) {
              final mb = (received / (1024 * 1024)).round();
              final totalMb = (total / (1024 * 1024)).round();
              debugPrint('[GemmaModelDownloader] Progress: $mb MB / $totalMb MB (${(progress * 100).round()}%)');
            }
          } else {
            onProgress(0);
          }
        },
      );
      debugPrint('[GemmaModelDownloader] Download complete: $filePath');
    } on DioException catch (e) {
      debugPrint('[GemmaModelDownloader] Download failed: ${e.type} - ${e.message}');
      if (e.response?.statusCode == 401) {
        debugPrint('[GemmaModelDownloader] 401 — set a Hugging Face read token in Settings/onboarding.');
      }
      rethrow;
    }
  }
}
