#!/usr/bin/env bash
source "$(cd "${BASH_SOURCE[0]%/*}" && pwd)/lib.sh"

step 5 "Smoke test"

SMOKE="$HOME/deck-smoke-test"
HERMES_PY="${HERMES_PY:-$(discover_hermes_py || true)}"
[ -n "$HERMES_PY" ] || die "HERMES_PY not set — run just pptx first"

KEY_NAME=""
PROBE_OUT=""
A_OK=0
B_OK=0

check_provider() {
  A_OK=0
  B_OK=0
  KEY_NAME=""
  if [ -f "$HERMES_ENV_FILE" ]; then
    KEY_NAME="$(grep -E '^[A-Z0-9_]+_API_KEY=.+' "$HERMES_ENV_FILE" 2>/dev/null | head -1 | cut -d= -f1)"
    [ -n "$KEY_NAME" ] && A_OK=1
  fi
  if PROBE_OUT="$(timeout 60 hermes -z "Reply with exactly: PONG" 2>&1)"; then
    if printf '%s' "$PROBE_OUT" | grep -q PONG; then
      B_OK=1
    fi
  fi
}

check_provider

if [ "$A_OK" = 1 ] && [ "$B_OK" = 1 ]; then
  echo "PROVIDER OK ($KEY_NAME from $HERMES_ENV_FILE)"
else
  if [ -t 0 ]; then
    echo "No working API key in $HERMES_ENV_FILE."
    read -r -p "Run 'hermes setup' now to configure a provider? [y/N] " ans
    if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
      hermes setup
      check_provider
    fi
  fi
  if [ "$A_OK" != 1 ] || [ "$B_OK" != 1 ]; then
    local_fail=""
    if [ "$A_OK" != 1 ]; then
      local_fail="(a) no uncommented *_API_KEY line in $HERMES_ENV_FILE"
    else
      local_fail="(b) provider probe failed"
    fi
    echo "--- provider probe output ---" >&2
    printf '%s\n' "$PROBE_OUT" >&2
    die "NO MODEL PROVIDER: add a provider API key (e.g. OPENROUTER_API_KEY=...) to ~/.hermes/.env, or run 'hermes setup' interactively, then re-run: just from 5 [$local_fail]"
  fi
fi

rm -rf "$SMOKE"
mkdir -p "$SMOKE/research"
run cp "$REPO_ROOT/fixtures/smoke-brief.md" "$SMOKE/research/brief.md"

cd "$SMOKE"
set +e
timeout 600 hermes -z "Use deck-builder to turn research/brief.md into a 3-slide deck at out.pptx. No template. Append nothing; build fresh." > build.log 2>&1
BUILD_RC=$?
set -e
echo "hermes build exit: $BUILD_RC (log: $SMOKE/build.log)"

SLIDES="$( "$HERMES_PY" -c "from pptx import Presentation; print(len(Presentation('$SMOKE/out.pptx').slides))" 2>&1 )"
echo "slides: $SLIDES"
if [ "$SLIDES" != "3" ]; then
  echo "--- build.log (tail) ---" >&2
  tail -40 build.log >&2
  die "deck build failed: expected 3 slides, got '$SLIDES'"
fi

if command -v soffice >/dev/null 2>&1 && command -v pdftoppm >/dev/null 2>&1; then
  if test -n "$(ls -A render 2>/dev/null)"; then
    echo "RENDER OK"
  else
    echo "RENDER MISSING PNGs"
    exit 1
  fi
else
  echo "RENDER SKIPPED — install libreoffice + poppler-utils for visual QA"
fi

state_set SMOKE_TEST passed
state_set SMOKE_DIR "$SMOKE"

echo "STEP 5 OK"
