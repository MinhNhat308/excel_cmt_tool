import 'thesis_comment.dart';

class FgStudent {
  const FgStudent({
    required this.roll,
    required this.name,
    required this.groupCode,
  });

  final String roll;
  final String name;
  final String groupCode;

  Map<String, dynamic> toJson() => {
        'roll': roll,
        'name': name,
        'groupCode': groupCode,
      };

  factory FgStudent.fromJson(Map<String, dynamic> j) => FgStudent(
        roll: j['roll']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        groupCode: j['groupCode']?.toString() ?? '',
      );

  ThesisStudent toThesisStudent() => ThesisStudent(
        roll: roll,
        name: name,
      );
}

class FgRoster {
  const FgRoster({
    this.teacher = '',
    this.subjectCode = '',
    this.className = '',
    this.semester = '',
    this.password = '',
    this.students = const [],
    this.sourcePath = '',
    this.version = '',
    this.fuGradePayload,
  });

  final String teacher;
  final String subjectCode;
  final String className;
  final String semester;
  final String password;
  final List<FgStudent> students;
  final String sourcePath;
  final String version;
  final Map<String, dynamic>? fuGradePayload;

  List<String> get groupCodes {
    final set = <String>{};
    for (final s in students) {
      final g = normalizeGroupCode(s.groupCode);
      if (g.isNotEmpty) set.add(g);
    }
    return set.toList()..sort();
  }

  List<FgStudent> studentsInGroup(String code) {
    final n = normalizeGroupCode(code);
    return students
        .where((s) => normalizeGroupCode(s.groupCode) == n)
        .toList();
  }

  static String normalizeGroupCode(String code) =>
      code.trim().toUpperCase();

  static bool groupsMatch(String a, String b) {
    final x = normalizeGroupCode(a);
    final y = normalizeGroupCode(b);
    if (x.isEmpty || y.isEmpty) return false;
    if (x == y) return true;
    if (x.endsWith('_$y') || y.endsWith('_$x')) return true;
    final xTail = x.contains('_') ? x.split('_').last : x;
    final yTail = y.contains('_') ? y.split('_').last : y;
    if (xTail == yTail && xTail.length >= 3) return true;
    return false;
  }

  String? resolveGroupCode(String code) {
    final n = normalizeGroupCode(code);
    if (n.isEmpty) return null;
    for (final g in groupCodes) {
      if (groupsMatch(g, n)) return g;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'teacher': teacher,
        'subjectCode': subjectCode,
        'className': className,
        'semester': semester,
        'password': password,
        'students': students.map((e) => e.toJson()).toList(),
        'sourcePath': sourcePath,
        'version': version,
        if (fuGradePayload != null) 'fuGradePayload': fuGradePayload,
      };

  factory FgRoster.fromJson(Map<String, dynamic> j) => FgRoster(
        teacher: j['teacher']?.toString() ?? '',
        subjectCode: j['subjectCode']?.toString() ?? '',
        className: j['className']?.toString() ?? '',
        semester: j['semester']?.toString() ?? '',
        password: j['password']?.toString() ?? '',
        sourcePath: j['sourcePath']?.toString() ?? '',
        version: j['version']?.toString() ?? '',
        fuGradePayload: j['fuGradePayload'] != null
            ? Map<String, dynamic>.from(j['fuGradePayload'] as Map)
            : null,
        students: (j['students'] as List<dynamic>? ?? [])
            .map((e) => FgStudent.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
