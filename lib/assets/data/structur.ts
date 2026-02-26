{
    "_meta": {
        "version": "1.0.0",
            "created": "2026-02-26",
                "description": "Schema definition for database structure and UI configuration. Used by AI coding agent to generate database models and UI screens.",
                    "file": "lib/assets/data/structur.json"
    },

    "database": {

        "tables": [

            {
                "name": "bemerkung",
                "comment": "Generic note/remark entity reused across all tables via FK.",
                "fields": [
                    { "name": "id", "type": "INTEGER", "primaryKey": true, "autoIncrement": true },
                    { "name": "titel", "type": "TEXT", "nullable": false, "maxLength": 200, "unicode": true },
                    { "name": "text", "type": "TEXT", "nullable": true, "maxLength": 10000, "unicode": true },
                    { "name": "datum_erstellt", "type": "DATETIME", "nullable": false, "default": "CURRENT_TIMESTAMP" }
                ]
            },

            {
                "name": "stammdaten",
                "comment": "Key/value configuration store. Contains global settings like MwSt rate, file paths, app config.",
                "fields": [
                    { "name": "id", "type": "INTEGER", "primaryKey": true, "autoIncrement": true },
                    {
                        "name": "schluessel", "type": "TEXT", "nullable": false, "unique": true, "maxLength": 100,
                        "comment": "Unique config key, e.g. 'mwst_standard', 'firma_name'"
                    },
                    {
                        "name": "wert", "type": "TEXT", "nullable": true,
                        "comment": "Stored as text, parsed according to 'typ'"
                    },
                    {
                        "name": "typ", "type": "TEXT", "nullable": false,
                        "enum": ["string", "number", "boolean", "date"],
                        "comment": "Data type for correct parsing of 'wert'"
                    },
                    {
                        "name": "kategorie", "type": "TEXT", "nullable": false,
                        "enum": ["finanzen", "programm", "firma", "druck", "sonstiges"],
                        "comment": "Groups settings in the UI"
                    },
                    {
                        "name": "bezeichnung", "type": "TEXT", "nullable": false, "maxLength": 200,
                        "comment": "Human-readable label shown in settings UI"
                    },
                    {
                        "name": "beschreibung", "type": "TEXT", "nullable": true, "maxLength": 500,
                        "comment": "Tooltip / help text shown in settings UI"
                    },
                    {
                        "name": "aenderbar", "type": "INTEGER", "nullable": false, "default": 1,
                        "comment": "1 = user may edit, 0 = read-only system value"
                    }
                ],
                "seedData": [
                    { "schluessel": "mwst_standard", "wert": "19", "typ": "number", "kategorie": "finanzen", "bezeichnung": "MwSt. Standardsatz (%)", "aenderbar": 1 },
                    { "schluessel": "mwst_ermaessigt", "wert": "7", "typ": "number", "kategorie": "finanzen", "bezeichnung": "MwSt. ermäßigter Satz (%)", "aenderbar": 1 },
                    { "schluessel": "mwst_aktiv_schluessel", "wert": "mwst_standard", "typ": "string", "kategorie": "finanzen", "bezeichnung": "Verwendeter MwSt.-Schlüssel", "aenderbar": 1 },
                    { "schluessel": "firma_name", "wert": "", "typ": "string", "kategorie": "firma", "bezeichnung": "Firmenname", "aenderbar": 1 },
                    { "schluessel": "firma_strasse", "wert": "", "typ": "string", "kategorie": "firma", "bezeichnung": "Straße / Hausnummer", "aenderbar": 1 },
                    { "schluessel": "firma_plz", "wert": "", "typ": "string", "kategorie": "firma", "bezeichnung": "PLZ", "aenderbar": 1 },
                    { "schluessel": "firma_ort", "wert": "", "typ": "string", "kategorie": "firma", "bezeichnung": "Ort", "aenderbar": 1 },
                    { "schluessel": "pfad_export", "wert": "", "typ": "string", "kategorie": "programm", "bezeichnung": "Export-Verzeichnis", "aenderbar": 1 },
                    { "schluessel": "pfad_backup", "wert": "", "typ": "string", "kategorie": "programm", "bezeichnung": "Backup-Verzeichnis", "aenderbar": 1 },
                    { "schluessel": "db_version", "wert": "1", "typ": "number", "kategorie": "programm", "bezeichnung": "Datenbankversion", "aenderbar": 0 }
                ]
            },

            {
                "name": "preis",
                "comment": "Price entity. Nettopreis is always computed at runtime from bruttopreis and mwst from stammdaten.",
                "fields": [
                    { "name": "id", "type": "INTEGER", "primaryKey": true, "autoIncrement": true },
                    { "name": "bruttopreis", "type": "REAL", "nullable": false, "comment": "Stored value. Always gross." },
                    { "name": "bemerkung_id", "type": "INTEGER", "nullable": true, "foreignKey": { "table": "bemerkung", "field": "id", "onDelete": "SET NULL" } }
                ],
                "computedFields": [
                    {
                        "name": "nettopreis",
                        "comment": "NOT stored. Computed at runtime: bruttopreis / (1 + mwst/100). MwSt read from stammdaten.mwst_aktiv_schluessel.",
                        "formula": "bruttopreis / (1 + stammdaten['mwst_aktiv_schluessel'] / 100)"
                    }
                ]
            },

            {
                "name": "leistung",
                "comment": "Service or membership tier offered to members.",
                "fields": [
                    { "name": "id", "type": "INTEGER", "primaryKey": true, "autoIncrement": true },
                    { "name": "name", "type": "TEXT", "nullable": false, "maxLength": 200, "unicode": true },
                    { "name": "preis_id", "type": "INTEGER", "nullable": false, "foreignKey": { "table": "preis", "field": "id", "onDelete": "RESTRICT" } },
                    {
                        "name": "laufzeit", "type": "TEXT", "nullable": false,
                        "enum": ["einmalig", "monatlich", "quartalsweise", "jaehrlich"],
                        "comment": "Used to auto-calculate Vertrag_Laufzeit_bis when Vertrag_Laufzeit_von changes"
                    },
                    { "name": "bemerkung_id", "type": "INTEGER", "nullable": true, "foreignKey": { "table": "bemerkung", "field": "id", "onDelete": "SET NULL" } }
                ]
            },

            {
                "name": "mitglied",
                "comment": "Main member entity.",
                "fields": [
                    { "name": "id", "type": "INTEGER", "primaryKey": true, "autoIncrement": true },
                    { "name": "anrede", "type": "TEXT", "nullable": true, "enum": ["Herr", "Frau", "Divers", "Keine"] },
                    { "name": "name", "type": "TEXT", "nullable": false, "maxLength": 100, "unicode": true },
                    { "name": "vorname", "type": "TEXT", "nullable": false, "maxLength": 100, "unicode": true },
                    { "name": "plz", "type": "TEXT", "nullable": true, "maxLength": 10 },
                    { "name": "ort", "type": "TEXT", "nullable": true, "maxLength": 100, "unicode": true },
                    { "name": "telefon1", "type": "TEXT", "nullable": true, "maxLength": 50 },
                    { "name": "telefon2", "type": "TEXT", "nullable": true, "maxLength": 50 },
                    { "name": "email", "type": "TEXT", "nullable": true, "maxLength": 200 },
                    { "name": "geschlecht", "type": "TEXT", "nullable": true, "enum": ["maennlich", "weiblich", "divers"] },
                    { "name": "geboren", "type": "DATE", "nullable": true, "comment": "Date of birth. Format: ISO 8601 (YYYY-MM-DD) in DB." },
                    { "name": "leistung_id", "type": "INTEGER", "nullable": true, "foreignKey": { "table": "leistung", "field": "id", "onDelete": "SET NULL" } },
                    { "name": "vertrag_kontierung", "type": "DATE", "nullable": true, "comment": "Booking/accounting date of the contract." },
                    { "name": "vertrag_laufzeit_von", "type": "DATE", "nullable": true },
                    {
                        "name": "vertrag_laufzeit_bis", "type": "DATE", "nullable": true,
                        "comment": "Auto-calculated from vertrag_laufzeit_von + leistung.laufzeit. Can be overridden by user."
                    },
                    { "name": "bemerkung_id", "type": "INTEGER", "nullable": true, "foreignKey": { "table": "bemerkung", "field": "id", "onDelete": "SET NULL" } }
                ],
                "computedFields": [
                    {
                        "name": "alter",
                        "comment": "NOT stored. Computed at runtime from 'geboren' and today's date.",
                        "formula": "floor(days_between(geboren, today) / 365.25)"
                    }
                ]
            }

        ],

            "indexes": [
                { "table": "mitglied", "name": "idx_mitglied_name", "fields": ["name", "vorname"], "comment": "Full-name search" },
                { "table": "mitglied", "name": "idx_mitglied_plz_ort", "fields": ["plz", "ort"] },
                { "table": "mitglied", "name": "idx_mitglied_leistung", "fields": ["leistung_id"] },
                { "table": "mitglied", "name": "idx_mitglied_vertrag_von", "fields": ["vertrag_laufzeit_von"], "comment": "Range queries on contract start" },
                { "table": "mitglied", "name": "idx_mitglied_vertrag_bis", "fields": ["vertrag_laufzeit_bis"], "comment": "Expiry queries" },
                { "table": "mitglied", "name": "idx_mitglied_geboren", "fields": ["geboren"] },
                { "table": "leistung", "name": "idx_leistung_name", "fields": ["name"] },
                { "table": "leistung", "name": "idx_leistung_preis", "fields": ["preis_id"] },
                { "table": "stammdaten", "name": "idx_stammdaten_schluessel", "fields": ["schluessel"], "unique": true },
                { "table": "stammdaten", "name": "idx_stammdaten_kategorie", "fields": ["kategorie"] },
                { "table": "bemerkung", "name": "idx_bemerkung_datum", "fields": ["datum_erstellt"] }
            ],

                "relations": [
                    { "from": "mitglied.leistung_id", "to": "leistung.id", "type": "many-to-one", "label": "Mitglied hat eine Leistung" },
                    { "from": "mitglied.bemerkung_id", "to": "bemerkung.id", "type": "many-to-one", "label": "Mitglied hat eine Bemerkung" },
                    { "from": "leistung.preis_id", "to": "preis.id", "type": "many-to-one", "label": "Leistung hat einen Preis" },
                    { "from": "leistung.bemerkung_id", "to": "bemerkung.id", "type": "many-to-one", "label": "Leistung hat eine Bemerkung" },
                    { "from": "preis.bemerkung_id", "to": "bemerkung.id", "type": "many-to-one", "label": "Preis hat eine Bemerkung" }
                ]
    },

    "ui": {

        "globalRules": {
            "dataGridPackage": "pluto_grid",
                "dataGridPackageUrl": "https://pub.dev/packages/pluto_grid",
                    "dateDisplayFormat": "dd.MM.yyyy",
                        "dateDbFormat": "YYYY-MM-DD",
                            "locale": "de_DE",
                                "allTablesUseAppDataGrid": true,
                                    "appDataGridBaseClass": "AppDataGrid",
                                        "appDataGridLocation": "lib/widgets/data_grid/app_data_grid.dart",
                                            "comment": "See datagrid_agent_config.md for full AppDataGrid specification including search, sort dialog and filter dialog."
        },

        "screens": [

            {
                "id": "screen_mitglied_list",
                "title": "Mitglieder",
                "route": "/mitglieder",
                "type": "dataGridScreen",
                "dataSource": "mitglied",
                "baseClass": "AppDataGrid",

                "dataGrid": {
                    "sortableColumns": [
                        { "field": "name", "label": "Name", "enabledByDefault": true, "defaultAscending": true },
                        { "field": "vorname", "label": "Vorname", "enabledByDefault": false, "defaultAscending": true },
                        { "field": "vertrag_kontierung", "label": "Kontierung", "enabledByDefault": false, "defaultAscending": false },
                        { "field": "vertrag_laufzeit_von", "label": "Laufzeit von", "enabledByDefault": false, "defaultAscending": true },
                        { "field": "vertrag_laufzeit_bis", "label": "Laufzeit bis", "enabledByDefault": false, "defaultAscending": true },
                        { "field": "leistung_name", "label": "Vertragsart", "enabledByDefault": false, "defaultAscending": true }
                    ],
                    "columns": [
                        { "field": "name", "label": "Name", "type": "text", "width": 150, "enableSorting": true, "enableFilter": true },
                        { "field": "vorname", "label": "Vorname", "type": "text", "width": 130, "enableSorting": true, "enableFilter": true },
                        { "field": "ort", "label": "Ort", "type": "text", "width": 120, "enableSorting": true, "enableFilter": true },
                        { "field": "telefon1", "label": "Telefon", "type": "text", "width": 130, "enableSorting": false, "enableFilter": true },
                        { "field": "email", "label": "E-Mail", "type": "text", "width": 180, "enableSorting": false, "enableFilter": true },
                        {
                            "field": "leistung_name", "label": "Vertragsart", "type": "text", "width": 150, "enableSorting": true, "enableFilter": true,
                            "comment": "Joined display value from leistung.name"
                        },
                        { "field": "vertrag_laufzeit_von", "label": "Laufzeit von", "type": "date", "width": 120, "enableSorting": true, "enableFilter": true, "format": "dd.MM.yyyy" },
                        { "field": "vertrag_laufzeit_bis", "label": "Laufzeit bis", "type": "date", "width": 120, "enableSorting": true, "enableFilter": true, "format": "dd.MM.yyyy" },
                        {
                            "field": "alter", "label": "Alter", "type": "number", "width": 70, "enableSorting": true, "enableFilter": false,
                            "computed": true, "comment": "Computed from 'geboren'. Not stored in DB."
                        }
                    ],
                    "toSearchStringFields": ["name", "vorname", "ort", "plz", "email", "telefon1", "telefon2", "leistung_name", "vertrag_laufzeit_von", "vertrag_laufzeit_bis", "vertrag_kontierung"]
                },

                "actions": [
                    { "id": "btn_neu", "label": "Neu", "icon": "Icons.add", "opensDialog": "dialog_mitglied_vertrag_start" },
                    { "id": "btn_bearbeiten", "label": "Bearbeiten", "icon": "Icons.edit", "opensScreen": "screen_mitglied_edit", "requiresSelection": true },
                    { "id": "btn_loeschen", "label": "Löschen", "icon": "Icons.delete", "requiresSelection": true, "confirm": true }
                ]
            },

            {
                "id": "screen_mitglied_edit",
                "title": "Mitglied bearbeiten",
                "route": "/mitglieder/edit",
                "type": "formScreen",
                "dataSource": "mitglied",

                "formSections": [
                    {
                        "title": "Person",
                        "fields": [
                            { "field": "anrede", "label": "Anrede", "widget": "DropdownField", "options": ["Herr", "Frau", "Divers", "Keine"], "nullable": true },
                            { "field": "vorname", "label": "Vorname", "widget": "TextField", "maxLength": 100, "required": true },
                            { "field": "name", "label": "Name", "widget": "TextField", "maxLength": 100, "required": true },
                            { "field": "geboren", "label": "Geburtsdatum", "widget": "DateField", "format": "dd.MM.yyyy" },
                            { "field": "alter", "label": "Alter", "widget": "ReadOnlyField", "computed": true, "suffix": "Jahre" },
                            { "field": "geschlecht", "label": "Geschlecht", "widget": "DropdownField", "options": ["maennlich", "weiblich", "divers"], "nullable": true }
                        ]
                    },
                    {
                        "title": "Kontakt",
                        "fields": [
                            { "field": "plz", "label": "PLZ", "widget": "TextField", "maxLength": 10, "keyboardType": "number" },
                            { "field": "ort", "label": "Ort", "widget": "TextField", "maxLength": 100 },
                            { "field": "telefon1", "label": "Telefon 1", "widget": "TextField", "maxLength": 50, "keyboardType": "phone" },
                            { "field": "telefon2", "label": "Telefon 2", "widget": "TextField", "maxLength": 50, "keyboardType": "phone" },
                            {
                                "field": "email", "label": "E-Mail", "widget": "TextField", "maxLength": 200, "keyboardType": "email",
                                "validation": "email"
                            }
                        ]
                    },
                    {
                        "title": "Vertrag",
                        "fields": [
                            {
                                "field": "vertrag_start_action",
                                "label": "",
                                "widget": "ElevatedButton",
                                "buttonLabel": "Start",
                                "icon": "Icons.play_arrow",
                                "opensDialog": "dialog_mitglied_vertrag_start",
                                "comment": "Opens the contract start modal dialog"
                            },
                            {
                                "field": "vertrag_kontierung", "label": "Kontierung", "widget": "DateField", "format": "dd.MM.yyyy", "readOnly": true,
                                "comment": "Set by dialog_mitglied_vertrag_start. Read-only in form."
                            },
                            {
                                "field": "leistung_id", "label": "Leistung", "widget": "ReadOnlyDisplayField", "displayField": "leistung_name",
                                "comment": "Set by dialog_mitglied_vertrag_start. Displayed as Leistung.name."
                            },
                            { "field": "vertrag_laufzeit_von", "label": "Laufzeit von", "widget": "DateField", "format": "dd.MM.yyyy" },
                            {
                                "field": "vertrag_laufzeit_bis", "label": "Laufzeit bis", "widget": "DateField", "format": "dd.MM.yyyy",
                                "comment": "Auto-calculated when vertrag_laufzeit_von changes. User may override."
                            }
                        ]
                    },
                    {
                        "title": "Bemerkung",
                        "fields": [
                            { "field": "bemerkung_titel", "label": "Titel", "widget": "TextField", "maxLength": 200, "linkedTable": "bemerkung", "linkedField": "titel" },
                            { "field": "bemerkung_text", "label": "Text", "widget": "TextAreaField", "maxLength": 10000, "minLines": 4, "linkedTable": "bemerkung", "linkedField": "text" }
                        ]
                    }
                ]
            },

            {
                "id": "screen_leistung_list",
                "title": "Leistungen",
                "route": "/leistungen",
                "type": "dataGridScreen",
                "dataSource": "leistung",
                "baseClass": "AppDataGrid",

                "dataGrid": {
                    "sortableColumns": [
                        { "field": "name", "label": "Name", "enabledByDefault": true, "defaultAscending": true },
                        { "field": "laufzeit", "label": "Laufzeit", "enabledByDefault": false, "defaultAscending": true }
                    ],
                    "columns": [
                        { "field": "name", "label": "Name", "type": "text", "width": 200, "enableSorting": true, "enableFilter": true },
                        { "field": "laufzeit", "label": "Laufzeit", "type": "text", "width": 130, "enableSorting": true, "enableFilter": true },
                        {
                            "field": "bruttopreis", "label": "Brutto (€)", "type": "number", "width": 110, "enableSorting": true, "enableFilter": false,
                            "format": "#,##0.00", "comment": "Joined from preis.bruttopreis"
                        },
                        {
                            "field": "nettopreis", "label": "Netto (€)", "type": "number", "width": 110, "enableSorting": false, "enableFilter": false,
                            "computed": true, "comment": "Computed from bruttopreis and stammdaten MwSt."
                        }
                    ],
                    "toSearchStringFields": ["name", "laufzeit", "bruttopreis"]
                },

                "actions": [
                    { "id": "btn_neu", "label": "Neu", "icon": "Icons.add", "opensScreen": "screen_leistung_edit" },
                    { "id": "btn_bearbeiten", "label": "Bearbeiten", "icon": "Icons.edit", "opensScreen": "screen_leistung_edit", "requiresSelection": true },
                    { "id": "btn_loeschen", "label": "Löschen", "icon": "Icons.delete", "requiresSelection": true, "confirm": true }
                ]
            },

            {
                "id": "screen_leistung_edit",
                "title": "Leistung bearbeiten",
                "route": "/leistungen/edit",
                "type": "formScreen",
                "dataSource": "leistung",

                "formSections": [
                    {
                        "title": "Leistung",
                        "fields": [
                            { "field": "name", "label": "Name", "widget": "TextField", "maxLength": 200, "required": true },
                            {
                                "field": "laufzeit", "label": "Laufzeit", "widget": "DropdownField",
                                "options": [
                                    { "value": "einmalig", "label": "Einmalig" },
                                    { "value": "monatlich", "label": "Monatlich" },
                                    { "value": "quartalsweise", "label": "Quartalsweise" },
                                    { "value": "jaehrlich", "label": "Jährlich" }
                                ],
                                "required": true
                            }
                        ]
                    },
                    {
                        "title": "Preis",
                        "fields": [
                            { "field": "bruttopreis", "label": "Bruttopreis (€)", "widget": "CurrencyField", "required": true },
                            {
                                "field": "nettopreis", "label": "Nettopreis (€)", "widget": "ReadOnlyField", "computed": true,
                                "comment": "Displayed for info. Computed from bruttopreis and current MwSt from stammdaten."
                            }
                        ]
                    },
                    {
                        "title": "Bemerkung",
                        "fields": [
                            { "field": "bemerkung_titel", "label": "Titel", "widget": "TextField", "maxLength": 200, "linkedTable": "bemerkung", "linkedField": "titel" },
                            { "field": "bemerkung_text", "label": "Text", "widget": "TextAreaField", "maxLength": 10000, "minLines": 4, "linkedTable": "bemerkung", "linkedField": "text" }
                        ]
                    }
                ]
            },

            {
                "id": "screen_stammdaten",
                "title": "Stammdaten / Einstellungen",
                "route": "/stammdaten",
                "type": "configScreen",
                "dataSource": "stammdaten",
                "comment": "Grouped by 'kategorie'. Only rows with aenderbar=1 are editable.",

                "groupBy": "kategorie",
                "categoryLabels": {
                    "finanzen": "Finanzen & Steuer",
                    "firma": "Firmendaten",
                    "programm": "Programm & Pfade",
                    "druck": "Druck & Export",
                    "sonstiges": "Sonstiges"
                },
                "fieldRendering": {
                    "string": "TextField",
                    "number": "NumberField",
                    "boolean": "SwitchField",
                    "date": "DateField"
                }
            }

        ],

            "dialogs": [

                {
                    "id": "dialog_mitglied_vertrag_start",
                    "title": "Vertrag starten",
                    "type": "modalDialog",
                    "comment": "Opened by the 'Start' button in the member form or member list. Sets kontierung date and selects Leistung. Auto-calculates Laufzeit bis.",

                    "fields": [
                        {
                            "field": "vertrag_kontierung",
                            "label": "Kontierungsdatum",
                            "widget": "DateField",
                            "format": "dd.MM.yyyy",
                            "default": "today",
                            "required": true
                        },
                        {
                            "field": "leistung_id",
                            "label": "Leistung",
                            "widget": "DropdownField",
                            "dataSource": "leistung",
                            "displayField": "name",
                            "valueField": "id",
                            "required": true,
                            "comment": "Dropdown populated from leistung table. Selecting a leistung triggers auto-calculation of vertrag_laufzeit_bis."
                        },
                        {
                            "field": "vertrag_laufzeit_von",
                            "label": "Laufzeit von",
                            "widget": "DateField",
                            "format": "dd.MM.yyyy",
                            "default": "today",
                            "required": true,
                            "onChange": "autoCalculateLaufzeitBis",
                            "comment": "Changing this value triggers auto-calculation of vertrag_laufzeit_bis."
                        },
                        {
                            "field": "vertrag_laufzeit_bis",
                            "label": "Laufzeit bis",
                            "widget": "DateField",
                            "format": "dd.MM.yyyy",
                            "autoCalculated": true,
                            "userCanOverride": true,
                            "comment": "Auto-calculated from vertrag_laufzeit_von + leistung.laufzeit. User may manually override after auto-fill."
                        }
                    ],

                    "autoCalculationRules": [
                        {
                            "trigger": "vertrag_laufzeit_von_changed OR leistung_id_changed",
                            "target": "vertrag_laufzeit_bis",
                            "logic": {
                                "einmalig": "vertrag_laufzeit_von + 0 days (same day)",
                                "monatlich": "vertrag_laufzeit_von + 1 month - 1 day",
                                "quartalsweise": "vertrag_laufzeit_von + 3 months - 1 day",
                                "jaehrlich": "vertrag_laufzeit_von + 1 year - 1 day"
                            }
                        }
                    ],

                    "buttons": [
                        { "label": "Abbrechen", "action": "close", "variant": "outlined" },
                        { "label": "Übernehmen", "action": "submit", "variant": "filled", "writesFields": ["vertrag_kontierung", "leistung_id", "vertrag_laufzeit_von", "vertrag_laufzeit_bis"] }
                    ]
                }

            ]
    }
}