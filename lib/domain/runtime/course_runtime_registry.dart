class CourseRuntimeDescriptor {
  const CourseRuntimeDescriptor({
    required this.courseId,
    required this.grade,
    required this.label,
    required this.assetRoot,
  });

  final String courseId;
  final int grade;
  final String label;
  final String assetRoot;

  String get manifestAsset => '$assetRoot/runtime_manifest.json';
  String get databaseAsset => '$assetRoot/course_runtime.sqlite';
  String get validationReportAsset => '$assetRoot/runtime_validation_report.md';
}

const supportedCourseRuntimes = <CourseRuntimeDescriptor>[
  CourseRuntimeDescriptor(
    courseId: 'TDE_9',
    grade: 9,
    label: '9. Sınıf Türk Dili ve Edebiyatı',
    assetRoot: 'assets/courses/TDE_9',
  ),
  CourseRuntimeDescriptor(
    courseId: 'TDE_10',
    grade: 10,
    label: '10. Sınıf Türk Dili ve Edebiyatı',
    assetRoot: 'assets/courses/TDE_10',
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
