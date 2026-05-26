import '../utils/fugrade_password.dart';
import 'fg_roster.dart';
import 'thesis_comment.dart';

class DeTaiRecord {
  DeTaiRecord({
    this.maDeTai = '',
    this.maNhom = '',
    this.titleEn = '',
    this.titleVn = '',
    this.danhGia = '',
    this.nhanXetSv = '',
    List<ThesisStudent>? students,
    this.teacher = '',
    this.subjectCode = '',
    this.className = '',
    this.semester = '',
    this.password = '',
    this.content = '',
    this.form = '',
    this.attitude = '',
    this.achievement = '',
    this.limitation = '',
    this.conclusion = '',
  }) : students = students ?? [];

  String maDeTai;
  String maNhom;
  String titleEn;
  String titleVn;
  String danhGia;
  String nhanXetSv;
  List<ThesisStudent> students;

  String teacher;
  String subjectCode;
  String className;
  String semester;
  String password;

  String content;
  String form;
  String attitude;
  String achievement;
  String limitation;
  String conclusion;

  String get displayTitle {
    if (titleVn.isNotEmpty) return titleVn;
    if (titleEn.isNotEmpty) return titleEn;
    return maDeTai.isNotEmpty ? maDeTai : '(Chưa có tên đề tài)';
  }

  void applySheetFields({
    required String maDeTai,
    required String maNhom,
    required String titleEn,
    required String titleVn,
    String danhGia = '',
    String nhanXetSv = '',
    String content = '',
    String form = '',
    String attitude = '',
    String achievement = '',
    String limitation = '',
  }) {
    this.maDeTai = maDeTai;
    this.maNhom = maNhom;
    this.titleEn = titleEn;
    this.titleVn = titleVn;
    this.danhGia = danhGia;
    this.nhanXetSv = nhanXetSv;
    if (content.isNotEmpty) this.content = content;
    if (form.isNotEmpty) this.form = form;
    if (attitude.isNotEmpty) this.attitude = attitude;
    if (achievement.isNotEmpty) {
      this.achievement = achievement;
    } else if (danhGia.isNotEmpty) {
      this.achievement = danhGia;
    }
    if (limitation.isNotEmpty) this.limitation = limitation;
    if (nhanXetSv.isNotEmpty && this.content.isEmpty) {
      this.content = nhanXetSv;
    }
  }

  void attachStudentsFromRoster(FgRoster roster) {
    teacher = roster.teacher;
    subjectCode = roster.subjectCode;
    className = roster.className;
    semester = roster.semester;
    if (password.isEmpty) password = roster.password;
    final resolved = roster.resolveGroupCode(maNhom) ?? maNhom;
    if (resolved.isNotEmpty && resolved != maNhom) {
      maNhom = resolved;
    }
    if (students.isEmpty) {
      students = roster
          .studentsInGroup(maNhom)
          .map((s) => s.toThesisStudent())
          .toList();
    } else {
      mergeStudentsWithRoster(roster);
    }
  }

  void mergeStudentsWithRoster(FgRoster roster) {
    final marksByRoll = <String, ThesisStudent>{};
    for (final s in students) {
      final k = s.roll.trim().toUpperCase();
      if (k.isNotEmpty) marksByRoll[k] = s;
    }
    final merged = roster.studentsInGroup(maNhom).map((fg) {
      final k = fg.roll.trim().toUpperCase();
      final prev = marksByRoll[k];
      return ThesisStudent(
        roll: fg.roll,
        name: fg.name,
        agreeToDefense: prev?.agreeToDefense ?? '',
        revisedForSecondDefense: prev?.revisedForSecondDefense ?? '',
        disagreeToDefense: prev?.disagreeToDefense ?? '',
        note: prev?.note ?? '',
      );
    }).toList();
    if (merged.isNotEmpty) students = merged;
  }

  ThesisComment toThesisComment() {
    return ThesisComment(
      teacher: teacher,
      dt: DateTime.now().toIso8601String(),
      subjectCode: subjectCode,
      className: className,
      semester: semester,
      password: FugradePassword.forCmtExport(password),
      titleVn: titleVn,
      titleEn: titleEn,
      content: content,
      form: form,
      attitude: attitude,
      achievement: achievement,
      limitation: limitation,
      conclusion: conclusion,
      students: List<ThesisStudent>.from(students),
    );
  }

  void updateFromThesis(ThesisComment t) {
    teacher = t.teacher;
    subjectCode = t.subjectCode;
    className = t.className;
    semester = t.semester;
    password = t.password;
    titleVn = t.titleVn;
    titleEn = t.titleEn;
    content = t.content;
    form = t.form;
    attitude = t.attitude;
    achievement = t.achievement;
    limitation = t.limitation;
    conclusion = t.conclusion;
    if (t.className.isNotEmpty && maNhom.isEmpty) {
      maNhom = t.className;
    }
    students = t.students
        .map(
          (s) => ThesisStudent(
            roll: s.roll,
            name: s.name,
            agreeToDefense: s.agreeToDefense,
            revisedForSecondDefense: s.revisedForSecondDefense,
            disagreeToDefense: s.disagreeToDefense,
            note: s.note,
          ),
        )
        .toList();
    if (nhanXetSv.isEmpty && content.isNotEmpty) nhanXetSv = content;
    if (danhGia.isEmpty && achievement.isNotEmpty) danhGia = achievement;
  }

  Map<String, dynamic> toJson() => {
        'maDeTai': maDeTai,
        'maNhom': maNhom,
        'titleEn': titleEn,
        'titleVn': titleVn,
        'danhGia': danhGia,
        'nhanXetSv': nhanXetSv,
        'teacher': teacher,
        'subjectCode': subjectCode,
        'className': className,
        'semester': semester,
        'password': password,
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

  factory DeTaiRecord.fromJson(Map<String, dynamic> j) => DeTaiRecord(
        maDeTai: j['maDeTai']?.toString() ?? '',
        maNhom: j['maNhom']?.toString() ?? '',
        titleEn: j['titleEn']?.toString() ?? '',
        titleVn: j['titleVn']?.toString() ?? '',
        danhGia: j['danhGia']?.toString() ?? '',
        nhanXetSv: j['nhanXetSv']?.toString() ?? '',
        teacher: j['teacher']?.toString() ?? '',
        subjectCode: j['subjectCode']?.toString() ?? '',
        className: j['className']?.toString() ?? '',
        semester: j['semester']?.toString() ?? '',
        password: j['password']?.toString() ?? '',
        content: j['content']?.toString() ?? '',
        form: j['form']?.toString() ?? '',
        attitude: j['attitude']?.toString() ?? '',
        achievement: j['achievement']?.toString() ?? '',
        limitation: j['limitation']?.toString() ?? '',
        conclusion: j['conclusion']?.toString() ?? '',
        students: (j['students'] as List<dynamic>? ?? [])
            .map(
              (e) => ThesisStudent(
                roll: e['roll']?.toString() ?? '',
                name: e['name']?.toString() ?? '',
                agreeToDefense: e['agreeToDefense']?.toString() ?? '',
                revisedForSecondDefense:
                    e['revisedForSecondDefense']?.toString() ?? '',
                disagreeToDefense: e['disagreeToDefense']?.toString() ?? '',
                note: e['note']?.toString() ?? '',
              ),
            )
            .toList(),
      );
}
