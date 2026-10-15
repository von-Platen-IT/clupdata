import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clupdata/features/calendar/domain/models/kursplan_termin_row_data.dart';
import 'package:clupdata/features/calendar/presentation/widgets/kursplan_tagesansicht.dart';

/// Erzeugt einen Test-Termin mit sinnvollen Defaults.
KursplanTerminRowData termin({
  int id = 1,
  int kursId = 1,
  String kursName = 'Boxen',
  int wochentag = 1,
  required String startzeit,
  String? endezeit,
}) {
  return KursplanTerminRowData(
    id: id,
    kursplanId: 1,
    kursId: kursId,
    kursName: kursName,
    kampfsportart: 'Boxen',
    farbe: '#FFCDD2',
    wochentag: wochentag,
    startzeit: startzeit,
    endezeit: endezeit,
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('parallele Termine werden nebeneinander positioniert', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        KursplanTagesansicht(
          tag: DateTime(2026, 10, 5), // Montag
          termine: [
            termin(
              id: 1,
              kursId: 1,
              kursName: 'Boxen',
              startzeit: '16:00',
              endezeit: '18:00',
            ),
            termin(
              id: 2,
              kursId: 2,
              kursName: 'Kickboxen',
              startzeit: '16:00',
              endezeit: '17:30',
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final boxen = tester.getTopLeft(find.text('Boxen'));
    final kickboxen = tester.getTopLeft(find.text('Kickboxen'));
    // Gleiche Startzeit → unterschiedliche horizontale Position (Lanes).
    expect(boxen.dx, isNot(equals(kickboxen.dx)));
  });

  testWidgets('leere Tagesansicht zeigt Hinweis ohne Overflow', (tester) async {
    await tester.pumpWidget(
      _wrap(
        KursplanTagesansicht(tag: DateTime(2026, 10, 5), termine: const []),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Keine Kurse an diesem Tag.'), findsOneWidget);
  });

  testWidgets('rendert in begrenzter Höhe (Screen-Setup) ohne Overflow', (
    tester,
  ) async {
    // Bildet das Setup im KursplanScreen nach: Expanded in einer Column.
    // Regression: Ein äußerer SingleChildScrollView führte zu
    // "non-zero flex but incoming height constraints are unbounded".
    await tester.pumpWidget(
      _wrap(
        Column(
          children: [
            const Text('Kopfzeile'),
            Expanded(
              child: KursplanTagesansicht(
                tag: DateTime(2026, 10, 5),
                termine: const [],
              ),
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('initialer Scroll-Offset zeigt 15:00 Uhr oben', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          height: 400,
          child: KursplanTagesansicht(
            tag: DateTime(2026, 10, 5),
            termine: const [],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    // (15:00 − 06:00) × 60 px = 540 px
    expect(scrollView.controller?.offset, 540.0);
  });
}
