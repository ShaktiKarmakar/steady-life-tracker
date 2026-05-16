import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/ai/food_vision_service.dart';
import '../../core/ai/gemma_service.dart';
import '../../core/ai/mcp_core.dart';
import '../../core/design_system/design_tokens.dart';
import '../../shared/models/food_models.dart';
import '../../shared/providers/app_state.dart';
import 'chat_messages_provider.dart';
import 'voice_input_provider.dart';
import 'widgets/food_review_card.dart';

final _uuid = const Uuid();

class AiHubScreen extends ConsumerStatefulWidget {
  const AiHubScreen({super.key});

  @override
  ConsumerState<AiHubScreen> createState() => _AiHubScreenState();
}

class _AiHubScreenState extends ConsumerState<AiHubScreen> {
  final _ctrl = TextEditingController();
  final _scrollController = ScrollController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    final msg = text.trim();
    _ctrl.clear();

    final notifier = ref.read(chatMessagesProvider.notifier);
    notifier.addUser(msg);
    setState(() => _busy = true);
    _scrollToBottom();

    try {
      final client = McpClient(
        gemma: ref.read(gemmaServiceProvider),
        ref: ref,
        server: McpServer.instance,
      );

      String result;
      final fast = await client.fastPath(msg);
      if (fast != null) {
        result = fast;
      } else {
        final history = _buildHistory();
        result = await client.executeTurn(msg, history: history);
      }

      notifier.addAi(result);
    } catch (e) {
      notifier.addAi('Error: $e');
    } finally {
      setState(() => _busy = false);
      _scrollToBottom();
    }
  }

  /// Resize image to max dimension 512 to keep vision encoder stable.
  static Future<Uint8List> _resizeImage(Uint8List imageBytes, {int maxDimension = 512}) async {
    try {
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final original = frame.image;
      final srcW = original.width;
      final srcH = original.height;
      if (srcW <= maxDimension && srcH <= maxDimension) {
        original.dispose();
        return imageBytes;
      }
      final ratio = srcW > srcH
          ? maxDimension / srcW
          : maxDimension / srcH;
      final targetW = (srcW * ratio).round();
      final targetH = (srcH * ratio).round();

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      canvas.drawImageRect(
        original,
        ui.Rect.fromLTWH(0, 0, srcW.toDouble(), srcH.toDouble()),
        ui.Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final resized = await picture.toImage(targetW, targetH);
      picture.dispose();
      original.dispose();

      final byteData = await resized.toByteData(format: ui.ImageByteFormat.png);
      resized.dispose();
      if (byteData == null) throw StateError('PNG encoding failed');
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('[AiHub] Image resize failed: $e, using original');
      return imageBytes;
    }
  }

  Future<void> _pickImage() async {
    try {
      debugPrint('[AiHub] Opening image picker...');
      final picker = ImagePicker();
      debugPrint('[AiHub] Picker created, calling pickImage...');
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      debugPrint('[AiHub] pickImage returned: ${picked?.path ?? 'null'}');
      if (picked == null) {
        debugPrint('[AiHub] User canceled or picker failed');
        return;
      }

      debugPrint('[AiHub] Reading bytes from ${picked.path}');
      final rawBytes = await picked.readAsBytes();
      debugPrint('[AiHub] Read ${rawBytes.length} bytes');
      final bytes = await _resizeImage(rawBytes);
      debugPrint('[AiHub] Resized to ${bytes.length} bytes');
    final fileName = '${_uuid.v4()}.jpg';
    final docsDir = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${docsDir.path}/food_photos');
    await photoDir.create(recursive: true);
    final filePath = '${photoDir.path}/$fileName';
    await File(filePath).writeAsBytes(bytes);

    final notifier = ref.read(chatMessagesProvider.notifier);
    notifier.addUserImage(filePath, text: picked.name);
    setState(() => _busy = true);
    _scrollToBottom();

    try {
      final vision = FoodVisionService(gemma: ref.read(gemmaServiceProvider));
      final (result, raw) = await vision.analyzePhoto(imageBytes: bytes);
      setState(() => _busy = false);

      if (!mounted) return;

      if (result != null) {
        await _showReviewSheet(result, filePath);
      } else {
        notifier.addAi(
          'I had trouble reading the nutrition data. Here is what I saw:\n\n$raw\n\n'
          'Try describing what you ate in text.',
        );
        _scrollToBottom();
      }
    } catch (e, st) {
      debugPrint('[AiHub] Photo analysis failed: $e\n$st');
      setState(() => _busy = false);
      notifier.addAi(
        'Could not analyze the photo. Try describing what you ate instead.',
      );
      _scrollToBottom();
    }
    } catch (e, st) {
      debugPrint('[AiHub] _pickImage error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e')),
        );
      }
    }
  }

  Future<void> _showReviewSheet(FoodAnalysisResult result, String photoPath) async {
    if (!mounted) return;
    final notifier = ref.read(chatMessagesProvider.notifier);

    var logged = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: FoodReviewCard(
                result: result,
                photoPath: photoPath,
                actions: FoodReviewActions(
                  onLog: (finalResult, mealType) {
                    logged = true;
                    Navigator.pop(ctx);
                    ref.read(foodEntriesProvider.notifier).logWithAi(
                      finalResult,
                      mealType: mealType,
                      photoPath: photoPath,
                    );
                    notifier.addAi(
                      'Logged ${finalResult.totalCalories} kcal for ${mealType.label.toLowerCase()}. ✅',
                    );
                    _scrollToBottom();
                  },
                ),
              ),
            ),
          );
        },
      ),
    );

    if (!logged) {
      notifier.addAi('Photo analysis complete. You can close the review without logging.');
      _scrollToBottom();
    }
  }

  List<McpChatTurn> _buildHistory() {
    final messages = ref.read(chatMessagesProvider);
    final start = (messages.length - 6).clamp(0, messages.length);
    final recent = messages.sublist(start);
    return recent
        .map((m) => McpChatTurn(role: m.role, text: m.text))
        .toList();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleVoice() async {
    final speech = ref.read(speechToTextProvider);
    if (speech.isListening) {
      await speech.stopListening();
      return;
    }
    await speech.startListening(onResult: (words) {
      if (words.trim().isNotEmpty) _send(words);
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final speech = ref.watch(speechToTextProvider);
    final gemma = ref.watch(gemmaServiceProvider);
    final inferenceReady = gemma.realInferenceActive;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userBubbleColor = isDark
        ? DesignTokens.accentActiveDark.withValues(alpha: 0.4)
        : DesignTokens.accentActiveLight.withValues(alpha: 0.6);
    final aiBubbleColor = isDark
        ? DesignTokens.bgSurfaceDark
        : DesignTokens.bgSurfaceLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Steady AI'),
        actions: [
          if (!inferenceReady)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.zapOff, size: 14, color: DesignTokens.warnTextDark),
                    const SizedBox(width: 4),
                    Text(
                      'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: DesignTokens.warnTextDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              reverse: true,
              itemCount: messages.length + (_busy ? 1 : 0),
              itemBuilder: (context, i) {
                if (_busy && i == 0) {
                  return const _ThinkingBubble();
                }
                final msg = messages[messages.length - 1 - i + (_busy ? 1 : 0)];
                return _MessageBubble(
                  msg: msg,
                  userColor: userBubbleColor,
                  aiColor: aiBubbleColor,
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _pickImage,
                    icon: const Icon(LucideIcons.camera),
                  ),
                  IconButton(
                    onPressed: _toggleVoice,
                    icon: Icon(
                      speech.isListening ? LucideIcons.mic : LucideIcons.micOff,
                      color: speech.isListening
                          ? (isDark ? DesignTokens.textSecondaryDark : DesignTokens.textSecondaryLight)
                          : null,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        hintText: 'Ask or command...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: _send,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _send(_ctrl.text),
                    icon: const Icon(LucideIcons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.msg,
    required this.userColor,
    required this.aiColor,
  });
  final ChatMessage msg;
  final Color userColor;
  final Color aiColor;

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: msg.isImage
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? userColor : aiColor,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          border: isUser
              ? null
              : Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? DesignTokens.borderDefaultDark
                      : DesignTokens.borderDefaultLight,
                  width: DesignTokens.borderWidthDefault,
                ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * (msg.isImage ? 0.65 : 0.75),
        ),
        child: msg.isImage
            ? _ImageBubble(msg: msg)
            : Text(
                msg.text,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
      ),
    );
  }
}

class _ImageBubble extends StatelessWidget {
  const _ImageBubble({required this.msg});
  final ChatMessage msg;

  @override
  Widget build(BuildContext context) {
    final file = File(msg.imagePath!);
    final exists = file.existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 280,
          maxHeight: 320,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (exists)
              Image.file(
                file,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildError(),
              )
            else
              _buildError(),
            if (msg.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: Text(
                  msg.text,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      height: 120,
      color: Colors.grey.shade800,
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.white54),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? DesignTokens.bgSurfaceDark
              : DesignTokens.bgSurfaceLight,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? DesignTokens.borderDefaultDark
                : DesignTokens.borderDefaultLight,
            width: DesignTokens.borderWidthDefault,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Thinking...',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
