import 'package:flutter/material.dart';

import '../../domain/models/course_models.dart' as model;
import '../../domain/repositories/course_knowledge_repository.dart';
import '../shared/feature_widgets.dart';

class BookFirstPage extends StatefulWidget {
  const BookFirstPage({
    super.key,
    required this.repository,
    this.initialThemeId,
  });

  final CourseKnowledgeRepository repository;
  final String? initialThemeId;

  @override
  State<BookFirstPage> createState() => _BookFirstPageState();
}

class _BookFirstPageState extends State<BookFirstPage> {
  String? _selectedThemeId;
  late Future<_BookFirstData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BookFirstData> _load() async {
    final themes = await widget.repository.getThemes();
    if (themes.isEmpty) {
      return const _BookFirstData(
        themes: [],
        decisions: [],
        selectedThemeId: null,
      );
    }
    final selectedId = _selectedThemeId ?? widget.initialThemeId;
    final selectedTheme = themes.any((theme) => theme.id == selectedId)
        ? selectedId!
        : themes.first.id;
    final decisions = await widget.repository.getResourceDecisions(
      selectedTheme,
    );
    return _BookFirstData(
      themes: themes,
      decisions: decisions,
      selectedThemeId: selectedTheme,
    );
  }

  void _selectTheme(String themeId) {
    setState(() {
      _selectedThemeId = themeId;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kitap-Önce')),
    body: FutureBuilder<_BookFirstData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return FeatureErrorView(
            message: 'Kaynak kararları yüklenemedi.',
            onRetry: () {
              setState(() {
                _future = _load();
              });
            },
          );
        }
        final data = snapshot.data!;
        if (data.themes.isEmpty || data.selectedThemeId == null) {
          return const Center(
            child: UnresolvedText(label: 'Tema verisi bulunmuyor.'),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text(
              'Bu görünüm, runtime paketindeki kaynak kararlarını gösterir. Uygulama kendi pedagojik kararını üretmez.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: data.selectedThemeId,
              decoration: const InputDecoration(
                labelText: 'Tema',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final theme in data.themes)
                  DropdownMenuItem<String>(
                    value: theme.id,
                    child: Text(theme.title),
                  ),
              ],
              onChanged: (value) {
                if (value != null) _selectTheme(value);
              },
            ),
            SectionHeading('Runtime kaynak kararları'),
            if (data.decisions.isEmpty)
              const InfoCard(
                title: 'Karar bulunmuyor',
                child: UnresolvedText(
                  label:
                      'Seçili tema için doğrulanmış kaynak kararı bulunmuyor.',
                ),
              )
            else
              for (final decision in data.decisions)
                ResourceDecisionCard(decision: decision),
          ],
        );
      },
    ),
  );
}

class _BookFirstData {
  const _BookFirstData({
    required this.themes,
    required this.decisions,
    required this.selectedThemeId,
  });

  final List<model.Theme> themes;
  final List<model.ResourceDecision> decisions;
  final String? selectedThemeId;
}
