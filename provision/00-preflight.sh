#!/usr/bin/env bash
source "$(cd "${BASH_SOURCE[0]%/*}" && pwd)/lib.sh"

step 0 "Preflight"

for tool in git curl find uv just python3; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "OK $tool"
  else
    die "missing required tool: $tool"
  fi
done

if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)'; then
  die "python3 is older than 3.11"
fi
echo "OK python3 >= 3.11"

mkdir -p "$HOME/.local/bin"
if [ ! -w "$HOME/.local/bin" ]; then
  die "$HOME/.local/bin is not writable"
fi
echo "OK ~/.local/bin writable"

if command -v soffice >/dev/null 2>&1; then
  echo "soffice: present"
else
  echo "soffice: absent"
fi
if command -v pdftoppm >/dev/null 2>&1; then
  echo "pdftoppm: present"
else
  echo "pdftoppm: absent"
fi

RENDER_AVAILABLE=false
if command -v soffice >/dev/null 2>&1 && command -v pdftoppm >/dev/null 2>&1; then
  RENDER_AVAILABLE=true
fi
state_set RENDER_AVAILABLE "$RENDER_AVAILABLE"

echo "PREFLIGHT OK"
