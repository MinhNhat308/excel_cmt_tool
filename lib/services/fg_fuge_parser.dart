import '../models/fg_roster.dart';

class FgFugeParser {
  const FgFugeParser({
    this.thesisSubjectsOnly = true,
    this.subjectPrefixes = const ['SEP'],
  });

  final bool thesisSubjectsOnly;
  final List<String> subjectPrefixes;

  FgRoster parseTeacherGradeJson(
    Map<String, dynamic> root, {
    required String sourcePath,
  }) {
    final students = <FgStudent>[];
    final classes = root['SubjectClassGrades'] as List<dynamic>? ?? [];

    for (final entry in classes) {
      final sc = Map<String, dynamic>.from(entry as Map);
      final subject = sc['Subject']?.toString() ?? '';
      if (thesisSubjectsOnly &&
          !subjectPrefixes.any(
            (p) => subject.toUpperCase().startsWith(p.toUpperCase()),
          )) {
        continue;
      }
      final groupCode = sc['Class']?.toString() ?? '';
      final list = sc['Students'] as List<dynamic>? ?? [];
      for (final st in list) {
        final sm = Map<String, dynamic>.from(st as Map);
        final roll = sm['Roll']?.toString() ?? '';
        final name = sm['Name']?.toString() ?? '';
        if (roll.isEmpty && name.isEmpty) continue;
        students.add(
          FgStudent(roll: roll, name: name, groupCode: groupCode),
        );
      }
    }

    return FgRoster(
      teacher: root['Login']?.toString() ?? '',
      subjectCode: _firstSubject(classes),
      className: '',
      semester: root['Semester']?.toString() ?? '',
      password: root['Password']?.toString() ?? '',
      students: students,
      sourcePath: sourcePath,
      fuGradePayload: root,
      version: root['Version']?.toString() ?? '',
    );
  }

  String _firstSubject(List<dynamic> classes) {
    for (final entry in classes) {
      final sc = Map<String, dynamic>.from(entry as Map);
      final subject = sc['Subject']?.toString() ?? '';
      if (thesisSubjectsOnly &&
          !subjectPrefixes.any(
            (p) => subject.toUpperCase().startsWith(p.toUpperCase()),
          )) {
        continue;
      }
      if (subject.isNotEmpty) return subject;
    }
    if (classes.isEmpty) return '';
    return Map<String, dynamic>.from(classes.first as Map)['Subject']
            ?.toString() ??
        '';
  }
}
