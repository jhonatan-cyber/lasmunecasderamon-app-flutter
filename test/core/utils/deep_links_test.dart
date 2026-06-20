import 'package:flutter_test/flutter_test.dart';
import 'package:lasmunecasderamon_flutter/core/utils/deep_links.dart';

void main() {
  group('DeepLinks', () {
    group('fromNotificationType', () {
      test('returns garzon servicios for servicio type (no role)', () {
        expect(DeepLinks.fromNotificationType('servicio', '123'), '/garzon/servicios');
      });

      test('returns cajero servicios for servicio with cajero role', () {
        expect(
          DeepLinks.fromNotificationType('servicio', '123', role: 'cajero'),
          '/cajero/servicios',
        );
      });

      test('returns cajero ventas for venta type', () {
        expect(DeepLinks.fromNotificationType('venta', '123'), '/cajero/ventas');
      });

      test('returns cajero solicitudes for solicitud type', () {
        expect(DeepLinks.fromNotificationType('solicitud', '123'), '/cajero/solicitudes');
      });

      test('returns root for unknown type', () {
        expect(DeepLinks.fromNotificationType('unknown', null), '/');
      });
    });

    group('fromExternalUrl', () {
      test('parses custom scheme URLs (defaults to garzon)', () {
        
        final uri = Uri.parse('lasmunecasderamon:///servicio/abc-123');
        expect(DeepLinks.fromExternalUrl(uri), '/garzon/servicios');
      });

      test('parses web URLs', () {
        final uri = Uri.parse('https://lasmunecasderamon.app/reset-password');
        expect(DeepLinks.fromExternalUrl(uri), '/auth/reset-password');
      });

      test('returns root for unrecognized URLs', () {
        final uri = Uri.parse('https://other.app/page');
        expect(DeepLinks.fromExternalUrl(uri), '/');
      });
    });
  });
}
