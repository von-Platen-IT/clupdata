# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Ask Mode - Non-Obvious Context

- **[`lib/assets/data/structur.md`](lib/assets/data/structur.md)** is the SSOT — defines DB schema, relations, UI config, status colors, and business rules. Must be consulted before answering architecture questions.
- **Rechnungsnummer formats differ by feature**: Beiträge = `RE-YYYY-XXXXX`, Waren = `R-YYYY-XXXXX`
- **Bemerkung (notes)** are not per-feature — all centralized via [`bemerkung_repository.dart`](lib/core/data/bemerkung_repository.dart) with FK from any entity
- **Status history** on `beitrag` is auto-logged — [`updateBeitrag()`](lib/features/beitraege/data/beitraege_repository.dart:134) detects changes and creates `beitrag_status_verlauf` entries; comment is mandatory
- **Export architecture is split**: Feature-specific UI in `lib/features/export/`, reusable PDF/CSV infrastructure in `lib/widgets/data_grid_v2/export/`
- **Drift table class names** use German pluralization: `Mitglieds`, `Beitraege`, `Rechnungen`, `RechnungPositionen`
- **CSV export** uses UTF-8 with BOM (not plain UTF-8) for Excel compatibility
- **`gap` package** replaces `SizedBox` for spacing throughout the project
- **Status colors** source: [`beitrag_status_colors.dart`](lib/features/beitraege/utils/beitrag_status_colors.dart) — never hardcode hex values
