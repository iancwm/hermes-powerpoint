#!/usr/bin/env bash
source "$(cd "${BASH_SOURCE[0]%/*}" && pwd)/lib.sh"

step 2 "Install python-pptx into the Hermes venv"

HERMES_PY="$(discover_hermes_py || true)"
[ -n "$HERMES_PY" ] || die "Hermes interpreter not found"

echo "HERMES_PY=$HERMES_PY"

if "$HERMES_PY" -c 'import pptx' >/dev/null 2>&1; then
  echo "python-pptx already importable; skipping install"
else
  run uv pip install --python "$HERMES_PY" python-pptx
fi

VERIFY_OUT="$( "$HERMES_PY" -c "import pptx; print('ok', pptx.__version__)" 2>&1 )"
echo "$VERIFY_OUT"

PPTX_VERSION="$( "$HERMES_PY" -c 'import pptx; print(pptx.__version__)' 2>/dev/null || true )"
[ -n "$PPTX_VERSION" ] || die "could not read pptx version from $HERMES_PY"

state_set HERMES_PY "$HERMES_PY"
state_set PPTX_VERSION "$PPTX_VERSION"

echo "STEP 2 OK"
