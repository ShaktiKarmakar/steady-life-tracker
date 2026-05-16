import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatMessage {
  const ChatMessage({
    required this.role,
    this.text = '',
    this.imagePath,
    this.isToolCall = false,
  });

  final String role; // 'user' | 'ai'
  final String text;
  final String? imagePath;
  final bool isToolCall;

  bool get isImage => imagePath != null && imagePath!.isNotEmpty;

  ChatMessage copyWith({
    String? role,
    String? text,
    String? imagePath,
    bool? isToolCall,
  }) =>
      ChatMessage(
        role: role ?? this.role,
        text: text ?? this.text,
        imagePath: imagePath ?? this.imagePath,
        isToolCall: isToolCall ?? this.isToolCall,
      );
}

class ChatMessagesNotifier extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() => [];

  void addUser(String text) => state = [...state, ChatMessage(role: 'user', text: text)];

  void addUserImage(String imagePath, {String text = ''}) =>
      state = [...state, ChatMessage(role: 'user', imagePath: imagePath, text: text)];

  void addAi(String text, {bool isToolCall = false}) =>
      state = [...state, ChatMessage(role: 'ai', text: text, isToolCall: isToolCall)];

  void updateLastAi(String text) {
    if (state.isEmpty || state.last.role != 'ai') return;
    state = [...state.sublist(0, state.length - 1), state.last.copyWith(text: text)];
  }

  void clear() => state = [];
}

final chatMessagesProvider = NotifierProvider<ChatMessagesNotifier, List<ChatMessage>>(
  ChatMessagesNotifier.new,
);
