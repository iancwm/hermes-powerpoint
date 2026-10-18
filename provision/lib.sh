#!/usr/bin/env bash
# Shared library for provisioning scripts. Every provision/*.sh sources this.

set -euo pipefail

# C4: non-interactive bash returns early from .bashrc, so put ~/.local/bin on PATH here.
export PATH="$HOME/.local/bin:$PATH"

# NOTE: source-time operations below use only bash builtins (cd/pwd, parameter
# expansion) so lib.sh loads correctly even when PATH is broken (Review Focus #3).
REPO_ROOT="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)"
STATE_FILE="${PROVISION_STATE:-$REPO_ROOT/.state/provision.env}"
CURRENT_STEP="?"

# Hermes honours HERMES_HOME. Read-only: no script writes this file.
HERMES_ENV_FILE="${HERMES_HOME:-$HOME/.hermes}/.env"

if [ -f "$STATE_FILE" ]; then
  # shellcheck disable=SC1090
  source "$STATE_FILE"
fi

step() {
  CURRENT_STEP="$1"
  shift
  echo "=== Step $CURRENT_STEP — $* ==="
}

die() {
  echo "FAILED step ${CURRENT_STEP}: $*" >&2
  exit 1
}

run() {
  echo "+ $*" >&2
  "$@" || die "command failed: $*"
}

state_set() {
  local key="$1" val="$2"
  mkdir -p "${STATE_FILE%/*}"
  local tmp="$STATE_FILE.tmp"
  if [ -f "$STATE_FILE" ]; then
    grep -v "^${key}=" "$STATE_FILE" > "$tmp" || true
  else
    : > "$tmp"
  fi
  printf "%s='%s'\n" "$key" "$val" >> "$tmp"
  mv "$tmp" "$STATE_FILE"
}

discover_hermes_py() {
  local py
  py="$(find "$HOME/.hermes/hermes-agent" \
    \( -path '*/venv/bin/python' -o -path '*/.venv/bin/python' \) \
    \( -type f -o -type l \) 2>/dev/null | head -1)"
  if [ -n "$py" ]; then
    echo "$py"
    return 0
  fi
  local hx
  hx="$(command -v hermes 2>/dev/null || true)"
  if [ -n "$hx" ]; then
    head -1 "$hx" | sed -n 's/^#!//p' | tr -d ' \r'
    return 0
  fi
  return 1
}

discover_pptx_script() {
  local found
  found="$(find "$HOME/.hermes/skills" -name "$1" 2>/dev/null | head -1)"
  if [ -n "$found" ]; then
    echo "$found"
    return 0
  fi
  return 1
}
