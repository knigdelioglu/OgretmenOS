import 'package:flutter/material.dart';

import '../../domain/models/course_models.dart' as model;
import '../../domain/repositories/course_knowledge_repository.dart';
import '../shared/feature_widgets.dart';

class RuntimeSpikePage extends StatefulWidget {
  const RuntimeSpikePage({super.key, required this.repository});

  final CourseKnowledgeRepository repository;

  @override
  State<RuntimeSpikePage> createState() => _RuntimeSpikePageState();
}

class _RuntimeSpikePageState extends State<RuntimeSpikePage> {
  late Future<_SpikeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SpikeData> _load() async {
    final manifest = await widget.repository.getManifest();
    final course = await widget.repository.getCourse();
    final themes = await widget.repository.getThemes();
    final sequence = await widget.repository.getAnnualSequence();
    if (themes.isEmpty) throw StateError('Runtime tema sorgusu boş döndü.');
    final selectedTheme = themes.length > 1 ? themes[1] : themes.first;
    final blocks = await widget.repository.getBlocks(selectedTheme.id);
    final blockDetail = blocks.isEmpty
        ? null
        : await widget.repository.getBlock(blocks.first.id);
    return _SpikeData(
      manifest: manifest,
      course: course,
      themes: themes,
      sequence: sequence,
      selectedTheme: selectedTheme,
      selectedThemeBlockCount: blocks.length,
      blockDetail: blockDetail,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Runtime doğrulama')),
    body: FutureBuilder<_SpikeData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return FeatureErrorView(
            message: 'Runtime doğrulama ekranı yüklenemedi.',
            onRetry: () {
              setState(() {
                _future = _load();
              });
            },
          );
        }
        final data = snapshot.data!;
        final detail = data.blockDetail;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const InfoCard(
              title: 'Geçici debug doğrulama ekranı',
              child: Text(
                'Bu ekran yalnız debug derlemesinde erişilebilir; üretim akışının parçası değildir.',
              ),
            ),
            InfoCard(
              title: 'Runtime paketi',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Course: ${data.manifest.courseId}'),
                  Text('Schema: ${data.manifest.schemaVersion}'),
                  Text('Package: ${data.manifest.runtimePackageVersion}'),
                  Text('Validation: ${data.manifest.validationStatus}'),
                  Text('Compatible: ${data.manifest.isCompatible}'),
                ],
              ),
            ),
            InfoCard(
              title: 'Gerçek sorgular',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kurs: ${data.course.title}'),
                  Text('Tema sayısı: ${data.themes.length}'),
                  Text('Yıllık sıra blok sayısı: ${data.sequence.length}'),
                  Text('Seçilen tema: ${data.selectedTheme.id}'),
                  Text(
                    'Seçilen tema blok sayısı: ${data.selectedThemeBlockCount}',
                  ),
                ],
              ),
            ),
            if (detail != null) ...[
              InfoCard(
                title: 'Gerçek ilişki kanıtı',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Blok: ${detail.block.id}'),
                    Text('Çıktı ilişkileri: ${detail.outcomes.length}'),
                    Text('Etkinlik ilişkileri: ${detail.activities.length}'),
                    Text('Kitap bölümleri: ${detail.textbookSections.length}'),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class _SpikeData {
  const _SpikeData({
    required this.manifest,
    required this.course,
    required this.themes,
    required this.sequence,
    required this.selectedTheme,
    required this.selectedThemeBlockCount,
    required this.blockDetail,
  });

  final model.RuntimeManifest manifest;
  final model.Course course;
  final List<model.Theme> themes;
  final List<model.TimelineEntry> sequence;
  final model.Theme selectedTheme;
  final int selectedThemeBlockCount;
  final model.BlockDetail? blockDetail;
}
