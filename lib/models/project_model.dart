class StudentModel {
  final String roll;
  final String name;
  final String email;
  final String studentEvaluation;

  const StudentModel({
    required this.roll,
    required this.name,
    this.email = '',
    this.studentEvaluation = '',
  });

  StudentModel copyWith({
    String? roll,
    String? name,
    String? email,
    String? studentEvaluation,
  }) {
    return StudentModel(
      roll: roll ?? this.roll,
      name: name ?? this.name,
      email: email ?? this.email,
      studentEvaluation: studentEvaluation ?? this.studentEvaluation,
    );
  }

  Map<String, dynamic> toJson() => {
        'roll': roll,
        'name': name,
        'email': email,
        'student_evaluation': studentEvaluation,
      };

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      roll: json['roll']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      studentEvaluation: json['student_evaluation']?.toString() ?? '',
    );
  }
}

class StudentVerdictModel {
  final String roll;
  final bool agreeToDefense;
  final bool revisedForSecondDefense;
  final bool disagreeToDefense;
  final String note;

  const StudentVerdictModel({
    required this.roll,
    this.agreeToDefense = false,
    this.revisedForSecondDefense = false,
    this.disagreeToDefense = false,
    this.note = '',
  });

  StudentVerdictModel copyWith({
    String? roll,
    bool? agreeToDefense,
    bool? revisedForSecondDefense,
    bool? disagreeToDefense,
    String? note,
  }) {
    return StudentVerdictModel(
      roll: roll ?? this.roll,
      agreeToDefense: agreeToDefense ?? this.agreeToDefense,
      revisedForSecondDefense: revisedForSecondDefense ?? this.revisedForSecondDefense,
      disagreeToDefense: disagreeToDefense ?? this.disagreeToDefense,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'roll': roll,
        'agree_to_defense': agreeToDefense,
        'revised_for_second_defense': revisedForSecondDefense,
        'disagree_to_defense': disagreeToDefense,
        'note': note,
      };

  factory StudentVerdictModel.fromJson(Map<String, dynamic> json) {
    return StudentVerdictModel(
      roll: json['roll']?.toString() ?? '',
      agreeToDefense: json['agree_to_defense'] == true,
      revisedForSecondDefense: json['revised_for_second_defense'] == true,
      disagreeToDefense: json['disagree_to_defense'] == true,
      note: json['note']?.toString() ?? '',
    );
  }
}

class GvEvaluationModel {
  final String content;
  final String form;
  final String attitude;
  final String achievement;
  final String limitation;
  final String conclusion;
  final List<StudentVerdictModel> studentVerdicts;

  const GvEvaluationModel({
    this.content = '',
    this.form = '',
    this.attitude = '',
    this.achievement = '',
    this.limitation = '',
    this.conclusion = '',
    this.studentVerdicts = const [],
  });

  GvEvaluationModel copyWith({
    String? content,
    String? form,
    String? attitude,
    String? achievement,
    String? limitation,
    String? conclusion,
    List<StudentVerdictModel>? studentVerdicts,
  }) {
    return GvEvaluationModel(
      content: content ?? this.content,
      form: form ?? this.form,
      attitude: attitude ?? this.attitude,
      achievement: achievement ?? this.achievement,
      limitation: limitation ?? this.limitation,
      conclusion: conclusion ?? this.conclusion,
      studentVerdicts: studentVerdicts ?? this.studentVerdicts,
    );
  }

  Map<String, dynamic> toJson() => {
        'content': content,
        'form': form,
        'attitude': attitude,
        'achievement': achievement,
        'limitation': limitation,
        'conclusion': conclusion,
        'student_verdicts': studentVerdicts.map((e) => e.toJson()).toList(),
      };

  factory GvEvaluationModel.fromJson(Map<String, dynamic> json) {
    final list = json['student_verdicts'] as List?;
    return GvEvaluationModel(
      content: json['content']?.toString() ?? '',
      form: json['form']?.toString() ?? '',
      attitude: json['attitude']?.toString() ?? '',
      achievement: json['achievement']?.toString() ?? '',
      limitation: json['limitation']?.toString() ?? '',
      conclusion: json['conclusion']?.toString() ?? '',
      studentVerdicts: list != null
          ? list.map((e) => StudentVerdictModel.fromJson(e as Map<String, dynamic>)).toList()
          : const [],
    );
  }
}

class ProjectModel {
  final String topicCode;
  final String groupCode;
  final String titleVn;
  final String titleEn;
  final List<StudentModel> students;
  final GvEvaluationModel gvEvaluation;
  final String validationStatus; // VALID, MISSING_DATA, DUPLICATE, TOPIC_CONFLICT
  final bool hasTitleConflict;
  final String conflictDetails; // Ghi chi tiết sai lệch tên đề tài từ SV

  const ProjectModel({
    required this.topicCode,
    required this.groupCode,
    this.titleVn = '',
    this.titleEn = '',
    this.students = const [],
    this.gvEvaluation = const GvEvaluationModel(),
    this.validationStatus = 'MISSING_DATA',
    this.hasTitleConflict = false,
    this.conflictDetails = '',
  });

  ProjectModel copyWith({
    String? topicCode,
    String? groupCode,
    String? titleVn,
    String? titleEn,
    List<StudentModel>? students,
    GvEvaluationModel? gvEvaluation,
    String? validationStatus,
    bool? hasTitleConflict,
    String? conflictDetails,
  }) {
    return ProjectModel(
      topicCode: topicCode ?? this.topicCode,
      groupCode: groupCode ?? this.groupCode,
      titleVn: titleVn ?? this.titleVn,
      titleEn: titleEn ?? this.titleEn,
      students: students ?? this.students,
      gvEvaluation: gvEvaluation ?? this.gvEvaluation,
      validationStatus: validationStatus ?? this.validationStatus,
      hasTitleConflict: hasTitleConflict ?? this.hasTitleConflict,
      conflictDetails: conflictDetails ?? this.conflictDetails,
    );
  }

  Map<String, dynamic> toJson() => {
        'topic_code': topicCode,
        'group_code': groupCode,
        'title_vn': titleVn,
        'title_en': titleEn,
        'students': students.map((e) => e.toJson()).toList(),
        'gv_evaluation': gvEvaluation.toJson(),
        // Không lưu conflict state vào file — sẽ tái tính khi import lại
      };

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    final listStudents = json['students'] as List?;
    final gvEval = json['gv_evaluation'] as Map<String, dynamic>?;
    return ProjectModel(
      topicCode: json['topic_code']?.toString() ?? '',
      groupCode: json['group_code']?.toString() ?? '',
      titleVn: json['title_vn']?.toString() ?? '',
      titleEn: json['title_en']?.toString() ?? '',
      students: listStudents != null
          ? listStudents.map((e) => StudentModel.fromJson(e as Map<String, dynamic>)).toList()
          : const [],
      gvEvaluation: gvEval != null
          ? GvEvaluationModel.fromJson(gvEval)
          : const GvEvaluationModel(),
    );
  }
}
