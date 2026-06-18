import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Mirror of Expo's `services/reportService.ts`.
///
/// Generates PDF reports (sales, attendance, services) and CSV exports,
/// then shares them via the system share sheet.
class ReportService {
  // ── Public API ────────────────────────────────────────────────────────

  /// Generates a sales report PDF and returns its file path, or `null` on failure.
  Future<String?> exportSalesReport(ReportConfig config) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => _buildSalesPage(context, config),
        ),
      );
      return await _savePdf(pdf, 'reporte_ventas');
    } catch (e) {
      return null;
    }
  }

  /// Generates an attendance report PDF.
  Future<String?> exportAttendanceReport(ReportConfig config) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => _buildAttendancePage(context, config),
        ),
      );
      return await _savePdf(pdf, 'reporte_asistencia');
    } catch (e) {
      return null;
    }
  }

  /// Generates a services report PDF.
  Future<String?> exportServicesReport(ReportConfig config) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => _buildServicesPage(context, config),
        ),
      );
      return await _savePdf(pdf, 'reporte_servicios');
    } catch (e) {
      return null;
    }
  }

  /// Generates a CSV file from [data] and returns its path, or `null`.
  Future<String?> exportToCSV(
    List<Map<String, dynamic>> data,
    String filename,
  ) async {
    if (data.isEmpty) return null;

    try {
      final headers = data.first.keys.toList();
      final csvRows = StringBuffer();

      // Header row
      csvRows.writeln(headers.map((h) => '"${h.replaceAll('"', '""')}"').join(','));

      // Data rows
      for (final row in data) {
        final values = headers.map((h) {
          final v = row[h]?.toString() ?? '';
          return '"${v.replaceAll('"', '""')}"';
        });
        csvRows.writeln(values.join(','));
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename.csv');
      await file.writeAsString(csvRows.toString());

      return file.path;
    } catch (e) {
      return null;
    }
  }

  /// Opens the system share sheet for the file at [uri].
  Future<bool> shareReport(String uri, String title) async {
    try {
      await Share.shareXFiles([XFile(uri)], subject: title);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── PDF builders ──────────────────────────────────────────────────────

  pw.Widget _buildHeader(pw.Context context, ReportConfig config) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          config.title,
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.indigo,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Las Muñecas de Ramón',
          style: const pw.TextStyle(
            fontSize: 12,
            color: PdfColors.grey600,
          ),
        ),
        if (config.dateRange != null) ...[
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Text(
              'Período: ${config.dateRange!.start} - ${config.dateRange!.end}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ),
        ],
        pw.SizedBox(height: 16),
        pw.Divider(color: PdfColors.indigo, thickness: 1.5),
        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.Widget _buildTable(pw.Context context, List<String> headers, List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        for (var i = 0; i < headers.length; i++)
          i: const pw.FlexColumnWidth(1),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.indigo),
          children: headers
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ))
              .toList(),
        ),
        // Data rows
        ...rows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return pw.TableRow(
            decoration: i.isEven
                ? const pw.BoxDecoration(color: PdfColors.grey50)
                : null,
            children: row
                .map((cell) => pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(cell.toString(),
                          style: const pw.TextStyle(fontSize: 8)),
                    ))
                .toList(),
          );
        }),
      ],
    );
  }

  List<pw.Widget> _buildSalesPage(pw.Context context, ReportConfig config) {
    final rows = config.rows.map((r) {
      return config.headers.map((h) => r[h]?.toString() ?? '').toList();
    }).toList();

    final total = config.rows.fold<double>(
      0,
      (sum, r) => sum + ((r['total'] ?? r['monto'] ?? 0) as num).toDouble(),
    );

    return [
      _buildHeader(context, config),
      _buildTable(context, config.headers, rows),
      pw.SizedBox(height: 16),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.indigo50,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'Total Ventas: ',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            pw.Text(
              'S/ ${total.toStringAsFixed(2)}',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo,
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 8),
      if (config.summary != null)
        pw.Text(
          'Transacciones: ${config.summary!['totalTransactions'] ?? config.rows.length}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      pw.SizedBox(height: 32),
      pw.Text(
        'Generado el ${_formatDate(DateTime.now())}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        textAlign: pw.TextAlign.center,
      ),
    ];
  }

  List<pw.Widget> _buildAttendancePage(pw.Context context, ReportConfig config) {
    final rows = config.rows.map((r) {
      return config.headers.map((h) => r[h]?.toString() ?? '').toList();
    }).toList();

    return [
      _buildHeader(context, config),
      _buildTable(context, config.headers, rows),
      pw.SizedBox(height: 16),
      pw.Text(
        'Total: ${rows.length} registros — Generado: ${_formatDate(DateTime.now())}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        textAlign: pw.TextAlign.center,
      ),
    ];
  }

  List<pw.Widget> _buildServicesPage(pw.Context context, ReportConfig config) {
    final rows = config.rows.map((r) {
      return config.headers.map((h) => r[h]?.toString() ?? '').toList();
    }).toList();

    return [
      _buildHeader(context, config),
      _buildTable(context, config.headers, rows),
    ];
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  Future<String> _savePdf(pw.Document pdf, String baseName) async {
    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${baseName}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  String _formatDate(DateTime dt) {
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'setiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${dt.day} de ${months[dt.month - 1]} de ${dt.year}';
  }
}

/// Configuration for a report generation.
class ReportConfig {
  final String title;
  final List<String> headers;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic>? summary;
  final ({String start, String end})? dateRange;

  ReportConfig({
    required this.title,
    required this.headers,
    required this.rows,
    this.summary,
    this.dateRange,
  });
}

/// Singleton instance (mirrors Expo's `export const reportService = new ReportService()`).
final reportService = ReportService();
