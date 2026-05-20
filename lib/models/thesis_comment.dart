class ThesisStudent {
  const ThesisStudent({
    required this.roll,
    required this.name,
    this.agreeToDefense = 'x',
    this.revisedForSecondDefense = '',
    this.disagreeToDefense = '',
    this.note = '',
  });

  final String roll;
  final String name;
  final String agreeToDefense;
  final String revisedForSecondDefense;
  final String disagreeToDefense;
  final String note;

  bool get isEmpty => roll.isEmpty && name.isEmpty;
}

class ThesisComment {
  const ThesisComment({
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
    this.students = const [],
  });

  final String teacher;
  final String dt;
  final String subjectCode;
  final String className;
  final String semester;
  final String password;
  final String titleVn;
  final String titleEn;
  final String content;
  final String form;
  final String attitude;
  final String achievement;
  final String limitation;
  final String conclusion;
  final List<ThesisStudent> students;

  bool get hasStudents => students.isNotEmpty;

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
