from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    path.write_text(text.replace(old, new, 1))


# 1) Convenience continuity parsing must never turn malformed optional fields
# into a crash.
continuity_repo = Path('lib/data/preferences/continuity_repository.dart')
replace_once(
    continuity_repo,
    """    final updatedAt = json['updated_at'];
    if (courseId is! String ||
        academicYear is! String ||
        weekNumber is! int ||
        trackingKey is! String ||
        outcomeCode is! String ||
        updatedAt is! String) {
      return null;
    }
    final parsedUpdatedAt = DateTime.tryParse(updatedAt);
    if (parsedUpdatedAt == null) return null;
    return LastFocusState(
      courseId: courseId,
      academicYear: academicYear,
      weekNumber: weekNumber,
      trackingKey: trackingKey,
      outcomeCode: outcomeCode,
      themeTitle: json['theme_title'] as String?,
      blockId: json['block_id'] as String?,
      blockTitle: json['block_title'] as String?,
      updatedAt: parsedUpdatedAt,
    );
""",
    """    final updatedAt = json['updated_at'];
    final themeTitle = json['theme_title'];
    final blockId = json['block_id'];
    final blockTitle = json['block_title'];
    if (courseId is! String ||
        academicYear is! String ||
        weekNumber is! int ||
        trackingKey is! String ||
        outcomeCode is! String ||
        updatedAt is! String ||
        (themeTitle != null && themeTitle is! String) ||
        (blockId != null && blockId is! String) ||
        (blockTitle != null && blockTitle is! String)) {
      return null;
    }
    final parsedUpdatedAt = DateTime.tryParse(updatedAt);
    if (parsedUpdatedAt == null) return null;
    return LastFocusState(
      courseId: courseId,
      academicYear: academicYear,
      weekNumber: weekNumber,
      trackingKey: trackingKey,
      outcomeCode: outcomeCode,
      themeTitle: themeTitle as String?,
      blockId: blockId as String?,
      blockTitle: blockTitle as String?,
      updatedAt: parsedUpdatedAt,
    );
""",
    'safe optional continuity fields',
)
replace_once(
    continuity_repo,
    """  Future<LastFocusState?> getLastFocus(String courseId) async {
    final key = _key(courseId);
    final raw = _preferences.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await _preferences.remove(key);
        return null;
      }
      final state = LastFocusState.fromJson(decoded);
      if (state == null || state.courseId != courseId) {
        await _preferences.remove(key);
        return null;
      }
      return state;
    } on FormatException {
      await _preferences.remove(key);
      return null;
    }
  }
""",
    """  Future<LastFocusState?> getLastFocus(String courseId) async {
    final key = _key(courseId);
    try {
      final raw = _preferences.getString(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await _removeBestEffort(key);
        return null;
      }
      final state = LastFocusState.fromJson(decoded);
      if (state == null || state.courseId != courseId) {
        await _removeBestEffort(key);
        return null;
      }
      return state;
    } on Object {
      // Continuity is convenience state. Corruption or preference read errors
      // must never block authoritative lesson content.
      await _removeBestEffort(key);
      return null;
    }
  }

  Future<void> _removeBestEffort(String key) async {
    try {
      await _preferences.remove(key);
    } on Object {
      // A failed cleanup may leave stale convenience state, but it must not
      // turn a non-authoritative preference into an app failure.
    }
  }
""",
    'best effort continuity repository read',
)

# 2) This Week must load the authoritative plan even if continuity storage is
# unavailable or stale cleanup fails.
continuity_page = Path('lib/features/this_week/continuity_this_week_page.dart')
replace_once(
    continuity_page,
    """  Future<_ContinuityData> _load() async {
    final results = await Future.wait<Object?>([
      widget.service.buildPlan(),
      widget.continuity.getLastFocus(widget.courseId),
    ]);
    final plan = results[0] as AnnualOutcomePlan;
    final stored = results[1] as LastFocusState?;
    if (stored == null) return _ContinuityData(plan: plan);
    if (stored.academicYear != plan.academicYear) {
      await widget.continuity.clearLastFocus(widget.courseId);
      return _ContinuityData(plan: plan);
    }

    final item = _resolveFocus(plan, stored);
    if (item == null) {
      await widget.continuity.clearLastFocus(widget.courseId);
      return _ContinuityData(plan: plan);
    }
    return _ContinuityData(plan: plan, stored: stored, item: item);
  }
""",
    """  Future<_ContinuityData> _load() async {
    final plan = await widget.service.buildPlan();
    final stored = await _readLastFocusBestEffort();
    if (stored == null) return _ContinuityData(plan: plan);
    if (stored.academicYear != plan.academicYear) {
      await _clearLastFocusBestEffort();
      return _ContinuityData(plan: plan);
    }

    final item = _resolveFocus(plan, stored);
    if (item == null) {
      await _clearLastFocusBestEffort();
      return _ContinuityData(plan: plan);
    }
    return _ContinuityData(plan: plan, stored: stored, item: item);
  }

  Future<LastFocusState?> _readLastFocusBestEffort() async {
    try {
      return await widget.continuity.getLastFocus(widget.courseId);
    } on Object {
      return null;
    }
  }

  Future<void> _clearLastFocusBestEffort() async {
    try {
      await widget.continuity.clearLastFocus(widget.courseId);
    } on Object {
      // Stale continuity cleanup must never block the weekly workspace.
    }
  }
""",
    'weekly continuity resilience',
)

# 3) Canonicalize tracking identity once for projection, persistence and annual
# summaries.
models = Path('lib/domain/models/outcome_tracking_models.dart')
text = models.read_text()
anchor = "import 'weekly_plan_models.dart';\n\n"
if text.count(anchor) != 1:
    raise SystemExit('tracking key function anchor mismatch')
text = text.replace(
    anchor,
    anchor
    + "String outcomeTrackingKey({\n"
    + "  required String academicYear,\n"
    + "  required String outcomeId,\n"
    + "  required int plannedWeekNumber,\n"
    + "}) => '$academicYear:$outcomeId:$plannedWeekNumber';\n\n",
    1,
)
text = text.replace(
    "  final DateTime updatedAt;\n\n  LearningOutcomeTrackingRecord copyWith({",
    "  final DateTime updatedAt;\n\n"
    "  String get trackingKey => outcomeTrackingKey(\n"
    "    academicYear: academicYear,\n"
    "    outcomeId: outcomeId,\n"
    "    plannedWeekNumber: plannedWeekNumber,\n"
    "  );\n\n"
    "  LearningOutcomeTrackingRecord copyWith({",
    1,
)
text = text.replace(
    "  String get trackingKey => '$academicYear:${outcome.id}:$plannedWeekNumber';",
    "  String get trackingKey => outcomeTrackingKey(\n"
    "    academicYear: academicYear,\n"
    "    outcomeId: outcome.id,\n"
    "    plannedWeekNumber: plannedWeekNumber,\n"
    "  );",
    1,
)
models.write_text(text)

service = Path('lib/domain/services/outcome_planning_service.dart')
text = service.read_text()
text = text.replace(
    'for (final record in records) _recordKey(record): record,',
    'for (final record in records) record.trackingKey: record,',
)
text = text.replace(
    'final key = _key(weeklyPlan.academicYear, outcome.id, week.weekNumber);',
    "final key = outcomeTrackingKey(\n"
    "          academicYear: weeklyPlan.academicYear,\n"
    "          outcomeId: outcome.id,\n"
    "          plannedWeekNumber: week.weekNumber,\n"
    "        );",
)
text = text.replace('baseByKey[_recordKey(record)]', 'baseByKey[record.trackingKey]')
text = text.replace('_recordKey(record) == item.trackingKey', 'record.trackingKey == item.trackingKey')
old_helpers = """  String _recordKey(LearningOutcomeTrackingRecord record) => _key(
    record.academicYear,
    record.outcomeId,
    record.plannedWeekNumber,
  );

  String _key(String year, String outcomeId, int week) => '$year:$outcomeId:$week';

"""
if text.count(old_helpers) != 1:
    raise SystemExit('service tracking helper mismatch')
text = text.replace(old_helpers, '', 1)
service.write_text(text)

# 4) Annual convenience reads are best-effort; explicit marker writes show a
# recoverable user-facing error instead of leaking an async exception.
annual = Path('lib/features/annual_plan/annual_plan_page.dart')
text = annual.read_text()
text = text.replace(
    "import '../shared/feature_widgets.dart';",
    "import '../shared/feature_widgets.dart';\nimport '../shared/interaction_polish.dart';",
    1,
)
text = text.replace(
    "    final manual = await _getManualPosition();\n    final lastFocus = await widget.continuity.getLastFocus(widget.courseId);",
    "    final manual = await _getManualPositionBestEffort();\n"
    "    final lastFocus = await _getLastFocusBestEffort();",
    1,
)
text = text.replace(
    "              '${record.academicYear}:${record.outcomeId}:${record.plannedWeekNumber}',",
    '              record.trackingKey,',
    1,
)
old_get = """  Future<ManualPositionOverrideState?> _getManualPosition() async {
    final preferences = widget.preferences;
    if (preferences is ScopedManualPositionPreferences) {
      return (preferences as ScopedManualPositionPreferences)
          .getManualPositionOverrideForCourse(widget.courseId);
    }
    final blockId = await preferences.getManualPositionOverride();
    if (blockId == null) return null;
    return ManualPositionOverrideState(
      courseId: widget.courseId,
      blockId: blockId,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
"""
new_get = """  Future<ManualPositionOverrideState?> _getManualPositionBestEffort() async {
    try {
      final preferences = widget.preferences;
      if (preferences is ScopedManualPositionPreferences) {
        return await (preferences as ScopedManualPositionPreferences)
            .getManualPositionOverrideForCourse(widget.courseId);
      }
      final blockId = await preferences.getManualPositionOverride();
      if (blockId == null) return null;
      return ManualPositionOverrideState(
        courseId: widget.courseId,
        blockId: blockId,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    } on Object {
      return null;
    }
  }

  Future<LastFocusState?> _getLastFocusBestEffort() async {
    try {
      return await widget.continuity.getLastFocus(widget.courseId);
    } on Object {
      return null;
    }
  }
"""
if text.count(old_get) != 1:
    raise SystemExit('annual preference getter mismatch')
text = text.replace(old_get, new_get, 1)
old_actions = """  Future<void> _setPosition(String blockId) async {
    await _setPositionPreference(blockId);
    if (mounted) _reload();
  }

  Future<void> _clearPosition() async {
    await _clearPositionPreference();
    if (mounted) _reload();
  }
"""
new_actions = """  Future<void> _setPosition(String blockId) async {
    try {
      await _setPositionPreference(blockId);
      if (mounted) _reload();
    } on Object {
      if (mounted) {
        showTeacherFeedback(context, 'Geçici konum işareti kaydedilemedi.');
      }
    }
  }

  Future<void> _clearPosition() async {
    try {
      await _clearPositionPreference();
      if (mounted) _reload();
    } on Object {
      if (mounted) {
        showTeacherFeedback(context, 'Geçici konum işareti temizlenemedi.');
      }
    }
  }
"""
if text.count(old_actions) != 1:
    raise SystemExit('annual action mismatch')
text = text.replace(old_actions, new_actions, 1)
annual.write_text(text)

# 5) Regression coverage for the newly audited failure modes.
continuity_test = Path('test/continuity_test.dart')
text = continuity_test.read_text()
marker = "\n}\n\nclass _FakeRepository implements CourseKnowledgeRepository {"
if text.count(marker) != 1:
    raise SystemExit('continuity test insertion marker mismatch')
addition = r'''

  test('malformed optional continuity fields are ignored instead of throwing', () async {
    SharedPreferences.setMockInitialValues({
      'last_focus_v1_TDE_9':
          '{"course_id":"TDE_9","academic_year":"2026-2027","week_number":1,'
          '"tracking_key":"2026-2027:TEST_OUTCOME:1","outcome_code":"TEST.1",'
          '"theme_title":42,"updated_at":"2026-09-14T10:00:00.000"}',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesContinuityRepository(preferences);

    expect(await repository.getLastFocus('TDE_9'), isNull);
    expect(preferences.getString('last_focus_v1_TDE_9'), isNull);
  });

  testWidgets('continuity read failure does not block the weekly lesson workspace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeRepository();
    final service = OutcomePlanningService(
      repository: repository,
      weeklyPlanning: _FakeWeeklyPlanning(),
      trackingRepository: MemoryOutcomeTrackingRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContinuityThisWeekPage(
            repository: repository,
            service: service,
            continuity: const _FailingContinuityRepository(),
            courseId: 'TDE_9',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ŞİMDİ'), findsOneWidget);
    expect(find.text('TEST.1'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Ders ayrıntısını aç'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
'''
text = text.replace(marker, addition + marker, 1)
text += r'''

class _FailingContinuityRepository implements ContinuityRepository {
  const _FailingContinuityRepository();

  @override
  Future<LastFocusState?> getLastFocus(String courseId) =>
      Future<LastFocusState?>.error(StateError('continuity unavailable'));

  @override
  Future<void> setLastFocus(LastFocusState state) =>
      Future<void>.error(StateError('continuity unavailable'));

  @override
  Future<void> clearLastFocus(String courseId) =>
      Future<void>.error(StateError('continuity unavailable'));
}
'''
continuity_test.write_text(text)

annual_test = Path('test/adhd_phase5_annual_continuity_test.dart')
text = annual_test.read_text()
marker = "\n}\n\nfinal _oldFocusTime = DateTime.utc(2020, 1, 1);"
if text.count(marker) != 1:
    raise SystemExit('annual test insertion marker mismatch')
addition = r'''

  testWidgets('convenience preference failures do not block the annual plan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnnualPlanPage(
            repository: _Repository(),
            preferences: _FailingPreferences(),
            continuity: _FailingAnnualContinuity(),
            courseId: 'TDE_9',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1 tema · 45 saat · 2 blok'), findsOneWidget);
    expect(find.text('Test Tema'), findsOneWidget);
    expect(find.text('ŞU AN BURADASIN'), findsNothing);
    expect(tester.takeException(), isNull);
  });
'''
text = text.replace(marker, addition + marker, 1)
text += r'''

class _FailingPreferences implements UserPreferencesRepository {
  const _FailingPreferences();

  @override
  Future<String?> getManualPositionOverride() =>
      Future<String?>.error(StateError('preferences unavailable'));

  @override
  Future<void> setManualPositionOverride(String blockId) =>
      Future<void>.error(StateError('preferences unavailable'));

  @override
  Future<void> clearManualPositionOverride() =>
      Future<void>.error(StateError('preferences unavailable'));
}

class _FailingAnnualContinuity implements ContinuityRepository {
  const _FailingAnnualContinuity();

  @override
  Future<LastFocusState?> getLastFocus(String courseId) =>
      Future<LastFocusState?>.error(StateError('continuity unavailable'));

  @override
  Future<void> setLastFocus(LastFocusState state) =>
      Future<void>.error(StateError('continuity unavailable'));

  @override
  Future<void> clearLastFocus(String courseId) =>
      Future<void>.error(StateError('continuity unavailable'));
}
'''
annual_test.write_text(text)

Path('test/tracking_identity_test.dart').write_text(r'''import 'package:flutter_test/flutter_test.dart';
import 'package:ogretmen_os/domain/models/outcome_tracking_models.dart';

void main() {
  test('tracking identity uses one canonical encoding', () {
    final record = LearningOutcomeTrackingRecord(
      academicYear: '2026-2027',
      outcomeId: 'OUTCOME_1',
      plannedWeekNumber: 7,
      status: OutcomeTrackingStatus.completed,
      updatedAt: DateTime(2026, 10, 1),
    );

    expect(
      record.trackingKey,
      outcomeTrackingKey(
        academicYear: '2026-2027',
        outcomeId: 'OUTCOME_1',
        plannedWeekNumber: 7,
      ),
    );
    expect(record.trackingKey, '2026-2027:OUTCOME_1:7');
  });
}
''')

# 6) Binding product/governance docs must describe the product that actually
# ships after Faz 0-6, otherwise future agents are instructed to regress it.
Path('docs/PRODUCT_SCOPE.md').write_text(r'''# PRODUCT_SCOPE.md — ÖğretmenOS V1.3

**Product:** ÖğretmenOS  
**Document version:** 1.3.0  
**Status:** Binding Product Scope Authority  
**Implementation:** Flutter + Dart + Material 3  
**Operation mode:** Offline-first, deterministic, local

## 1. Product definition

ÖğretmenOS öğretmenin derse girerken **şu anki ders bağlamını mümkün olan en az karar yüküyle** görmesini sağlar. Birincil akış:

```text
uygulamayı aç
→ Bu Hafta / ŞİMDİ
→ ders bağlamını ve gerekli doğrulanmış bilgiyi gör
→ gerekirse ayrıntı/kaynak aç
→ çık
```

**Tracking isteğe bağlıdır.** Bir kazanımı görüntülemek, derse hazırlanmak veya uygulamadan çıkmak için `Başla`, `İşlendi` ya da başka bir tracking durumu zorunlu değildir.

## 2. Authority and truth boundary

Authority order:

```text
1. PRODUCT_SCOPE.md
2. FLUTTER_BLUEPRINT.md
3. AGENT.md
```

Canonical TYMM knowledge yalnız doğrulanmış runtime paketinden gelir:

```text
Canonical TYMM Knowledge
→ deterministic runtime compiler
→ course_runtime.sqlite
→ read-only CourseKnowledgeRepository
```

Uygulama runtime outcome/theme/block/textbook/activity/assessment ilişkilerini değiştirmez veya uydurmaz.

## 3. Primary navigation

Top-level navigation yalnız üç öğretmen işidir:

```text
Bu Hafta
Yıllık
Kaynaklar
```

Default surface `Bu Hafta`dır.

Legacy `Kazanımlar / Haftalık / Paket` ekranları top-level ürün navigasyonu değildir. Tracking, haftalık ders akışının ikincil/isteğe bağlı bir özelliğidir.

## 4. Bu Hafta — single focus contract

`Bu Hafta` tek baskın `ŞİMDİ` odağı sunar. Birincil CTA:

```text
Ders ayrıntısını aç
```

Varsayılan `planned` durumu kullanıcıya eksik iş, ilerleme veya yapılacaklar listesi gibi sunulmaz. Explicit öğretmen durumları yalnız kullanıcı gerçekten işaretlediyse `Takip: ...` olarak görünür.

İsteğe bağlı işlemler:

```text
Devam ediyor olarak işaretle
İşlendi olarak işaretle
Kısmen işlendi
sonraki öğretim haftasına taşı
hızlı öğretmen notu
```

Bu işlemler ana CTA değildir.

## 5. Continuity / Kaldığın Yer

`LastFocusState` **son görüntülenen ders bağlamıdır**, tracking durumu değildir.

- outcome detail açılması continuity kaydını günceller;
- status değişikliği continuity oluşturmaz veya silmez;
- `completed` olmak son görüntülenen dersi yok etmez;
- continuity okuma/yazma/temizleme hatası ana ders içeriğini bloke edemez;
- stale veya bozuk continuity state güvenle yok sayılır.

## 6. Ders ayrıntısı

Ders ayrıntısı bilgi-first yüzeydir. `Derste lazım` bölümü official outcome, hafta/blok/tema, kitap/etkinlik ipuçları ve varsa öğretmen notunu öne çıkarır.

Tracking kontrolleri yalnız `Daha fazla bilgi → Takip seçenekleri` altında bulunur. Varsayılan durum `İsteğe bağlı · Takip yok` olarak sunulur.

Öğretmen notu otomatik kaydolur; kayıt başarısızsa sessiz veri kaybına izin verilmez ve sayfadan çıkış engellenir.

## 7. Kaynaklar

Kaynak ekranı tema 1'e körlemesine sıfırlanmaz. Bağlam önceliği:

```text
1. son görüntülenen ders
2. mevcut öğretim haftası
3. güvenli ilk-tema fallback
```

Bağlam convenience state'tir; okunamazsa kaynak erişimi yine çalışır. Manuel tema seçimi ekranda kalındığı sürece korunur; sekmeye yeniden girişte güncel ders bağlamı tekrar çözülür.

## 8. Yıllık plan

Yıllık plan canonical öğretim sırasını gösterir. `ŞU AN BURADASIN` konumu:

```text
son görüntülenen ders
veya daha yeni geçici manuel konum işareti
```

Manuel işaret course-scoped ve geçicidir; daha sonra açılan yeni ders odağı eski manuel işareti otomatik geçersiz kılar.

**Konum ilerleme değildir.** Blok sırası yüzde/tamamlanma progress bar'ına dönüştürülemez.

Tracking kullanılmışsa ayrı `İSTEĞE BAĞLI TAKİP` özeti yalnız açıkça işaretlenen statü adetlerini gösterebilir. İşaretlenmemiş kazanımlar eksik sayılmaz ve denominator/yüzde üretilmez.

## 9. Teacher-local mutable state

Canonical runtime'dan ayrı tutulur:

```text
teacher_state.sqlite
  learning_outcome_tracking

SharedPreferences
  last viewed lesson continuity
  course-scoped temporary annual marker
  UI preferences
```

Tracking record alanları:

```text
academic_year
outcome_id
planned_week_number
status
actual_hours (optional)
teacher_note (optional)
completed_at (optional)
carried_to_week_number (optional)
updated_at
```

## 10. Tracking semantics

Valid storage states:

```text
planned
in_progress
completed
partially_completed
carried_over
```

`planned` domain/storage fallback'ıdır; kullanıcıya otomatik ilerleme borcu olarak gösterilmez. Canonical schedule ve classroom tracking iki ayrı gerçektir.

Carry-over canonical planned week'i değiştirmez, EVENT_WEEK'e hedeflenemez ve aynı original tracking identity üzerinden yürür.

## 11. Calendar/runtime invariants

Aktif TDE_9 2026-2027 profilinde:

```text
weekly_hours = 5
annual_hours = 180
theme_count = 4
theme_hours = 45
structured_theme_hours = 43
school_based_theme_hours = 2
instructional_weeks = 36
active_week_37 = EVENT_WEEK
EVENT_WEEK new curriculum hours = 0
```

Bu değerler feature widget'larında hardcode edilmez; versioned planning/runtime authority'den gelir.

## 12. Offline/privacy boundary

Core kullanım kurulum sonrası offline çalışır. V1.3 dışında kalanlar:

```text
student roster / attendance / grades
student mastery analytics
cloud account/backend/sync
MEBBİS/e-Okul
LLM/RAG/AI generation
OCR/PDF ingestion
curriculum editing
general-purpose notes/task manager
```

## 13. Required UX invariants

- Tek baskın mevcut ders odağı.
- Tracking zorunlu değildir.
- Bir dersi görüntülemek tracking kaydı oluşturmaz.
- Continuity tracking'den bağımsızdır.
- Convenience preference hataları authoritative içeriği bloke etmez.
- Notlarda sessiz veri kaybı yoktur.
- Tracking/carry mutationları gerçek Undo sunar.
- `planned` bir kullanıcı borcu gibi sunulmaz.
- Konum, tamamlanma yüzdesi değildir.
- Phone/tablet, large text ve dark mode kullanılabilir kalır.
- Touch target'lar Material minimumlarını korur.

## 14. Definition of success

V1.3 başarılıdır when a teacher can:

1. uygulamayı açıp `ŞİMDİ` dersini doğrudan görmek;
2. hiçbir tracking işlemi yapmadan ders ayrıntısına ve kaynaklara ulaşmak;
3. kesinti sonrası son görüntülenen derse dönmek;
4. isterse tracking/not/carry özelliklerini kullanmak ve Undo yapabilmek;
5. yıllık konumu ilerleme yüzdesiyle karıştırmamak;
6. runtime doğruluğunu bozmadan tüm core akışı offline kullanmak.

## 15. Change protocol

```text
scope → blueprint → implementation → regression tests → full CI
```

DEHB Faz 0–6 sözleşmesini değiştiren bir çalışma önce bu belgeyi bilinçli biçimde revize etmelidir; eski unrouted ekranları yeniden bağlamak scope değişikliği sayılır.
''')

Path('docs/FLUTTER_BLUEPRINT.md').write_text(r'''# ÖğretmenOS — Flutter Blueprint V1.3

**Belge sürümü:** 1.3.0  
**Durum:** Bağlayıcı teknik blueprint  
**Teknoloji:** Flutter + Dart + Material 3  
**Çalışma modu:** Offline-first / yerel / deterministik

`PRODUCT_SCOPE.md` üst otoritedir.

## 1. Architecture

```text
course_runtime.sqlite (read-only)
        ↓
CourseKnowledgeRepository

calendar/profile assets
        ↓
WeeklyPlanningService

teacher_state.sqlite (mutable optional tracking)
        ↓
OutcomeTrackingRepository

CourseKnowledgeRepository + WeeklyPlanningService + OutcomeTrackingRepository
        ↓
OutcomePlanningService
        ↓
Bu Hafta / Yıllık / Kaynaklar
```

Continuity ve annual manual marker SharedPreferences tabanlı convenience state'tir; curriculum veya tracking authority değildir.

## 2. Top-level shell

`TeacherOsApp` üç destination kullanır:

```text
0 Bu Hafta
1 Yıllık
2 Kaynaklar
```

`IndexedStack` ekran state'ini korur. Resource destination inactive→active geçişinde lesson context yeniden çözülür.

## 3. Bu Hafta composition

```text
ContinuityThisWeekPage
  ├─ optional KALDIĞIN YER card
  └─ ThisWeekPage
       └─ single ŞİMDİ focus card
```

`ContinuityThisWeekPage` önce authoritative `OutcomePlanningService.buildPlan()` sonucunu yükler. Continuity read/cleanup hataları yakalanır ve weekly workspace yine render edilir.

`ThisWeekPage` detail açılmadan önce optional `onOutcomeViewed` callback'ini best-effort çağırır. Callback hatası navigation'ı bloke etmez.

## 4. Continuity contract

`LastFocusState`:

```text
courseId
academicYear
weekNumber
trackingKey
outcomeCode
theme/block context
updatedAt
```

Continuity yalnız viewing event ile güncellenir. Production `OutcomePlanningService` continuity callback'i almaz. Tracking mutationları continuity üzerinde side effect üretmez.

Malformed JSON, malformed optional field veya preference I/O problemi `null` continuity olarak ele alınır.

## 5. OutcomePlanningService and tracking identity

Tracking storage identity tek canonical encoder kullanır:

```text
outcomeTrackingKey(
  academicYear,
  outcomeId,
  plannedWeekNumber,
)
```

`LearningOutcomeTrackingRecord.trackingKey`, `TrackedOutcome.trackingKey`, plan projection ve annual optional tracking scope aynı encoder'a dayanır.

Missing tracking row projection'da `planned` olur; bu storage/domain fallback'ıdır, zorunlu kullanıcı görevi değildir.

## 6. Outcome detail

`OutcomeDetailPage` foreground hiyerarşisi:

```text
official outcome
Derste lazım
Daha fazla bilgi
  ├─ Takip seçenekleri (optional)
  ├─ Öğretmen notu
  ├─ süreç bileşenleri
  ├─ plan/blok context
  └─ doğrulanmış resource/assessment context
```

`Başla` / `İşlendi` primary CTA değildir.

Teacher note:

- 700ms debounce autosave;
- lifecycle/back flush;
- concurrent save serialization;
- save error görünür retry state;
- dirty note kaydedilemezse route kapanmaz.

## 7. Mutation safety

Status/carry/bulk tracking mutations persisted snapshot alır ve gerçek Undo sağlar. Status undo newer note/actual-hours state'ini ezmez.

Tracking optional olsa da kullanıldığında persistence authoritative teacher state'tir; mutation hataları sessizce başarı gibi gösterilemez.

## 8. Resources context resolver

Resolution order:

```text
valid last-viewed outcome
→ current week outcome/theme
→ first theme fallback
```

Resolver errors resource package access'ini engellemez. Manual theme selection yalnız mevcut Resources oturumu için override'dır.

## 9. Annual plan

Annual authoritative sequence `CourseKnowledgeRepository.getAnnualSequence()`dan gelir.

Manual marker ve continuity read hataları annual sequence'i bloke etmez. Manual marker write/clear hataları kullanıcı feedback'i verir.

Active position:

```text
newer temporary manual marker
else last viewed block
```

Position presentation:

```text
Öğretim sırası: N. blok / total
```

Position-derived `LinearProgressIndicator` yasaktır.

Optional tracking panel yalnız active course planındaki canonical tracking keys ile eşleşen explicit non-planned statüleri sayar. Yüzde/denominator üretmez.

## 10. Runtime truth

- `course_runtime.sqlite` read-only.
- Widgets raw SQL çalıştırmaz.
- Block-level relation outcome-specific gibi sunulmaz.
- UI missing canonical relationship üretmez.
- Calendar/year rules versioned assets'ten gelir.

## 11. Responsive/accessibility

- Material 3.
- Phone bottom navigation, tablet/desktop NavigationRail.
- Large text fixed-height cardlarla kırılmaz.
- Action groups overflow için `Wrap` kullanır.
- Dark mode scheme-based.
- Standard interactive target >= 48 logical px where audited.

## 12. Legacy feature code

Faz 0–6 öncesi top-level alternatif ekranlar active shell tarafından route edilmez. Unrouted duplicate implementations ürün authority'si değildir ve bakım borcu olarak kaldırılabilir. Aynı capability gerekiyorsa mevcut `Bu Hafta / Yıllık / Kaynaklar / OutcomeDetail / BlockDetail` akışları üzerinden geliştirilir.

## 13. Error hierarchy

Authoritative failures:

```text
runtime/course DB
weekly planning
tracking DB startup (production dependency)
```

uygun Loading/Error state üretir.

Convenience failures:

```text
last focus
manual annual marker
resource context preference
```

ana içeriği bloke etmez.

## 14. Validation gate

Her merge öncesi:

```text
flutter analyze
runtime contract TDE9–TDE12
flutter test
flutter build apk --release
APK runtime asset verification
```

Regresyon testleri ayrıca DEHB sözleşmesini korur: tracking-free primary flow, continuity independence, autosave/Undo, context-aware resources, temporary annual marker ve truthful progress semantics.
''')

Path('AGENT.md').write_text(r'''# AGENT.md — ÖğretmenOS Agent Execution Protocol

> **Document version:** 1.3.0  
> **Status:** Binding execution protocol

## 0. Authority

Kod değişikliğinden önce sırayla oku:

1. `docs/PRODUCT_SCOPE.md`
2. `docs/FLUTTER_BLUEPRINT.md`
3. `AGENT.md`

Belge çatışması varsa yüksek otorite kazanır; çatışmayı çözmeden eski davranışı restore etme.

## 1. Mission

Öğretmenin **uygulamayı aç → şu anki dersi gör → gereken doğrulanmış bilgiyi al → çık** akışını en düşük karar yüküyle destekle.

**Tracking isteğe bağlıdır. `İşlendi` zorunlu değildir.** Tracking kullanan öğretmen için veri güvenilir ve geri alınabilir olmalıdır; kullanmayan öğretmen için ana ders akışı eksik/geride görünmemelidir.

## 2. Hard invariants

- Canonical TYMM runtime read-only.
- Curriculum facts Dart'ta hardcode edilmez.
- Runtime/calendar update teacher state'i silmez.
- Planned schedule != classroom tracking != last-viewed continuity.
- Viewing an outcome tracking kaydı oluşturmaz.
- Tracking status continuity oluşturmaz/silmez.
- Convenience preference failure authoritative content'i bloke etmez.
- Teacher note silent-loss kabul etmez.
- Position != progress/completion percentage.
- Missing tracking row kullanıcıya borç/eksik iş olarak gösterilmez.
- No backend/account/telemetry/AI dependency for V1 core.

## 3. Active product surfaces

Top-level:

```text
Bu Hafta
Yıllık
Kaynaklar
```

Default `Bu Hafta`.

Supporting routed details:

```text
OutcomeDetailPage
BlockDetailPage
```

Eski `Kazanımlar / Haftalık / Paket` top-level yapısını veya unrouted legacy pages'i scope revizyonu olmadan yeniden bağlama.

## 4. Bu Hafta UX gate

- Tek dominant `ŞİMDİ` card.
- Primary CTA `Ders ayrıntısını aç`.
- Direct `Başla/İşlendi` primary button yok.
- Tracking overflow/disclosure altında optional.
- Default planned status badge/text yok.
- Completed/carry groups explicit teacher-marking dili kullanır.

## 5. Continuity

`LastFocusState` last-viewed lesson'dır. View event detail navigation öncesi best-effort yazılır.

Read/write/cleanup failure navigation veya weekly content'i engelleyemez. Stale academic year/tracking key güvenle temizlenir veya yok sayılır.

## 6. Detail and notes

Outcome detail information-first kalır. Tracking `Daha fazla bilgi` altında optionaldır.

Not sistemi:

```text
700ms autosave
back/lifecycle flush
save failure => no silent exit
retry feedback
```

Tracking/carry mutationları Undo sunar ve newer note/hours'u ezmez.

## 7. Resources

Context priority:

```text
last viewed lesson
→ current instructional week
→ fallback theme
```

Tema 1'e hardcoded reset yok. Context resolution failure resource access'i engellemez.

## 8. Annual

Temporary manual marker course-scoped ve timestamped'dır. Daha yeni viewed lesson eski marker'ı geçersiz kılar.

Annual sequence konumu yalnız `Sıra N / total` anlamındadır; progress bar veya completion yüzdesi üretme.

Optional tracking summary sadece explicit non-planned states sayar ve active course tracking keys ile scope edilir.

## 9. Data boundaries

```text
course_runtime.sqlite  READ ONLY
calendar assets        READ ONLY
teacher_state.sqlite   READ/WRITE optional tracking/note/carry
SharedPreferences      continuity/manual UI convenience
```

Widget raw SQL çalıştırmaz. Missing curriculum relationship uydurulmaz.

## 10. Tracking identity

Tracking identity için yalnız domain helper kullan:

```dart
outcomeTrackingKey(
  academicYear: ...,
  outcomeId: ...,
  plannedWeekNumber: ...,
)
```

Aynı string formatını UI/service içinde tekrar elle kurma.

## 11. Git safety

- Unrelated user work korunur.
- Feature/debt work current `main`den branch edilir.
- Kullanıcı uygulama istemişse PR + CI + merge akışı tamamlanabilir.
- Geçici patch workflow/script final diff'te bırakılmaz.

## 12. Validation

Final gate:

```text
flutter analyze
Runtime Contract TDE9/TDE10/TDE11/TDE12
flutter test
Android release APK
APK runtime asset verification
```

Tests yalnız happy path değil, convenience-state failure ve stale/malformed state davranışlarını da kanıtlamalıdır.

## 13. Pre-merge checklist

- binding docs active UX ile uyumlu;
- tracking optional;
- continuity independent;
- no fake progress semantics;
- note/Undo safety preserved;
- resources lesson-context aware;
- runtime read-only / teacher state separate;
- full CI green.
''')

Path('README.md').write_text(r'''# ÖğretmenOS

![Flutter CI](https://github.com/knigdelioglu/OgretmenOS/actions/workflows/flutter-ci.yml/badge.svg)

Offline-first Flutter öğretmen uygulaması. Ana akış **tracking yapmak değil, mevcut ders bağlamına hızlı ulaşmaktır**:

```text
Bu Hafta / ŞİMDİ
→ Ders ayrıntısını aç
→ doğrulanmış program/kitap/etkinlik/kaynak bilgisini kullan
```

Tracking (`Devam ediyor / Kısmen / İşlendi / Taşındı`) tamamen isteğe bağlıdır.

## Ana navigasyon

```text
Bu Hafta
Yıllık
Kaynaklar
```

`Bu Hafta` varsayılan ekrandır. Son görüntülenen ders `KALDIĞIN YER` olarak korunur; bu continuity bilgisi tracking statüsünden bağımsızdır.

## DEHB odaklı UX sözleşmesi

- tek baskın `ŞİMDİ` odağı;
- primary CTA `Ders ayrıntısını aç`;
- `İşlendi` zorunlu değil;
- teacher note autosave + başarısız kayıtta sessiz çıkış yok;
- tracking/carry işlemlerinde gerçek Undo;
- Kaynaklar: son görüntülenen ders → mevcut hafta → fallback tema;
- Yıllık manuel konum geçici, course-scoped ve yeni ders görüntülemesiyle otomatik güncellenir;
- blok konumu tamamlanma yüzdesi değildir;
- işaretlenmemiş kazanımlar eksik sayılmaz.

Ayrıntılı bağlayıcı sözleşme: `docs/PRODUCT_SCOPE.md` ve `docs/FLUTTER_BLUEPRINT.md`.

## Veri sınırları

### Read-only course knowledge

Versioned TYMM package runtime'ları `tymm-verileri/turk-dili-ve-edebiyati/<COURSE>/runtime/` altında tutulur ve uygulamada read-only kullanılır.

### Versioned academic calendar

```text
assets/calendars/calendar_index.json
assets/calendars/academic_calendar_2026_2027.json
```

### Local teacher state

`teacher_state.sqlite` yalnız optional outcome tracking, kısa teacher note, actual hours ve carry bilgisini saklar. Continuity/manual marker SharedPreferences convenience state'tir. Runtime/calendar refresh bu state'i silmez.

## Tracking semantiği

Storage/domain durumları:

```text
planned
in_progress
completed
partially_completed
carried_over
```

Missing row = `planned`, fakat UI bunu otomatik bir görev/borç gibi göstermez. Planned schedule ile explicit classroom tracking ayrı gerçeklerdir.

## Runtime sync

```sh
dart run tool/sync_course_runtime.dart
```

## Final validation

```sh
flutter pub get
flutter analyze
cd tool/runtime_verifier && dart pub get && dart run bin/verify_runtime.dart
cd ../..
flutter test
flutter build apk --release
```

GitHub Actions ayrıca TDE9–TDE12 runtime contract ve APK içi runtime assetlerini doğrular.

## Android signing

```sh
cp android/key.properties.example android/key.properties
```

`android/key.properties`, `*.jks` ve `*.keystore` Git tarafından yok sayılır.
''')

Path('docs/ADHD_UX_PHASE_AUDIT.md').write_text(r'''# DEHB UX Faz 0–6 Final Audit

**Audit target:** post-Faz-6 `main`  
**Result after debt cleanup:** COMPLETE

| Faz | Kabul sözleşmesi | Son durum |
|---|---|---|
| 0 | not autosave, silent-loss engeli, persisted Undo | COMPLETE |
| 1 | tek `ŞİMDİ`, detail-first CTA, tracking optional | COMPLETE |
| 2 | last-viewed continuity tracking'den bağımsız | COMPLETE |
| 3 | Kaynaklar current lesson context aware | COMPLETE |
| 4 | Outcome detail information-first, tracking secondary | COMPLETE |
| 5 | annual manual marker temporary/course-scoped/latest-context aware | COMPLETE |
| 6 | position ≠ progress; planned ≠ user debt; optional tracking truthful | COMPLETE |

## Cross-phase invariants

```text
viewing != tracking
tracking != continuity
position != completion percentage
planned != mandatory todo
convenience-state failure != authoritative content failure
```

## Audit sırasında bulunan ve kapatılan borçlar

1. Weekly continuity preference read/cleanup hatası authoritative weekly content'i bloke edebiliyordu → best-effort hale getirildi.
2. Annual manual/continuity preference read hatası annual sequence'i bloke edebiliyordu → best-effort hale getirildi; explicit marker write failure feedback verir.
3. Malformed optional continuity JSON fields runtime cast hatasına yol açabiliyordu → safe parsing + invalid-state cleanup.
4. Tracking identity string'i service/UI/domain arasında elle tekrar ediliyordu → canonical `outcomeTrackingKey`.
5. Binding `PRODUCT_SCOPE`, `FLUTTER_BLUEPRINT`, `AGENT` ve README eski tracking-first navigation'ı tarif ediyordu → V1.3 DEHB contract ile hizalandı.
6. Unrouted pre-DEHB duplicate screens stale UX kodu taşıyordu → active shell tarafından kullanılmadıkları doğrulanıp kaldırıldı.

## Validation expectation

Bu audit ancak full CI (`Analyze`, `Tests`, `Runtime Contract TDE9–TDE12`, `Android Release Build`, APK runtime asset verification) yeşil olduğunda final kabul edilir.
''')

Path('test/product_contract_test.dart').write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('binding docs preserve the post-phase DEHB product contract', () {
    final product = File('docs/PRODUCT_SCOPE.md').readAsStringSync();
    final blueprint = File('docs/FLUTTER_BLUEPRINT.md').readAsStringSync();
    final agent = File('AGENT.md').readAsStringSync();

    for (final document in [product, blueprint, agent]) {
      expect(document, contains('Bu Hafta'));
      expect(document, contains('Yıllık'));
      expect(document, contains('Kaynaklar'));
      expect(document.toLowerCase(), contains('tracking'));
    }

    expect(product, contains('Tracking isteğe bağlıdır'));
    expect(product, contains('Konum ilerleme değildir'));
    expect(agent, contains('`İşlendi` zorunlu değildir'));
    expect(blueprint, contains('Position-derived `LinearProgressIndicator` yasaktır'));

    const staleNavigation = 'Kazanımlar\nHaftalık\nYıllık Plan\nPaket';
    expect(product, isNot(contains(staleNavigation)));
    expect(blueprint, isNot(contains(staleNavigation)));
    expect(agent, isNot(contains(staleNavigation)));
  });
}
''')

# 7) Remove unrouted duplicate pre-DEHB pages that retained stale tracking-first
# controls. Search audit confirmed these classes have no live call sites.
for dead in [
    'lib/features/home/home_page.dart',
    'lib/features/outcomes/outcome_tracker_page.dart',
    'lib/features/weekly_plan/weekly_plan_page.dart',
    'lib/features/teacher_package/teacher_package_page.dart',
    'lib/features/book_first/book_first_page.dart',
    'lib/features/runtime_spike/runtime_spike_page.dart',
]:
    path = Path(dead)
    if path.exists():
        path.unlink()
