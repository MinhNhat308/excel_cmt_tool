import '../models/de_tai_record.dart';
import '../models/fg_roster.dart';
import '../models/project_bundle.dart';

class ProjectMergeService {
  ProjectBundle merge({
    required FgRoster roster,
    required List<DeTaiRecord> sheetTopics,
    String sheetUrl = '',
  }) {
    final topics = <DeTaiRecord>[];
    final matchedGroups = <String>{};

    for (final t in sheetTopics) {
      final copy = DeTaiRecord.fromJson(t.toJson());
      copy.attachStudentsFromRoster(roster);
      if (copy.students.isNotEmpty) {
        matchedGroups.add(FgRoster.normalizeGroupCode(copy.maNhom));
      }
      topics.add(copy);
    }

    for (final g in roster.groupCodes) {
      final ng = FgRoster.normalizeGroupCode(g);
      if (matchedGroups.contains(ng)) continue;
      final alreadyListed = topics.any((t) => FgRoster.groupsMatch(t.maNhom, g));
      if (alreadyListed) continue;
      final stub = DeTaiRecord(maNhom: g);
      stub.attachStudentsFromRoster(roster);
      topics.add(stub);
    }

    topics.sort((a, b) => a.maNhom.compareTo(b.maNhom));

    return ProjectBundle(
      roster: roster,
      topics: topics,
      sheetUrl: sheetUrl,
    );
  }

  List<String> unmatchedGroups(FgRoster roster, List<DeTaiRecord> topics) {
    final topicGroups = topics
        .map((t) => FgRoster.normalizeGroupCode(t.maNhom))
        .where((g) => g.isNotEmpty)
        .toSet();
    return roster.groupCodes
        .where((g) => !topicGroups.any((tg) => FgRoster.groupsMatch(tg, g)))
        .toList();
  }

  List<DeTaiRecord> topicsWithoutStudents(List<DeTaiRecord> topics) =>
      topics.where((t) => t.students.isEmpty).toList();
}
