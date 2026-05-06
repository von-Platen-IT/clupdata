#!/usr/bin/env python3
"""
CSV Testdaten-Generator für ClupData

Generiert 100 zusätzliche Datensätze pro Tabelle, unter Beachtung der
FK-Reihenfolge und UUID-Referenzen, damit die CSV-Dateien direkt
über den CSV-Bulk-Import importiert werden können.

Import-Reihenfolge (FK-Abhängigkeiten):
 1. bemerkung          (keine FK)
 2. stammdaten         (keine FK)
 3. preis              → bemerkung
 4. leistung           → preis, bemerkung
 5. mitglied           → leistung, preis, bemerkung
 6. waren              → bemerkung
 7. beitrag            → mitglied, leistung, preis, bemerkung
 8. beitrag_status_verlauf → beitrag
 9. rechnung           → mitglied, bemerkung
10. rechnung_position  → rechnung, waren

Export-Format:
- UTF-8 BOM (am Dateianfang)
- Semikolon als Trennzeichen
- Europäisches Zahlenformat (1.234,56)
- Unix-Timestamps (Sekunden seit Epoch)
- <NULL> für NULL-Werte
"""

import csv
import io
import os
import random
import uuid
from collections import defaultdict
from datetime import datetime, timedelta
from typing import Any

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# ── Konfiguration ──────────────────────────────────────────────────────────

ROWS_PER_TABLE = 100  # Anzahl neuer Datensätze pro Tabelle

# Import-Reihenfolge (FK-Abhängigkeiten: Eltern zuerst)
TABLE_ORDER = [
    "bemerkung",
    "stammdaten",
    "preis",
    "leistung",
    "mitglied",
    "waren",
    "beitrag",
    "beitrag_status_verlauf",
    "rechnung",
    "rechnung_position",
]

# Spalten mit europäischem Zahlenformat (Komma als Dezimaltrenner)
EUROPEAN_NUMBER_COLUMNS = {
    "preis": {"bruttopreis"},
    "leistung": set(),
    "waren": {"einkaufspreis", "bruttopreis", "gewicht_kg"},
    "rechnung": {"betrag_netto", "betrag_brutto", "betrag_mwst"},
    "rechnung_position": {
        "einzelpreis_netto",
        "einzelpreis_brutto",
        "mwst_satz",
        "gesamt_netto",
        "gesamt_brutto",
        "menge",
    },
    "mitglied": set(),
    "beitrag": set(),
    "beitrag_status_verlauf": set(),
    "bemerkung": set(),
    "stammdaten": set(),
}

# FK-Mapping: Tabellenname → Liste der FK-Spalten (Header-Namen)
FK_COLUMNS = {
    "bemerkung": [],
    "stammdaten": [],
    "preis": ["bemerkung_uuid"],
    "leistung": ["preis_uuid", "bemerkung_uuid"],
    "mitglied": ["leistung_uuid", "preis_uuid", "bemerkung_uuid"],
    "waren": ["bemerkung_uuid"],
    "beitrag": ["mitglied_uuid", "leistung_uuid", "preis_uuid", "bemerkung_uuid"],
    "beitrag_status_verlauf": ["beitrag_uuid"],
    "rechnung": ["mitglied_uuid", "bemerkung_uuid"],
    "rechnung_position": ["rechnung_uuid", "waren_uuid"],
}

# FK-Quelltabellen: Spaltenname → Quelltabelle
FK_SOURCE_TABLE = {
    "bemerkung_uuid": "bemerkung",
    "preis_uuid": "preis",
    "leistung_uuid": "leistung",
    "mitglied_uuid": "mitglied",
    "waren_uuid": "waren",
    "beitrag_uuid": "beitrag",
    "rechnung_uuid": "rechnung",
}


# ── Hilfsfunktionen ─────────────────────────────────────────────────────────

def generate_uuid() -> str:
    return str(uuid.uuid4())


def random_date(start_year: int = 2020, end_year: int = 2026) -> int:
    """Erzeugt einen Unix-Timestamp (Sekunden) zwischen start_year und end_year."""
    start = datetime(start_year, 1, 1)
    end = datetime(end_year, 12, 31)
    delta = end - start
    random_days = random.randint(0, delta.days)
    return int((start + timedelta(days=random_days)).timestamp())


def random_bool() -> str:
    return "1" if random.random() > 0.5 else "0"


def format_european(value: float) -> str:
    """Formatiert eine Zahl im europäischen Format: 1.234,56"""
    integer_part = int(value)
    decimal_part = int(round((value - integer_part) * 100))
    # Tausendertrennung
    int_str = f"{integer_part:,}".replace(",", ".")
    return f"{int_str},{decimal_part:02d}"


def pick_random(values: list[str]) -> str:
    return random.choice(values) if values else "<NULL>"


def read_csv_safe(filepath: str) -> tuple[list[str], list[dict[str, str]]]:
    """
    Liest eine CSV-Datei mit Semikolon-Trennung und UTF-8 BOM.
    Gibt (header, rows) zurück.
    """
    if not os.path.exists(filepath):
        return [], []

    with open(filepath, encoding="utf-8-sig") as f:
        content = f.read()

    # Leere Datei?
    if not content.strip():
        return [], []

    reader = csv.DictReader(io.StringIO(content), delimiter=";")
    header = reader.fieldnames or []
    rows = list(reader)
    return header, rows


def write_csv_safe(filepath: str, header: list[str], rows: list[dict[str, str]]) -> None:
    """Schreibt eine CSV-Datei mit UTF-8 BOM und Semikolon-Trennung."""
    with open(filepath, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=header, delimiter=";")
        writer.writeheader()
        writer.writerows(rows)
    print(f"  ✅ {len(rows)} Datensätze geschrieben → {os.path.basename(filepath)}")


# ── Datengeneratoren ───────────────────────────────────────────────────────

def generate_bemerkung_row(uuid_pool: dict[str, list[str]]) -> dict[str, str]:
    titel = random.choice([
        "Training", "Wettkampf", "Verletzung", "Mitgliedsbeitrag",
        "Sonderaktion", "Turnier", "Geburtstag", "Jubiläum",
        "Sponsoring", "Kooperation", "Workshop", "Lehrgang",
        "Prüfung", "Gürtelprüfung", "Ferien", "Sommerfest",
        "Weihnachtsfeier", "Vorstandssitzung", "Mitgliederversammlung",
        "Jahreshauptversammlung",
    ])
    text = random.choice([
        "",  # Manchmal leer
        "Wichtige Information",
        "Bitte beachten",
        "Erinnerung an Zahlung",
        "Erfolgreich absolviert",
        "Teilnahme bestätigt",
        "Rücksprache erforderlich",
        "Dokument eingereicht",
        "Antrag gestellt",
        "Genehmigt",
    ])
    return {
        "titel": titel,
        "text": text if random.random() > 0.3 else "",
        "datum_erstellt": str(random_date()),
        "uuid": generate_uuid(),
    }


def generate_stammdaten_row(index: int, uuid_pool: dict[str, list[str]]) -> dict[str, str]:
    stammdaten_keys = [
        ("sync_interval", "Tage", "integer", "system", "Sync-Intervall",
         "Intervall für Datensynchronisation", "1", "0"),
        ("max_mitglieder", "", "integer", "system", "Max. Mitglieder",
         "Maximale Anzahl Mitglieder", "1", "0"),
        ("club_name", "", "text", "stammdaten", "Vereinsname",
         "Name des Vereins", "1", "0"),
        ("club_street", "", "text", "stammdaten", "Straße",
         "Straße des Vereins", "1", "0"),
        ("club_city", "", "text", "stammdaten", "Ort",
         "Ort des Vereins", "1", "0"),
        ("club_zip", "", "text", "stammdaten", "PLZ",
         "Postleitzahl des Vereins", "1", "0"),
        ("club_phone", "", "text", "stammdaten", "Telefon",
         "Telefonnummer des Vereins", "1", "0"),
        ("club_email", "", "text", "stammdaten", "E-Mail",
         "E-Mail des Vereins", "1", "0"),
        ("training_start", "", "text", "training", "Trainingsbeginn",
         "Beginn der Trainingseinheit", "1", "0"),
        ("training_end", "", "text", "training", "Trainingsende",
         "Ende der Trainingseinheit", "1", "0"),
    ]
    key_info = stammdaten_keys[index % len(stammdaten_keys)]
    return {
        "schluessel": f"test_{key_info[0]}_{index}",
        "wert": f"Testwert_{index}",
        "typ": key_info[2],
        "kategorie": key_info[3],
        "bezeichnung": f"{key_info[4]} (Test {index})",
        "beschreibung": key_info[5],
        "aenderbar": "1",
        "system_pflicht": "0",
        "uuid": generate_uuid(),
    }


def generate_preis_row(uuid_pool: dict[str, list[str]]) -> dict[str, str]:
    bruttopreis = random.choice([19.99, 29.99, 39.99, 45.01, 55.00, 60.00, 80.00, 99.99, 120.00, 150.00, 199.99, 230.00])
    bemerkung_uuid = pick_random(uuid_pool["bemerkung"]) if random.random() > 0.7 else "<NULL>"
    return {
        "bruttopreis": format_european(bruttopreis),
        "bemerkung_uuid": bemerkung_uuid,
        "uuid": generate_uuid(),
    }


def generate_leistung_row(uuid_pool: dict[str, list[str]]) -> dict[str, str]:
    name = random.choice([
        "Boxen", "Kickboxen", "Muay Thai", "Brazilian Jiu-Jitsu",
        "Karate", "Taekwondo", "Judo", "Aikido", "Kung Fu",
        "Capoeira", "Krav Maga", "Wing Chun", "Escrima",
        "Mixed Martial Arts", "Ringen", "Fitnessboxen",
        "Selbstverteidigung", "Yoga für Kämpfer", "Krafttraining",
        "Ausdauertraining",
    ])
    laufzeit = random.choice(["monatlich", "einmalig", "quartalsweise", "jaehrlich"])
    preis_uuid = pick_random(uuid_pool["preis"])
    bemerkung_uuid = pick_random(uuid_pool["bemerkung"]) if random.random() > 0.5 else "<NULL>"
    return {
        "name": name,
        "preis_uuid": preis_uuid,
        "laufzeit": laufzeit,
        "bemerkung_uuid": bemerkung_uuid,
        "uuid": generate_uuid(),
    }


def generate_mitglied_row(uuid_pool: dict[str, list[str]]) -> dict[str, str]:
    vornamen = [
        "Max", "Erika", "Hans", "Maria", "Klaus", "Petra", "Thomas",
        "Sabine", "Michael", "Susanne", "Andreas", "Monika", "Stefan",
        "Nicole", "Christian", "Simone", "Frank", "Kerstin", "Peter",
        "Heike", "Jürgen", "Angelika", "Bernd", "Ute", "Ralf",
        "Diana", "Volker", "Silke", "Gerd", "Brigitte",
    ]
    nachnamen = [
        "Müller", "Schmidt", "Schneider", "Fischer", "Weber",
        "Wagner", "Becker", "Hoffmann", "Schäfer", "Koch",
        "Bauer", "Richter", "Klein", "Wolf", "Schröder",
        "Neumann", "Schwarz", "Zimmermann", "Braun", "Krüger",
        "Hofmann", "Hartmann", "Lange", "Schmitt", "Werner",
        "Krause", "Meier", "Lehmann", "Schulze", "Maier",
    ]
    orte = [
        "Berlin", "Hamburg", "München", "Köln", "Frankfurt",
        "Stuttgart", "Düsseldorf", "Leipzig", "Dortmund", "Essen",
        "Bremen", "Dresden", "Hannover", "Nürnberg", "Duisburg",
        "Bochum", "Wuppertal", "Bielefeld", "Bonn", "Münster",
    ]
    anreden = ["Herr", "Frau", "<NULL>"]
    geschlechter = ["maennlich", "weiblich", "<NULL>"]

    vorname = random.choice(vornamen)
    nachname = random.choice(nachnamen)
    anrede = random.choice(anreden)
    geschlecht = random.choice(geschlechter)

    leistung_uuid = pick_random(uuid_pool["leistung"])
    preis_uuid = pick_random(uuid_pool["preis"])
    bemerkung_uuid = pick_random(uuid_pool["bemerkung"]) if random.random() > 0.7 else "<NULL>"

    vertrag_von = random_date(2024, 2026)
    vertrag_bis = random_date(2026, 2028)

    return {
        "anrede": anrede,
        "name": nachname,
        "vorname": vorname,
        "plz": f"{random.randint(10000, 99999)}",
        "ort": random.choice(orte),
        "strasse": random.choice(["Hauptstr.", "Schulweg", "Bahnhofstr.", "Am Park",
                                   "Wiesenweg", "Bergstr.", "Mühlenweg", "Kirchenweg"]),
        "hausnummer": str(random.randint(1, 150)),
        "telefon1": f"0{random.randint(100, 9999)}{random.randint(100000, 999999)}",
        "telefon2": f"0{random.randint(100, 9999)}{random.randint(100000, 999999)}" if random.random() > 0.5 else "",
        "email": f"{vorname.lower()}.{nachname.lower()}{random.randint(1, 999)}@email.de",
        "geboren": str(random_date(1960, 2008)),
        "geschlecht": geschlecht,
        "leistung_uuid": leistung_uuid,
        "vertrag_kontierung": str(random_date(2024, 2026)),
        "vertrag_laufzeit_von": str(vertrag_von),
        "vertrag_laufzeit_bis": str(vertrag_bis),
        "preis_uuid": preis_uuid,
        "bemerkung_uuid": bemerkung_uuid,
        "uuid": generate_uuid(),
    }


def generate_waren_row(uuid_pool: dict[str, list[str]]) -> dict[str, str]:
    bezeichnungen = [
        ("Boxhandschuhe", "boxen"),
        ("Mundschutz", "boxen"),
        ("Bandagen", "boxen"),
        ("T-Shirt", "bekleidung"),
        ("Hose", "bekleidung"),
        ("Trainingsanzug", "bekleidung"),
        ("Handschuhe", "training"),
        ("Springseil", "training"),
        ("Pratze", "training"),
        ("Boxsack", "training"),
        ("Kopfschutz", "boxen"),
        ("Tiefschutz", "boxen"),
        ("Schienbeinschoner", "boxen"),
        ("Boxhandschuh-Tasche", "zubehoer"),
        ("Getränkeflasche", "zubehoer"),
        ("Handtuch", "zubehoer"),
        ("Kapuzenpullover", "bekleidung"),
        ("Mütze", "bekleidung"),
        ("Trainingsjacke", "bekleidung"),
        ("Boxshort", "bekleidung"),
    ]
    bezeichnung, kategorie = random.choice(bezeichnungen)
    farben = ["rot", "blau", "schwarz", "weiss", "silber", "gelb", "gruen", "orange", "lila", "pink"]
    groessen = ["S", "M", "L", "XL", "XXL", "XS", "einheitlich", "42", "44", "46"]
    materialien = ["Leder", "Kunstleder", "Polyester", "Baumwolle", "Nylon", "Schaumstoff", "Latex"]
    lieferanten = ["Sport GmbH", "Kampfsport AG", "Fitness OHG", "Boxwelt KG", "Training SE",
                    "Sports Unlimited", "Martial Arts Supply", "Combat Sports Ltd."]
    hersteller = ["Adidas", "Nike", "Everlast", "Venum", "Title", "Rival", "Fairtex", "Hayabusa"]

    einkauf = random.choice([15.00, 23.00, 34.00, 45.00, 60.00, 80.00, 120.00])
    aufschlag = random.uniform(0.3, 1.0)
    brutto = round(einkauf * (1 + aufschlag), 2)

    timestamp = random_date(2025, 2026)

    bemerkung_uuid = pick_random(uuid_pool["bemerkung"]) if random.random() > 0.7 else "<NULL>"

    return {
        "bezeichnung": bezeichnung,
        "beschreibung": f"{bezeichnung} für Training und Wettkampf",
        "kategorie": kategorie,
        "groesse": random.choice(groessen),
        "farbe": random.choice(farben),
        "geschlecht": random.choice(["Unisex", "Herren", "Damen"]),
        "material": random.choice(materialien),
        "einkaufspreis": format_european(einkauf),
        "bruttopreis": format_european(brutto),
        "bestand": str(random.randint(0, 50)),
        "mindestbestand": str(random.randint(0, 5)),
        "lieferant": random.choice(lieferanten),
        "hersteller": random.choice(hersteller),
        "hersteller_artikelnr": f"ART-{random.randint(10000, 99999)}",
        "gewicht_kg": format_european(round(random.uniform(0.1, 5.0), 2)) if random.random() > 0.3 else "<NULL>",
        "einheit": random.choice(["Stück", "Paar", "Set", "Flasche", ""]),
        "bild_url": "<NULL>",
        "aktiv": random_bool(),
        "erstellt_am": str(timestamp),
        "aktualisiert_am": str(timestamp),
        "bemerkung_uuid": bemerkung_uuid,
        "uuid": generate_uuid(),
    }


def generate_beitrag_row(uuid_pool: dict[str, list[str]]) -> dict[str, str]:
    status = random.choice(["kontiert", "offen", "bezahlt", "angemahnt"])
    kontiert_am = random_date(2025, 2026)
    bemerkung_uuid = pick_random(uuid_pool["bemerkung"]) if random.random() > 0.7 else "<NULL>"
    mitglied_uuid = pick_random(uuid_pool["mitglied"])
    leistung_uuid = pick_random(uuid_pool["leistung"])
    preis_uuid = pick_random(uuid_pool["preis"])
    return {
        "mitglied_uuid": mitglied_uuid,
        "leistung_uuid": leistung_uuid,
        "preis_uuid": preis_uuid,
        "rechnungsnummer": f"RE-{random.randint(2024, 2026)}-{random.randint(10000, 99999)}",
        "status": status,
        "kontiert_am": str(kontiert_am),
        "abrechnungs_zeitraum": "<NULL>",
        "status_datum": str(kontiert_am),
        "bemerkung_uuid": bemerkung_uuid,
        "uuid": generate_uuid(),
    }


def generate_beitrag_status_verlauf_row(uuid_pool: dict[str, list[str]]) -> dict[str, str]:
    status = random.choice(["kontiert", "offen", "bezahlt", "angemahnt", "storniert", "inkasso"])
    beitrag_uuid = pick_random(uuid_pool["beitrag"])
    return {
        "beitrag_uuid": beitrag_uuid,
        "status": status,
        "geaendert_am": str(random_date(2025, 2026)),
        "bemerkung": random.choice(["Beitrag angelegt", "Zahlung eingegangen", "Mahnung versendet",
                                     "Storniert", "Inkasso eingeleitet", "Automatisch erstellt"]),
        "uuid": generate_uuid(),
    }


def generate_rechnung_row(uuid_pool: dict[str, list[str]]) -> dict[str, str]:
    betrag_netto = round(random.uniform(20.00, 500.00), 2)
    betrag_brutto = round(betrag_netto * 1.19, 2)
    betrag_mwst = round(betrag_brutto - betrag_netto, 2)

    mitglied_uuid = pick_random(uuid_pool["mitglied"])
    bemerkung_uuid = pick_random(uuid_pool["bemerkung"]) if random.random() > 0.7 else "<NULL>"

    datum = random_date(2025, 2026)
    faellig = datum + 14 * 24 * 3600  # +14 Tage

    return {
        "rechnungsnummer": f"R-{random.randint(2024, 2026)}-{random.randint(10000, 99999)}",
        "mitglied_uuid": mitglied_uuid,
        "kunde_name": f"Kunde {random.randint(1, 999)}",
        "status": random.choice(["offen", "bezahlt", "storniert"]),
        "datum": str(datum),
        "faellig_am": str(faellig),
        "bezahlt_am": str(faellig + random.randint(1, 30) * 86400) if random.random() > 0.5 else "<NULL>",
        "betrag_netto": format_european(betrag_netto),
        "betrag_brutto": format_european(betrag_brutto),
        "betrag_mwst": format_european(betrag_mwst),
        "bemerkung_uuid": bemerkung_uuid,
        "erstellt_am": str(datum),
        "aktualisiert_am": str(datum),
        "uuid": generate_uuid(),
    }


def generate_rechnung_position_row(uuid_pool: dict[str, list[str]]) -> dict[str, str]:
    menge = random.randint(1, 10)
    einzelpreis_brutto = round(random.uniform(5.00, 200.00), 2)
    einzelpreis_netto = round(einzelpreis_brutto / 1.19, 2)
    gesamt_brutto = round(einzelpreis_brutto * menge, 2)
    gesamt_netto = round(einzelpreis_netto * menge, 2)

    rechnung_uuid = pick_random(uuid_pool["rechnung"])
    waren_uuid = pick_random(uuid_pool["waren"])

    return {
        "rechnung_uuid": rechnung_uuid,
        "position_nr": str(random.randint(1, 20)),
        "waren_uuid": waren_uuid,
        "bezeichnung": f"Artikel {random.randint(1, 999)}",
        "menge": format_european(float(menge)),
        "einzelpreis_netto": format_european(einzelpreis_netto),
        "einzelpreis_brutto": format_european(einzelpreis_brutto),
        "mwst_satz": format_european(19.00),
        "gesamt_netto": format_european(gesamt_netto),
        "gesamt_brutto": format_european(gesamt_brutto),
        "uuid": generate_uuid(),
    }


# Generator-Map: Tabelle → Funktion
GENERATORS = {
    "bemerkung": generate_bemerkung_row,
    "stammdaten": generate_stammdaten_row,
    "preis": generate_preis_row,
    "leistung": generate_leistung_row,
    "mitglied": generate_mitglied_row,
    "waren": generate_waren_row,
    "beitrag": generate_beitrag_row,
    "beitrag_status_verlauf": generate_beitrag_status_verlauf_row,
    "rechnung": generate_rechnung_row,
    "rechnung_position": generate_rechnung_position_row,
}


# ── Hauptprogramm ──────────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("ClupData CSV Testdaten-Generator")
    print(f"Generiere {ROWS_PER_TABLE} neue Datensätze pro Tabelle")
    print("=" * 60)

    # UUID-Pool: Tabelle → Liste von UUIDs (aus bestehenden + neu generierten)
    uuid_pool: dict[str, list[str]] = defaultdict(list)

    # Schritt 1: Bestehende UUIDs aus allen Tabellen laden
    print("\n📖 Lese bestehende CSV-Dateien...")
    all_tables: dict[str, dict] = {}
    for table in TABLE_ORDER:
        filepath = os.path.join(SCRIPT_DIR, f"{table}.csv")
        header, rows = read_csv_safe(filepath)
        all_tables[table] = {"header": header, "rows": rows}
        existing_uuids = [r.get("uuid", "") for r in rows if r.get("uuid")]
        uuid_pool[table].extend(existing_uuids)
        print(f"  📄 {table}.csv: {len(rows)} bestehende, {len(existing_uuids)} UUIDs geladen")

    # Schritt 2: Neue Daten generieren (in FK-Reihenfolge)
    print(f"\n🔄 Generiere {ROWS_PER_TABLE} neue Datensätze pro Tabelle...")
    for table in TABLE_ORDER:
        generator = GENERATORS[table]
        if not generator:
            print(f"  ⚠️ Kein Generator für {table} – überspringe")
            continue

        new_rows = []
        for i in range(ROWS_PER_TABLE):
            if table == "stammdaten":
                row = generator(i, uuid_pool)
            else:
                row = generator(uuid_pool)
            new_rows.append(row)

        # Neue UUIDs zum Pool hinzufügen
        new_uuids = [r["uuid"] for r in new_rows]
        uuid_pool[table].extend(new_uuids)

        # An bestehende Daten anhängen
        all_tables[table]["rows"].extend(new_rows)
        print(f"  ✅ {table}: +{len(new_rows)} Datensätze (Pool: {len(uuid_pool[table])} UUIDs)")

    # Schritt 3: Dateien zurückschreiben
    print("\n💾 Schreibe aktualisierte CSV-Dateien...")
    for table in TABLE_ORDER:
        filepath = os.path.join(SCRIPT_DIR, f"{table}.csv")
        header = all_tables[table]["header"]
        rows = all_tables[table]["rows"]
        if header and rows:
            write_csv_safe(filepath, header, rows)
        else:
            print(f"  ⚠️ {table}: Keine Header/Zeilen – übersprungen")

    # Schritt 4: Zusammenfassung
    print("\n" + "=" * 60)
    print("📊 Zusammenfassung")
    print("=" * 60)
    for table in TABLE_ORDER:
        filepath = os.path.join(SCRIPT_DIR, f"{table}.csv")
        if os.path.exists(filepath):
            with open(filepath, encoding="utf-8-sig") as f:
                line_count = sum(1 for _ in f) - 1  # Header abziehen
            print(f"  📄 {table}.csv: {line_count} Datensätze")
    print("=" * 60)
    print("🎉 Fertig! Die CSV-Dateien können importiert werden.")


if __name__ == "__main__":
    main()
