/// Maps habit names and keywords to relevant emojis.
/// Call [emojiForHabit] with the habit name to get the best matching emoji.
class HabitEmojiMapper {
  static const _mappings = <String, String>{
    // Water & drinks
    'water': '💧',
    'drink': '💧',
    'hydrate': '💧',
    'coffee': '☕',
    'tea': '🍵',
    'juice': '🧃',
    'alcohol': '🍷',
    'beer': '🍺',
    'wine': '🍷',
    'soda': '🥤',

    // Exercise & fitness
    'run': '🏃',
    'running': '🏃',
    'jog': '🏃',
    'walk': '🚶',
    'walking': '🚶',
    'gym': '💪',
    'workout': '💪',
    'exercise': '💪',
    'lift': '🏋️',
    'weights': '🏋️',
    'yoga': '🧘',
    'stretch': '🧘',
    'swim': '🏊',
    'swimming': '🏊',
    'cycle': '🚴',
    'bike': '🚴',
    'cycling': '🚴',
    'sport': '⚽',
    'sports': '⚽',
    'soccer': '⚽',
    'basketball': '🏀',
    'tennis': '🎾',
    'golf': '⛳',
    'hike': '🥾',
    'hiking': '🥾',
    'climb': '🧗',
    'climbing': '🧗',
    'dance': '💃',
    'martial': '🥋',
    'box': '🥊',
    'boxing': '🥊',

    // Mind & wellness
    'meditate': '🧘',
    'meditation': '🧘',
    'mindful': '🧘',
    'breathe': '🫁',
    'journal': '📓',
    'diary': '📓',
    'gratitude': '🙏',
    'pray': '🙏',
    'affirmation': '✨',
    'read': '📖',
    'reading': '📖',
    'book': '📖',
    'learn': '🎓',
    'study': '🎓',
    'course': '🎓',
    'skill': '🎯',
    'language': '🗣️',
    'piano': '🎹',
    'guitar': '🎸',
    'music': '🎵',
    'instrument': '🎵',
    'art': '🎨',
    'draw': '🎨',
    'paint': '🎨',
    'write': '✍️',
    'writing': '✍️',
    'blog': '✍️',
    'code': '💻',
    'coding': '💻',
    'program': '💻',
    'chess': '♟️',
    'puzzle': '🧩',

    // Health & body
    'vitamin': '💊',
    'vitamins': '💊',
    'medicine': '💊',
    'meds': '💊',
    'pill': '💊',
    'supplement': '💊',
    'sleep': '😴',
    'bed': '😴',
    'nap': '😴',
    'wake': '⏰',
    'shower': '🚿',
    'bathe': '🛁',
    'brush': '🪥',
    'teeth': '🪥',
    'floss': '🦷',
    'skin': '🧴',
    'moisturize': '🧴',
    'sunscreen': '☀️',
    'massage': '💆',
    'sauna': '🧖',
    'cold': '🥶',
    'plunge': '🥶',

    // Food & diet
    'eat': '🍽️',
    'food': '🍽️',
    'meal': '🍽️',
    'cook': '👨‍🍳',
    'cooking': '👨‍🍳',
    'prep': '👨‍🍳',
    'breakfast': '🍳',
    'lunch': '🥪',
    'dinner': '🍜',
    'snack': '🍿',
    'fruit': '🍎',
    'vegetable': '🥦',
    'veggie': '🥦',
    'salad': '🥗',
    'protein': '🥩',
    'meat': '🥩',
    'sugar': '🍬',
    'sweets': '🍬',
    'fast': '⏳',
    'fasting': '⏳',

    // Productivity
    'work': '💼',
    'job': '💼',
    'career': '💼',
    'focus': '🎯',
    'deep': '🎯',
    'pomodoro': '🍅',
    'timer': '⏱️',
    'plan': '📝',
    'schedule': '📝',
    'organize': '📂',
    'clean': '🧹',
    'tidy': '🧹',
    'declutter': '🗑️',
    'laundry': '👕',
    'dishes': '🍽️',
    'garden': '🌱',
    'plant': '🌱',
    'water plant': '🌱',
    'email': '📧',
    'inbox': '📧',
    'call': '📞',
    'network': '🤝',
    'meet': '🤝',

    // Relationships & social
    'family': '👨‍👩‍👧‍👦',
    'partner': '❤️',
    'spouse': '❤️',
    'date': '❤️',
    'friend': '👥',
    'social': '👥',
    'call mom': '📞',
    'call dad': '📞',
    'text': '💬',
    'message': '💬',
    'compliment': '💖',
    'kindness': '💖',
    'volunteer': '🤲',
    'help': '🤲',
    'donate': '💰',

    // Money & finance
    'save': '💰',
    'budget': '💰',
    'invest': '📈',
    'expense': '💳',
    'track money': '💳',
    'no buy': '🚫',
    'spend': '💸',

    // Screen & digital
    'phone': '📱',
    'screen': '📱',
    'social media': '📱',
    'instagram': '📱',
    'tiktok': '📱',
    'netflix': '📺',
    'tv': '📺',
    'game': '🎮',
    'gaming': '🎮',
    'scroll': '📱',
    'news': '📰',
    'podcast': '🎧',
    'audiobook': '🎧',

    // Nature & outdoors
    'sun': '☀️',
    'sunlight': '☀️',
    'outside': '🌳',
    'nature': '🌳',
    'park': '🌳',
    'forest': '🌲',
    'beach': '🏖️',
    'camp': '⛺',
    'star': '⭐',
    'moon': '🌙',

    // Misc
    'posture': '🪑',
    'stand': '🧍',
    'sit': '🪑',
    'walk dog': '🐕',
    'pet': '🐕',
    'cat': '🐈',
    'dog': '🐕',
  };

  /// Returns the best emoji for a habit name.
  /// Falls back to ✅ if no match found.
  static String emojiForHabit(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.isEmpty) return '✅';

    // Exact match
    if (_mappings.containsKey(lower)) return _mappings[lower]!;

    // Keyword match — find the longest matching keyword
    String? bestEmoji;
    var bestLen = 0;
    for (final entry in _mappings.entries) {
      if (lower.contains(entry.key)) {
        if (entry.key.length > bestLen) {
          bestLen = entry.key.length;
          bestEmoji = entry.value;
        }
      }
    }

    return bestEmoji ?? '✅';
  }
}
