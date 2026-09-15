class TeacherGuideNote {
  const TeacherGuideNote({
    required this.assignmentId,
    required this.guideItemId,
    required this.note,
    required this.canonicalPayloadSha256,
    required this.updatedAt,
  });

  final String assignmentId;
  final String guideItemId;
  final String note;
  final String canonicalPayloadSha256;
  final DateTime updatedAt;

  bool isStaleFor(String currentPayloadSha256) =>
      currentPayloadSha256.isNotEmpty &&
      canonicalPayloadSha256.isNotEmpty &&
      canonicalPayloadSha256 != currentPayloadSha256;
}
