#!/usr/bin/env bash
source "$(cd "${BASH_SOURCE[0]%/*}" && pwd)/lib.sh"

step 6 "Layout mapping probe"

SMOKE_DIR="${SMOKE_DIR:-$HOME/deck-smoke-test}"

if [ -z "${BRAND_TEMPLATE:-}" ]; then
  echo "STEP 6 SKIPPED — no BRAND_TEMPLATE"
  state_set LAYOUT_MAPPING_MODE not-tested
  exit 0
fi

HERMES_PY="${HERMES_PY:-$(discover_hermes_py || true)}"
[ -n "$HERMES_PY" ] || die "HERMES_PY not set — run just pptx first"

PPTX_FROM_TPL="$(discover_pptx_script pptx_from_template.py || true)"
[ -n "$PPTX_FROM_TPL" ] || die "pptx_from_template.py not found"

mkdir -p "$SMOKE_DIR/templates"
run cp "$BRAND_TEMPLATE" "$SMOKE_DIR/templates/brand.pptx"

set +e
"$HERMES_PY" "$REPO_ROOT/provision/probe_layout_mode.py" \
  "$SMOKE_DIR/templates/brand.pptx" \
  --scripts-dir "$(dirname "$PPTX_FROM_TPL")" \
  --out "$SMOKE_DIR/templates/brand-layouts.json"
PROBE_RC=$?
set -e

MODE="$(python3 -c "import json,sys; print(json.load(open('$SMOKE_DIR/templates/brand-layouts.json')).get('mode',''))" 2>/dev/null || true)"

if [ "$PROBE_RC" -ne 0 ] || [ "$MODE" = "failed" ]; then
  die "layout probe failed (mode=$MODE, exit=$PROBE_RC)"
fi

state_set LAYOUT_MAPPING_MODE "$MODE"
echo "layout mapping mode: $MODE"
echo "STEP 6 OK"
