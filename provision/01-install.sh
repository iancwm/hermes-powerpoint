#!/usr/bin/env bash
source "$(cd "${BASH_SOURCE[0]%/*}" && pwd)/lib.sh"

step 1 "Install Hermes (pinned)"

HERMES_TAG="$(git ls-remote --tags --refs https://github.com/NousResearch/hermes-agent.git 2>/dev/null \
  | awk -F/ '{print $3}' \
  | grep -vE -- '-(rc|alpha|beta)' \
  | sort -V \
  | tail -1 || true)"

[ -n "$HERMES_TAG" ] || die "tag discovery failed — check official Hermes install docs; not falling back to main"
echo "Latest stable tag: $HERMES_TAG"

if command -v hermes >/dev/null 2>&1 \
  && [ -d "$HOME/.hermes/hermes-agent" ] \
  && [ "$(git -C "$HOME/.hermes/hermes-agent" describe --tags --exact-match 2>/dev/null || true)" = "$HERMES_TAG" ]; then
  echo "SKIP step 1: already at $HERMES_TAG"
  state_set HERMES_TAG "$HERMES_TAG"
  state_set HERMES_VERSION "$(hermes --version 2>/dev/null | head -1 || true)"
  state_set HERMES_INSTALL_DIR "$HOME/.hermes/hermes-agent"
  exit 0
fi

mkdir -p "$HOME/.hermes" .state
set +e
curl -fsSL "https://raw.githubusercontent.com/NousResearch/hermes-agent/${HERMES_TAG}/scripts/install.sh" \
  | bash -s -- --skip-setup --non-interactive --branch "$HERMES_TAG" 2>&1 | tee .state/install.log
INSTALL_RC=$?
set -e

HERMES_VERSION="$(hermes --version 2>/dev/null | head -1 || true)"
DESCRIBED="$(git -C "$HOME/.hermes/hermes-agent" describe --tags --exact-match 2>/dev/null || true)"

if [ "$INSTALL_RC" -ne 0 ] \
  || ! command -v hermes >/dev/null 2>&1 \
  || ! printf '%s' "$HERMES_VERSION" | grep -q "${HERMES_TAG#v}" \
  || [ "$DESCRIBED" != "$HERMES_TAG" ]; then
  echo "--- .state/install.log ---" >&2
  cat .state/install.log >&2 2>/dev/null || true
  echo "--- hermes --version ---" >&2
  printf '%s\n' "$HERMES_VERSION" >&2
  die "hermes install verify failed"
fi

state_set HERMES_TAG "$HERMES_TAG"
state_set HERMES_VERSION "$HERMES_VERSION"
state_set HERMES_INSTALL_DIR "$HOME/.hermes/hermes-agent"

echo "STEP 1 OK"
