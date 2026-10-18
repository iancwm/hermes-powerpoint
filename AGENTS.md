## What this repo is
Provisions Hermes Agent with two composable skills (`research-brief`, `deck-builder`) and proves the handoff with a smoke test. Each spec step is a numbered script in `provision/`. A root `justfile` is the only entry point. State flows between steps through `.state/provision.env`.

## Layout
```
provision/       00-preflight.sh … 07-report.sh, lib.sh, probe_layout_mode.py, write_report.py
skills/          research-brief/, deck-builder/ — SKILL.md sources
tests/           pytest; one file per Python helper, plus text-contract tests for the skills
fixtures/        smoke-brief.md
.state/          gitignored; provision.env is the inter-step contract
justfile         the only entry point; just --list is the discoverability surface
hermes-deck-spec-v3.md   the spec (goal, why the two-skill split exists)
AGENTS.md        this file
```

## Read these first
1. **`hermes-deck-spec-v3.md`** — the goal: what gets provisioned, and why the two-skill split exists.
2. **The implementation plan** — the task-by-task breakdown. Its **corrections table (C1–C13)** lists every place the spec's bash is subtly wrong at the pinned Hermes tag. That table is the highest-value artifact in the repo.
3. **This file** — the conventions and traps that appear in neither of the above.

If this file and the corrections table disagree, the corrections table wins — it was verified against the Hermes source at `v2026.9.24`.

## How to run
```
just sync            # install dev deps via uv
just test            # full pytest
just all             # provision from Step 0
just from N          # resume from Step N
just step N          # one step
just install         # alias for `just step 1`; likewise pptx, gates, skills, smoke, layout, report
```

**Idempotency:** `just all` on a completed install short-circuits Steps 1–2 (`SKIP step 1: already at <tag>`, `import pptx` already works) and re-runs Steps 3–7, which are safe to repeat. `just from N` resumes from a specific step without touching earlier ones. Re-run 1–2 only after they fail.

## The silent-failure trap
`pptx_from_template.py` has two flags with two different jobs:

- **`--values FILE`** replaces `{{token}}` placeholders. It does **not** append slides.
- **`--add-slides SPEC`** appends slides, accepting template layout names or int indexes only.

Passing a slides spec to `--values` exits 0 and produces an unchanged deck. This class of bug — **success by exit code but no effect** — is the hardest to catch and the easiest to introduce.

**Every success check in this repo tests side effects, not exit codes.** A probe or build passes only when the slide count changes as expected. `probe_layout_mode.py` asserts `len(out) == len(template) + 1`, not `returncode == 0`. Preserve that discipline in anything you add.

## Rules

1. **Every script sources `provision/lib.sh`.** It sets `set -euo pipefail`, exports `~/.local/bin` on `PATH` (C4 — non-interactive bash returns early from `.bashrc`), defines `step`/`run`/`die`/`state_set`/`discover_*`, and sources the state file.

2. **State lives in `.state/provision.env`** (gitignored). Anything a later step consumes goes here via `state_set KEY VALUE`. To read state in a new script, source `lib.sh`.

3. **Steps 3–7 are idempotent. Steps 1–2 are not.** See "Idempotency" above for what `just all` and `just from N` actually do.

4. **Never fall back to `main`.** If tag discovery fails, `die`. If install fails, print `.state/install.log` and the `--version` output, then `die`. Do not try an alternative install method.

5. **Never write `~/.hermes/.env`.** Scripts read it (to check for a working provider in Step 5). Only the user writes it, or `hermes setup` does on their behalf.

6. **Never `pip install`.** Dev dependencies: `uv sync`, `uv run …`, `uv add --dev …`. The Hermes venv (managed by Hermes, not by `uv sync`): `uv pip install --python "$HERMES_PY"`.

7. **Never hardcode `productivity/powerpoint` or `.venv/bin/python`.** Use `discover_hermes_py` (matches both `venv` and `.venv` — C5) and `discover_pptx_script`.

8. **`hermes -z "…"`, not `hermes -p "…"`** (C7). `-p` is `--profile`. One-shot mode is `-z/--oneshot`.

9. **Skill files use `$S` and `$PY`** — defined once at the top of the skill, never `<skill_dir>` or bare `python`. `$S` is the directory containing `pptx_*.py`, resolved via `find ~/.hermes/skills -name pptx_create.py`. `$PY` is the Hermes interpreter, resolved via `discover_hermes_py` (matches both `venv/` and `.venv/`). Append mode uses `pptx_edit.py --set-footer N TEXT` for footers; `--add-slides` ignores the `footer` field (C11). Fall back to a bottom text box when `--set-footer` exits non-zero.

10. **Approval gate.** With `guard_agent_created` and `write_approval` enabled (Step 3), agent-authored skill writes are staged, not written. Check `/skills pending`, inspect `/skills diff <id>`, apply `/skills approve <id>`, discard `/skills reject <id>`. Writing to `~/.hermes/skills/…` directly via an editor bypasses staging — that's the path `04-skills.sh` uses. If a skill write appears to succeed but does nothing, check `/skills pending` first.

## Testing discipline

- **Write the failing test first.** Run it. Watch it fail for the right reason. Then implement. This is stated in the plan but easy to skip under time pressure.
- **`pytest.skip` for environment-dependent tests.** Tests that need installed Hermes should skip cleanly when the venv is absent — a fresh contributor's laptop shouldn't fail the suite before they've provisioned.
- **Text-contract tests are legitimate.** Task 4's tests assert the skill files contain the required rules and don't contain the forbidden patterns. That's correct: the skill is markdown, its "behavior" *is* its rules.

## The five traps (Review Focus)

Before marking a task done, verify against its trap:

1. **Re-run after a later step failed** → `just install` prints `SKIP step 1` in <10 s, no reinstall. (Task 1)
2. **Missing or broken `~/.hermes/.env`** → Step 5 never hangs and never prints an unreadable traceback. With TTY: offers `hermes setup`. Without TTY: exits 1 in under 60 s with `NO MODEL PROVIDER`. (Task 5)
3. **Non-interactive shell, minimal env** → `env -i HOME="$HOME" PATH=/usr/bin:/bin bash provision/03-gates.sh` still finds `hermes`. (Task 3)
4. **Layout names with quotes, `&`, spaces** → probe builds JSON with `json.dumps`, not heredoc interpolation. (Task 6)
5. **Exit 0 with no effect** → see "The silent-failure trap" above. (Task 6)

If you change a script, re-check its trap. If you add a script, add a trap.

## Why this shape

- **Two skills, one file handoff** (`research/brief.md`): the human review sits *between* them. Fixing a hallucinated claim in Markdown is cheaper than in a `.pptx`.
- **No `validate.py`, no disclaimer injection, no schema files**: YAGNI. Add each only when a real deck fails on it.
- **`just`, not `make`**: `just from N` composes from `just step i`; `just --list` is the discoverability surface.
- **`uv`, not pip**: lockfile, reproducible env, one tool.
- **Empirical layout probe, not spec assertion**: whether `--add-slides` accepts template names is a fact about the code at the pinned tag; the probe tests it rather than trusting documentation.

## Scope boundaries (deliberately not in)

- WACC / covenant structured fields — wrong for a regulatory deck.
- Column-width ratio schema — constrain content instead (≤5 cols, ≤8 rows, ≤20 chars per cell).
- `validate.py` gate, disclaimer injection, template-map files.

If one of these becomes necessary, add it because a *specific deck* failed, not because a critique suggested it. These were considered and rejected during review; see the Qwen critique in repo history for the original argument and the V3 spec for the reasoning. A future contributor who finds the critique does not need to relitigate the decision.

## If stuck

- **Check `.state/provision.env` first.** It is the inter-step contract.
- **Check the corrections table.** If something is behaving weird, one of C1–C13 probably explains why.
- **Check `~/.hermes/SETUP-NOTES.md`** (written by Step 3) for the skill approval flow.
- **The five traps above are the known failure modes.** If you're seeing something new, add a trap, not a workaround.