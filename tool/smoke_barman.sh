#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Smoke del rol Barman en Windows de una sola orden:
#
#   bash tool/smoke_barman.sh
#
# 1) Arranca el dashboard local (lasmunecasderamon-dashboard, pnpm dev :3000)
#    si no responde ya.
# 2) Prepara el toolchain Windows: PATH de flutter, JAVA_HOME (JDK 17) y, si
#    hiciera falta, el configure de CMake con los shims ATL de tool/win32-shims
#    (este equipo no tiene el componente "C++ ATL" de Visual Studio).
# 3) Ejecuta integration_test/barman_smoke_test.dart contra el backend local:
#    login → redirect /barman → los 5 tabs → tarjeta BAR → pantalla Bar con
#    sus 4 subtabs → acción del escáner, sin excepciones.
#
# Credenciales por defecto: damo / 123456789 (el usuario Barman de dev).
# Se pueden sobreescribir por entorno:
#   SMOKE_NICK=... SMOKE_PASSWORD=... SMOKE_PORT=3000 bash tool/smoke_barman.sh
# No se imprimen credenciales ni se escriben en ningún fichero: van por
# --dart-define.
#
# Logs: build/logs/smoke_barman.log (test) y build/logs/dashboard_dev.log (API).
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"                 # proyecto Flutter
DASHBOARD="$(cd "$ROOT/.." && pwd)/lasmunecasderamon-dashboard"
PORT="${SMOKE_PORT:-3000}"
NICK="${SMOKE_NICK:-damo}"
PASS="${SMOKE_PASSWORD:-123456789}"
LOG_DIR="$ROOT/build/logs"
mkdir -p "$LOG_DIR"

say() { printf '\n==> %s\n' "$*"; }

# Código HTTP de una URL (000 = no responde).
http_code() {
  curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$1" 2>/dev/null || echo 000
}

# ── 1) Backend local ────────────────────────────────────────────────────────
HEALTH_URL="http://localhost:$PORT/api/auth/check-users"
code="$(http_code "$HEALTH_URL")"
if [ "$code" = "000" ]; then
  if [ ! -d "$DASHBOARD" ]; then
    echo "✗ No encuentro el dashboard en $DASHBOARD" >&2
    exit 1
  fi
  say "Dashboard local no responde en :$PORT → arrancando pnpm dev"
  (cd "$DASHBOARD" && PORT="$PORT" nohup pnpm dev \
      >"$LOG_DIR/dashboard_dev.log" 2>&1 </dev/null &)
  for _ in $(seq 1 60); do
    sleep 2
    code="$(http_code "$HEALTH_URL")"
    if [ "$code" != "000" ]; then
      break
    fi
  done
fi
if [ "$code" = "000" ]; then
  echo "✗ El dashboard local no arrancó (ver $LOG_DIR/dashboard_dev.log)" >&2
  exit 1
fi
echo "✓ Dashboard local en :$PORT (HTTP $code)"

# ── 2) Toolchain Windows ────────────────────────────────────────────────────
export PATH="$HOME/flutter/bin:$PATH"
if ! command -v flutter >/dev/null 2>&1; then
  echo "✗ flutter no está en el PATH (esperado: \$HOME/flutter/bin)" >&2
  exit 1
fi

if [ -z "${JAVA_HOME:-}" ]; then
  # JDK 17 de esta máquina: instalación por usuario (AppData) primero; por si
  # acaso, también los sitios clásicos de Program Files.
  JDK=""
  for cand in \
    "$HOME/AppData/Local/Programs/Java"/jdk-* \
    "/c/Program Files/Microsoft"/jdk-* \
    "/c/Program Files/Java"/jdk-*; do
    if [ -d "$cand" ]; then
      JDK="$cand"
      break
    fi
  done
  if [ -n "$JDK" ] && command -v cygpath >/dev/null 2>&1; then
    export JAVA_HOME="$(cygpath -w "$JDK")"
    echo "✓ JAVA_HOME=$JAVA_HOME"
  else
    echo "⚠ JAVA_HOME sin definir y no hay JDK detectado: el plugin 'jni' podría" >&2
    echo "  fallar en el configure de CMake (build limpio)." >&2
  fi
fi

# Shims ATL: si el cache de CMake no los contiene (build limpio, repo movido),
# reconfiguramos con el mismo generador que usa Flutter.
CACHE="$ROOT/build/windows/x64/CMakeCache.txt"
SHIMS_M="$(cygpath -m "$ROOT/tool/win32-shims" 2>/dev/null || echo "$ROOT/tool/win32-shims")"
if [ ! -f "$CACHE" ] || ! grep -qF "$SHIMS_M" "$CACHE"; then
  say "Configure de CMake con shims ATL (tool/win32-shims)"
  cmake -S "$ROOT/windows" -B "$ROOT/build/windows/x64" \
    -G "Visual Studio 18 2026" -A x64 \
    -DCMAKE_CXX_FLAGS="/DWIN32 /D_WINDOWS /W3 /GR /EHsc /I\"$SHIMS_M\" /D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS"
fi

# ── 3) Smoke ────────────────────────────────────────────────────────────────
say "Smoke Barman: login → /barman → 5 tabs → pantalla Bar (backend http://localhost:$PORT)"
cd "$ROOT"
flutter test integration_test/barman_smoke_test.dart -d windows \
  --dart-define=SMOKE_NICK="$NICK" \
  --dart-define=SMOKE_PASSWORD="$PASS" \
  --dart-define=API_BASE_DOMAIN="http://localhost:$PORT" \
  2>&1 | tee "$LOG_DIR/smoke_barman.log"

echo
echo "✓ Smoke finalizado. Log: build/logs/smoke_barman.log"
