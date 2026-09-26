// Seed de fixtures para el smoke de la pantalla de Eventos Financieros (Flutter).
//
//   node tool/seed_financial_fixtures.mjs
//
// Crea (idempotente: primero borra los fixtures anteriores `smoke-fin-%`):
//   - 3 ventas viejas (fuera del día actual, no afectan stats ni "ventas del día")
//   - 2 propinas de Damo (una pendiente y una pagada) con su detalle
//   - 2 comisiones de Damo (una pendiente y una pagada) con su detalle
//
// El smoke los busca por su código:
//   integration_test/financial_events_smoke_test.dart
//     · /garzon/financieros    → SMOKE-TIPS-1 (Pendiente), SMOKE-TIPS-2 (Pagado)
//     · /anfitriona/financieros → SMOKE-COMM   (Pendiente), SMOKE-TIPS-1 (Pagado)
//
// Conexión: lee el .env del dashboard (../lasmunecasderamon-dashboard/.env) y
// usa el paquete `pg` de sus node_modules.
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const dashboardDir = path.resolve(here, '..', '..', 'lasmunecasderamon-dashboard');
const req = createRequire(path.join(dashboardDir, 'package.json'));
const { Client } = req('pg');
req('dotenv').config({ path: path.join(dashboardDir, '.env') });

const FECHA = {
  v1: '2026-01-05 21:00:00',
  v2: '2026-01-05 21:10:00',
  v3: '2026-01-05 21:20:00',
  p1: '2026-01-05 21:30:00',
  p2: '2026-01-05 21:40:00',
  c: '2026-01-05 21:50:00'
};

const client = new Client({
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME
});

async function main() {
  await client.connect();

  const users = await client.query(
    `SELECT id_usuario FROM usuarios
      WHERE lower(nick) = 'damo' OR lower(email) LIKE 'damo%'
      LIMIT 1`
  );
  if (users.rows.length === 0) throw new Error('No encontré al usuario Damo en la BD');
  const damo = users.rows[0].id_usuario;

  // Limpieza (orden por dependencias lógicas; solo toca IDs smoke-fin-%)
  await client.query(
    `DELETE FROM detalle_propinas WHERE propina_id IN (SELECT id_propina FROM propinas WHERE id_propina LIKE 'smoke-fin-%')`
  );
  await client.query(`DELETE FROM propinas WHERE id_propina LIKE 'smoke-fin-%'`);
  await client.query(
    `DELETE FROM detalle_comisiones WHERE comision_id IN (SELECT id_comision FROM comisiones WHERE id_comision LIKE 'smoke-fin-%')`
  );
  await client.query(`DELETE FROM comisiones WHERE id_comision LIKE 'smoke-fin-%'`);
  await client.query(`DELETE FROM ventas WHERE id_venta LIKE 'smoke-fin-%'`);

  // Ventas (fecha antigua: fuera de "ventas del día" y de stats por semana)
  const ventas = [
    ['smoke-fin-v1', 'SMOKE-TIPS-1', FECHA.v1],
    ['smoke-fin-v2', 'SMOKE-TIPS-2', FECHA.v2],
    ['smoke-fin-v3', 'SMOKE-COMM', FECHA.v3]
  ];
  for (const [id, codigo, fecha] of ventas) {
    await client.query(
      `INSERT INTO ventas (id_venta, codigo, metodo_pago, propina, sub_total, total, fecha_crea, estado, created_by)
       VALUES ($1, $2, 'efectivo', 0, 50000, 50000, $3, 1, $4)`,
      [id, codigo, fecha, damo]
    );
  }

  // Propinas: p1 pendiente (estado 1), p2 pagada (estado 0) — la convención
  // real de la BD es la de PayrollRepository.pay(): `UPDATE propinas SET
  // estado = 0 WHERE estado = 1` cuando se paga. El detalle usa COALESCE
  // (p.estado, 1), es decir el estado del padre.
  await client.query(
    `INSERT INTO propinas (id_propina, venta_id, propina, fecha_crea, estado)
     VALUES ('smoke-fin-p1', 'smoke-fin-v1', 700, $1, 1)`,
    [FECHA.p1]
  );
  await client.query(
    `INSERT INTO propinas (id_propina, venta_id, propina, fecha_crea, estado)
     VALUES ('smoke-fin-p2', 'smoke-fin-v2', 400, $1, 0)`,
    [FECHA.p2]
  );
  await client.query(
    `INSERT INTO detalle_propinas (id_detalle_propina, propina_id, usuario_id, monto, fecha_crea, estado)
     VALUES ('smoke-fin-dp1', 'smoke-fin-p1', $1, 70, $2, 1)`,
    [damo, FECHA.p1]
  );
  await client.query(
    `INSERT INTO detalle_propinas (id_detalle_propina, propina_id, usuario_id, monto, fecha_crea, estado)
     VALUES ('smoke-fin-dp2', 'smoke-fin-p2', $1, 40, $2, 0)`,
    [damo, FECHA.p2]
  );

  // Comisiones: c1 pendiente ('Por pagar' → 1), c2 pagada ('Pagado' → 2)
  await client.query(
    `INSERT INTO comisiones (id_comision, venta_id, monto, estado, fecha_crea)
     VALUES ('smoke-fin-c1', 'smoke-fin-v3', 5000, 1, $1)`,
    [FECHA.c]
  );
  await client.query(
    `INSERT INTO comisiones (id_comision, venta_id, monto, estado, fecha_crea)
     VALUES ('smoke-fin-c2', 'smoke-fin-v1', 9000, 2, $1)`,
    [FECHA.c]
  );
  await client.query(
    `INSERT INTO detalle_comisiones (id_detalle_comision, comision_id, usuario_id, comision, fecha_crea, estado)
     VALUES ('smoke-fin-dc1', 'smoke-fin-c1', $1, 5000, $2, 1)`,
    [damo, FECHA.c]
  );
  await client.query(
    `INSERT INTO detalle_comisiones (id_detalle_comision, comision_id, usuario_id, comision, fecha_crea, estado)
     VALUES ('smoke-fin-dc2', 'smoke-fin-c2', $1, 9000, $2, 2)`,
    [damo, FECHA.c]
  );

  // Verificación de las dos consultas que usan las pantallas
  const tips = await client.query(
    `SELECT p.id_propina AS propina_id, v.codigo AS codigo_venta, COALESCE(p.estado,1) AS estado
       FROM propinas p LEFT JOIN ventas v ON v.id_venta = p.venta_id
       INNER JOIN detalle_propinas dp ON dp.propina_id = p.id_propina
      WHERE dp.usuario_id = $1 ORDER BY p.fecha_crea DESC`,
    [damo]
  );
  const comms = await client.query(
    `SELECT c.id_comision AS id, v.codigo AS codigo_venta, c.estado
       FROM comisiones c
       INNER JOIN detalle_comisiones dc ON c.id_comision = dc.comision_id
       LEFT JOIN ventas v ON v.id_venta = c.venta_id
      WHERE dc.usuario_id = $1 AND c.venta_id IS NOT NULL AND c.venta_id <> '' AND c.venta_id <> '0'
      ORDER BY c.fecha_crea DESC`,
    [damo]
  );

  console.log('✓ Fixtures financieros sembrados para Damo (%s):', damo);
  console.log('  tips:', tips.rows.map(r => `${r.codigo_venta}(${r.estado})`).join(', '));
  console.log('  comisiones:', comms.rows.map(r => `${r.codigo_venta}(${r.estado})`).join(', '));

  await client.end();
}

main().catch(err => {
  console.error('✗', err.message);
  process.exit(1);
});
