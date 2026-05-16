/// Core MCP (Model Context Protocol) types for Steady AI.
/// This is a lightweight embedded MCP implementation optimized for
/// on-device 2.6B parameter models.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gemma_service.dart';

// ---------------------------------------------------------------------------
// MCP Tool Schema (JSON Schema inspired)
// ---------------------------------------------------------------------------

/// Defines the type of a tool parameter.
enum McpParameterType {
  string,
  number,
  integer,
  boolean,
  array,
  object,
}

/// A parameter definition for an MCP tool.
class McpParameter {
  const McpParameter({
    required this.name,
    required this.type,
    required this.description,
    this.required = true,
    this.enumValues,
    this.defaultValue,
  });

  final String name;
  final McpParameterType type;
  final String description;
  final bool required;
  final List<String>? enumValues;
  final dynamic defaultValue;

  Map<String, dynamic> toSchema() {
    final schema = <String, dynamic>{
      'type': type.name,
      'description': description,
    };
    if (enumValues != null) {
      schema['enum'] = enumValues;
    }
    if (defaultValue != null) {
      schema['default'] = defaultValue;
    }
    return schema;
  }
}

/// Full JSON Schema for an MCP tool.
class McpToolSchema {
  const McpToolSchema({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final List<McpParameter> parameters;

  Map<String, dynamic> toJson() {
    final props = <String, dynamic>{};
    final required = <String>[];
    for (final p in parameters) {
      props[p.name] = p.toSchema();
      if (p.required) required.add(p.name);
    }
    return {
      'name': name,
      'description': description,
      'parameters': {
        'type': 'object',
        'properties': props,
        'required': required,
      },
    };
  }
}

// ---------------------------------------------------------------------------
// MCP Tool
// ---------------------------------------------------------------------------

/// An MCP tool callable by the AI.
class McpTool {
  const McpTool({
    required this.schema,
    required this.executor,
  });

  final McpToolSchema schema;

  /// Executes the tool with validated arguments.
  /// Returns a structured [McpResult].
  final Future<McpResult> Function(Map<String, dynamic> args, WidgetRef ref) executor;

  String get name => schema.name;
}

// ---------------------------------------------------------------------------
// MCP Result Types
// ---------------------------------------------------------------------------

/// The outcome of an MCP tool execution.
class McpResult {
  const McpResult({
    required this.success,
    required this.message,
    this.data,
    this.error,
  });

  final bool success;

  /// Human-readable message for the user.
  final String message;

  /// Optional structured data (e.g. habit ID, calories logged, etc).
  final Map<String, dynamic>? data;

  /// Error details if success == false.
  final McpError? error;

  /// Quick factory for success.
  factory McpResult.ok(String message, {Map<String, dynamic>? data}) {
    return McpResult(success: true, message: message, data: data);
  }

  /// Quick factory for failure.
  factory McpResult.fail(String message, {McpError? error, Map<String, dynamic>? data}) {
    return McpResult(success: false, message: message, error: error, data: data);
  }
}

/// Structured error from an MCP tool.
class McpError {
  const McpError({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;
}

// ---------------------------------------------------------------------------
// MCP Server
// ---------------------------------------------------------------------------

/// The MCP server exposes a set of tools and handles their invocation.
class McpServer {
  McpServer._();
  static final McpServer instance = McpServer._();

  final Map<String, McpTool> _tools = {};

  /// Register a tool.
  void register(McpTool tool) {
    _tools[tool.name] = tool;
    debugPrint('[McpServer] Registered tool: ${tool.name}');
  }

  /// Discover all available tools (for building system prompts).
  List<McpToolSchema> get tools => List.unmodifiable(_tools.values.map((t) => t.schema));

  /// Get a single tool by name.
  McpTool? getTool(String name) => _tools[name];

  /// Invoke a tool by name with raw JSON args.
  Future<McpResult> invoke(String toolName, Map<String, dynamic> args, WidgetRef ref) async {
    final tool = _tools[toolName];
    if (tool == null) {
      return McpResult.fail(
        'Tool "$toolName" not found.',
        error: const McpError(code: 'TOOL_NOT_FOUND', message: 'Unknown tool'),
      );
    }

    // Validate required args
    final validationError = _validateArgs(tool.schema, args);
    if (validationError != null) {
      return McpResult.fail(
        validationError,
        error: const McpError(code: 'INVALID_ARGUMENTS', message: 'Missing or invalid args'),
      );
    }

    try {
      return await tool.executor(args, ref);
    } catch (e, st) {
      debugPrint('[McpServer] Tool $toolName error: $e\n$st');
      return McpResult.fail(
        'Something went wrong executing "$toolName".',
        error: McpError(code: 'EXECUTION_ERROR', message: e.toString()),
      );
    }
  }

  String? _validateArgs(McpToolSchema schema, Map<String, dynamic> args) {
    for (final param in schema.parameters) {
      if (param.required && !args.containsKey(param.name)) {
        return 'Missing required parameter "${param.name}".';
      }
      if (args.containsKey(param.name)) {
        final value = args[param.name];
        if (value == null && param.required) {
          return 'Parameter "${param.name}" cannot be null.';
        }
        if (param.enumValues != null && value is String) {
          if (!param.enumValues!.contains(value)) {
            return 'Parameter "${param.name}" must be one of: ${param.enumValues!.join(', ')}.';
          }
        }
      }
    }
    return null;
  }

  /// Build a compact system prompt listing all tools (for 2.6B models).
  String buildSystemPrompt() {
    final buffer = StringBuffer();
    buffer.writeln(
        'You are Steady AI. You have access to TOOLS to help the user manage their wellness. '
        'Reply ONLY with a single JSON object.');
    buffer.writeln();
    buffer.writeln('RULES:');
    buffer.writeln('1. If the user wants an action, call the matching tool:');
    buffer.writeln('   {"tool":"name","args":{"param":"value"}}');
    buffer.writeln('2. If just chatting (greeting, questions, small talk), reply:');
    buffer.writeln('   {"tool":"none","message":"your reply"}');
    buffer.writeln('3. Do NOT include extra text outside the JSON.');
    buffer.writeln();
    buffer.writeln('TOOLS:');

    for (final tool in _tools.values) {
      final s = tool.schema;
      buffer.write('- ${s.name}: ${s.description}');
      if (s.parameters.isNotEmpty) {
        final params = s.parameters.map((p) {
          final req = p.required ? '' : ' (optional)';
          return '${p.name}${req}: ${p.type.name}';
        }).join(', ');
        buffer.write(' | args: $params');
      }
      buffer.writeln();
    }

    buffer.writeln();
    buffer.writeln('EXAMPLES:');
    buffer.writeln('User: hi → {"tool":"none","message":"Hello! How can I help?"}');
    buffer.writeln('User: drank 500ml water → {"tool":"log_habit_progress","args":{"habit_name":"Water","amount":500}}');
    buffer.writeln('User: mark meditate done → {"tool":"mark_habit_done","args":{"habit_name":"Meditate"}}');
    buffer.writeln('User: remove habit water → {"tool":"delete_habit","args":{"habit_name":"Water"}}');
    buffer.writeln('User: delete all habits → {"tool":"delete_all_habits","args":{}}');
    buffer.writeln('User: workout run 30 min → {"tool":"log_workout","args":{"type":"Run","duration_min":30}}');
    buffer.writeln('User: how am i doing → {"tool":"get_stats","args":{}}');

    return buffer.toString();
  }
}

// ---------------------------------------------------------------------------
// MCP Client (the AI command engine)
// ---------------------------------------------------------------------------

/// Orchestrates the user → AI → tool → result cycle using the MCP server.
class McpClient {
  McpClient({required this.gemma, required this.ref, required this.server});

  final GemmaService gemma;
  final WidgetRef ref;
  final McpServer server;

  /// Executes one conversational turn.
  /// Returns the final message to display to the user.
  Future<String> executeTurn(
    String userText, {
    List<McpChatTurn> history = const [],
  }) async {
    final system = _buildContextualPrompt(history);
    final raw = await gemma.ask(userText, systemContext: system);
    debugPrint('[McpClient] RAW: $raw');

    final cleaned = _cleanModelOutput(raw);
    debugPrint('[McpClient] CLEANED: $cleaned');

    final toolCall = _extractToolCall(cleaned);
    debugPrint('[McpClient] toolCall: $toolCall');

    if (toolCall == null) {
      return cleaned.trim();
    }

    final toolName = toolCall['tool'] as String?;
    debugPrint('[McpClient] toolName: $toolName');

    if (toolName == null || toolName.isEmpty || toolName == 'none') {
      final msg = (toolCall['message'] as String?)?.trim();
      if (msg != null && msg.isNotEmpty) return msg;
      return "I'm here to help! What would you like to do?";
    }

    // Invoke via MCP server
    final args = (toolCall['args'] as Map<String, dynamic>?) ?? {};
    debugPrint('[McpClient] Invoking "$toolName" with args: $args');

    final result = await server.invoke(toolName, args, ref);
    debugPrint('[McpClient] Result: ${result.message}');

    return result.message;
  }

  /// Fast-path: bypass LLM for common commands.
  Future<String?> fastPath(String userText) async {
    final lower = userText.toLowerCase().trim();

    final waterMatch = RegExp(r'(\d+)\s*ml').firstMatch(lower);
    if (lower.contains('water') && waterMatch != null) {
      final ml = int.tryParse(waterMatch.group(1)!);
      if (ml != null) {
        final result = await server.invoke(
          'log_habit_progress',
          {'habit_name': 'Water', 'amount': ml},
          ref,
        );
        return result.message;
      }
    }

    if (lower.contains('vitamin') && lower.contains('done')) {
      final result = await server.invoke(
        'mark_habit_done',
        {'habit_name': 'Vitamins'},
        ref,
      );
      return result.message;
    }

    if (lower.contains('meditate') && lower.contains('done')) {
      final result = await server.invoke(
        'mark_habit_done',
        {'habit_name': 'Meditate'},
        ref,
      );
      return result.message;
    }

    // Fast path for delete all
    if (RegExp(r'\b(delete|remove|clear)\b').hasMatch(lower) &&
        RegExp(r'\b(all|everything)\b').hasMatch(lower) &&
        RegExp(r'\b(habits?)\b').hasMatch(lower)) {
      final result = await server.invoke('delete_all_habits', {}, ref);
      return result.message;
    }

    return null;
  }

  String _buildContextualPrompt(List<McpChatTurn> history) {
    final base = server.buildSystemPrompt();
    if (history.isEmpty) return base;

    final buffer = StringBuffer();
    buffer.writeln(base);
    buffer.writeln();
    buffer.writeln('Previous conversation:');
    for (final turn in history) {
      final label = turn.role == 'user' ? 'User' : 'AI';
      buffer.writeln('$label: ${turn.text}');
    }
    return buffer.toString();
  }

  String _cleanModelOutput(String raw) {
    var text = raw.trim();

    if (text.startsWith('```json')) {
      text = text.substring('```json'.length).trim();
    }
    if (text.startsWith('```')) {
      text = text.substring('```'.length).trim();
    }
    if (text.endsWith('```')) {
      text = text.substring(0, text.length - '```'.length).trim();
    }

    // Strip echo markers
    final echoMarkers = [
      'You are Steady AI',
      'TOOLS:',
      'RULES:',
      'EXAMPLES:',
      'User:',
      'Reply ONLY',
    ];
    var echoCount = 0;
    for (final m in echoMarkers) {
      if (text.contains(m)) echoCount++;
    }
    if (echoCount >= 2) {
      final allJson = RegExp(r'\{[\s\S]*\}').allMatches(text);
      if (allJson.isNotEmpty) return allJson.last.group(0)!;
      return '';
    }

    return text;
  }

  Map<String, dynamic>? _extractToolCall(String raw) {
    final trimmed = raw.trim();

    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed) as Map<String, dynamic>;
        if (decoded.containsKey('tool')) return decoded;
      } catch (_) {}
    }

    final matches = RegExp(r'\{[\s\S]*\}').allMatches(raw).toList();
    matches.sort((a, b) => b.group(0)!.length.compareTo(a.group(0)!.length));

    for (final match in matches) {
      try {
        final decoded = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        if (decoded.containsKey('tool')) return decoded;
      } catch (_) {}
    }

    return null;
  }
}

/// One turn in an MCP conversation.
class McpChatTurn {
  const McpChatTurn({required this.role, required this.text});
  final String role;
  final String text;
}
