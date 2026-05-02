import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/ai/gemma_service.dart';
import '../../core/theme/app_theme.dart';
import '../habits/habit_ai_command_executor.dart';
import '../habits/habit_tracker_notifier.dart';
import '../../shared/widgets/glass_card.dart';

class AiHubScreen extends ConsumerStatefulWidget {
  const AiHubScreen({super.key});

  @override
  ConsumerState<AiHubScreen> createState() => _AiHubScreenState();
}

class _AiHubScreenState extends ConsumerState<AiHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _chatCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<Map<String, String>> _chatMessages = [];
  final _picker = ImagePicker();
  final _speech = SpeechToText();
  final _emailOriginal = TextEditingController();
  final _emailIntent = TextEditingController(
      text: 'Politely decline and propose next week');
  String _emailDraft = '';
  bool _emailLoading = false;
  bool _chatLoading = false;
  bool _speechAvailable = false;
  bool _listening = false;
  String? _pendingImagePath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  Future<void> _initSpeech() async {
    try {
      final ok = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _listening = false);
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _listening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Speech error: ${error.errorMsg}')),
          );
        },
      );
      if (mounted) setState(() => _speechAvailable = ok);
    } catch (_) {
      if (mounted) setState(() => _speechAvailable = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    _emailOriginal.dispose();
    _emailIntent.dispose();
    super.dispose();
  }

  void _clearChat() {
    ref.read(gemmaServiceProvider).clearChat();
    setState(() => _chatMessages.clear());
  }

  @override
  Widget build(BuildContext context) {
    final uiAsync = ref.watch(aiModelUiStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Steady AI'),
            const SizedBox(width: 8),
            uiAsync.when(
              data: (s) => Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.inferenceReady
                      ? Colors.greenAccent
                      : s.weightsOnDisk
                          ? Colors.amberAccent
                          : Colors.orangeAccent,
                ),
              ),
              loading: () => const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, _) => Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (_tabController.index == 0)
            IconButton(
              tooltip: 'New chat',
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: _chatLoading ? null : _clearChat,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentPurple,
          labelColor: AppColors.accentPurple,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Chat'),
            Tab(icon: Icon(Icons.mail_outline), text: 'Email'),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.black26,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: uiAsync.when(
                      data: (s) => Text(
                        s.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          color: Colors.white70,
                        ),
                      ),
                      loading: () => const Text(
                        'Checking on-device model…',
                        style: TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                      error: (e, _) => Text(
                        'Status error: $e',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.redAccent),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh status',
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () {
                      ref.read(aiModelUiTickProvider.notifier).bump();
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ChatTab(
                  controller: _chatCtrl,
                  scrollController: _scrollCtrl,
                  messages: _chatMessages,
                  loading: _chatLoading,
                  speechAvailable: _speechAvailable,
                  listening: _listening,
                  pendingImagePath: _pendingImagePath,
                  onPickCamera: _captureImage,
                  onPickGallery: _pickFromGallery,
                  onToggleVoice: _toggleVoice,
                  onSend: _sendChat,
                ),
                _EmailTab(
                  originalCtrl: _emailOriginal,
                  intentCtrl: _emailIntent,
                  draft: _emailDraft,
                  loading: _emailLoading,
                  onDraft: _draftEmail,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendChat(String text) async {
    if (text.trim().isEmpty) return;
    final trimmed = text.trim();
    final imagePath = _pendingImagePath;
    setState(() {
      _chatMessages.add({'role': 'user', 'text': trimmed});
      _chatMessages.add({'role': 'ai', 'text': ''});
      _chatLoading = true;
      _pendingImagePath = null;
    });
    _chatCtrl.clear();
    _scrollToBottom();
    final aiIndex = _chatMessages.length - 1;
    try {
      await for (final chunk in ref.read(gemmaServiceProvider).askChatStream(
            trimmed,
            imagePath: imagePath,
          )) {
        if (!mounted) return;
        setState(() {
          final prev = _chatMessages[aiIndex]['text'] ?? '';
          _chatMessages[aiIndex] = {'role': 'ai', 'text': prev + chunk};
        });
        _scrollToBottom();
      }
      await _applyHabitCommand(trimmed);
    } catch (e) {
      if (mounted) {
        setState(() {
          _chatMessages[aiIndex] = {'role': 'ai', 'text': 'Error: $e'};
        });
      }
    } finally {
      if (mounted) setState(() => _chatLoading = false);
    }
  }

  Future<void> _draftEmail() async {
    setState(() => _emailLoading = true);
    try {
      final draft = await ref.read(gemmaServiceProvider).draftEmailReply(
            _emailOriginal.text,
            _emailIntent.text,
          );
      setState(() => _emailDraft = draft);
    } catch (e) {
      setState(() => _emailDraft = 'Error generating draft: $e');
    } finally {
      setState(() => _emailLoading = false);
    }
  }

  Future<void> _applyHabitCommand(String userText) async {
    final habits = ref.read(habitTrackerProvider).habits;
    final habitNames = habits.map((h) => h.name).toList();
    final payload =
        await ref.read(gemmaServiceProvider).extractHabitCommand(
              userText,
              knownHabits: habitNames,
              contextHint: habitNames.isEmpty
                  ? ''
                  : 'Existing habits: ${habitNames.join(', ')}',
            );
    if (payload == null) return;
    final cmd = HabitAiCommand.fromJson(payload);
    final notifier = ref.read(habitTrackerProvider.notifier);
    final outcome = await HabitAiCommandExecutor.execute(notifier, cmd);
    if (outcome.isEmpty || !mounted) return;
    setState(() => _chatMessages.add({'role': 'ai', 'text': outcome}));
    _scrollToBottom();
  }

  Future<void> _captureImage() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.camera);
      if (file == null) return;
      setState(() => _pendingImagePath = file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera error: $e')),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      setState(() => _pendingImagePath = file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gallery error: $e')),
      );
    }
  }

  Future<void> _toggleVoice() async {
    if (!_speechAvailable) {
      await _initSpeech();
      if (!_speechAvailable && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition unavailable')),
        );
      }
      if (!_speechAvailable) return;
    }
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _chatCtrl.text = result.recognizedWords;
            _chatCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: _chatCtrl.text.length),
            );
            _listening = !result.finalResult;
          });
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
        ),
      );
      if (mounted) setState(() => _listening = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _listening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice input error: $e')),
      );
    }
  }
}

class _ChatTab extends StatelessWidget {
  const _ChatTab({
    required this.controller,
    required this.scrollController,
    required this.messages,
    required this.loading,
    required this.speechAvailable,
    required this.listening,
    required this.pendingImagePath,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onToggleVoice,
    required this.onSend,
  });
  final TextEditingController controller;
  final ScrollController scrollController;
  final List<Map<String, String>> messages;
  final bool loading;
  final bool speechAvailable;
  final bool listening;
  final String? pendingImagePath;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onToggleVoice;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Text(
                    'Ask anything…',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isUser = msg['role'] == 'user';
                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.8),
                        child: GlassCard(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            msg['text'] ?? '',
                            style: TextStyle(
                              color: isUser
                                  ? AppColors.accentTeal
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (pendingImagePath != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Image attached',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Camera',
                onPressed: onPickCamera,
                icon: const Icon(Icons.camera_alt_outlined),
              ),
              IconButton(
                tooltip: 'Gallery',
                onPressed: onPickGallery,
                icon: const Icon(Icons.photo_library_outlined),
              ),
              IconButton(
                tooltip: listening ? 'Stop voice' : 'Voice input',
                onPressed: onToggleVoice,
                icon: Icon(
                  listening ? Icons.mic : Icons.mic_none,
                  color: listening
                      ? AppColors.accentPink
                      : (speechAvailable ? null : Colors.white38),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Ask anything...',
                    filled: true,
                  ),
                  onSubmitted: onSend,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => onSend(controller.text),
                icon: const Icon(Icons.send, color: AppColors.accentPurple),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmailTab extends StatelessWidget {
  const _EmailTab({
    required this.originalCtrl,
    required this.intentCtrl,
    required this.draft,
    required this.loading,
    required this.onDraft,
  });
  final TextEditingController originalCtrl;
  final TextEditingController intentCtrl;
  final String draft;
  final bool loading;
  final VoidCallback onDraft;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Column(
            children: [
              TextField(
                controller: originalCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Original email',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: intentCtrl,
                decoration: const InputDecoration(labelText: 'Your intent'),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : onDraft,
                  child: loading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Draft reply'),
                ),
              ),
            ],
          ),
        ),
        if (draft.isNotEmpty) ...[
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Draft',
                        style: Theme.of(context).textTheme.titleMedium),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        // clipboard copy could be added here
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(draft),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
