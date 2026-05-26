class ThesisStudent {
  ThesisStudent({
    this.roll = '',
    this.name = '',
    this.agreeToDefense = '',
    this.revisedForSecondDefense = '',
    this.disagreeToDefense = '',
    this.note = '',
  });

  String roll;
  String name;
  String agreeToDefense;
  String revisedForSecondDefense;
  String disagreeToDefense;
  String note;

  bool get isEmpty => roll.isEmpty && name.isEmpty;

  bool get hasDefenseMark =>
      isDefenseMark(agreeToDefense) ||
      isDefenseMark(revisedForSecondDefense) ||
      isDefenseMark(disagreeToDefense);

  static bool isDefenseMark(String v) {
    final t = v.trim().toLowerCase();
    return t == 'x';
  }

  static String? normalizeDefenseMark(String input) {
    final t = input.trim();
    if (t.isEmpty) return '';
    if (t == 'x' || t == 'X') return 'x';
    return null;
  }

  ThesisStudent copyWith({
    String? roll,
    String? name,
    String? agreeToDefense,
    String? revisedForSecondDefense,
    String? disagreeToDefense,
    String? note,
  }) =>
      ThesisStudent(
        roll: roll ?? this.roll,
        name: name ?? this.name,
        agreeToDefense: agreeToDefense ?? this.agreeToDefense,
        revisedForSecondDefense:
            revisedForSecondDefense ?? this.revisedForSecondDefense,
        disagreeToDefense: disagreeToDefense ?? this.disagreeToDefense,
        note: note ?? this.note,
      );
}

class ThesisComment {
  ThesisComment({
    this.teacher = '',
    this.dt = '',
    this.subjectCode = '',
    this.className = '',
    this.semester = '',
    this.password = '',
    this.titleVn = '',
    this.titleEn = '',
    this.content = '',
    this.form = '',
    this.attitude = '',
    this.achievement = '',
    this.limitation = '',
    this.conclusion = '',
    List<ThesisStudent>? students,
  }) : students = students ?? [];

  String teacher;
  String dt;
  String subjectCode;
  String className;
  String semester;
  String password;
  String titleVn;
  String titleEn;
  String content;
  String form;
  String attitude;
  String achievement;
  String limitation;
  String conclusion;
  List<ThesisStudent> students;

  bool get hasStudents => students.isNotEmpty;

  factory ThesisComment.fromExportJson(Map<String, dynamic> j) {
    final list = <ThesisStudent>[];
    for (final e in j['students'] as List<dynamic>? ?? []) {
      final m = Map<String, dynamic>.from(e as Map);
      list.add(
        ThesisStudent(
          roll: m['roll']?.toString() ?? '',
          name: m['name']?.toString() ?? '',
          agreeToDefense: m['agreeToDefense']?.toString() ?? '',
          revisedForSecondDefense:
              m['revisedForSecondDefense']?.toString() ?? '',
          disagreeToDefense: m['disagreeToDefense']?.toString() ?? '',
          note: m['note']?.toString() ?? '',
        ),
      );
    }
    return ThesisComment(
      teacher: j['teacher']?.toString() ?? '',
      dt: j['dt']?.toString() ?? '',
      subjectCode: j['subjectCode']?.toString() ?? '',
      className: j['className']?.toString() ?? '',
      semester: j['semester']?.toString() ?? '',
      password: j['password']?.toString() ?? '',
      titleVn: j['titleVn']?.toString() ?? '',
      titleEn: j['titleEn']?.toString() ?? '',
      content: j['content']?.toString() ?? '',
      form: j['form']?.toString() ?? '',
      attitude: j['attitude']?.toString() ?? '',
      achievement: j['achievement']?.toString() ?? '',
      limitation: j['limitation']?.toString() ?? '',
      conclusion: j['conclusion']?.toString() ?? '',
      students: list,
    );
  }

  Map<String, dynamic> toExportJson() => {
        'teacher': teacher,
        'dt': dt,
        'subjectCode': subjectCode,
        'className': className,
        'semester': semester,
        'password': password,
        'titleVn': titleVn,
        'titleEn': titleEn,
        'content': content,
        'form': form,
        'attitude': attitude,
        'achievement': achievement,
        'limitation': limitation,
        'conclusion': conclusion,
        'students': students
            .map(
              (s) => {
                'roll': s.roll,
                'name': s.name,
                'agreeToDefense': s.agreeToDefense,
                'revisedForSecondDefense': s.revisedForSecondDefense,
                'disagreeToDefense': s.disagreeToDefense,
                'note': s.note,
              },
            )
            .toList(),
      };

  String toPreviewText() {
    final buf = StringBuffer();
    buf.writeln('NHẬN XÉT KHÓA LUẬN (NHÓM)');
    buf.writeln('—'.padRight(48, '—'));
    if (teacher.isNotEmpty) buf.writeln('Giảng viên: $teacher');
    if (subjectCode.isNotEmpty) buf.writeln('Mã môn: $subjectCode');
    if (className.isNotEmpty) buf.writeln('Lớp: $className');
    if (semester.isNotEmpty) buf.writeln('Học kỳ: $semester');
    buf.writeln();
    if (titleVn.isNotEmpty) buf.writeln('Tên KL (VN): $titleVn');
    if (titleEn.isNotEmpty) buf.writeln('Tên KL (EN): $titleEn');
    if (content.isNotEmpty) buf.writeln('Nội dung: $content');
    if (form.isNotEmpty) buf.writeln('Hình thức: $form');
    if (attitude.isNotEmpty) buf.writeln('Thái độ: $attitude');
    if (achievement.isNotEmpty) buf.writeln('Mức độ đạt: $achievement');
    if (limitation.isNotEmpty) buf.writeln('Hạn chế: $limitation');
    if (conclusion.isNotEmpty) buf.writeln('Kết luận: $conclusion');
    buf.writeln();
    buf.writeln('SINH VIÊN (${students.length})');
    for (var i = 0; i < students.length; i++) {
      final s = students[i];
      buf.writeln('${i + 1}. ${s.roll} — ${s.name}');
    }
    return buf.toString().trim();
  }
}
