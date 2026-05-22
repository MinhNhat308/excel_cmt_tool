import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project_model.dart';
import '../utils/fuzzy_matcher.dart';
import 'fg_service.dart';
import 'survey_import_service.dart';

class ProjectListState {
  final List<ProjectModel> projects;
  final String teacher;
  final String semester;
  final String subjectCode;
  final String className;
  final String filePath;
  final String fgPassword;
  final bool isLoading;
  final String? error;

  const ProjectListState({
    this.projects = const [],
    this.teacher = '',
    this.semester = '',
    this.subjectCode = '',
    this.className = '',
    this.filePath = '',
    this.fgPassword = '1',
    this.isLoading = false,
    this.error,
  });

  ProjectListState copyWith({
    List<ProjectModel>? projects,
    String? teacher,
    String? semester,
    String? subjectCode,
    String? className,
    String? filePath,
    String? fgPassword,
    bool? isLoading,
    String? error,
  }) {
    return ProjectListState(
      projects: projects ?? this.projects,
      teacher: teacher ?? this.teacher,
      semester: semester ?? this.semester,
      subjectCode: subjectCode ?? this.subjectCode,
      className: className ?? this.className,
      filePath: filePath ?? this.filePath,
      fgPassword: fgPassword ?? this.fgPassword,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ProjectNotifier extends StateNotifier<ProjectListState> {
  final _fgService = FgService();

  ProjectNotifier() : super(const ProjectListState());

  // Thiết lập toàn bộ danh sách dự án
  void setProjects(List<ProjectModel> projects) {
    state = state.copyWith(projects: projects);
    _validateAllProjects();
  }

  // Cập nhật thông tin chung (metadata)
  void updateMetadata({
    String? teacher,
    String? semester,
    String? subjectCode,
    String? className,
    String? fgPassword,
  }) {
    state = state.copyWith(
      teacher: teacher ?? state.teacher,
      semester: semester ?? state.semester,
      subjectCode: subjectCode ?? state.subjectCode,
      className: className ?? state.className,
      fgPassword: fgPassword ?? state.fgPassword,
    );
  }

  // Thêm một dự án mới
  void addProject(ProjectModel project) {
    state = state.copyWith(
      projects: [...state.projects, project],
    );
    _validateAllProjects();
  }

  // Xóa một dự án theo index
  void removeProject(int index) {
    if (index < 0 || index >= state.projects.length) return;
    final updated = List<ProjectModel>.from(state.projects)..removeAt(index);
    state = state.copyWith(projects: updated);
    _validateAllProjects();
  }

  // Cập nhật dự án tại index
  void updateProject(int index, ProjectModel updatedProject) {
    if (index < 0 || index >= state.projects.length) return;
    final updated = List<ProjectModel>.from(state.projects);
    updated[index] = updatedProject;
    state = state.copyWith(projects: updated);
    _validateAllProjects();
  }

  // Cập nhật nhanh các thuộc tính của một dự án
  void updateProjectField(
    int index, {
    String? topicCode,
    String? groupCode,
    String? titleVn,
    String? titleEn,
  }) {
    if (index < 0 || index >= state.projects.length) return;
    final updated = List<ProjectModel>.from(state.projects);
    final current = updated[index];
    updated[index] = current.copyWith(
      topicCode: topicCode ?? current.topicCode,
      groupCode: groupCode ?? current.groupCode,
      titleVn: titleVn ?? current.titleVn,
      titleEn: titleEn ?? current.titleEn,
    );
    state = state.copyWith(projects: updated);
    _validateAllProjects();
  }

  // Thêm sinh viên vào một dự án
  void addStudentToProject(int projectIndex, StudentModel student) {
    if (projectIndex < 0 || projectIndex >= state.projects.length) return;
    final updated = List<ProjectModel>.from(state.projects);
    final p = updated[projectIndex];
    updated[projectIndex] = p.copyWith(
      students: [...p.students, student],
    );
    state = state.copyWith(projects: updated);
    _validateAllProjects();
  }

  // Xóa sinh viên khỏi một dự án
  void removeStudentFromProject(int projectIndex, int studentIndex) {
    if (projectIndex < 0 || projectIndex >= state.projects.length) return;
    final updated = List<ProjectModel>.from(state.projects);
    final p = updated[projectIndex];
    if (studentIndex < 0 || studentIndex >= p.students.length) return;
    final updatedStudents = List<StudentModel>.from(p.students)..removeAt(studentIndex);
    updated[projectIndex] = p.copyWith(students: updatedStudents);
    state = state.copyWith(projects: updated);
    _validateAllProjects();
  }

  // Cập nhật thông tin sinh viên trong một dự án
  void updateStudentInProject(int projectIndex, int studentIndex, StudentModel updatedStudent) {
    if (projectIndex < 0 || projectIndex >= state.projects.length) return;
    final updated = List<ProjectModel>.from(state.projects);
    final p = updated[projectIndex];
    if (studentIndex < 0 || studentIndex >= p.students.length) return;
    final updatedStudents = List<StudentModel>.from(p.students);
    updatedStudents[studentIndex] = updatedStudent;
    updated[projectIndex] = p.copyWith(students: updatedStudents);
    state = state.copyWith(projects: updated);
    _validateAllProjects();
  }

  /// Nhập dữ liệu khảo sát sinh viên và ghép nối vào danh sách dự án.
  /// - Cập nhật Email và StudentEvaluation của từng SV theo Roll.
  /// - Dùng FuzzyMatcher so khớp tên đề tài (ngưỡng 90%).
  /// - Gắn cờ hasTitleConflict nếu tên đề tài lệch > 10%.
  void importStudentSurveys(List<SurveyRow> surveys) {
    // Tạo bảng tra nhanh: Roll → SurveyRow
    final byRoll = <String, SurveyRow>{
      for (final s in surveys) s.roll.toUpperCase(): s,
    };

    final updated = List<ProjectModel>.from(state.projects);

    for (var pi = 0; pi < updated.length; pi++) {
      final project = updated[pi];
      bool projectHasConflict = false;
      final conflictLines = <String>[];

      // Cập nhật thông tin từng sinh viên trong dự án
      final updatedStudents = project.students.map((student) {
        final survey = byRoll[student.roll.toUpperCase()];
        if (survey == null) return student;
        return student.copyWith(
          email: survey.email.isNotEmpty ? survey.email : student.email,
          studentEvaluation: survey.studentEval.isNotEmpty
              ? survey.studentEval
              : student.studentEvaluation,
        );
      }).toList();

      // Kiểm tra xung đột tên đề tài theo sinh viên đại diện đầu tiên có survey
      for (final student in project.students) {
        final survey = byRoll[student.roll.toUpperCase()];
        if (survey == null) continue;

        // So khớp tên tiếng Việt
        if (project.titleVn.isNotEmpty && survey.titleVn.isNotEmpty) {
          final simVn = FuzzyMatcher.getSimilarityPercent(project.titleVn, survey.titleVn);
          if (simVn < 90) {
            projectHasConflict = true;
            conflictLines.add(
              '[VN] Gốc: "${project.titleVn}"\n'
              '     SV nhập: "${survey.titleVn}" ($simVn%)',
            );
          }
        }

        // So khớp tên tiếng Anh
        if (project.titleEn.isNotEmpty && survey.titleEn.isNotEmpty) {
          final simEn = FuzzyMatcher.getSimilarityPercent(project.titleEn, survey.titleEn);
          if (simEn < 90) {
            projectHasConflict = true;
            conflictLines.add(
              '[EN] Gốc: "${project.titleEn}"\n'
              '     SV nhập: "${survey.titleEn}" ($simEn%)',
            );
          }
        }

        // Chỉ cần kiểm tra một SV đại diện là đủ (vì cùng nhóm có cùng đề tài)
        break;
      }

      updated[pi] = project.copyWith(
        students: updatedStudents,
        hasTitleConflict: projectHasConflict,
        conflictDetails: conflictLines.join('\n'),
      );
    }

    state = state.copyWith(projects: updated);
    _validateAllProjects();
  }

  /// Đồng bộ tên đề tài theo tên sinh viên khai báo trong khảo sát.
  void syncTitleFromSurvey(int projectIndex, {String? newTitleVn, String? newTitleEn}) {
    if (projectIndex < 0 || projectIndex >= state.projects.length) return;
    final updated = List<ProjectModel>.from(state.projects);
    final p = updated[projectIndex];
    updated[projectIndex] = p.copyWith(
      titleVn: newTitleVn ?? p.titleVn,
      titleEn: newTitleEn ?? p.titleEn,
      hasTitleConflict: false,
      conflictDetails: '',
    );
    state = state.copyWith(projects: updated);
    _validateAllProjects();
  }

  // Lưu dữ liệu vào file hiện tại
  Future<bool> saveToCurrentFile() async {
    if (state.filePath.isEmpty) return false;
    return saveToNewFile(state.filePath);
  }

  // Lưu dữ liệu vào một file mới
  Future<bool> saveToNewFile(String path, {String? password}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final activePassword = password ?? state.fgPassword;
      await _fgService.saveToFile(
        filePath: path,
        teacher: state.teacher,
        semester: state.semester,
        subjectCode: state.subjectCode,
        className: state.className,
        projects: state.projects,
        password: activePassword,
      );
      state = state.copyWith(isLoading: false, filePath: path, fgPassword: activePassword);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Không thể lưu file: $e');
      return false;
    }
  }

  // Mở và tải dữ liệu từ file .fg
  bool loadFromFgFile(String path, String password) {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = _fgService.loadFromFile(path, password);
      final meta = data['metadata'] as Map<String, dynamic>? ?? {};
      final list = data['projects'] as List? ?? [];
      final projects = list.map((e) => ProjectModel.fromJson(e as Map<String, dynamic>)).toList();

      state = ProjectListState(
        projects: projects,
        teacher: meta['teacher']?.toString() ?? '',
        semester: meta['semester']?.toString() ?? '',
        subjectCode: meta['subject_code']?.toString() ?? '',
        className: meta['class_name']?.toString() ?? '',
        filePath: path,
        fgPassword: password,
        isLoading: false,
      );
      _validateAllProjects();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Khóa bảo mật không chính xác hoặc tệp lỗi: $e');
      return false;
    }
  }

  // Kiểm duyệt và gắn trạng thái Validation cho các dự án (Mục 7 đặc tả)
  void _validateAllProjects() {
    final updated = <ProjectModel>[];
    final allRolls = <String>{};
    final duplicates = <String>{};

    // Bước 1: Quét trùng lặp sinh viên (cùng Roll_number trong các nhóm)
    for (final p in state.projects) {
      for (final s in p.students) {
        if (s.roll.isNotEmpty) {
          if (allRolls.contains(s.roll)) {
            duplicates.add(s.roll);
          } else {
            allRolls.add(s.roll);
          }
        }
      }
    }

    // Bước 2: Đánh giá trạng thái từng dự án
    for (final p in state.projects) {
      var status = 'VALID';

      // Điều kiện 1: Trùng lặp sinh viên nộp bài
      final hasDuplicate = p.students.any((s) => duplicates.contains(s.roll));
      
      // Điều kiện 2: Thiếu dữ liệu
      final missingTeacherComment = p.gvEvaluation.content.isEmpty ||
          p.gvEvaluation.form.isEmpty ||
          p.gvEvaluation.attitude.isEmpty ||
          p.gvEvaluation.achievement.isEmpty ||
          p.gvEvaluation.limitation.isEmpty;
          
      final missingStudentReviews = p.students.isEmpty;

      if (hasDuplicate) {
        status = 'DUPLICATE';
      } else if (p.hasTitleConflict || p.topicCode.isEmpty || p.groupCode.isEmpty) {
        // hasTitleConflict được gắn cờ bởi importStudentSurveys khi fuzzy < 90%
        status = 'TOPIC_CONFLICT';
      } else if (missingTeacherComment || missingStudentReviews) {
        status = 'MISSING_DATA';
      }

      updated.add(p.copyWith(validationStatus: status));
    }

    // Cập nhật trạng thái mới mà không tạo vòng lặp vô hạn
    state = state.copyWith(projects: updated);
  }
}

// Khai báo Provider dùng trong toàn ứng dụng
final projectListProvider = StateNotifierProvider<ProjectNotifier, ProjectListState>((ref) {
  return ProjectNotifier();
});
