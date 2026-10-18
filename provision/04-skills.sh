#!/usr/bin/env bash
source "$(cd "${BASH_SOURCE[0]%/*}" && pwd)/lib.sh"

step 4 "Install the two skills"

for skill in research-brief deck-builder; do
  mkdir -p "$HOME/.hermes/skills/$skill"
  run install -m 0644 "$REPO_ROOT/skills/$skill/SKILL.md" "$HOME/.hermes/skills/$skill/SKILL.md"
done

for f in "$HOME"/.hermes/skills/{research-brief,deck-builder}/SKILL.md; do
  head -1 "$f" | grep -qx -- '---' \
    && grep -q '^name: ' "$f" \
    && grep -q '^description: ' "$f" \
    && echo "OK $f" || { echo "BAD $f"; exit 1; }
done

STAGED="$(ls "$HOME/.hermes/pending/skills" 2>/dev/null | grep -E '^(research-brief|deck-builder)$' || true)"
if [ -n "$STAGED" ]; then
  die "staged skill writes present — run /skills pending in hermes"
fi

state_set SKILLS_INSTALLED "research-brief,deck-builder"

echo "STEP 4 OK"
