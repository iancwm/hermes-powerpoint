#!/usr/bin/env bash
source "$(cd "${BASH_SOURCE[0]%/*}" && pwd)/lib.sh"

step 7 "Report state"

run uv run --project "$REPO_ROOT" python "$REPO_ROOT/provision/write_report.py" \
  --state "$STATE_FILE" --out "$HOME/hermes-setup-report.json"

python3 -c "import json; json.load(open('$HOME/hermes-setup-report.json')); print('REPORT OK')"

echo "STEP 7 OK"
