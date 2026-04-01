import 'package:flutter_test/flutter_test.dart';
import 'package:clupdata/widgets/data_grid_v2/export/export_data_table.dart';
import 'package:clupdata/widgets/data_grid_v2/export/pdf/pdf_export_context.dart';
import 'package:clupdata/widgets/data_grid_v2/export/pdf/simple_table_template.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Test PDF Export', (WidgetTester tester) async {
    final template = SimpleTableTemplate();
    final dataTable = ExportDataTable(
      title: 'Test',
      headers: ['A', 'B'],
      rows: [['1', '2']],
      exportedAt: DateTime.now(),
    );
    final context = PdfExportContext(title: 'Test', exportTimestamp: DateTime.now());

    try {
      final doc = await template.generate(dataTable, context);
      await doc.save();
      print('Pdf generated successfully');
    } catch (e, stack) {
      print('Error during PDF generation: \$e');
      print(stack);
    }
  });
}
