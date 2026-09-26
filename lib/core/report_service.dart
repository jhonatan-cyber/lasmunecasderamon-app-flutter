import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';





class ReportService {
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  
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

  
  
  /// Reporte de liquidación de un usuario (paridad con el PDF de
  /// `PremiumLiquidationCard` de la app Expo): encabezado + recuadro
  /// USUARIO / FECHA DE REPORTE + detalle de eventos + fila de total.
  /// Devuelve la ruta del PDF generado o `null` si falló.
  Future<String?> exportLiquidationReport({
    required String userLabel,
    required List<LiquidationEvent> events,
    required double total,
    String title = 'Reporte de Liquidación',
    String totalLabel = 'Total a cobrar',
  }) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => _buildLiquidationPage(
            context,
            userLabel: userLabel,
            events: events,
            total: total,
            title: title,
            totalLabel: totalLabel,
          ),
        ),
      );
      return await _savePdf(pdf, 'reporte_liquidacion');
    } catch (e) {
      return null;
    }
  }

  Future<String?> exportToCSV(
    List<Map<String, dynamic>> data,
    String filename,
  ) async {
    if (data.isEmpty) return null;

    try {
      final headers = data.first.keys.toList();
      final csvRows = StringBuffer();

      
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

  
  Future<bool> shareReport(String uri, String title) async {
    try {
      await Share.shareXFiles([XFile(uri)], subject: title);
      return true;
    } catch (e) {
      return false;
    }
  }

  

  pw.Widget _buildHeader(
    pw.Context context, {
    required String title,
    String? period,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          title,
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
        if (period != null) ...[
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Text(
              'Período: $period',
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
      _buildHeader(context, title: config.title),
      _buildTable(context, config.headers, rows),
      pw.SizedBox(height: 16),
      _buildTotalRow('Total Ventas', 'S/ ${total.toStringAsFixed(2)}'),
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
      _buildHeader(context, title: config.title),
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
      _buildHeader(context, title: config.title),
      _buildTable(context, config.headers, rows),
    ];
  }

  List<pw.Widget> _buildLiquidationPage(
    pw.Context context, {
    required String userLabel,
    required List<LiquidationEvent> events,
    required double total,
    required String title,
    required String totalLabel,
  }) {
    const headers = ['FECHA Y HORA', 'TIPO', 'CODIGO', 'MONTO'];
    // El monto va con signo (los anticipos restan) para que la columna sume
    // exactamente el total de la fila inferior.
    final rows = events
        .map(
          (event) => [
            _dateTimeFormat.format(event.date),
            event.label,
            event.codigo,
            _formatMoney(event.signedAmount),
          ],
        )
        .toList();

    return [
      _buildHeader(context, title: title),
      _buildInfoGrid(userLabel: userLabel),
      _buildTable(context, headers, rows),
      pw.SizedBox(height: 16),
      _buildTotalRow(
        totalLabel,
        _formatMoney(total),
        valueColor: PdfColor.fromHex('#10B981'),
      ),
      pw.SizedBox(height: 32),
      pw.Text(
        'Este es un documento informativo generado automáticamente.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        textAlign: pw.TextAlign.center,
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        '© ${DateTime.now().year} Las Muñecas de Ramón - Sistema de Gestión',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        textAlign: pw.TextAlign.center,
      ),
    ];
  }

  /// Recuadro de datos del reporte (USUARIO + FECHA DE REPORTE), espejo del
  /// `.info-grid` del export de Expo.
  pw.Widget _buildInfoGrid({required String userLabel}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 24),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: _buildInfoBox('USUARIO', userLabel)),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: _buildInfoBox(
              'FECHA DE REPORTE',
              _dateTimeFormat.format(DateTime.now()),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInfoBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Fila de total con la etiqueta a la izquierda y el monto destacado a la
  /// derecha (espejo de `.total-row` de PremiumLiquidationCard).
  pw.Widget _buildTotalRow(
    String label,
    String value, {
    PdfColor? valueColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: valueColor ?? PdfColors.indigo,
            ),
          ),
        ],
      ),
    );
  }

  /// Monto en el formato de la app (`$52.000`), con signo para los anticipos.
  String _formatMoney(num value) {
    final sign = value < 0 ? '-' : '';
    final digits = value.abs().round().toString();
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write('.');
      grouped.write(digits[i]);
    }
    return '$sign\$$grouped';
  }

  

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

/// Evento normalizado para los reportes de liquidación: mismo shape que
/// devuelve `GET /events/user` (el endpoint que alimenta la tarjeta de
/// liquidación en Expo y en Flutter).
class LiquidationEvent {
  final String id;
  final String type;
  final String? subType;
  final String codigo;
  final DateTime date;
  final double amount;
  final int? estado;

  LiquidationEvent({
    required this.type,
    required this.codigo,
    required this.date,
    required this.amount,
    this.id = '',
    this.subType,
    this.estado,
  });

  factory LiquidationEvent.fromJson(Map<String, dynamic> json) {
    return LiquidationEvent(
      type: (json['type'] ?? json['tipo'] ?? 'otro').toString(),
      // Necesario para `GET /events/detail/{id}?type=...`.
      id: (json['id'] ?? '').toString(),
      subType: (json['subType'] ?? json['sub_tipo'])?.toString(),
      codigo: (json['codigo'] ?? '').toString(),
      date:
          DateTime.tryParse((json['date'] ?? json['fecha'] ?? '').toString()) ??
          DateTime.now(),
      amount:
          double.tryParse(
            (json['amount'] ?? json['monto'] ?? '0').toString(),
          ) ??
          0,
      // `null` cuando el endpoint no manda el campo: misma semántica que el
      // `estado === undefined` de Expo.
      estado: int.tryParse(json['estado']?.toString() ?? ''),
    );
  }

  bool get isAnticipo => type == 'anticipo';

  /// Importe con signo: los anticipos restan de la liquidación.
  double get signedAmount => isAnticipo ? -amount : amount;

  /// Etiqueta legible del tipo de evento para la tabla del PDF (nomenclatura
  /// de Expo: «COMISION DE VENTA», «VENTA DE PRODUCTO», ...).
  String get label => liquidationEventLabel(type, subType);
}

/// Total de la liquidación — regla idéntica a `PremiumLiquidationCard` de Expo:
/// los eventos con estado distinto de 1 se ignoran y los anticipos restan.
double calculateLiquidationTotal(List<LiquidationEvent> events) {
  return events.fold<double>(0, (sum, event) {
    if (event.estado != null && event.estado != 1) return sum;
    return sum + event.signedAmount;
  });
}

/// Nombre del usuario tal como aparece en el reporte (mismo formato que Expo:
/// «Nombre - nick»).
String liquidationUserLabel(String nombre, {String nick = ''}) {
  final parts = <String>[
    if (nombre.trim().isNotEmpty) nombre.trim(),
    if (nick.trim().isNotEmpty) nick.trim(),
  ];
  return parts.join(' - ');
}

/// Estado del evento para las vistas de detalle (misma nomenclatura que la
/// app Expo y que el administrativo del cajero).
String liquidationStatusLabel(int? estado, String type) {
  if (estado == null) return '';
  if (type == 'anticipo') {
    if (estado == 0) return 'Pagado';
    if (estado == 1) return 'Confirmado';
    if (estado == 2) return 'Pendiente';
    if (estado == 3) return 'Rechazado';
  }
  if (estado == 0) return 'Pagado';
  if (estado == 1) return 'Por cobrar';
  if (estado == 2) return 'Confirmado';
  if (estado == 3) return 'Rechazado';
  if (estado == 4) return 'Completado';
  return estado.toString();
}

String liquidationEventLabel(String type, [String? subType]) {
  if (type == 'comision') {
    if (subType == 'venta') return 'Comisión de Venta';
    if (subType == 'servicio') return 'Comisión de Servicio';
    return 'Comisión';
  }
  if (type == 'propina') {
    if (subType == 'venta') return 'Propina de Venta';
    return 'Propina';
  }
  const labels = {
    'asistencia': 'Asistencia',
    'anticipo': 'Anticipo',
    'venta': 'Venta de Producto',
    'servicio': 'Servicio',
    'gratificacion': 'Gratificación',
    'hora_extra': 'Hora Extra',
  };
  return labels[type] ?? type.toUpperCase();
}


final reportService = ReportService();
