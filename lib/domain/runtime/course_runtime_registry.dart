enum CourseDataMode { fullRuntime, curriculumOnly }

class CourseRuntimeDescriptor {
  const CourseRuntimeDescriptor({
    required this.subjectId,
    required this.subjectLabel,
    required this.courseId,
    required this.grade,
    required this.label,
    required this.packageRoot,
    required this.dataMode,
    required this.textbookStatus,
  });

  final String subjectId;
  final String subjectLabel;
  final String courseId;
  final int grade;
  final String label;
  final String packageRoot;
  final CourseDataMode dataMode;
  final String textbookStatus;

  String get runtimeRoot => '$packageRoot/runtime';
  String get manifestAsset => '$runtimeRoot/runtime_manifest.json';
  String get databaseAsset => '$runtimeRoot/course_runtime.sqlite';
  String get validationReportAsset => '$runtimeRoot/runtime_validation_report.md';
  String get packageManifestAsset => '$packageRoot/package_manifest.json';

  bool get isCurriculumOnly => dataMode == CourseDataMode.curriculumOnly;
  bool get hasOfficialTextbook => textbookStatus == 'AVAILABLE';
  bool get isAwaitingTextbook => textbookStatus == 'AWAITING_OFFICIAL_TEXTBOOK';
}

const _tdeRoot = 'tymm-verileri/turk-dili-ve-edebiyati';

const supportedCourseRuntimes = <CourseRuntimeDescriptor>[
  CourseRuntimeDescriptor(
    subjectId: 'turk-dili-ve-edebiyati',
    subjectLabel: 'Türk Dili ve Edebiyatı',
    courseId: 'TDE_9',
    grade: 9,
    label: '9. Sınıf Türk Dili ve Edebiyatı',
    packageRoot: '$_tdeRoot/TDE_9',
    dataMode: CourseDataMode.fullRuntime,
    textbookStatus: 'AVAILABLE',
  ),
  CourseRuntimeDescriptor(
    subjectId: 'turk-dili-ve-edebiyati',
    subjectLabel: 'Türk Dili ve Edebiyatı',
    courseId: 'TDE_10',
    grade: 10,
    label: '10. Sınıf Türk Dili ve Edebiyatı',
    packageRoot: '$_tdeRoot/TDE_10',
    dataMode: CourseDataMode.fullRuntime,
    textbookStatus: 'AVAILABLE',
  ),
  CourseRuntimeDescriptor(
    subjectId: 'turk-dili-ve-edebiyati',
    subjectLabel: 'Türk Dili ve Edebiyatı',
    courseId: 'TDE_11',
    grade: 11,
    label: '11. Sınıf Türk Dili ve Edebiyatı',
    packageRoot: '$_tdeRoot/TDE_11',
    dataMode: CourseDataMode.curriculumOnly,
    textbookStatus: 'AWAITING_OFFICIAL_TEXTBOOK',
  ),
  CourseRuntimeDescriptor(
    subjectId: 'turk-dili-ve-edebiyati',
    subjectLabel: 'Türk Dili ve Edebiyatı',
    courseId: 'TDE_12',
    grade: 12,
    label: '12. Sınıf Türk Dili ve Edebiyatı',
    packageRoot: '$_tdeRoot/TDE_12',
    dataMode: CourseDataMode.curriculumOnly,
    textbookStatus: 'AWAITING_OFFICIAL_TEXTBOOK',
  ),
];

bool isSupportedRuntimeCourse(String courseId) =>
    supportedCourseRuntimes.any((course) => course.courseId == courseId);

CourseRuntimeDescriptor runtimeForCourse(String courseId) =>
    supportedCourseRuntimes.firstWhere(
      (course) => course.courseId == courseId,
      orElse: () =>
          throw StateError('Desteklenmeyen ders runtime kimliği: $courseId'),
    );
