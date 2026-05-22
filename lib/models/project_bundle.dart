import 'de_tai_record.dart';
import 'fg_roster.dart';

class ProjectBundle {
  const ProjectBundle({
    this.roster,
    this.topics = const [],
    this.sheetUrl = '',
    this.savedAt,
  });

  final FgRoster? roster;
  final List<DeTaiRecord> topics;
  final String sheetUrl;
  final DateTime? savedAt;

  bool get isReady => roster != null && topics.isNotEmpty;

  int get matchedTopicCount =>
      topics.where((t) => t.students.isNotEmpty).length;

  Map<String, dynamic> toJson() => {
        'version': 1,
        'sheetUrl': sheetUrl,
        'savedAt': savedAt?.toIso8601String(),
        'roster': roster?.toJson(),
        'topics': topics.map((e) => e.toJson()).toList(),
      };

  factory ProjectBundle.fromJson(Map<String, dynamic> j) => ProjectBundle(
        sheetUrl: j['sheetUrl']?.toString() ?? '',
        savedAt: j['savedAt'] != null
            ? DateTime.tryParse(j['savedAt'].toString())
            : null,
        roster: j['roster'] != null
            ? FgRoster.fromJson(
                Map<String, dynamic>.from(j['roster'] as Map),
              )
            : null,
        topics: (j['topics'] as List<dynamic>? ?? [])
            .map(
              (e) => DeTaiRecord.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
      );
}
