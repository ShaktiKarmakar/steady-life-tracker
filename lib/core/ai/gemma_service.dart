import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/models/models.dart';
import 'gemma_model_downloader.dart';
import 'huggingface_config.dart';

/// Google MediaPipe iOS doc vs Steady: see `lib/core/ai/edge_ai_alignment.dart`.
final gemmaServiceProvider = Provider<GemmaService>((ref) => GemmaService());

/// Bump with `ref.read(aiModelUiTickProvider.notifier).bump()` after install / restore.
final aiModelUiTickProvider =
    NotifierProvider<AiModelUiTickNotifier, int>(AiModelUiTickNotifier.new);

class AiModelUiTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// What the user needs to see: weights on disk vs plugin “active” selection (survives only until we restore it).
final aiModelUiStatusProvider = FutureProvider<AiModelUiStatus>((ref) async {
  ref.watch(aiModelUiTickProvider);
  final gemma = ref.read(gemmaServiceProvider);
  await gemma.initialize();
  final installed = await gemma.isModelInstalled();
  final inferenceReady = await gemma.warmUpInferenceSession();
  return AiModelUiStatus(
    weightsOnDisk: installed,
    inferenceReady: inferenceReady,
  );
});

class AiModelUiStatus {
  const AiModelUiStatus({
    required this.weightsOnDisk,
    required this.inferenceReady,
  });

  final bool weightsOnDisk;
  final bool inferenceReady;

  bool get readyToRun => inferenceReady;

  String get subtitle {
    if (!weightsOnDisk) {
      return 'No model file yet — download from onboarding.';
    }
    if (!inferenceReady) {
      return 'Weights found but engine did not start — tap Fix on Home to repair.';
    }
    return 'On-device model loaded.';
  }
}

/// Gemma 4 E2B instruct LiteRT-LM — `litert-community/gemma-4-E2B-it-litert-lm` on Hugging Face (~2.6 GB).
/// Hugging Face LFS: almost always needs a read token (onboarding or `HUGGINGFACE_TOKEN` define).
const _defaultModelFile = 'gemma-4-E2B-it.litertlm';
/// Repository id may be stored as basename-without-extension depending on platform path.
const _defaultModelBaseName = 'gemma-4-E2B-it';
/// Permanent folder for Dio downloads — must NOT be deleted after install: flutter_gemma’s
/// [FileSourceHandler] registers this path (no copy). Deleting it breaks validation.
const _persistentModelSubdir = 'steady_models';
const _defaultModelUrl =
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

/// If you host the same file yourself (check model license), set at build time:
/// `flutter build ... --dart-define=STEADY_MODEL_MIRROR_URL=https://.../gemma-4-E2B-it.litertlm`
/// Users can then often download with one tap and no Hugging Face account.
const _modelMirrorUrl =
    String.fromEnvironment('STEADY_MODEL_MIRROR_URL', defaultValue: '');

/// Thrown when the download URL returns 401 and no bearer token is configured.
class HuggingFaceTokenRequiredException implements Exception {
  @override
  String toString() =>
      'This download URL requires authentication. Use a public mirror (STEADY_MODEL_MIRROR_URL) or set HUGGINGFACE_TOKEN at build time.';
}

class GemmaService {
  bool _modelReady = false;
  bool _fallbackMode = false;
  String? _lastError;
  InferenceModel? _model;
  // Persistent chat for multi-turn AI hub conversations.
  InferenceChat? _persistentChat;

  /// True when responses come from the real model session (not mock fallback).
  bool get realInferenceActive => _model != null && !_fallbackMode;

  /// Legacy: true when mock or real "something" responds — prefer [realInferenceActive] + [AiModelUiStatus].
  bool get modelReady => _modelReady || _fallbackMode;

  /// Why the model failed to load (for diagnostics).
  String? get lastError => _lastError;

  Future<void> initialize() async {
    try {
      // Safe to call often: reapplies if the HF token changed (e.g. after onboarding).
      await HuggingFaceConfig.applyToFlutterGemma();
      _fallbackMode = false;
    } catch (e) {
      debugPrint('[GemmaService] Init error: $e');
      _fallbackMode = true;
      return;
    }
    // flutter_gemma does not persist “active inference model” across process restarts.
    // Re-bind from the installed file so getActiveModel() works after each launch.
    await _reactivateInferenceModelIfNeeded();
  }

  /// Public alias for UI pull-to-refresh / retry.
  Future<void> ensureActiveInferenceModel() async {
    await initialize();
  }

  /// Loads the LiteRT session once so UI can tell real inference from “spec only”.
  Future<bool> warmUpInferenceSession() async {
    await _ensureSession();
    return realInferenceActive;
  }

  Future<void> _reactivateInferenceModelIfNeeded() async {
    if (_fallbackMode) return;
    if (FlutterGemma.hasActiveModel()) return;

    final path = await _resolveInstalledModelPath();
    if (path == null) {
      debugPrint('[GemmaService] .litertlm file not found on disk.');
      return;
    }
    // Skip if the file is clearly a partial download (< 2 GB for Gemma 4 E2B).
    // Trying to install an incomplete file crashes the native engine.
    try {
      final size = await File(path).length();
      if (size < 2 * 1024 * 1024 * 1024) {
        debugPrint('[GemmaService] Model file too small (${(size / 1024 / 1024).round()} MB) — likely partial download, skipping reactivation.');
        return;
      }
    } catch (_) {}
    try {
      await FlutterGemma.installModel(
        modelType: ModelType.gemma4,
        fileType: ModelFileType.litertlm,
      ).fromFile(path).install();
      debugPrint('[GemmaService] Restored active inference model from: $path');
    } catch (e) {
      debugPrint('[GemmaService] Could not restore active inference model: $e');
    }
  }

  Future<String?> _resolveInstalledModelPath() async {
    final docs = await getApplicationDocumentsDirectory();
    final support = await getApplicationSupportDirectory();
    final candidates = <String>[
      p.join(support.path, _persistentModelSubdir, _defaultModelFile),
      p.join(docs.path, _defaultModelFile),
      p.join(support.path, _defaultModelFile),
    ];
    for (final path in candidates) {
      if (await File(path).exists()) return path;
    }
    for (final dir in [docs, support]) {
      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is! File) continue;
          final name = p.basename(entity.path);
          if (name == _defaultModelFile ||
              (name.endsWith('.litertlm') &&
                  name.contains('gemma-4-E2B-it'))) {
            return entity.path;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<bool> isModelInstalled() async {
    try {
      // Check flutter_gemma registry first
      if (await FlutterGemma.isModelInstalled(_defaultModelFile)) return true;
      if (await FlutterGemma.isModelInstalled(_defaultModelBaseName)) return true;
      final ids = await FlutterGemma.listInstalledModels();
      final registryHit = ids.any(
        (id) =>
            id == _defaultModelFile ||
            id == _defaultModelBaseName ||
            id.endsWith(_defaultModelFile),
      );
      if (registryHit) return true;
    } catch (e) {
      debugPrint('[GemmaService] Registry check failed: $e');
    }
    // Fallback: check if the weight file still exists on disk
    // (flutter_gemma registry may not persist across restarts).
    // Require > 2 GB — the full Gemma 4 E2B model is ~2.6 GB. Smaller
    // files are partial downloads that will crash the native engine.
    final path = await _resolveInstalledModelPath();
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists() && await file.length() > 2 * 1024 * 1024 * 1024) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Removes registry entries + weight files so a fresh [downloadModel] can run.
  /// Call before redownload if the app is stuck with “session inactive”.
  Future<void> removeLocalModelForReinstall() async {
    await initialize();
    await _purgeSteadyGemmaModel();
  }

  Future<void> downloadModel({
    required void Function(double progress) onProgress,
    String? url,
    bool force = false,
  }) async {
    await initialize();
    if (_fallbackMode) {
      throw StateError('On-device AI engine could not be initialized');
    }

    if (force) {
      await _purgeSteadyGemmaModel();
    } else {
      final registered = await isModelInstalled();
      final active = FlutterGemma.hasActiveModel();
      if (registered && active) {
        await _reactivateInferenceModelIfNeeded();
        _modelReady = true;
        _fallbackMode = false;
        onProgress(1);
        debugPrint('[GemmaService] Model active — skipping download.');
        return;
      }
      if (registered && !active) {
        await _reactivateInferenceModelIfNeeded();
        if (FlutterGemma.hasActiveModel()) {
          _modelReady = true;
          _fallbackMode = false;
          onProgress(1);
          debugPrint('[GemmaService] Session restored — skipping download.');
          return;
        }
        debugPrint(
          '[GemmaService] Registry present but session inactive — purging for clean reinstall.',
        );
        await _purgeSteadyGemmaModel();
      }
    }
    // Prefer your own mirror when defined; otherwise Hugging Face.
    final targetUrl = url ??
        (_modelMirrorUrl.trim().isNotEmpty
            ? _modelMirrorUrl.trim()
            : _defaultModelUrl);
    final token = await HuggingFaceConfig.resolveToken();
    final support = await getApplicationSupportDirectory();
    final modelDir = Directory(p.join(support.path, _persistentModelSubdir));
    await modelDir.create(recursive: true);
    // Basename must stay exactly [_defaultModelFile] — see FileSourceHandler / InferenceInstallationBuilder.
    final fileName = p.basename(Uri.parse(targetUrl).path);
    final filePath = p.join(modelDir.path, fileName);
    final file = File(filePath);

    // Don't delete partial downloads — Dio resumes automatically.
    // Only delete if the file is clearly corrupted (e.g. 0 bytes).
    try {
      if (await file.exists() && await file.length() == 0) {
        debugPrint('[GemmaService] Removing empty model file.');
        await file.delete();
      }
    } catch (e) {
      debugPrint('[GemmaService] Could not check existing file: $e');
    }

    try {
      debugPrint('[GemmaService] Downloading model via Dio → $filePath');
      onProgress(0.02);

      Future<void> runDownload(String? bearer) async {
        await GemmaModelDownloader.downloadToFile(
          url: targetUrl,
          filePath: filePath,
          bearerToken: bearer,
          onProgress: onProgress,
        );
      }

      // Easiest path: try without a token (works for some mirrors / public URLs).
      try {
        await runDownload(null);
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          if (token != null && token.isNotEmpty) {
            debugPrint('[GemmaService] Retrying download with saved HF token');
            onProgress(0.02);
            await runDownload(token);
          } else {
            throw HuggingFaceTokenRequiredException();
          }
        } else {
          rethrow;
        }
      }

      if (!await file.exists() || await file.length() == 0) {
        throw StateError('Downloaded model file is missing or empty');
      }

      // `.litertlm` → LiteRT FFI (mobile + desktop macOS/Windows/Linux when fileType matches).
      await FlutterGemma.installModel(
        modelType: ModelType.gemma4,
        fileType: ModelFileType.litertlm,
      ).fromFile(filePath).install();

      _modelReady = true;
      _fallbackMode = false;
      debugPrint('[GemmaService] Model installed successfully.');
    } catch (e) {
      debugPrint('[GemmaService] Download failed: $e');
      final msg = e.toString();
      final authFail = e is HuggingFaceTokenRequiredException ||
          msg.contains('401') ||
          msg.contains('Authentication') ||
          msg.contains('Invalid username');
      if (!authFail) {
        _fallbackMode = true;
      }
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      rethrow;
    }
    // Do not delete [filePath] on success — flutter_gemma keeps a live FileSource to it.
  }

  /// Clears flutter_gemma metadata and deletes known Gemma 4 weight files on disk.
  Future<void> _purgeSteadyGemmaModel() async {
    try {
      final ids = await FlutterGemma.listInstalledModels();
      for (final id in ids) {
        if (id.contains('gemma-4-E2B') || id.contains('gemma-4')) {
          try {
            await FlutterGemma.uninstallModel(id);
          } catch (e) {
            debugPrint('[GemmaService] uninstallModel($id): $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[GemmaService] listInstalledModels during purge: $e');
    }
    for (final id in [_defaultModelFile, _defaultModelBaseName]) {
      try {
        await FlutterGemma.uninstallModel(id);
      } catch (_) {}
    }
    try {
      final support = await getApplicationSupportDirectory();
      final steadyDir = Directory(p.join(support.path, _persistentModelSubdir));
      if (await steadyDir.exists()) {
        await steadyDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('[GemmaService] delete steady_models: $e');
    }
    try {
      final tmp = Directory(
        p.join((await getTemporaryDirectory()).path, 'steady_dl_tmp'),
      );
      if (await tmp.exists()) await tmp.delete(recursive: true);
    } catch (_) {}
    for (final dir in [
      await getApplicationDocumentsDirectory(),
      await getApplicationSupportDirectory(),
    ]) {
      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is! File) continue;
          final name = p.basename(entity.path);
          if (name.endsWith('.litertlm') && name.contains('gemma-4-E2B')) {
            try {
              await entity.delete();
            } catch (e) {
              debugPrint('[GemmaService] delete ${entity.path}: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('[GemmaService] scan ${dir.path}: $e');
      }
    }
    _model?.close();
    _model = null;
    _persistentChat = null;
    _modelReady = false;
    _fallbackMode = false;
  }

  Future<void> _ensureSession() async {
    await initialize();
    if (_fallbackMode) return;
    if (_model != null) return;
    try {
      _model = await FlutterGemma.getActiveModel(
        maxTokens: 4096,
        preferredBackend: PreferredBackend.gpu,
        supportImage: true,
        maxNumImages: 1,
      );
      _modelReady = true;
      _lastError = null;
    } on Object catch (e) {
      _lastError = 'GPU backend failed: $e';
      debugPrint('[GemmaService] Could not create model session (GPU): $e');
      final desktop = !kIsWeb &&
          (Platform.isMacOS || Platform.isLinux || Platform.isWindows);
      if (desktop) {
        try {
          _model = await FlutterGemma.getActiveModel(
            maxTokens: 4096,
            preferredBackend: PreferredBackend.cpu,
            supportImage: true,
            maxNumImages: 1,
          );
          _modelReady = true;
          _lastError = null;
          return;
        } on Object catch (e2) {
          _lastError = 'CPU backend also failed: $e2';
          debugPrint('[GemmaService] CPU backend also failed: $e2');
        }
      }
      _model = null;
      _persistentChat = null;
      _fallbackMode = true;
    }
  }

  /// Resets the fallback flag so the next call retries model initialization.
  /// Call this after fixing an issue (e.g. downloading the model).
  void resetFallback() {
    _fallbackMode = false;
    _lastError = null;
  }

  /// Clears the persistent chat history (call when the user starts a new conversation).
  void clearChat() {
    _persistentChat = null;
  }

  /// Token streaming for chat UIs. Uses a persistent [Chat] so the model
  /// remembers previous turns — call [clearChat] to start fresh.
  Stream<String> askChatStream(
    String prompt, {
    String systemContext = '',
    String? imagePath,
    Uint8List? audioBytes,
  }) async* {
    await _ensureSession();
    if (_fallbackMode || _model == null) {
      yield _mockResponse(prompt, systemContext: systemContext);
      return;
    }
    try {
      // Reuse the same InferenceChat object across turns so the model has full history.
      _persistentChat ??= await _model!.createChat(
        systemInstruction: systemContext.isEmpty ? null : systemContext,
        supportImage: true,
      );
      final userMessage = await _buildUserMessage(
        prompt,
        imagePath: imagePath,
        audioBytes: audioBytes,
      );
      await _persistentChat!.addQueryChunk(
        userMessage,
      );
      await for (final response
          in _persistentChat!.generateChatResponseAsync()) {
        if (response is TextResponse) {
          yield response.token;
        }
      }
    } catch (e) {
      // Session may have gone stale — reset so the next call rebuilds it.
      _persistentChat = null;
      debugPrint('[GemmaService] Streaming inference error: $e');
      yield 'Error: $e';
    }
  }

  Future<String> ask(String prompt, {String systemContext = ''}) async {
    await _ensureSession();
    if (_fallbackMode || _model == null) {
      return _mockResponse(prompt, systemContext: systemContext);
    }
    try {
      final chat = await _model!.createChat(
        systemInstruction: systemContext.isEmpty ? null : systemContext,
        supportImage: true,
      );
      await chat.addQueryChunk(
        Message.text(text: prompt, isUser: true),
      );
      final response = await chat.generateChatResponse();
      if (response is TextResponse) {
        return response.token.trim();
      }
      return response.toString().trim();
    } catch (e) {
      debugPrint('[GemmaService] Inference error: $e');
      return _mockResponse(prompt, systemContext: systemContext);
    }
  }

  /// Preprocess image for vision encoder: resize to 896x896, white bg, convert to PNG.
  static Future<Uint8List> _preprocessImage(Uint8List imageBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final original = frame.image;

      const targetSize = 896;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      // Fill white background — vision encoders often fail on transparent PNGs
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, targetSize.toDouble(), targetSize.toDouble()),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;

      final srcW = original.width.toDouble();
      final srcH = original.height.toDouble();
      final srcAspect = srcW / srcH;

      double drawW, drawH, offsetX, offsetY;
      if (srcAspect > 1.0) {
        drawW = targetSize.toDouble();
        drawH = drawW / srcAspect;
        offsetX = 0;
        offsetY = (targetSize - drawH) / 2;
      } else {
        drawH = targetSize.toDouble();
        drawW = drawH * srcAspect;
        offsetX = (targetSize - drawW) / 2;
        offsetY = 0;
      }

      canvas.drawImageRect(
        original,
        ui.Rect.fromLTWH(0, 0, srcW, srcH),
        ui.Rect.fromLTWH(offsetX, offsetY, drawW, drawH),
        paint,
      );

      final picture = recorder.endRecording();
      final resized = await picture.toImage(targetSize, targetSize);
      picture.dispose();
      original.dispose();

      final byteData = await resized.toByteData(format: ui.ImageByteFormat.png);
      resized.dispose();

      if (byteData == null) throw StateError('PNG encoding failed');
      final processed = byteData.buffer.asUint8List();
      debugPrint('[GemmaService] Preprocessed image: ${imageBytes.length} bytes → ${processed.length} bytes PNG @ ${targetSize}x$targetSize');
      return processed;
    } catch (e) {
      debugPrint('[GemmaService] Image preprocessing failed: $e, using original');
      return imageBytes;
    }
  }

  /// Send a one-shot prompt with image bytes (no persistent chat history).
  Future<String> askWithImage({
    required Uint8List imageBytes,
    required String prompt,
    String systemContext = '',
  }) async {
    await _ensureSession();
    debugPrint('[GemmaService] askWithImage: bytes=${imageBytes.length}, fallbackMode=$_fallbackMode, model=${_model != null}, lastError=$_lastError');
    if (_fallbackMode || _model == null) {
      debugPrint('[GemmaService] Using mock response because model not ready');
      return _mockResponse(prompt, systemContext: systemContext);
    }
    try {
      final processedBytes = await _preprocessImage(imageBytes);
      debugPrint('[GemmaService] Creating chat with supportImage=true...');
      final chat = await _model!.createChat(
        systemInstruction: systemContext.isEmpty ? null : systemContext,
        supportImage: true,
      );
      debugPrint('[GemmaService] Chat created, building Message.withImage...');
      final message = Message.withImage(
        imageBytes: processedBytes,
        text: prompt,
      );
      debugPrint('[GemmaService] Message built, adding to chat...');
      await chat.addQueryChunk(message);
      debugPrint('[GemmaService] Generating response...');
      final response = await chat.generateChatResponse();
      String result;
      if (response is TextResponse) {
        result = response.token.trim();
      } else {
        result = response.toString().trim();
      }
      debugPrint('[GemmaService] Raw response: $result');
      return result;
    } catch (e, st) {
      debugPrint('[GemmaService] Image inference error: $e\n$st');
      // Reset session so next call recreates it
      _model = null;
      _persistentChat = null;
      return _mockResponse(prompt, systemContext: systemContext);
    }
  }

  Future<Message> _buildUserMessage(
    String prompt, {
    String? imagePath,
    Uint8List? audioBytes,
  }) async {
    Uint8List? imageBytes;
    if (imagePath != null && imagePath.trim().isNotEmpty) {
      try {
        imageBytes = await File(imagePath).readAsBytes();
      } catch (e) {
        debugPrint('[GemmaService] Could not read image "$imagePath": $e');
      }
    }
    if (imageBytes != null && imageBytes.isNotEmpty) {
      return Message.withImage(
        imageBytes: imageBytes,
        text: prompt,
      );
    }
    return Message.text(
      text: prompt,
      isUser: true,
    );
  }

  Future<String> analyzeFood(String description) async {
    final system =
        'You are a nutrition assistant. Reply with ONLY a JSON object containing keys: calories (int), protein_g (int), carbs_g (int), fat_g (int).';
    final result = await ask(
      'Estimate calories and macros for: "$description".',
      systemContext: system,
    );
    // Try to extract JSON if model wrapped it in markdown
    final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(result);
    if (jsonMatch != null) {
      return jsonMatch.group(0)!;
    }
    return result;
  }

  Future<String> generateHabitNudge(String habitName, int streak) async {
    return ask(
      'Give a short, encouraging nudge for someone on a $streak-day streak for "$habitName". Keep it under 20 words.',
      systemContext: 'You are a supportive personal coach.',
    );
  }

  Future<String> draftEmailReply(
    String originalEmail,
    String userIntent,
  ) async {
    return ask(
      'Draft a concise professional email reply.\n\nOriginal email:\n$originalEmail\n\nMy intent:\n$userIntent',
      systemContext: 'You are a concise professional assistant.',
    );
  }

  Future<String> tagReel(String caption) async {
    final system =
        'You are a content tagging assistant. Reply with ONLY a JSON array of 3-5 short tags (each under 15 chars).';
    final result = await ask(
      'Generate tags for this caption: "$caption"',
      systemContext: system,
    );
    final jsonMatch = RegExp(r'\[[^\]]+\]').firstMatch(result);
    if (jsonMatch != null) return jsonMatch.group(0)!;
    return result;
  }

  Future<String> generateDailyBriefing(
    List<Habit> habits,
    List<FoodEntry> foods,
    List<WorkoutEntry> workouts,
  ) async {
    final totalCal = foods.fold<int>(0, (s, e) => s + e.totalCalories);
    final totalProt = foods.fold<double>(0, (s, e) => s + e.totalProteinG);
    final topHabit = habits.isNotEmpty
        ? habits.reduce((a, b) => a.currentStreak > b.currentStreak ? a : b)
        : null;
    final workoutMin = workouts.fold<int>(0, (s, e) => s + e.durationMin);

    final prompt = '''
Here is today's wellness data:
- Top habit: ${topHabit?.name ?? 'None'} (streak ${topHabit?.currentStreak ?? 0})
- Calories logged: $totalCal kcal
- Protein: ${totalProt.toStringAsFixed(0)}g
- Workout minutes: $workoutMin

Give a 2-sentence encouraging daily briefing. Keep it warm and specific.'''.trim();

    return ask(prompt,
        systemContext: 'You are Steady AI, a friendly wellness coach.');
  }

  void dispose() {
    _persistentChat = null;
    _model?.close();
    _model = null;
  }

  /// Ask model for a structured habit command. Returns null when no action.
  Future<Map<String, dynamic>?> extractHabitCommand(
    String userText, {
    List<String> knownHabits = const [],
    String contextHint = '',
  }) async {
    final quick = _heuristicHabitCommand(userText, knownHabits: knownHabits);
    if (quick != null) return quick;

    final system = '''
You convert natural language into habit commands.
Reply ONLY as JSON.
If the user is not asking to change habit data, return {"action":"none"}.
Supported action values:
- create_habit
- update_habit
- mark_habit_done
- log_habit_progress
- none

Optional fields:
habitName, newName, emoji, kind(checkbox|count|quantity|stopwatch|countdown),
goalCount(int), goalAmount(number), goalSeconds(int), quantityIncrement(number),
unitLabel, timeOfDay(anytime|morning|afternoon|evening)

Examples:
User: "add a new habit drink water 3000 ml"
JSON: {"action":"create_habit","habitName":"Drink water","kind":"quantity","goalAmount":3000,"quantityIncrement":500,"unitLabel":"ml"}

User: "change water goal to 3500 ml"
JSON: {"action":"update_habit","habitName":"Water","goalAmount":3500,"unitLabel":"ml"}

User: "mark vitamins done"
JSON: {"action":"mark_habit_done","habitName":"Vitamins"}
''';
    final prompt = contextHint.isEmpty
        ? userText
        : '$userText\n\nContext:\n$contextHint';
    final raw = await ask(prompt, systemContext: system);
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
    if (match == null) return null;
    try {
      final decoded = jsonDecode(match.group(0)!) as Map<String, dynamic>;
      final action = (decoded['action'] as String? ?? 'none').trim().toLowerCase();
      if (action == 'none' || action.isEmpty) return null;
      final habitName = decoded['habitName'] as String?;
      if ((habitName == null || habitName.trim().isEmpty) &&
          knownHabits.isNotEmpty) {
        final resolved = _resolveHabitNameFromText(userText, knownHabits);
        if (resolved != null) decoded['habitName'] = resolved;
      }
      return decoded;
    } catch (_) {
      return _heuristicHabitCommand(userText, knownHabits: knownHabits);
    }
  }

  Map<String, dynamic>? _heuristicHabitCommand(
    String input, {
    List<String> knownHabits = const [],
  }) {
    final t = input.trim();
    if (t.isEmpty) return null;
    final lower = t.toLowerCase();

    String? habitName;
    final quoted = RegExp(r'"([^"]+)"').firstMatch(t);
    if (quoted != null) {
      habitName = quoted.group(1)?.trim();
    } else {
      final afterHabit = RegExp(r'\bhabit\s+([a-zA-Z][a-zA-Z0-9 ]{1,40})')
          .firstMatch(lower)
          ?.group(1);
      if (afterHabit != null) habitName = _title(afterHabit);
    }
    habitName ??= _resolveHabitNameFromText(input, knownHabits);

    final amountMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(ml|l|liters|liter|cups|cup)')
        .firstMatch(lower);
    final amount = amountMatch == null ? null : double.tryParse(amountMatch.group(1)!);
    final unit = amountMatch?.group(2);
    final countMatch = RegExp(r'(\d+)\s*(times|reps|count|tablets|pills)?')
        .firstMatch(lower);
    final count = countMatch == null ? null : int.tryParse(countMatch.group(1)!);
    final minMatch = RegExp(r'(\d+)\s*(min|mins|minutes)').firstMatch(lower);
    final parsedMin = minMatch == null ? null : int.tryParse(minMatch.group(1)!);
    final secFromMin = parsedMin == null ? null : parsedMin * 60;

    if (lower.contains('drink water') && (habitName == null || habitName.isEmpty)) {
      habitName = 'Drink water';
    }
    if (lower.contains('vitamin') && (habitName == null || habitName.isEmpty)) {
      habitName = 'Vitamins';
    }

    final isCreate = RegExp(r'\b(add|create|new)\b').hasMatch(lower) &&
        RegExp(r'\bhabit\b').hasMatch(lower);
    final isUpdate =
        RegExp(r'\b(update|change|set|edit)\b').hasMatch(lower) &&
            !isCreate;
    final isMarkDone = RegExp(r'\b(mark|set)\b').hasMatch(lower) &&
        RegExp(r'\b(done|complete|completed)\b').hasMatch(lower);

    if (isCreate) {
      return {
        'action': 'create_habit',
        'habitName': habitName ?? _title(_guessNameFromCreate(lower)),
        if (amount != null) 'goalAmount': amount,
        if (unit != null) 'unitLabel': unit == 'liter' || unit == 'liters' ? 'l' : unit,
        if (amount != null) 'kind': 'quantity',
        if (count != null && amount == null) 'goalCount': count,
        if (count != null && amount == null) 'kind': 'count',
        if (secFromMin != null) 'goalSeconds': secFromMin,
        if (secFromMin != null) 'kind': 'countdown',
      };
    }

    if (isMarkDone && habitName != null) {
      return {'action': 'mark_habit_done', 'habitName': habitName};
    }

    if (isUpdate && habitName != null) {
      return {
        'action': 'update_habit',
        'habitName': habitName,
        if (amount != null) 'goalAmount': amount,
        if (unit != null) 'unitLabel': unit == 'liter' || unit == 'liters' ? 'l' : unit,
        if (count != null && amount == null) 'goalCount': count,
        if (secFromMin != null) 'goalSeconds': secFromMin,
      };
    }

    final isLog = RegExp(r'\b(log|did|done|drank|took|add)\b').hasMatch(lower);
    if (isLog && habitName != null) {
      return {
        'action': 'log_habit_progress',
        'habitName': habitName,
        if (amount != null) 'goalAmount': amount,
        if (count != null && amount == null) 'goalCount': count,
        if (secFromMin != null) 'goalSeconds': secFromMin,
      };
    }

    return null;
  }

  String? _resolveHabitNameFromText(String text, List<String> knownHabits) {
    if (knownHabits.isEmpty) return null;
    final lower = text.toLowerCase();
    String? best;
    var bestScore = 0;
    for (final h in knownHabits) {
      final n = h.trim();
      if (n.isEmpty) continue;
      final hn = n.toLowerCase();
      if (lower.contains(hn)) {
        final score = hn.length * 3;
        if (score > bestScore) {
          bestScore = score;
          best = n;
        }
        continue;
      }
      final tokens = hn.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      var tokenHits = 0;
      for (final t in tokens) {
        if (t.length >= 3 && lower.contains(t)) tokenHits++;
      }
      final score = tokenHits * 2;
      if (score > bestScore) {
        bestScore = score;
        best = n;
      }
    }
    return bestScore >= 2 ? best : null;
  }

  String _title(String text) {
    final parts = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    return parts
        .map((p) => p[0].toUpperCase() + (p.length > 1 ? p.substring(1) : ''))
        .join(' ');
  }

  String _guessNameFromCreate(String lower) {
    final cleaned = lower
        .replaceAll(RegExp(r'\b(add|create|new|habit|a|an|the)\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'New habit';
    return cleaned;
  }

  Future<String> describeImageForPrompt(String imagePath) async {
    final base = p.basename(imagePath);
    return 'Image attached: $base. Interpret visual context and answer user request.';
  }

  // ---------------------------------------------------------------------------
  // Mock fallback (used when model isn't downloaded or platform unsupported)
  // ---------------------------------------------------------------------------
  String _mockResponse(String prompt, {String systemContext = ''}) {
    final clean = prompt.toLowerCase();
    // Only mimic food JSON for explicit macro estimation (not “Calories logged” in briefings).
    if (clean.contains('estimate calories and macros')) {
      return jsonEncode({
        'calories': 420,
        'protein_g': 20,
        'carbs_g': 40,
        'fat_g': 18,
      });
    }
    // In fallback mode, NEVER leak the system prompt.
    // Return a clear offline message so the user knows the model isn't ready.
    return 'Steady AI is offline — the on-device model has not finished downloading yet. '
        'Complete onboarding to enable AI commands.';
  }
}
