# Plan de Mejoras — Las Muñecas de Ramón (Flutter)

> Basado en análisis comparativo con la app Expo (React Native).
> **Estado actual**: `flutter analyze` 0 errores | `flutter test` 177/177 pasando
> **Feature parity**: 100% ✅

---

## 🔥 Fase 1 — Notifiers & Tests (Alta Prioridad)

> **Objetivo**: Extraer lógica de datos de screens >1000 líneas a Riverpod notifiers, y cubrirlos con tests.

### 1.1 AuthNotifier Tests
**Archivo**: `lib/features/auth/data/auth_notifier.dart`

**Problema**: El notifier de auth tiene lógica crítica (login, logout, session, biometric) sin tests.

**Deliverables**:
- `test/features/auth/data/auth_notifier_test.dart` — 22 tests

**Esfuerzo**: 1 día ✅

---

### 1.2 Garzon ServiciosForm Notifier
**Archivo**: `lib/features/garzon/presentation/servicios_screen.dart` (~1147 → ~480 líneas)

**Problema**: Lógica de fetch de habitaciones, anfitrionas, clientes, cálculo de resumen inline.

**Deliverables**:
- `lib/features/garzon/data/servicios_notifier.dart` ✅
- 20 tests del notifier ✅
- Screen refactorizada a UI pura con Riverpod ✅

**Esfuerzo**: 1 día ✅

---

### 1.3 Cajero ServiciosScreen Notifier
**Archivo**: `lib/features/cajero/presentation/servicios_screen.dart` (~460 → ~340 líneas)

**Problema**: La lógica de productos, carrito, búsqueda, categorías, submit está inline.

**Deliverables**:
- `lib/features/cajero/data/servicios_notifier.dart` ✅
- 11 tests del notifier ✅
- Screen reducida a UI pura con Riverpod ✅

**Esfuerzo**: 1 día ✅

---

### 1.4 Extraer VentasScreen Notifier
**Archivo**: `lib/features/cajero/presentation/ventas_screen.dart` (~1800 → ~1700 líneas)

**Problema**: La screen más grande del proyecto. Fetching de ventas, filtros, búsqueda, modales de detalle/anulación.

**Deliverables**:
- `lib/features/cajero/data/ventas_notifier.dart` ✅
- 18 tests del notifier ✅
- Screen refactorizada con Riverpod ✅

**Esfuerzo**: 1.5 días ✅

---

### 1.5 Extraer SolicitudesScreen Notifier
**Archivo**: `lib/features/cajero/presentation/solicitudes_screen.dart` (2283 líneas → modelo extraído + screen refactorizada)

**Problema**: Fetching de solicitudes, filtros por tipo, acciones de aprobar/rechazar inline.

**Deliverables**:
- `lib/features/cajero/data/solicitud_item.dart` — modelo extraído ✅
- `lib/features/cajero/data/solicitudes_notifier.dart` — notifier con fetch combinado (5 endpoints) + mutations ✅
- 11 tests del notifier ✅
- Screen refactorizada con Riverpod + modales inline preservados ✅

**Esfuerzo**: 1 día ✅

---

### 1.6 Extraer CuentasScreen Notifier
**Archivo**: `lib/features/cajero/presentation/cuentas_screen.dart` (~1563 → ~1487 líneas)

**Problema**: Fetching de cuentas, modales de detalle, pagos, filtros.

**Deliverables**:
- `lib/features/cajero/data/cuentas_notifier.dart` ✅
- 15 tests del notifier ✅
- Screen refactorizada con Riverpod ✅

**Esfuerzo**: 1 día ✅

---

### 1.7 Extraer ProductosScreen Notifier
**Archivo**: `lib/features/garzon/presentation/productos_screen.dart` (~1596 líneas)

**Problema**: Catálogo de productos, carrito, búsqueda, filtros por categoría — TODO inline.

**Deliverables**:
- `lib/features/garzon/data/productos_notifier.dart` (ya existe `cart_notifier.dart` parcial)
- Tests del notifier

**Esfuerzo**: 1 día

---

**Total Fase 1**: ~5.5 días (completado ~5.5 días)

---

## 🟡 Fase 2 — Imagen y Performance (Prioridad Media)

### 2.1 Image Caching
**Dependencia**: `cached_network_image`

**Problema**: Las imágenes de perfiles, productos, etc. se descargan cada vez desde el servidor.

**Deliverables**:
- Agregar `cached_network_image` a pubspec.yaml
- Reemplazar `Image.network()` → `CachedNetworkImage()` en toda la app
- Configurar cache manager (memoria + disco)

**Esfuerzo**: 1 día

---

### 2.2 Pull-to-Refresh Hook Reutilizable
**Problema**: Cada screen implementa su propio pull-to-refresh con estado de refresco inline.

**Deliverables**:
- `lib/core/hooks/refresh_provider.dart` — provider reutilizable
- Refactor screens para usar `ref.watch(refreshProvider)` + `ref.read(refreshProvider.notifier).refresh()`

**Esfuerzo**: 0.5 día

---

### 2.3 Debounced Search en Screens
**Problema**: Búsqueda en productos, clientes, ventas sin debounce.

**Deliverables**:
- Provider reutilizable `debouncedSearchProvider`
- Aplicar a screens con search field

**Esfuerzo**: 0.5 día

---

**Total Fase 2**: ~2 días

---

## 🟢 Fase 3 — Componentes UI Faltantes (Prioridad Baja)

### 3.1 PremiumCalendar Widget
**Problema**: `calendario_screen.dart` tiene un calendario custom inline. Expo tiene `PremiumCalendar.tsx`.

**Deliverables**:
- Extraer a `lib/core/widgets/premium_calendar.dart`
- Usar `table_calendar` o calendario custom con fl_chart

**Esfuerzo**: 1 día

---

### 3.2 DonutChart Widget
**Problema**: El analytics screen usa fl_chart directo. Expo tiene `DonutChart.tsx` reusable.

**Deliverables**:
- `lib/core/widgets/donut_chart.dart` — wrapper sobre fl_chart PieChart
- Tests del widget

**Esfuerzo**: 0.5 día

---

### 3.3 AnimatedScreen / ParallaxScrollView
**Deliverables**: Animaciones de transición de pantalla y parallax.

**Esfuerzo**: 1 día

---

**Total Fase 3**: ~2.5 días

---

## 🔵 Fase 4 — Arquitectura (Prioridad Baja)

### 4.1 Error Interceptor Centralizado
**Problema**: try/catch disperso en cada screen. Expo tiene `errors.ts` + `retry.ts`.

**Deliverables**:
- `lib/core/api_errors.dart` — tipos de error, retry policy
- Integrar con Dio interceptor existente

**Esfuerzo**: 0.5 día

---

### 4.2 Shared Dart Package
**Problema**: `@lasmunecasderamon/config`, `@lasmunecasderamon/types` etc. existen para Expo pero no para Flutter.

**Deliverables**:
- `packages/lasmunecasderamon_shared/` con tipos, constantes, config
- Publicar en pub.dev (o path dependency local)

**Esfuerzo**: 2 días

---

### 4.3 Offline Sync Mejoras
**Problema**: Offline queue usa SharedPreferences (no SQLite). Expo usa SQLite.

**Deliverables**:
- Migrar queue a SQLite (drift/sqflite)
- Mejor feedback de sync al usuario

**Esfuerzo**: 2 días

---

**Total Fase 4**: ~4.5 días

---

## 📊 Resumen

| Fase | Prioridad | Esfuerzo | Impacto |
|------|-----------|----------|---------|
| **F1** Notifiers + Tests | 🔥 Alta | ~5.5 días (~5.5 completados) | 🔥 Alto |
| **F2** Imagen + Performance | 🟡 Media | ~2 días | 🟡 Medio |
| **F3** Componentes UI | 🟢 Baja | ~2.5 días | 🟢 Bajo |
| **F4** Arquitectura | 🔵 Baja | ~4.5 días | 🟡 Medio |

**Total**: ~14.5 días de trabajo estimados (~5.5 completados).

---

## ✅ Estado de Seguimiento

<!-- Actualizar a medida que se completa -->

| Item | Estado | Inicio | Fin |
|------|--------|--------|-----|
| 1.1 AuthNotifier Tests | ✅ Completado | 17/06/2026 | 17/06/2026 |
| 1.2 Garzon ServiciosForm Notifier | ✅ Completado | 17/06/2026 | 17/06/2026 |
| 1.3 Cajero ServiciosScreen Notifier | ✅ Completado | 17/06/2026 | 17/06/2026 |
| 1.4 VentasScreen Notifier | ✅ Completado | 17/06/2026 | 17/06/2026 |
| 1.5 SolicitudesScreen Notifier | ✅ Completado | 17/06/2026 | 17/06/2026 |
| 1.6 CuentasScreen Notifier | ✅ Completado | 17/06/2026 | 17/06/2026 |
| 1.7 ProductosScreen Notifier | 🔲 Pendiente | — | — |
| 2.1 Image Caching | 🔲 Pendiente | — | — |
| 2.2 Pull-to-Refresh Hook | 🔲 Pendiente | — | — |
| 2.3 Debounced Search | 🔲 Pendiente | — | — |
| 3.1 PremiumCalendar | 🔲 Pendiente | — | — |
| 3.2 DonutChart | 🔲 Pendiente | — | — |
| 3.3 AnimatedScreen | 🔲 Pendiente | — | — |
| 4.1 Error Interceptor | 🔲 Pendiente | — | — |
| 4.2 Shared Dart Package | 🔲 Pendiente | — | — |
| 4.3 Offline Sync Mejoras | 🔲 Pendiente | — | — |

---

## 📁 Archivos Relacionados

- `pubspec.yaml` — dependencias
- `test/` — 177 tests (57 utils + 23 widgets + 22 auth notifier + 20 garzon servicios + 11 cajero servicios + 18 ventas + 15 cuentas + 11 solicitudes)
- `lib/features/*/data/` — notifiers existentes (auth, cart, garzon, servicios_form, financial, analytics)
- `lib/features/*/presentation/` — screens (algunas >1500 líneas)
- `lib/core/widgets/` — 15 widgets reutilizables
- `lib/core/utils/` — 5 utilidades
- `lib/core/offline/` — 5 archivos de offline sync
