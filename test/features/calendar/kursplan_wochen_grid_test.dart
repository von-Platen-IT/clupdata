import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clupdata/features/calendar/domain/models/kursplan_termin_row_data.dart';
import 'package:clupdata/features/calendar/presentation/widgets/kursplan_wochen_grid.dart';

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

/// Bettet das Raster in eine scrollbare MaterialApp ein.
Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('zwei gleichzeitige Kurse rendern ohne Overflow', (tester) async {
    await tester.pumpWidget(
      _wrap(
        KursplanWochenGrid(
          wochenAnfang: DateTime(2026, 10, 5),
          termine: [
            termin(
              id: 1,
              kursId: 1,
              kursName: 'Boxen Erwachsene',
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
    expect(find.text('Boxen Erwachsene'), findsOneWidget);
    expect(find.text('Kickboxen'), findsOneWidget);
  });

  testWidgets('30-Minuten-Block zeigt nur den Kursnamen (kein Overflow)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        KursplanWochenGrid(
          wochenAnfang: DateTime(2026, 10, 5),
          termine: [
            termin(startzeit: '16:00', endezeit: '16:30'),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Boxen'), findsOneWidget);
    // Zeit wird bei zu geringer Höhe nicht gerendert.
    expect(find.text('16:00–16:30'), findsNothing);
  });

  testWidgets('Parallel-Badge erscheint bei gleichzeitigen Kursen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        KursplanWochenGrid(
          wochenAnfang: DateTime(2026, 10, 5),
          termine: [
            termin(
              id: 1,
              kursId: 1,
              startzeit: '16:00',
              endezeit: '18:00',
            ),
            termin(
              id: 2,
              kursId: 2,
              startzeit: '16:00',
              endezeit: '17:30',
            ),
          ],
        ),
      ),
    );

    expect(find.byIcon(Icons.people_alt_outlined), findsNWidgets(2));
  });

  testWidgets('sequenzielle Kurse zeigen kein Parallel-Badge', (tester) async {
    await tester.pumpWidget(
      _wrap(
        KursplanWochenGrid(
          wochenAnfang: DateTime(2026, 10, 5),
          termine: [
            termin(id: 1, startzeit: '16:00', endezeit: '17:00'),
            termin(id: 2, startzeit: '17:00', endezeit: '18:00'),
          ],
        ),
      ),
    );

    expect(find.byIcon(Icons.people_alt_outlined), findsNothing);
  });
}
