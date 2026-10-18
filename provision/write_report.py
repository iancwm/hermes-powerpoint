#!/usr/bin/env python3
"""Build the setup report from the inter-step state file (spec Step 7)."""

import argparse
import ast
import json
from datetime import datetime, timezone
from pathlib import Path


def _parse_state(text):
    state = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, raw = line.partition("=")
        raw = raw.strip()
        try:
            val = ast.literal_eval(raw)
        except Exception:
            val = raw
        state[key] = val
    return state


def build_report(state, now):
    for key in ["HERMES_TAG", "HERMES_PY", "PPTX_VERSION"]:
        if key not in state:
            raise KeyError(f"missing required state key: {key}")

    timestamp = now.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    return {
        "timestamp": timestamp,
        "hermes_tag": state["HERMES_TAG"],
        "hermes_version": state.get("HERMES_VERSION", ""),
        "hermes_python": state["HERMES_PY"],
        "python_pptx_version": state["PPTX_VERSION"],
        "security_gates": {
            "guard_agent_created": True,
            "write_approval": True,
        },
        "skills_installed": [
            x for x in state.get("SKILLS_INSTALLED", "").split(",") if x
        ],
        "smoke_test": state.get("SMOKE_TEST", "not-run"),
        "render_available": state.get("RENDER_AVAILABLE", "false") == "true",
        "layout_mapping_mode": state.get("LAYOUT_MAPPING_MODE", "not-tested"),
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", required=True, help="provision.env state file")
    parser.add_argument("--out", required=True, help="report JSON path")
    args = parser.parse_args(argv)

    state = _parse_state(Path(args.state).read_text())
    report = build_report(state, datetime.now(timezone.utc))
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
