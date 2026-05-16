export 'habit_models.dart';
export 'food_models.dart';

class WorkoutEntry {
  WorkoutEntry({
    required this.id,
    required this.type,
    required this.durationMin,
    required this.calories,
    required this.source,
    required this.timestamp,
  });

  final String id;
  final String type;
  final int durationMin;
  final int calories;
  final String source;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'durationMin': durationMin,
    'calories': calories,
    'source': source,
    'timestamp': timestamp.toIso8601String(),
  };

  factory WorkoutEntry.fromJson(Map<String, dynamic> json) => WorkoutEntry(
    id: json['id'] as String,
    type: json['type'] as String,
    durationMin: json['durationMin'] as int,
    calories: json['calories'] as int,
    source: json['source'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

class NoteItem {
  NoteItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.aiSummary,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String body;
  final String? aiSummary;
  final List<String> tags;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'aiSummary': aiSummary,
    'tags': tags,
    'createdAt': createdAt.toIso8601String(),
  };

  factory NoteItem.fromJson(Map<String, dynamic> json) => NoteItem(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    aiSummary: json['aiSummary'] as String?,
    tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class SavedReel {
  SavedReel({
    required this.id,
    required this.url,
    required this.caption,
    required this.savedAt,
    this.thumbnailPath,
    this.aiTags = const [],
  });

  final String id;
  final String url;
  final String caption;
  final DateTime savedAt;
  final String? thumbnailPath;
  final List<String> aiTags;

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'caption': caption,
    'savedAt': savedAt.toIso8601String(),
    'thumbnailPath': thumbnailPath,
    'aiTags': aiTags,
  };

  factory SavedReel.fromJson(Map<String, dynamic> json) => SavedReel(
    id: json['id'] as String,
    url: json['url'] as String,
    caption: json['caption'] as String,
    savedAt: DateTime.parse(json['savedAt'] as String),
    thumbnailPath: json['thumbnailPath'] as String?,
    aiTags: (json['aiTags'] as List<dynamic>? ?? []).cast<String>(),
  );
}
