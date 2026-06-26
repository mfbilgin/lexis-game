import '../services/firestore_service.dart';

class BadgeCondition {
  final String metric;
  final int threshold;

  const BadgeCondition({required this.metric, required this.threshold});

  bool isMet(UserStats? stats) {
    if (stats == null) return false;
    switch (metric) {
      case 'gamesWon':
        return stats.gamesWon >= threshold;
      case 'currentStreak':
        return stats.currentStreak >= threshold;
      case 'totalScore':
        return stats.totalScore >= threshold;
      case 'gamesPlayed':
        return stats.gamesPlayed >= threshold;
      default:
        return false;
    }
  }

  factory BadgeCondition.fromJson(Map<String, dynamic> json) {
    return BadgeCondition(
      metric: json['metric'] as String? ?? '',
      threshold: json['threshold'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'metric': metric,
    'threshold': threshold,
  };
}

/// Badge definition with localized name/description and unlock condition
class BadgeDefinition {
  final String id;
  final String emoji;
  final Map<String, String> name;
  final Map<String, String> description;
  final BadgeCondition condition;

  const BadgeDefinition({
    required this.id,
    required this.emoji,
    required this.name,
    required this.description,
    required this.condition,
  });

  String getName(String locale) => name[locale] ?? name['tr'] ?? id;
  String getDescription(String locale) => description[locale] ?? description['tr'] ?? '';

  bool isUnlocked(UserStats? stats) => condition.isMet(stats);

  factory BadgeDefinition.fromJson(Map<String, dynamic> json, String documentId) {
    return BadgeDefinition(
      id: documentId,
      emoji: json['emoji'] as String? ?? '🏆',
      name: Map<String, String>.from(json['name'] as Map? ?? {}),
      description: Map<String, String>.from(json['description'] as Map? ?? {}),
      condition: BadgeCondition.fromJson(json['condition'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'emoji': emoji,
    'name': name,
    'description': description,
    'condition': condition.toJson(),
  };
}
