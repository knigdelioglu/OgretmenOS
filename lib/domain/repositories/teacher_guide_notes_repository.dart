import '../models/teacher_guide_note_models.dart';

abstract interface class TeacherGuideNotesRepository {
  Future<TeacherGuideNote?> get({
    required String assignmentId,
    required String guideItemId,
  });

  Future<void> save(TeacherGuideNote note);
}
