# Plan de Paridad Funcional — Flutter App vs Expo App

> **Objetivo:** Que `lasmunecasderamon-app-flutter` tenga las mismas funcionalidades que `lasmunecasderamon-app` (Expo React Native).
>
> **Estado actual:** Flutter app tiene ~30 screens. Expo app tiene ~35 screens + features avanzadas.
>
> **Análisis base:** Comparativa completa de estructuras de carpetas, routing y servicios.

---

## Leyenda

| Símbolo | Significado |
|---------|-------------|
| 🔴 P0 | Crítico — bloquea funcionalidad principal |
| 🟡 P1 | Importante — mejora significativa |
| 🟢 P2 | Nice to have — mejora de UX/calidad |
| ⚪ P3 | Futuro — no urgente |

---

## 1. 🏗️ Screens Faltantes

### 1.1 🔴 Pedidos Screen (Garzon)

**¿Qué hace en Expo?** Pantalla para que los garzones tomen pedidos de productos para las mesas. Es una funcionalidad CORE del rol Garzón.

**Referencia en Expo:** `app/(app)/garzon/pedidos.tsx`, `components/garzon/`

**Lo que incluye:**
- [ ] Selección de productos por categoría
- [ ] Asignación a mesa / habitación
- [ ] Carrito de compras (`cartStore.ts`)
- [ ] Checkout/confirmación
- [ ] Historial de pedidos activos

**Complejidad:** Alta (nuevo feature completo)
**Dependencias:** Cart store, products API, mesas/habitaciones API

---

## 2. 🧩 Features de Infraestructura

### 2.1 🔴 Offline Sync

**¿Qué hace en Expo?** Permite operar la app sin conexión a internet usando `services/offlineSync.ts` y `hooks/useOfflineSync.ts`. Las operaciones se encolan y sincronizan cuando hay conexión.

**Referencia en Expo:** `store/`, `services/offlineSync.ts`, `hooks/useOfflineSync.ts`

**Lo que incluye:**
- [ ] Service worker / cola de operaciones offline
- [ ] Cache de datos locales con Hive/Drift
- [ ] Detección de conectividad
- [ ] Sincronización automática al reconectar
- [ ] UI de estado offline/online
- [ ] Indicador de operaciones pendientes de sincronizar

**Complejidad:** Muy alta (cambia la arquitectura de networking)
**Dependencias:** Base de datos local, connectivity_plus, cola de operaciones

---

### 2.2 🟡 Push Notifications

**¿Qué hace en Expo?** Notificaciones push nativas usando `expo-notifications`. Configuración en `services/pushNotifications.ts`.

**Referencia en Expo:** `services/pushNotifications.ts`, `hooks/useNotificationHandler.ts`

**Lo que incluye:**
- [x] Configuración de Firebase y FCM (firebase_core + firebase_messaging)
- [x] Solicitud de permisos al usuario
- [x] Registro de token FCM en backend (POST /notifications)
- [x] Manejo de notificaciones foreground (local notifications con flutter_local_notifications)
- [x] Manejo de notificaciones background (FirebaseMessaging.onBackgroundMessage)
- [x] Deep linking desde notificaciones (navegación por tipo)
- [x] Haptic feedback (heavyImpact para priority, mediumImpact para normal)
- [x] Canal de notificaciones Android configurado (default_channel)
- [x] Inicialización automática desde ProviderScope bootstrap

**Complejidad:** Media
**Dependencias:** `firebase_messaging`, `flutter_local_notifications`

---

### 2.3 🟢 Biometric Auth

**¿Qué hace en Expo?** Login con huella digital o reconocimiento facial usando `expo-local-authentication`.

**Referencia en Expo:** `store/authStore.ts` (métodos `authenticateWithBiometric`, `checkBiometricAvailability`, `saveCredentials`)

**Lo que incluye:**
- [x] Detección de biometría disponible
- [x] Guardado seguro de credenciales (flutter_secure_storage)
- [x] Login biométrico en pantalla de login
- [x] Opción de habilitar/deshabilitar en Perfil

**Complejidad:** Media
**Dependencias:** `local_auth`, `flutter_secure_storage`

---

### 2.4 🟡 QR Scanner

**¿Qué hace en Expo?** Escaneo de códigos QR para identificación de mesas, productos o usuarios.

**Referencia en Expo:** `components/shared/QRScannerModal.tsx`

**Lo que incluye:**
- [x] Pantalla de escaneo con cámara (`MobileScanner`)
- [x] Procesamiento de datos escaneados con callback `onScanned`
- [x] Modal reutilizable (`QRScannerModal.show<T>(context, onScanned: ...)`)
- [x] Marco de esquinas animado con `_CornerFramePainter` (pulse animation)
- [x] Botón de linterna (toggle torch)
- [x] Botón de zoom (normal / macro)
- [x] Badge de código actual (fetch `/codigo/actual`)
- [x] Overlay oscurecido con `ScanWindowOverlay`
- [x] Texto de ayuda contextual según modo de zoom

**Complejidad:** Baja
**Dependencias:** `mobile_scanner` (ya incluido en pubspec)

---

## 3. 🎨 Screens / Features Transversales

### 3.1 🟢 Profile Editing

**¿Qué hace en Expo?** Modal de edición de perfil donde el usuario puede cambiar su nickname, foto y datos personales.

**Referencia en Expo:** `components/shared/ProfileEditModal.tsx`

**Lo que incluye:**
- [x] Modal de edición de perfil (pantalla completa `/perfil`)
- [x] Cambio de nickname
- [x] Actualización de foto con image_picker
- [x] Persistencia vía API PUT /users

**Complejidad:** Baja
**Dependencias:** API `/users/me/update`

---

### 3.2 🟢 Cart / Checkout

**¿Qué hace en Expo?** `cartStore.ts` (Zustand) + `CheckoutModal.tsx` para manejar el flujo de compra.

**Referencia en Expo:** `store/cartStore.ts`, `components/cajero/CheckoutModal.tsx`

**Lo que incluye:**
- [x] Store de carrito con Riverpod (`cart_notifier.dart`)
- [x] Modal de checkout con selección de anfitriona, habitación, propina
- [x] Selección de cliente (opcional)
- [x] Confirmación de venta con validación de comisiones
- [x] Bottom cart bar con total y botón submit
- [x] Toast feedback en pull-to-refresh con detección de cambios
- [x] Cart badge en PremiumHeader con contador de items
- [x] Skeleton loader para categorías

**Complejidad:** Media
**Dependencias:** Store de carrito, API de ventas

---

### 3.3 🟢 Financial Events (Chequeos)

**¿Qué hace en Expo?** Pantalla de eventos financieros (chequeos) para llevar registro de transacciones.

**Referencia en Expo:** `components/screens/FinancialEventsScreen.tsx`, `hooks/useFinancialEvents.ts`

**Lo que incluye:**
- [ ] Lista de eventos financieros
- [ ] Filtros por tipo/fecha
- [ ] Detalle de evento
- [ ] Creación de nuevo evento

**Complejidad:** Media
**Dependencias:** API de eventos financieros

---

### 3.4 🟢 Analytics Dashboard

**¿Qué hace en Expo?** Dashboard analítico con gráficos y estadísticas.

**Referencia en Expo:** `components/shared/AnalyticsDashboard.tsx`

**Lo que incluye:**
- [ ] Gráficos de ventas
- [ ] Estadísticas de servicios
- [ ] Métricas de rendimiento

**Complejidad:** Media-Alta
**Dependencias:** `fl_chart` o similar, API de estadísticas

---

### 3.5 🟢 Horas Extras Admin

**¿Qué hace en Expo?** Gestión de horas extras desde el rol admin/cajero. En Expo existe como `horas-extras.tsx`. En Flutter ya existe como `horas_extras_admin_screen.dart`. Verificar paridad.

**Referencia en Expo:** `app/(app)/cajero/horas-extras.tsx`

**Lo que incluye:**
- [ ] Lista de solicitudes de horas extras
- [ ] Aprobación/rechazo
- [ ] Vista por empleado

**Complejidad:** Baja (ya existe en Flutter, verificar paridad de features)

---

## 4. 🛠️ Mejoras de Calidad / Refactors

### 4.1 🟡 React Query / Caché de API

**¿Qué hace en Expo?** `@tanstack/react-query` maneja caché automático, stale-while-revalidate, refetch en foco, etc.

**En Flutter:** Se usa `dio` directamente sin caché. Cada screen maneja su propio estado de carga.

**Opción implementada:** `dio_cache_interceptor` con `HiveCacheStore` (disco), `forceCache` + 5 min `maxStale`, integrado directamente en `ApiClient`.

**Lo que incluye:**
- [x] `dio_cache_interceptor` configurado con `CachePolicy.forceCache`
- [x] Cache persistente en disco via `HiveCacheStore`
- [x] 5 minutos de `maxStale` antes de revalidar
- [x] `cacheStoreProvider` (FutureProvider) inicialización lazy
- [x] Cache automático para todas las respuestas GET
- [x] Sobrescribible por request via `CacheOptions.copyWith()` en `options.extra`

**Complejidad:** Baja (implementado)
**Dependencias:** `dio_cache_interceptor`, `dio_cache_interceptor_hive_store`, `path_provider`

---

### 4.2 🟡 Haptics y Animaciones

**¿Qué hace en Expo?** `useHaptics.ts` proporciona feedback táctil en interacciones clave. `StaggeredFadeIn`, `AnimatedScreen` para animaciones.

**Lo que incluye:**
- [ ] Feedback háptico en botones principales
- [ ] Animaciones de entrada con `AnimatedOpacity`/`SlideTransition`
- [ ] Stagger animations en listas

**Complejidad:** Baja
**Dependencias:** Paquete haptics (viene con Flutter)

---

### 4.3 🟢 Crash Reporting

**¿Qué hace en Expo?** `@sentry/react-native` captura errores no controlados.

**En Flutter:** Usar `sentry_flutter` o `firebase_crashlytics`.

**Lo que incluye:**
- [x] `sentry_flutter` SDK configurado en `main.dart`
- [x] DSN vía `--dart-define=SENTRY_DSN=...` (fallback placeholder)
- [x] `Logger` utility — espejo del `logger.ts` de Expo
- [x] Captura de excepciones con `Logger.captureException()`
- [x] Breadcrumbs automáticos por nivel (info/warn/error/debug)
- [x] `tracesSampleRate: 1.0`

**Complejidad:** Baja
**Dependencias:** `sentry_flutter` o `firebase_crashlytics`

---

## 5. 📋 Tabla Resumen

| # | Feature | Prioridad | Complejidad | Dependencias | Estado |
|---|---------|-----------|-------------|--------------|--------|
| 1.1 | Pedidos (Garzon) | 🔴 P0 | 🔴 Alta | Cart store, API productos | ✅ Ya existía. Mejorado: toast, badge, skeleton |
| 2.1 | Offline Sync | 🔴 P0 | 🔴 Muy alta | connectivity_plus, SharedPrefs | ✅ Completado — `core/offline/` con queue, interceptor, sync manager, banner |
| 2.2 | Push Notifications | 🟡 P1 | 🟡 Media | firebase_core, firebase_messaging, flutter_local_notifications | ✅ Completado — `core/push_notification_service.dart` |
| 2.4 | QR Scanner | 🟡 P1 | 🟢 Baja | mobile_scanner ✅ ya incluido | ✅ Completado — `core/widgets/qr_scanner_modal.dart` |
| 3.1 | Profile Editing | 🟢 P2 | 🟢 Baja | API /users/me ✅ | ✅ Completado — `perfil_screen.dart` con edición de nick, foto, teléfono, dirección, estado civil, password |
| 3.2 | Cart / Checkout | 🟢 P2 | 🟡 Media | Cart store, API ventas ✅ | ✅ Verificado — `cart_notifier.dart`, checkout modal, bottom cart bar, skeleton |
| 3.3 | Financial Events | 🟢 P2 | 🟡 Media | API eventos | ✅ Completado — `financial_events_screen.dart` con lista, filtros, detalle modal |
| 3.4 | Analytics Dashboard | 🟢 P2 | 🟡 Media-Alta | fl_chart | ✅ Completado — stat cards, bar chart, pie chart, demo data |
| 2.3 | Biometric Auth | 🟢 P2 | 🟡 Media | local_auth, secure_storage ✅ | ✅ Completado — detección, login, toggle en Perfil |
| 4.1 | API Cache (Riverpod/Dio) | 🟡 P1 | 🟡 Media | dio_cache_interceptor ✅ | ✅ Completado — `core/api_client.dart` con `HiveCacheStore` |
| 4.2 | Haptics & Animaciones | 🟢 P2 | 🟢 Baja | HapticFeedback (built-in) | ✅ Completado — `core/haptic_service.dart`, `StaggeredFadeIn`, integrado en login, perfil, garzon home |
| 4.3 | Crash Reporting | 🟡 P1 | 🟢 Baja | sentry_flutter ✅ | ✅ Completado — `core/logger.dart` + `SentryFlutter.init` en `main.dart` |
| 5.1 | Report Service | 🟡 P1 | 🟡 Media | pdf, share_plus, path_provider | ✅ Completado — `core/report_service.dart` con PDF (ventas/asistencia/servicios) + CSV + share |
| 5.2 | Reset Password | 🟡 P1 | 🟢 Baja | N/A (endpoints existentes) | ✅ Completado — 2-step flow: email → code+password. Expo ya tenía vía RUN |

---

## 6. 🎯 Orden de Implementación Sugerido

### Fase 1 — Funcionalidad Core (P0)
```
1. Pedidos (Garzon)
   └─ Cart store (Riverpod)
   └─ Pantalla de pedidos
   └─ Checkout integrado
```

### Fase 2 — Infraestructura (P1)
```
2. QR Scanner (dependencia mobile_scanner ya existe)
3. Push Notifications
4. API Cache (dio_cache_interceptor o Riverpod)
5. Crash Reporting (Sentry)
```

### Fase 3 — Features UX (P2)
```
6. Biometric Auth
7. Profile Editing
8. Financial Events
9. Cart / Checkout (refinar)
10. Haptics & Animaciones
```

### Fase 4 — Avanzado (P2/P3)
```
11. Analytics Dashboard
12. Offline Sync (complejidad muy alta, requiere replanteo de arquitectura)
```

---

## 7. 📐 Arquitectura para Features Nuevos

Cada nuevo feature debe seguir la misma estructura que los existentes:

```
lib/features/{feature}/
├── data/
│   └── {feature}_repository.dart    # Llamadas API
├── domain/
│   └── {feature}_model.dart         # Modelos de datos
└── presentation/
    ├── {feature}_screen.dart        # Pantalla principal
    ├── {feature}_provider.dart      # Riverpod StateNotifier
    └── widgets/                     # Widgets específicos
```

Para features compartidos entre roles, usar `lib/features/shared/`.

---

## 8. 🧪 Criterios de Aceptación

Cada feature completada debe cumplir:
- [ ] `flutter analyze` pasa sin errores
- [ ] La app compila y corre en Android
- [ ] La funcionalidad existe en la Expo app y se comporta igual
- [ ] Manejo de estados: loading, error, empty, data
- [ ] Pull-to-refresh cuando aplica
- [ ] Diseño responsivo / adaptativo

---

## 9. 📊 Seguimiento

| Fecha | Feature | Estado | Notas |
|-------|---------|--------|-------|
| 2026-06-16 | Pedidos (Garzon) | ✅ Mejorado | Ya existía en `productos_screen.dart`. Se agregó: toast con detección de cambios en pull-to-refresh, cart badge en header con contador, skeleton loader para categorías, `dart:convert` import para data hash |
| 2026-06-16 | QR Scanner | ✅ Completado | Nuevo `QRScannerModal` reusable en `core/widgets/qr_scanner_modal.dart`. 0 issues analyze |
| 2026-06-16 | Push Notifications | ✅ Completado | Nuevo `PushNotificationService` en `core/push_notification_service.dart`. Se agregaron: firebase_core, firebase_messaging, flutter_local_notifications a pubspec. Gradle config para google-services. Android minSdk 23. |
| 2026-06-16 | API Cache | ✅ Completado | `dio_cache_interceptor` + `HiveCacheStore` integrado en `ApiClient`. Cache persistente 5 min forceCache. `cacheStoreProvider` lazy via FutureProvider. |
| 2026-06-16 | Crash Reporting | ✅ Completado | `sentry_flutter` 8.14.2. Logger utility en `core/logger.dart` con captureException, breadcrumbs. DSN via `--dart-define`. |
| 2026-06-16 | Biometric Auth | ✅ Completado | Toggle en PerfilScreen con SwitchListTile. Dectección, login biometrico, y toggle ya existian. 0 issues analyze. |
| 2026-06-16 | Profile Editing | ✅ Verificado | Ya existía en `perfil_screen.dart` (nick, foto, teléfono, dirección, estado civil, password). Se actualizó planilla. |
| 2026-06-16 | Cart / Checkout | ✅ Verificado | Ya existía `cart_notifier.dart`, checkout modal, bottom cart bar, skeleton. Se actualizó planilla. |
| 2026-06-16 | Financial Events | 🔄 Delegado | Nueva pantalla con lista, filtros, detalle. En progreso. |
| 2026-06-16 | Analytics Dashboard | 🔄 Delegado | Nueva pantalla con fl_chart. En progreso. |
| 2026-06-16 | Haptics & Animaciones | 🔄 Delegado | HapticService + StaggeredFadeIn + animaciones en screens existentes. En progreso. |
| 2026-06-17 | Haptics & Animaciones | ✅ Completado | HapticService en core/haptic_service.dart. StaggeredFadeIn widget. Haptics en login, perfil, garzon home. |
| 2026-06-17 | Financial Events | ✅ Completado | Nueva feature: domain, notifier, screen con filtros, detalle modal, pull-to-refresh. |
| 2026-06-17 | Analytics Dashboard | ✅ Completado | Nueva feature: stat cards, bar chart (fl_chart), pie chart, demo data fallback. |
| 2026-06-17 | Router extendido | ✅ Completado | Rutas /{rol}/financieros y /{rol}/analytics agregadas para garzon, cajero, anfitriona. |
| 2026-06-17 | Offline Sync | ✅ Completado | Nuevo módulo `core/offline/`: queue en SharedPreferences, Dio interceptor para conexiones fallidas, sync manager con auto-sync al reconectar (max 3 retries), banner UI offline, providers Riverpod. `connectivity_plus` agregado. 0 issues analyze. |
| 2026-06-17 | Report Service | ✅ Completado | `core/report_service.dart`: PDF generation (ventas/asistencia/servicios) con `pdf` package, CSV export, share via `share_plus`. Singleton `reportService`. `pdf: ^3.12.0`, `share_plus: ^10.1.4` agregados. |
| 2026-06-17 | Reset Password | ✅ Completado | Flutter: 2-step flow (`reset_password_screen.dart` + `reset_password_confirm_screen.dart`). AuthNotifier: `requestPasswordReset` + `confirmPasswordReset`. Rutas en router. LoginScreen: reemplazado placeholder dialog por navegación. Expo: ya existía modal-based via RUN. |
