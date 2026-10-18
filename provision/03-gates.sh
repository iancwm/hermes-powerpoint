#!/usr/bin/env bash
source "$(cd "${BASH_SOURCE[0]%/*}" && pwd)/lib.sh"

step 3 "Enable skill-write gates"

run hermes config set skills.guard_agent_created true
run hermes config set skills.write_approval true

if test "$(hermes config get skills.guard_agent_created)" = "true" \
  && test "$(hermes config get skills.write_approval)" = "true"; then
  echo "GATES OK"
else
  echo "GATES FAILED"
  exit 1
fi

SETUP_NOTES="$HOME/.hermes/SETUP-NOTES.md"

if ! grep -q '## Skill write approval flow' "$SETUP_NOTES" 2>/dev/null; then
  cat >> "$SETUP_NOTES" <<'EOF'

## Skill write approval flow
With write_approval enabled, agent-authored skills are staged, not written.
- `/skills pending` — list staged writes
- `/skills diff <id>` — inspect
- `/skills approve <id>` — apply
- `/skills reject <id>` — discard
Skills written directly with an editor bypass staging.
EOF
fi

echo "STEP 3 OK"
