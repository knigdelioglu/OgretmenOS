import 'package:sqflite/sqflite.dart';

import '../../domain/models/teacher_guide_note_models.dart';
import '../../domain/repositories/teacher_guide_notes_repository.dart';

class SqfliteTeacherGuideNotesRepository
    implements TeacherGuideNotesRepository {
  const SqfliteTeacherGuideNotesRepository(this._database);

  final Database _database;

  @override
  Future<TeacherGuideNote?> get({
    required String assignmentId,
    required String guideItemId,
  }) async {
    final rows = await _database.query(
      'assignment_teacher_guide_notes',
      where: 'assignment_id = ? AND guide_item_id = ?',
      whereArgs: [assignmentId, guideItemId],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<void> save(TeacherGuideNote note) async {
    if (note.assignmentId.trim().isEmpty || note.guideItemId.trim().isEmpty) {
      throw ArgumentError('Öğretmen rehberi not kapsamı boş olamaz.');
    }
    if (note.canonicalPayloadSha256.trim().isEmpty) {
      throw ArgumentError('Öğretmen rehberi canonical hash eksik.');
    }
    final assignment = await _database.query(
      'teaching_assignments',
      columns: ['assignment_id'],
      where: 'assignment_id = ?',
      whereArgs: [note.assignmentId],
      limit: 1,
    );
    if (assignment.isEmpty) {
      throw StateError('Not için ders ataması bulunamadı.');
    }
    await _database.insert(
      'assignment_teacher_guide_notes',
      {
        'assignment_id': note.assignmentId,
        'guide_item_id': note.guideItemId,
        'note': note.note,
        'canonical_payload_sha256': note.canonicalPayloadSha256,
        'updated_at': note.updatedAt.toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  TeacherGuideNote _fromRow(Map<String, Object?> row) => TeacherGuideNote(
    assignmentId: row['assignment_id']! as String,
    guideItemId: row['guide_item_id']! as String,
    note: row['note']! as String,
    canonicalPayloadSha256: row['canonical_payload_sha256']! as String,
    updatedAt: DateTime.parse(row['updated_at']! as String).toLocal(),
  );
}
