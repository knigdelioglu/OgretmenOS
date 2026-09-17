#!/usr/bin/env python3
"""Materialize the TDE11 textbook-first Teacher Guide V3 into OgretmenOS runtime.

This projector intentionally reuses the audited V2.3 source mirror/component snapshot
already vendored in this repository, then applies the V3 grouped-question split and
task-specific teacher guidance contract. Curriculum/runtime tables outside the teacher
guide presentation are left intact.

The projection is deterministic: rerunning it against an already-current runtime is a
no-op at the byte level for SQLite and metadata files.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import sqlite3
from pathlib import Path
from typing import Any, Iterable

import project_teacher_guide_v23 as core
import run_teacher_guide_v23_projection as frozen

ARCHITECTURE_VERSION = "3.0.0"
PROJECTION_VERSION = "1.0.0+textbook-first-v3-snapshot"
SOURCE_COMMIT = "bb345b0c51074aa351b1b88b6b889cebf6a2af48"
RUNTIME_PACKAGE_VERSION = "1.5.0"
EXPECTED_THEME_COUNTS = {
    "TEMA_01": (129, 81),
    "TEMA_02": (158, 107),
    "TEMA_03": (146, 114),
    "TEMA_04": (143, 105),
}
EXPECTED_TOTALS = {"entries": 576, "questions": 407, "locator_only_questions": 0}
EXPECTED_CANONICAL_ITEMS = 283
EXPECTED_CANONICAL_RELATIONS = 3750
EXPECTED_UNITS = 431
V3_UNIT_PREFIX = "__v23_unit__"
V3_ITEM_PREFIX = "__v23_item__"
REPO_ROOT = Path(__file__).resolve().parents[1]

EXTERNAL_REVIEW = re.compile(
    r"\b(?:qr|video|eba|rubrik|dereceli puanlama|fedakârlık|çalışkanlık|aidiyet)\b",
    re.IGNORECASE,
)

PROFILE_TERMS: tuple[tuple[str, tuple[str, ...]], ...] = (
    ("karagoz", ("karagöz", "hacivat", "gölge oyunu", "seyirlik", "yazıcı")),
    ("language_grammar", ("fiil", "çatı", "kip", "noktalama", "cümle öge", "cümle öğe", "yüklem", "özne", "nesne")),
    ("mektup", ("mektup", "e-posta", "eposta", "dilekçe")),
    ("old_turkic", ("orhun", "kül tigin", "dîvânu lugâti", "divanu lugati", "bengü taş", "yazıt")),
    ("ashik", ("âşık", "aşık", "atışma", "saz", "ozan")),
    ("kucurek", ("küçürek", "minimal hikâye", "ferit edgü", "merdiven")),
    ("bio_tezkire", ("biyografi", "tezkire", "mehmet akif", "orhan veli", "mustafa inan")),
    ("interview", ("mülakat", "röportaj")),
    ("radio", ("radyo tiyatrosu", "radyo tiyat")),
    ("documentary", ("belgesel", "fedakârlık", "aidiyet")),
    ("poster", ("afiş", "poster")),
    ("huzur", ("huzur", "tanpınar", "mümtaz", "nuran")),
    ("theatre", ("tiyatro", "mimar sinan", "monolog", "sahne", "canlandır")),
    ("communication", ("iletişim", "sosyal medya", "telefon", "internet", "dijital")),
    ("cultural_memory", ("kültür", "millî kimlik", "türk dünyası", "nevruz", "dede korkut")),
    ("story_memoir", ("hikâye", "anı", "olay örgüsü", "hikâye haritası")),
)

BACKGROUND = {
    "karagoz": (
        "Karagöz geleneğinde tip, söz varlığı, yanlış anlama, taklit ve doğaçlama birlikte mizahı kurar. "
        "Hacivat ile Karagöz arasındaki eğitim, kültür ve sosyal statü farkı yalnız kişilik ayrımı değil; "
        "oyunun dil ve çatışma düzeninin temel kaynaklarından biridir."
    ),
    "language_grammar": (
        "Dil bilgisi burada yalnız terim bulma işi değildir. Fiil kipi, çatı, cümle kuruluşu ve noktalama; "
        "eyleyenin görünürlüğünü, zamanı, vurguyu ve anlam akışını değiştirir. Öğrenci biçimi tanıdıktan sonra "
        "metindeki işlevini de açıklamalıdır."
    ),
    "mektup": (
        "Mektup, e-posta ve dilekçe; gönderici, alıcı, amaç ve bağlama göre dil ve biçim seçimi gerektirir. "
        "Özel/edebî mektuptaki öznel-samimi ton ile resmî yazışmadaki açıklık, nezaket ve düzen aynı ölçütlerle "
        "değerlendirilmemelidir."
    ),
    "old_turkic": (
        "Orhun Yazıtları hitabet, devlet-millet ilişkisi ve tarihsel dil açısından; Dîvânu Lugâti't-Türk ise "
        "Türkçenin söz varlığı ve kültürel birliği açısından temel kaynaklardır. Öğrencinin tarihsel bilgiyi "
        "metindeki dil, amaç ve hitap özellikleriyle ilişkilendirmesi gerekir."
    ),
    "ashik": (
        "Âşık edebiyatı sözlü gelenek, saz, usta-çırak ilişkisi, doğaçlama, hece ölçüsü ve mahlas kullanımıyla "
        "birlikte düşünülmelidir. Şiirin biçim özelliği kadar icra ortamı ve toplumsal hafıza işlevi de önemlidir."
    ),
    "kucurek": (
        "Küçürek hikâye yalnız kısa metin değildir; seçilmiş bir anı yoğunlaştırır, az ayrıntıyla geniş çağrışım "
        "alanı kurar ve bazı boşlukları okura bırakır. Yorum imge, tekrar, başlık ve yapı gibi gerçek metin "
        "göstergelerine dayanmalıdır."
    ),
    "bio_tezkire": (
        "Biyografi ve tezkirede kişi bilgisi seçilir, düzenlenir ve anlatıcı/yazar tutumuyla sunulur. "
        "Doğrulanabilir olgu ile değerlendirme dili ayrılmalı; modern biyografi ile tezkire geleneğinin amaç ve "
        "sunum farkı metin kanıtlarıyla kurulmalıdır."
    ),
    "interview": (
        "Mülakat planlı bir soru-cevap sürecidir. Açık uçlu soru, aktif dinleme ve takip sorusu görüşün derinleşmesini "
        "sağlar; röportaj ise gözlem ve araştırma unsurlarını daha geniş biçimde kullanabilir."
    ),
    "radio": (
        "Radyo tiyatrosunda söz, ton, sessizlik, müzik ve ses efekti birlikte mekân, eylem ve duygu kurar. "
        "Dinleyicinin zihinsel görüntüsü yalnız konuşulan sözcüklerden oluşmaz."
    ),
    "documentary": (
        "Belgesel gerçek olgulara dayanır fakat seçim, kurgu, görüntü, ses ve anlatıcı kullanımıyla onları çerçeveler. "
        "İzlenmeyen dış video veya QR içeriği hakkında ayrıntı uydurulmamalı; yalnız gözlenen kanıt değerlendirilmelidir."
    ),
    "poster": (
        "Afişte görsel-sözel uyum, hiyerarşi, odak, okunabilirlik ve hedef kitle tek bir iletişim tasarımının parçalarıdır. "
        "Her görsel tercih iletinin algılanma biçimini etkiler."
    ),
    "huzur": (
        "Huzur romanında gerçek yaşam izleri kurmaca kişi, olay, zaman, mekân ve anlatıcı düzeni içinde yeniden anlamlandırılır. "
        "Metinden doğrulanabilen ayrıntı ile biyografik/tarihsel yorum aynı kanıt düzeyinde ele alınmamalıdır."
    ),
    "theatre": (
        "Tiyatroda diyalog kadar karakter amacı, çatışma, sahne yönergesi, beden, mekân, dekor ve ses de anlam üretir. "
        "Tarihî kişi veya olay sahnelenirken kaynak bilgisi ile kurmaca tercih açıkça ayrılmalıdır."
    ),
    "communication": (
        "İletişimde gönderici, alıcı, ileti, kanal, amaç ve bağlam birbirini etkiler. Araç değiştikçe hız, geri bildirim, "
        "dil tercihi ve yanlış anlaşılma ihtimali de değişir."
    ),
    "cultural_memory": (
        "Dil ve edebiyat kültürel belleği yalnız bilgi aktararak değil; değerleri, ortak imgeleri, anlatıları ve söyleyiş "
        "biçimlerini kuşaklar arasında taşıyarak kurar. Kültür unsuru metindeki işleviyle değerlendirilmelidir."
    ),
    "story_memoir": (
        "Hikâye ve anıda olay, kişi, zaman ve mekân anlatıcının seçimiyle anlam kazanır. Anı yaşanmışlık iddiası taşırken "
        "hikâye kurmaca düzenlemeyi daha görünür kullanabilir; her iki türde de özet ile yorum ayrılmalıdır."
    ),
    "text_analysis": (
        "Metin çözümlemesinde cevap, soru kökünün istediği kavramı doğru kullanmalı ve iddiayı metindeki somut bir ayrıntıyla "
        "ilişkilendirmelidir. Özet, yorum ve dış bilgi aynı kanıt düzeyiymiş gibi sunulmamalıdır."
    ),
}


class V3ProjectionError(core.ProjectionError):
    pass


def read_json(path: Path) -> dict[str, Any]:
    return core.read_json(path)


def compact(value: Any) -> str:
    return core.compact(value)


def norm(value: Any) -> str:
    text = str(value or "").replace("İ", "i").replace("I", "ı").casefold().replace("’", "'")
    return re.sub(r"\s+", " ", text).strip()


def nonempty(value: Any) -> bool:
    return core.nonempty(value)


def dedupe(values: Iterable[Any], limit: int | None = None) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    for raw in values:
        if not isinstance(raw, str) or not raw.strip():
            continue
        value = re.sub(r"\s+", " ", raw.strip())
        key = norm(value)
        if key in seen:
            continue
        seen.add(key)
        out.append(value)
        if limit is not None and len(out) >= limit:
            break
    return out


def scalar_text(value: Any, limit: int = 220) -> str:
    if value is None or value == [] or value == {}:
        return ""
    if isinstance(value, str):
        text = value
    elif isinstance(value, dict):
        text = "; ".join(f"{k}: {scalar_text(v, 90)}" for k, v in list(value.items())[:4])
    elif isinstance(value, list):
        text = "; ".join(scalar_text(v, 90) for v in value[:4])
    else:
        text = str(value)
    text = re.sub(r"\s+", " ", text).strip()
    return text if len(text) <= limit else text[: limit - 1].rstrip() + "…"


def profile_for(entry: dict[str, Any]) -> str:
    blob = norm(" ".join(str(entry.get(k) or "") for k in ("book_heading", "prompt_display", "teacher_note", "source_locator")))
    for profile, terms in PROFILE_TERMS:
        if any(term in blob for term in terms):
            return profile
    if any(term in blob for term in ("tür değiş", "dönüştür", "başka bir tür")):
        return "text_analysis"
    return "text_analysis"


def focus_for(entry: dict[str, Any]) -> str:
    text = norm(f"{entry.get('book_heading','')} {entry.get('prompt_display','')}")
    pairs = (
        (("konu", "tema"), "konu-tema ayrımı ve soyutlama"),
        (("öznel", "nesnel"), "kanıtlanabilirlik ile kişisel değerlendirme"),
        (("söz varlığı",), "söz seçimi ile kişi ve bağlam ilişkisi"),
        (("ana düşünce",), "ana düşüncenin metin kanıtlarıyla kurulması"),
        (("özet",), "ana çizgiyi koruyarak özetleme"),
        (("üslup",), "dil tercihi ve üslup etkisi"),
        (("değerlendir",), "ölçüt kullanarak değerlendirme"),
        (("gerekçe",), "iddia-gerekçe bağı"),
        (("dostluk",), "farklılıklar içinde dostluk ve iletişim"),
        (("kültür",), "kültürel unsurun bağlam ve aktarımı"),
        (("fiil", "çatı"), "dil bilgisini metin işleviyle ilişkilendirme"),
        (("gerçeklik", "kurmaca"), "gerçeklik ile sanatsal dönüşüm"),
    )
    for needles, focus in pairs:
        if all(n in text for n in needles):
            return focus
    label = re.sub(r"^(?:soru|adım)\s*[0-9a-z/.\-–— ]*[:—-]?\s*", "", str(entry.get("book_heading") or ""), flags=re.I)
    return (label[:110] or "kaynakla ilişkilendirilmiş anlam oluşturma").strip()


def task_guidance(
    entry: dict[str, Any],
    expected: Any,
    acceptance: Any,
    canonical_guidance: Any,
    misconceptions: Any,
    assessment_evidence: Any,
    review_required: bool,
) -> dict[str, Any]:
    profile = profile_for(entry)
    focus = focus_for(entry)
    prompt = re.sub(r"\s+", " ", str(entry.get("prompt_display") or entry.get("book_heading") or "").strip())
    short_prompt = prompt if len(prompt) <= 190 else prompt[:187].rstrip() + "…"
    exp = scalar_text(expected)
    canonical_moves: list[str] = []
    if isinstance(canonical_guidance, list):
        canonical_moves.extend(str(x) for x in canonical_guidance if str(x).strip())
    elif isinstance(canonical_guidance, str) and canonical_guidance.strip():
        canonical_moves.append(canonical_guidance.strip())
    elif isinstance(canonical_guidance, dict):
        canonical_moves.extend(str(v) for v in canonical_guidance.values() if isinstance(v, str) and v.strip())

    moves = dedupe(
        [
            *canonical_moves,
            f"“{short_prompt}” görevinde öğrenciden önce iddiasını açıkça kurmasını, ardından bu iddiayı metindeki somut bir ayrıntıyla ilişkilendirmesini isteyin.",
            f"Cevabı yalnız sonuç olarak kabul etmeyin; {focus} bakımından hangi kanıtın hangi çıkarımı desteklediğini açıklattırın.",
        ],
        4,
    )
    if review_required:
        moves = dedupe(
            [
                "Dış video, QR, görsel veya rubrik sınıfta gerçekten açılmadan kişi, olay, ana düşünce ya da tek doğru cevap üretmeyin.",
                "Öğrencinin gözlediği gerçek medya/görsel kanıtı önce kaydettirin; yorumunu bu kanıttan sonra kurdurun.",
                *moves,
            ],
            4,
        )

    follow = [
        f"Bu yargıyı destekleyen en güçlü metin/gösterge hangisidir ve {focus} ile ilişkisi nedir?",
        "Aynı soruya farklı fakat metinle uyumlu bir cevap verilebilir mi? Kabul sınırını hangi kanıt belirler?",
    ]
    if entry.get("presentation_type") in {"PROCESS", "ACTIVITY", "PERFORMANCE_TASK"}:
        follow[1] = "Ürünün veya sürecin başarılı olduğunu hangi somut ölçüt üzerinden anlayabiliriz?"

    misconception_list: list[str] = []
    if isinstance(misconceptions, list):
        misconception_list = dedupe(misconceptions, 3)
    elif nonempty(misconceptions):
        misconception_list = [scalar_text(misconceptions)]

    interventions = [
        f"Öğrenci {focus} ile ilgili kanıtsız genelleme yaparsa iddia ve metin dayanağını iki sütuna ayırıp eksik dayanağı buldurun.",
        "Özet ile yorumu karıştırırsa önce metinde açıkça söyleneni, sonra öğrencinin çıkardığı sonucu ayrı cümlelerle yazdırın.",
    ]
    if profile == "language_grammar":
        interventions = [
            "Terimi doğru adlandırdığı hâlde işlevi açıklayamıyorsa aynı cümleyi ilgili yapı değişecek biçimde yeniden yazdırıp anlam/vurgu farkını karşılaştırın.",
            "Önce biçimsel kanıtı işaretletin; ardından yapının cümledeki eyleyen, zaman veya vurguya etkisini açıklattırın.",
        ]
    elif profile in {"documentary", "radio"}:
        interventions = [
            "Gözlem ile tahmini ayrı başlıklara yazdırın; gerçekten duyulan/görülen kanıt olmadan kesin yargıya geçmesine izin vermeyin.",
            "Ses, görüntü veya söz ayrıntısını seçtirip bunun kişi, mekân, duygu ya da ileti üzerindeki işlevini açıklattırın.",
        ]

    answer_explanation = (
        f"Beklenen yanıtın temel ölçütü {focus} odağını karşılaması ve kaynakla çelişmemesidir. "
        f"{('Yapılandırılmış cevapta her bileşen ayrı kanıtla doğrulanmalıdır.' if isinstance(expected, (dict, list)) else 'Cevabın doğruluğu yalnız sonuçtan değil, kullanılan dayanak ve gerekçeden anlaşılır.')}"
    )
    if exp:
        answer_explanation += f" Canonical cevap çerçevesinin özeti: {exp}"
    elif review_required:
        answer_explanation = (
            "Bu görev için kaynakta bulunmayan dış görsel/video/rubrik içeriğinden tek bir cevap üretilemez. "
            "Doğru değerlendirme, öğrencinin gerçekten eriştiği materyaldeki kanıtı göstermesi ve yorumunu o kanıtla sınırlandırmasıdır."
        )
    else:
        answer_explanation += " Tek bir hazır cevap yerine görev yönergesi ve kabul ölçütleri birlikte değerlendirilmelidir."

    student_explanation = (
        f"Bu görevde {focus} üzerinde çalışıyoruz. Önce metinde gerçekten gördüğün bilgiyi belirle, "
        "sonra yorumunu bu bilgiye bağla ve nedenini açıkla."
    )

    why = (
        f"“{short_prompt}” çalışması öğrencinin {focus} becerisini yalnız terim düzeyinde değil, "
        "kaynak kanıtı ile gerekçeli yorum arasında bağ kurarak kullanmasını görünür hâle getirir."
    )

    return {
        "teacher_background": BACKGROUND.get(profile, BACKGROUND["text_analysis"]),
        "student_explanation": student_explanation,
        "why_it_matters": why,
        "teacher_moves": moves,
        "follow_up_questions": follow,
        "misconception_interventions": interventions[: max(1, len(misconception_list))],
        "answer_explanation": answer_explanation,
        "board_notes": [],
        "v3_profile": profile,
        "v3_focus": focus,
    }


def is_review_required(entry: dict[str, Any], expected: Any, fragment_status: str) -> bool:
    if fragment_status == "REVIEW_REQUIRED":
        return True
    blob = " ".join(str(entry.get(k) or "") for k in ("book_heading", "prompt_display", "teacher_note", "source_locator"))
    rights_mode = str(entry.get("rights_mode") or "").upper()
    if EXTERNAL_REVIEW.search(blob) and (rights_mode == "PAGE_REFERENCE" or not nonempty(expected)):
        return True
    return False


def load_prompt_overrides(path: Path) -> dict[str, list[dict[str, Any]]]:
    data = read_json(path)
    if data.get("course_id") != "TDE_11":
        raise V3ProjectionError("PROMPT_OVERRIDE_COURSE_INVALID")
    overrides = data.get("overrides")
    if not isinstance(overrides, dict):
        raise V3ProjectionError("PROMPT_OVERRIDES_OBJECT_REQUIRED")
    return overrides


def expand_grouped(entry: dict[str, Any], parts: list[dict[str, Any]]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    group_id = str(entry["mirror_id"])
    for part in parts:
        qn = str(part["question_number"])
        expanded = copy.deepcopy(entry)
        expanded["mirror_id"] = f"{group_id}#Q{qn}"
        expanded["prompt_display"] = f"Soru {qn} — {part['prompt']}"
        expanded["prompt_mode"] = "VERBATIM_SHORT"
        expanded["answer_keys"] = [str(part["answer_key"])]
        expanded["question_number"] = qn
        expanded["printed_page_range"] = str(part.get("printed_page_range") or entry.get("printed_page_range") or "")
        expanded["source_locator"] = str(part.get("source_locator") or entry.get("source_locator") or "")
        expanded["split_from_group"] = True
        expanded["group_source_task_id"] = group_id
        out.append(expanded)
    return out


def apply_canonical_overrides(canonical: dict[str, dict[str, Any]], path: Path) -> None:
    data = read_json(path)
    # The override file belongs to the frozen canonical snapshot.  V3 changes
    # projection/pedagogy, not the reviewed canonical answer corrections.
    if data.get("source_commit") != "20860e3165d5e9de18913364286e6f89f28f6046":
        raise V3ProjectionError("CANONICAL_OVERRIDE_SOURCE_COMMIT_MISMATCH")
    overrides = data.get("items") or {}
    if not isinstance(overrides, dict):
        raise V3ProjectionError("CANONICAL_OVERRIDES_OBJECT_REQUIRED")
    allowed = {"expected_response", "acceptance_criteria", "common_misconceptions", "differentiation"}
    for item_id, fields in overrides.items():
        if item_id not in canonical or not isinstance(fields, dict):
            raise V3ProjectionError(f"CANONICAL_OVERRIDE_INVALID:{item_id}")
        for field, value in fields.items():
            if field not in allowed:
                raise V3ProjectionError(f"CANONICAL_OVERRIDE_FIELD_NOT_ALLOWED:{item_id}:{field}")
            canonical[item_id][field] = copy.deepcopy(value)


def install_source_contract(
    canonical_snapshot: Path,
    canonical_overrides: Path,
    prompt_override_path: Path,
) -> tuple[dict[str, Any], dict[str, list[dict[str, Any]]]]:
    core.ARCHITECTURE_VERSION = ARCHITECTURE_VERSION
    core.PROJECTION_VERSION = PROJECTION_VERSION
    core.SOURCE_COMMIT = SOURCE_COMMIT
    core.EXPECTED_THEME_COUNTS = dict(EXPECTED_THEME_COUNTS)
    core.EXPECTED_TOTALS = dict(EXPECTED_TOTALS)
    core.V23_UNIT_PREFIX = V3_UNIT_PREFIX
    core.V23_ITEM_PREFIX = V3_ITEM_PREFIX

    canonical_items, canonical_relations = frozen._load_canonical_snapshot(canonical_snapshot)
    if len(canonical_items) != EXPECTED_CANONICAL_ITEMS:
        raise V3ProjectionError("CANONICAL_ITEM_COUNT_INVALID")
    if sum(len(v) for v in canonical_relations.values()) != EXPECTED_CANONICAL_RELATIONS:
        raise V3ProjectionError("CANONICAL_RELATION_COUNT_INVALID")

    def snapshot_canonical(_db: sqlite3.Connection):
        return copy.deepcopy(canonical_items), copy.deepcopy(canonical_relations)

    core.snapshot_canonical = snapshot_canonical

    canonical_override_doc = read_json(canonical_overrides)
    aliases_raw = canonical_override_doc.get("section_aliases") or {}
    if not isinstance(aliases_raw, dict):
        raise V3ProjectionError("SECTION_ALIASES_OBJECT_REQUIRED")
    aliases = {str(k): str(v) for k, v in aliases_raw.items()}
    prompt_overrides = load_prompt_overrides(prompt_override_path)

    original_loader = core.load_mirror_entries

    def load_mirror_entries(source_root: Path, theme_id: str):
        entries, statuses, paths = original_loader(source_root, theme_id)
        normalized: list[dict[str, Any]] = []
        new_statuses: dict[str, str] = {}
        alias_use = 0
        for raw in entries:
            entry = copy.deepcopy(raw)
            source_section = str(entry.get("section_id") or "")
            target_section = aliases.get(source_section, source_section)
            if target_section != source_section:
                alias_use += 1
                entry["section_id"] = target_section
                entry["source_section_id"] = source_section
            group_parts = prompt_overrides.get(str(entry.get("mirror_id") or ""))
            expanded_entries = expand_grouped(entry, group_parts) if group_parts else [entry]
            for expanded in expanded_entries:
                normalized.append(expanded)
                new_statuses[str(expanded["mirror_id"])] = statuses[str(raw["mirror_id"])]
        if theme_id == "TEMA_04" and aliases and alias_use != 1:
            raise V3ProjectionError(f"SECTION_ALIAS_USE_DRIFT:{theme_id}:{alias_use}!=1")
        return normalized, new_statuses, paths

    core.load_mirror_entries = load_mirror_entries
    return canonical_override_doc, prompt_overrides


def build_projection(
    db: sqlite3.Connection,
    source_root: Path,
    override_path: Path,
    canonical_snapshot: Path,
    prompt_override_path: Path,
) -> tuple[dict[str, Any], list[Path]]:
    canonical, source_rel = core.snapshot_canonical(db)
    apply_canonical_overrides(canonical, override_path)
    sections = core.section_order_map(db)

    all_entries: list[tuple[str, dict[str, Any], str]] = []
    source_paths: list[Path] = [canonical_snapshot, prompt_override_path]
    component_count = 0
    metrics: dict[str, Any] = {"themes": {}}

    for theme_id, (expected_entries, expected_questions) in EXPECTED_THEME_COUNTS.items():
        entries, statuses, mirror_paths = core.load_mirror_entries(source_root, theme_id)
        component_docs = core.source_patch_docs(source_root, theme_id, "components")
        components = core.merge_component_registries(component_docs, theme_id)
        component_count += core.apply_components(canonical, components)
        source_paths.extend(mirror_paths)
        source_paths.extend(path for path, _ in component_docs)
        questions = [e for e in entries if e.get("presentation_type") == "QUESTION"]
        locator_only = [e for e in questions if e.get("prompt_mode") == "LOCATOR_ONLY"]
        if (len(entries), len(questions)) != (expected_entries, expected_questions):
            raise V3ProjectionError(
                f"THEME_COUNT_DRIFT:{theme_id}:{len(entries)}/{len(questions)}!={expected_entries}/{expected_questions}"
            )
        if locator_only:
            raise V3ProjectionError(f"LOCATOR_ONLY_QUESTION:{theme_id}")
        metrics["themes"][theme_id] = {
            "entries": len(entries),
            "questions": len(questions),
            "locator_only_questions": 0,
            "mirror_files": len(mirror_paths),
            "component_registry_entries": sum(len(v) for v in components.values()),
        }
        all_entries.extend((theme_id, e, statuses[str(e["mirror_id"])]) for e in entries)

    totals = {
        "entries": len(all_entries),
        "questions": sum(1 for _, e, _ in all_entries if e.get("presentation_type") == "QUESTION"),
        "locator_only_questions": 0,
    }
    if totals != EXPECTED_TOTALS:
        raise V3ProjectionError(f"TOTAL_COUNT_DRIFT:{totals}!={EXPECTED_TOTALS}")

    for theme_id, entry, _ in all_entries:
        section_id = str(entry.get("section_id") or "")
        if section_id not in sections:
            raise V3ProjectionError(f"MIRROR_UNKNOWN_SECTION:{entry['mirror_id']}:{section_id}")
        guide_id, _ = sections[section_id]
        scope = db.execute("SELECT scope_id FROM teacher_guides WHERE guide_id=?", (guide_id,)).fetchone()
        if scope is None or str(scope[0]) != theme_id:
            raise V3ProjectionError(f"MIRROR_SECTION_THEME_MISMATCH:{entry['mirror_id']}:{theme_id}")

    core.delete_old_presentation(db)

    unit_orders: dict[str, int] = {}
    current_key: tuple[str, str, str] | None = None
    current_unit_id: str | None = None
    current_item_order = 0
    used_unit_ids: set[str] = set()
    review_count = 0

    for theme_id, entry, fragment_status in all_entries:
        section_id = str(entry["section_id"])
        key = (section_id, str(entry["printed_page_range"]), str(entry["book_heading"]))
        if key != current_key:
            unit_orders[section_id] = unit_orders.get(section_id, 0) + 1
            raw_id = f"{V3_UNIT_PREFIX}{entry['mirror_id'].split('#Q', 1)[0]}"
            current_unit_id = raw_id
            suffix = 2
            while current_unit_id in used_unit_ids:
                current_unit_id = f"{raw_id}_{suffix}"
                suffix += 1
            used_unit_ids.add(current_unit_id)
            current_item_order = 0
            unit_provenance = {
                "content_class": "BOOK_FIRST_V3_UNIT",
                "architecture_version": ARCHITECTURE_VERSION,
                "projection_version": PROJECTION_VERSION,
                "source_repository": "knigdelioglu/tymm",
                "source_tymm_commit": SOURCE_COMMIT,
                "source_ids": ["official_textbook_pdf"],
                "source_locators": [str(entry.get("source_locator") or f"basılı s.{entry['printed_page_range']}")],
                "theme_id": theme_id,
                "section_id": section_id,
                "printed_page_range": entry["printed_page_range"],
                "book_heading": entry["book_heading"],
            }
            db.execute(
                """INSERT INTO teacher_guide_units(
                     unit_id,section_id,unit_order,title,page_locator,source_locator,
                     content_status,purpose_json,provenance_json
                   ) VALUES (?,?,?,?,?,?,?,?,?)""",
                (
                    current_unit_id,
                    section_id,
                    unit_orders[section_id],
                    str(entry["book_heading"]),
                    str(entry["printed_page_range"]),
                    str(entry.get("source_locator") or ""),
                    "VERIFIED",
                    compact({
                        "architecture_version": ARCHITECTURE_VERSION,
                        "presentation_policy": "textbook-first-v3",
                        "printed_page_range": entry["printed_page_range"],
                        "book_heading": entry["book_heading"],
                    }),
                    compact(unit_provenance),
                ),
            )
            current_key = key

        assert current_unit_id is not None
        current_item_order += 1
        refs = [str(ref) for ref in entry.get("canonical_item_refs", [])]
        expected = core.projected_field(entry, canonical, "expected_response")
        acceptance = core.projected_field(entry, canonical, "acceptance_criteria")
        misconceptions = core.projected_field(entry, canonical, "common_misconceptions")
        canonical_guidance = core.projected_field(entry, canonical, "teacher_guidance")
        assessment = core.projected_field(entry, canonical, "assessment_evidence")
        differentiation = core.projected_differentiation({**entry, "show_differentiation": True}, canonical)
        review_required = is_review_required(entry, expected, fragment_status)
        if review_required:
            review_count += 1
        guidance = task_guidance(
            entry, expected, acceptance, canonical_guidance, misconceptions, assessment, review_required
        )
        relations = core.union_relations(refs, source_rel)
        item_id = f"{V3_ITEM_PREFIX}{entry['mirror_id']}"
        title = str(entry.get("prompt_display") or entry["book_heading"])
        label = str(entry["book_heading"])
        content_status = "REVIEW_REQUIRED" if review_required else "VERIFIED"

        assessment_list: list[Any] = []
        if isinstance(assessment, list):
            assessment_list.extend(assessment)
        elif nonempty(assessment):
            assessment_list.append(assessment)
        assessment_list.extend(
            [
                f"{guidance['v3_focus']} odağının doğru kurulması.",
                "İddia ile kaynak/metin kanıtı arasında açık gerekçe bağı bulunması.",
            ]
        )

        provenance = {
            # Compatibility class keeps the existing book-first viewer active.
            "content_class": "BOOK_FIRST_V2_3_ITEM",
            "teacher_guide_version": "3.0.0",
            "architecture_version": ARCHITECTURE_VERSION,
            "projection_version": PROJECTION_VERSION,
            "source_repository": "knigdelioglu/tymm",
            "source_tymm_commit": SOURCE_COMMIT,
            "source_ids": ["official_textbook_pdf"],
            "source_locators": [str(entry.get("source_locator") or "")],
            "theme_id": theme_id,
            "section_id": section_id,
            "mirror_id": entry["mirror_id"],
            "group_source_task_id": entry.get("group_source_task_id"),
            "split_from_group": bool(entry.get("split_from_group", False)),
            "question_number": entry.get("question_number"),
            "canonical_item_refs": refs,
            "answer_component_keys": [str(k) for k in entry.get("answer_keys", [])],
            "prompt_mode": entry.get("prompt_mode"),
            "rights_mode": entry.get("rights_mode"),
            "fragment_status": fragment_status,
            "v3_profile": guidance["v3_profile"],
            "v3_focus": guidance["v3_focus"],
        }
        payload = {
            "item_id": item_id,
            "unit_id": current_unit_id,
            "item_order": current_item_order,
            "title": title,
            "label": label,
            "item_type": str(entry["presentation_type"]),
            "page_locator": str(entry["printed_page_range"]),
            "source_locator": str(entry.get("source_locator") or ""),
            "content_status": content_status,
            "expected_response": expected,
            "acceptance_criteria": acceptance,
            "teacher_guidance": guidance,
            "common_misconceptions": misconceptions,
            "assessment_evidence": assessment_list,
            "differentiation": differentiation,
            "provenance": provenance,
            "relations": [
                {"target_type": t, "target_id": i, "relation_type": r, "order": n}
                for n, (t, i, r) in enumerate(relations, start=1)
            ],
        }
        digest = core.item_digest(payload)
        db.execute(
            """INSERT INTO teacher_guide_items(
                 item_id,unit_id,item_order,title,label,item_type,page_locator,source_locator,
                 content_status,expected_response_json,acceptance_criteria_json,
                 teacher_guidance_json,common_misconceptions_json,assessment_evidence_json,
                 differentiation_json,provenance_json,canonical_payload_sha256
               ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (
                item_id,
                current_unit_id,
                current_item_order,
                title,
                label,
                str(entry["presentation_type"]),
                str(entry["printed_page_range"]),
                str(entry.get("source_locator") or ""),
                content_status,
                compact(expected),
                compact(acceptance),
                compact(guidance),
                compact(misconceptions),
                compact(assessment_list),
                compact(differentiation),
                compact(provenance),
                digest,
            ),
        )
        for order, (target_type, target_id, relation_type) in enumerate(relations, start=1):
            db.execute(
                """INSERT INTO teacher_guide_item_relations(
                     item_id,target_type,target_id,relation_type,relation_order
                   ) VALUES (?,?,?,?,?)""",
                (item_id, target_type, target_id, relation_type, order),
            )

    metrics.update(totals)
    metrics["component_registry_entries"] = component_count
    metrics["units"] = core.table_count(db, "teacher_guide_units")
    metrics["review_required_items"] = review_count
    return metrics, sorted(set(source_paths))


def repo_relative(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(REPO_ROOT).as_posix()
    except ValueError as exc:
        raise V3ProjectionError(f"SOURCE_PATH_OUTSIDE_REPOSITORY:{resolved}") from exc


def source_hashes(source_root: Path, canonical_snapshot: Path, canonical_overrides: Path, prompt_overrides: Path) -> dict[str, str]:
    paths = sorted(
        [p.resolve() for p in source_root.rglob("*.patch") if p.is_file()],
        key=repo_relative,
    )
    paths.extend([canonical_snapshot.resolve(), canonical_overrides.resolve(), prompt_overrides.resolve()])
    return dict(sorted((repo_relative(p), core.sha256_file(p)) for p in paths))


def metadata_current(
    runtime_dir: Path,
    package_path: Path | None,
    expected_hashes: dict[str, str],
) -> bool:
    manifest_path = runtime_dir / "runtime_manifest.json"
    seal_path = runtime_dir / "teacher_guide_validation_seal.json"
    db_path = runtime_dir / "course_runtime.sqlite"
    if not all(p.is_file() for p in (manifest_path, seal_path, db_path)):
        return False
    try:
        manifest = read_json(manifest_path)
        seal = read_json(seal_path)
        book = (manifest.get("teacher_guide_capabilities") or {}).get("book_first_v3") or {}
        if (
            book.get("available") is not True
            or book.get("architecture_version") != ARCHITECTURE_VERSION
            or book.get("projection_version") != PROJECTION_VERSION
            or book.get("source_tymm_commit") != SOURCE_COMMIT
            or book.get("entries") != 576
            or book.get("questions") != 407
            or manifest.get("teacher_guide_source_commit") != SOURCE_COMMIT
            or seal.get("projection_version") != PROJECTION_VERSION
        ):
            return False
        stored = seal.get("source_files")
        if not isinstance(stored, dict):
            return False
        relevant = {
            str(k): str(v)
            for k, v in stored.items()
            if str(k).startswith("tool/teacher_guide/v23_source/")
            or str(k) in {
                "tool/teacher_guide/v23_canonical_snapshot.json",
                "tool/teacher_guide/v23_canonical_overrides.json",
                "tool/teacher_guide/v3_prompt_overrides.json",
            }
        }
        if relevant != expected_hashes:
            return False
        db = sqlite3.connect(db_path)
        try:
            checks = {
                "items": int(db.execute("SELECT COUNT(*) FROM teacher_guide_items").fetchone()[0]),
                "questions": int(db.execute("SELECT COUNT(*) FROM teacher_guide_items WHERE item_type='QUESTION'").fetchone()[0]),
                "v3_items": int(db.execute("SELECT COUNT(*) FROM teacher_guide_items WHERE item_id LIKE '__v23_item__%'").fetchone()[0]),
                "units": int(db.execute("SELECT COUNT(*) FROM teacher_guide_units").fetchone()[0]),
                "v3_units": int(db.execute("SELECT COUNT(*) FROM teacher_guide_units WHERE unit_id LIKE '__v23_unit__%'").fetchone()[0]),
            }
            if checks != {
                "items": 576,
                "questions": 407,
                "v3_items": 576,
                "units": EXPECTED_UNITS,
                "v3_units": EXPECTED_UNITS,
            }:
                return False
            if db.execute("PRAGMA foreign_key_check").fetchall():
                return False
        finally:
            db.close()
        if package_path and package_path.is_file():
            package = read_json(package_path)
            pbook = (package.get("teacher_guide_capabilities") or {}).get("book_first_v3") or {}
            if pbook.get("projection_version") != PROJECTION_VERSION:
                return False
        return True
    except (OSError, sqlite3.Error, ValueError, json.JSONDecodeError):
        return False


def update_metadata(
    db: sqlite3.Connection,
    runtime_dir: Path,
    package_path: Path | None,
    source_paths: list[Path],
    canonical_overrides: Path,
    metrics: dict[str, Any],
    prompt_overrides: Path,
) -> None:
    manifest_path = runtime_dir / "runtime_manifest.json"
    seal_path = runtime_dir / "teacher_guide_validation_seal.json"
    manifest = read_json(manifest_path)
    old_seal = read_json(seal_path)

    source_files: dict[str, str] = {}
    existing = old_seal.get("source_files")
    if isinstance(existing, dict):
        for raw_key, value in existing.items():
            key = str(raw_key)
            if (
                key.startswith("/")
                or "teacher_guide_v2_profiles.json" in key
                or "v23_source" in key
                or "v23_canonical_" in key
                or "v3_prompt_overrides.json" in key
            ):
                continue
            source_files[key] = str(value)
    for path in sorted(set(source_paths + [canonical_overrides, prompt_overrides]), key=repo_relative):
        source_files[repo_relative(path)] = core.sha256_file(path)
    source_files = dict(sorted(source_files.items()))

    counts = core.teacher_counts(db)
    fingerprint_payload = {
        "projection_version": PROJECTION_VERSION,
        "source_tymm_commit": SOURCE_COMMIT,
        "source_hashes": source_files,
        "row_counts": counts,
        "items": core.ordered_item_hashes(db),
    }
    fingerprint = core.sha256_bytes(compact(fingerprint_payload).encode("utf-8"))
    book_v3 = {
        "available": True,
        "architecture_version": ARCHITECTURE_VERSION,
        "projection_version": PROJECTION_VERSION,
        "source_tymm_commit": SOURCE_COMMIT,
        "source_mode": "VENDORED_SOURCE_BOUND_TEXTBOOK_FIRST_V3_PROJECTION",
        **metrics,
    }
    # Compatibility metadata keeps the existing viewer/page-jump path active.
    book_compat = {
        **book_v3,
        "compatibility_alias": "book_first_v3",
    }
    seal = {
        "seal_type": "TEACHER_GUIDE_COURSE_VALIDATION_SEAL",
        "projection_version": PROJECTION_VERSION,
        "status": "PASS",
        "scope": "COURSE",
        "course_id": manifest.get("course_id"),
        "canonical_content_fingerprint": manifest.get("canonical_content_fingerprint"),
        "teacher_guide_content_fingerprint": fingerprint,
        "source_validation_status": "PASS_WITH_REVIEW",
        "source_files": source_files,
        "row_counts": counts,
        "book_first_v3": book_v3,
        "book_first_v23": book_compat,
    }
    seal_path.write_text(compact(seal) + "\n", encoding="utf-8")
    seal_sha = core.sha256_file(seal_path)

    row_counts = manifest.get("row_counts")
    capabilities = manifest.get("teacher_guide_capabilities")
    validation = manifest.get("teacher_guide_validation")
    if not isinstance(row_counts, dict) or not isinstance(capabilities, dict) or not isinstance(validation, dict):
        raise V3ProjectionError("RUNTIME_MANIFEST_TEACHER_GUIDE_METADATA_INVALID")
    row_counts.update(counts)
    capabilities["row_counts"] = counts
    capabilities.pop("pedagogy_overlay", None)
    capabilities["book_first_v3"] = book_v3
    capabilities["book_first_v23"] = book_compat
    capabilities["architecture_version"] = ARCHITECTURE_VERSION
    validation["status"] = "PASS"
    validation["source_validation_status"] = "PASS_WITH_REVIEW"
    validation["content_fingerprint"] = f"sha256:{fingerprint}"
    validation["seal_sha256"] = seal_sha
    validation["projection_version"] = PROJECTION_VERSION
    validation["architecture_version"] = ARCHITECTURE_VERSION
    manifest["teacher_guide_source_commit"] = SOURCE_COMMIT
    manifest["runtime_package_version"] = RUNTIME_PACKAGE_VERSION
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if package_path is not None:
        package = read_json(package_path)
        package["teacher_guide_source_commit"] = SOURCE_COMMIT
        package["runtime_package_version"] = RUNTIME_PACKAGE_VERSION
        package["runtime_capabilities"] = manifest.get("capabilities", {})
        package["teacher_guide_capabilities"] = capabilities
        package["teacher_guide_validation"] = validation
        package["teacher_guide_row_counts"] = counts
        package_path.write_text(json.dumps(package, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def project(
    runtime_dir: Path,
    source_root: Path,
    canonical_snapshot: Path,
    canonical_overrides: Path,
    prompt_overrides: Path,
    package_path: Path | None,
) -> int:
    expected_hashes = source_hashes(source_root, canonical_snapshot, canonical_overrides, prompt_overrides)
    if metadata_current(runtime_dir, package_path, expected_hashes):
        print("TEACHER_GUIDE_V3_PROJECTION: ALREADY_CURRENT")
        print("ENTRIES: 576")
        print("QUESTIONS: 407")
        print("LOCATOR_ONLY_QUESTIONS: 0")
        return 0

    install_source_contract(canonical_snapshot, canonical_overrides, prompt_overrides)
    db_path = runtime_dir / "course_runtime.sqlite"
    db = sqlite3.connect(db_path)
    try:
        db.execute("PRAGMA foreign_keys=ON")
        db.execute("BEGIN IMMEDIATE")
        metrics, paths = build_projection(
            db, source_root, canonical_overrides, canonical_snapshot, prompt_overrides
        )
        if metrics["entries"] != 576 or metrics["questions"] != 407:
            raise V3ProjectionError(f"V3_COUNT_INVALID:{metrics}")
        if metrics["units"] != EXPECTED_UNITS:
            raise V3ProjectionError(f"V3_UNIT_COUNT_INVALID:{metrics['units']}")
        if db.execute("SELECT COUNT(*) FROM teacher_guide_items WHERE item_id NOT LIKE '__v23_item__%'").fetchone()[0]:
            raise V3ProjectionError("NON_V3_ITEMS_REMAIN")
        if int(db.execute("SELECT COUNT(*) FROM teacher_guide_items WHERE item_type='QUESTION'").fetchone()[0]) != 407:
            raise V3ProjectionError("V3_QUESTION_COUNT_INVALID")
        if db.execute("PRAGMA foreign_key_check").fetchall():
            raise V3ProjectionError("FOREIGN_KEY_CHECK_FAILED")
        db.commit()
        update_metadata(db, runtime_dir, package_path, paths, canonical_overrides, metrics, prompt_overrides)
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()

    # WAL/SHM sidecars must never be committed; make the database self-contained.
    for suffix in ("-wal", "-shm"):
        sidecar = Path(str(db_path) + suffix)
        if sidecar.exists():
            sidecar.unlink()

    print("TEACHER_GUIDE_V3_PROJECTION: PASS")
    print(f"ARCHITECTURE_VERSION: {ARCHITECTURE_VERSION}")
    print(f"PROJECTION_VERSION: {PROJECTION_VERSION}")
    print("ENTRIES: 576")
    print("QUESTIONS: 407")
    print("LOCATOR_ONLY_QUESTIONS: 0")
    print(f"UNITS: {EXPECTED_UNITS}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime-dir", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--canonical-snapshot", type=Path, required=True)
    parser.add_argument("--canonical-overrides", type=Path, required=True)
    parser.add_argument("--prompt-overrides", type=Path, required=True)
    parser.add_argument("--package-manifest", type=Path)
    args = parser.parse_args()
    return project(
        runtime_dir=args.runtime_dir.resolve(),
        source_root=args.source_root.resolve(),
        canonical_snapshot=args.canonical_snapshot.resolve(),
        canonical_overrides=args.canonical_overrides.resolve(),
        prompt_overrides=args.prompt_overrides.resolve(),
        package_path=args.package_manifest.resolve() if args.package_manifest else None,
    )


if __name__ == "__main__":
    raise SystemExit(main())
