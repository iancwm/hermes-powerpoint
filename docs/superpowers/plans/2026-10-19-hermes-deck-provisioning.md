# Hermes Deck Provisioning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provision Hermes (pinned) with the `research-brief` and `deck-builder` skills, and prove the handoff with a smoke test, using numbered scripts that stop on the first failed Verify and can be re-run from any step.

**Architecture:** This repo is the source of truth. Skill sources live in `skills/`, and each spec Step is a numbered script in `provision/` (`01-install.sh` … `07-report.sh`) that sources `provision/lib.sh` for logging, fail-fast, PATH setup and path discovery. Values found in one step (tag, interpreter, results) go into a gitignored state file (`.state/provision.env`), so `just from N` can resume. Logic that's easy to get wrong in bash (the layout probe, the report JSON) lives in small Python helpers with pytest tests. A root `justfile` is the single entry point, for both provisioning steps and dev tasks. The repo's Python dependencies are declared in `pyproject.toml` and locked in `uv.lock`, managed only with `uv`.

**Tech Stack:** bash, `just` (task runner), `uv` (Python deps, lockfile, venv), Python 3.11+, python-pptx, pytest, Hermes Agent `v2026.9.24` (latest stable tag on 2026-10-19).

**Spec:** `hermes-deck-spec-v3.md` (repo root). Executors read both documents. Where this plan differs from the spec, the reason is in **Spec corrections**, and each one was checked against the Hermes source at tag `v2026.9.24`.

## Spec corrections (verified against `NousResearch/hermes-agent@v2026.9.24`)

| # | Spec says | Reality at the tag | Plan does |
|---|---|---|---|
| C1 | `git ls-remote … \| tail -20` to find the latest tag | Output is sorted lexically, so `v2026.9.7` comes after `v2026.9.24` and `v2026.10.x` would sort before `v2026.8.x` | `--refs`, strip prefix, drop `-rc/-alpha/-beta`, `sort -V \| tail -1` |
| C2 | Fetching `install.sh` from the tag pins the install | `install.sh` sets `BRANCH="main"` by default and clones that | Also pass `--branch "$HERMES_TAG"`. Verify with `git -C <install> describe --tags --exact-match` |
| C3 | `hermes --version` "matches HERMES_TAG" | It prints `Hermes Agent v0.21.5 (2026.9.24)`, i.e. semver plus release date | Verify that the output contains `${HERMES_TAG#v}` and that the checkout tag equals `HERMES_TAG` |
| C4 | `source ~/.bashrc` makes `hermes` available | Non-interactive bash usually returns early from `.bashrc` | `lib.sh` exports `PATH="$HOME/.local/bin:$PATH"` |
| C5 | Venv at `*/.venv/bin/python` | Installer runs `python -m venv venv`, so it's `~/.hermes/hermes-agent/venv/bin/python` | `find` matches both `*/venv/bin/python` and `*/.venv/bin/python` under `~/.hermes/hermes-agent` |
| C6 | `"$HERMES_PY" -m pip install` | A uv-built venv may have no pip. The repo also standardizes on uv | `uv pip install --python "$HERMES_PY" python-pptx`. Skip the install if `import pptx` already works |
| C7 | `hermes -p "<prompt>"` | `-p` means `--profile`. One-shot mode is `-z/--oneshot PROMPT` ("approvals are auto-bypassed") | Use `hermes -z "<prompt>"` everywhere |
| C8 | Step 6 tests appending with `pptx_from_template.py … --values` | `--values` replaces `{{token}}` placeholders. Appending slides uses `--add-slides SPEC_JSON`, which accepts template layout **names or int indexes only** (`find_layout` → `SystemExit` otherwise). A slides spec passed to `--values` exits 0 and appends nothing, which falsely reports "template-names" | The probe uses `--add-slides` and passes only if the slide count goes up by 1 |
| C9 | Step 6 writes the raw outline over `brand-layouts.json` at the end | That overwrites the `mode` just recorded | Write a single file: `{"mode": …, "layouts_available": […]}`. The key name matches what deck-builder reads |
| C10 | Appendix B `<skill_dir>/pptx_*.py`, bare `python` | Scripts live in the bundled `powerpoint` skill (`skills/productivity/powerpoint/scripts/`), not in deck-builder. Bare `python` may not have pptx | Appendix B with minimal edits (Task 4 lists them) |
| C11 | Appendix B uses the `footer` field in append mode | `--add-slides` ignores `footer`. Only `pptx_create.py` (new mode) honours it. In append mode the tool is `pptx_edit.py --set-footer N TEXT`, which exits non-zero when the layout has no footer placeholder | Appendix B append path: run `--set-footer` per slide, and fall back to a bottom text box |
| C12 | The smoke test needs only the skills | `--skip-setup` leaves no model provider. Hermes reads provider keys from `~/.hermes/.env` (`load_hermes_dotenv`), and the spec forbids the scripts editing that file | The user supplies a key in `~/.hermes/.env` (README says so). Step 5 runs a provider preflight first: a valid `.env` continues through the smoke test to Task 6; otherwise the user is asked to run `hermes setup` (Review Focus #2) |
| C13 | Step 6 reads `templates/brand.pptx` "in the target project" | Step 5 `rm -rf`s `~/deck-smoke-test`, so no template can survive there | Template comes from env `BRAND_TEMPLATE=/abs/path.pptx` and is copied in. If unset, mode is `not-tested` |

Confirmed as stated in the spec: the repo path; the `--skip-setup` and `--non-interactive` flags; `hermes config get|set` (booleans print as `true`/`false`); the `skills.guard_agent_created` and `skills.write_approval` keys; `/skills pending|approve` (staging goes to `~/.hermes/pending/skills/`); `pptx_read.py --outline` → `layouts_available: [str]`; `pptx_create.py` built-in layout keys `title, title_content, section, two_content, title_only, blank`; `pptx_render.py --outdir`.

## Global Constraints

- Stop on first failed Verify: print step number, command, full stdout/stderr, exit non-zero. No skipping ahead.
- Never modify `~/.hermes/.env`.
- Never install from `main`. If tag discovery fails, stop.
- If Step 1's Verify fails, stop and print the install output plus `hermes --version`. Don't try another install method.
- Steps 1–2 are not idempotent: re-run only if they failed. Steps 3–7 are idempotent.
- Platforms: Linux, macOS, WSL2. Requires `git`, `python3` ≥ 3.11, `find`, `curl`, `uv`, `just`.
- Python dependencies: uv only. Repo deps live in `pyproject.toml` `[dependency-groups] dev` and are locked in a committed `uv.lock`. Use `uv sync`, `uv run …` and `uv add --dev …`. Never `pip install`, never a `requirements*.txt`, never activate a venv by hand. The Hermes venv is the one exception to `uv sync`: it's managed by Hermes, so it gets `uv pip install --python "$HERMES_PY"`.
- Every command a human or `claude -p` runs is a `just` recipe. Scripts in `provision/` are implementation details behind those recipes.
- Skill paths and the Hermes interpreter are found with `find`, never hardcoded (`productivity/` prefix is not universal).
- Missing `soffice`/`pdftoppm` is not a failure: print `RENDER SKIPPED — install libreoffice + poppler-utils for visual QA`.
- Out of scope (spec): `validate.py` gate, disclaimer injection, template-map files, WACC/covenant fields, column-width schema.
- Smoke brief date: `2026-10-19`.

## Review Focus

1. **Re-run after a later step failed.** Running `just all` again (or `just install` by itself) once Hermes is already at the tag should print `SKIP step 1: already at <tag>` and not reinstall. Test in Task 1.
2. **`~/.hermes/.env` missing, or it has a key that doesn't work** (the expected state after `--skip-setup`). Step 5 must never hang or print an unreadable traceback. On a terminal it offers to run `hermes setup` interactively. Without a terminal it exits 1 in under 60 s with the `NO MODEL PROVIDER` message from Task 5. Test in Task 5.
3. **Non-interactive shell with a minimal environment.** `env -i HOME="$HOME" PATH=/usr/bin:/bin bash provision/03-gates.sh` (direct call, bypassing `just`) should still find `hermes`. Test in Task 3.
4. **Layout names containing quotes, `&`, or spaces** (e.g. `Title "Quoted" & Content`). The probe must build the JSON with `json.dumps` and still detect `template-names`. The spec's heredoc would emit broken JSON. Test in Task 6.
5. **A spec flag that exits 0 but does nothing** (the C8 class). A probe or build "succeeds" only when the output's slide count changes as expected, never on exit code alone. Test in Task 6.

---

### Task 0: Repo scaffold, shared library, preflight

**Files:**
- Create: `.gitignore` (`.state/`, `.venv/`, `__pycache__/`, `setup-run.json`)
- Create: `provision/lib.sh`
- Create: `provision/00-preflight.sh`
- Create: `pyproject.toml`: `[project] name = "hermes-deck-provisioning"`, `version = "0.1.0"`, `requires-python = ">=3.11"`, `dependencies = []`; `[dependency-groups] dev = ["python-pptx", "pytest", "pyyaml"]`; `[tool.pytest.ini_options] testpaths = ["tests"]`. No `[build-system]`: this isn't a package, so uv treats it as a virtual project.
- Create: `.python-version` (`3.12`, the local interpreter)
- Create: `uv.lock` (generated by `uv lock`, committed)
- Create: `justfile`

**Interfaces:**
- Produces (from `lib.sh`, which every step sources):
  - `STATE_FILE` = `${PROVISION_STATE:-<repo>/.state/provision.env}`. `lib.sh` creates the directory and sources the file if it exists.
  - `step N "title"`: prints `=== Step N — title ===` and sets `CURRENT_STEP=N`.
  - `run cmd…`: echoes `+ cmd`, runs it with stdout/stderr passed through, and on failure calls `die`.
  - `die "msg"`: prints `FAILED step $CURRENT_STEP: msg` to stderr and exits 1.
  - `state_set KEY VALUE`: upserts `KEY='VALUE'` (single-quoted) into `STATE_FILE`.
  - `discover_hermes_py`: echoes the first match of `find "$HOME/.hermes/hermes-agent" \( -path '*/venv/bin/python' -o -path '*/.venv/bin/python' \) \( -type f -o -type l \)`, or returns 1. Fallback: the `#!` interpreter of `$(command -v hermes)`.
  - `discover_pptx_script NAME`: echoes `find "$HOME/.hermes/skills" -name "$NAME" | head -1`, or returns 1.
  - `lib.sh` runs `set -euo pipefail` and `export PATH="$HOME/.local/bin:$PATH"` (C4).
  - `REPO_ROOT`: absolute path of the repo.
  - `HERMES_ENV_FILE` = `${HERMES_HOME:-$HOME/.hermes}/.env`. Read-only; no script writes it. Hermes honours `HERMES_HOME`, which Task 5's tests use to point at a scratch home.
- Produces (`justfile`, which every later task invokes). It starts with `set shell := ["bash", "-euo", "pipefail", "-c"]`. Recipes:
  - `default`: `@just --list`
  - `sync`: `uv sync`
  - `test *args`: `uv run pytest {{args}}`
  - `step n`: runs the single script `provision/0{{n}}-*.sh`. It errors if the glob doesn't match exactly one file.
  - One alias per step, all calling `just step N`: `preflight` (0), `install` (1), `pptx` (2), `gates` (3), `skills` (4), `smoke` (5), `layout` (6), `report` (7).
  - `from n="0"`: a shebang recipe that runs `just step i` for i = n…7 in order and stops at the first non-zero exit, with that step's exit code.
  - `all`: `just from 0`
  - Python helpers run from scripts go through `uv run python …` (repo env). The one exception is `probe_layout_mode.py`, which runs under `"$HERMES_PY"` (Task 6).

- [ ] **Step 1:** `git init`, write `.gitignore`, `pyproject.toml` and `.python-version`, then `uv lock && uv sync`. Expected: `.venv/` and `uv.lock` are created, and `uv run python -c "import pptx, pytest, yaml"` exits 0.
- [ ] **Step 1b:** Write the `justfile`. Check: `just --list` shows all the recipes above. `just test` runs; at this point "no tests ran" (pytest exit code 5) is expected.
- [ ] **Step 2:** Write `lib.sh` and `00-preflight.sh`. Preflight checks: `git`, `curl`, `find`, `uv`, `just` on PATH; `python3` ≥ 3.11 (`python3 -c 'import sys; sys.exit(sys.version_info < (3,11))'`); `~/.local/bin` writable (create it if missing); prints `soffice`/`pdftoppm` as `present`/`absent` and writes `RENDER_AVAILABLE=true|false` to the state file.
- [ ] **Step 3:** Run `just preflight`. Expected: ends with `PREFLIGHT OK`, and `.state/provision.env` contains `RENDER_AVAILABLE=`.
- [ ] **Step 4:** Check fail-fast: `env PATH=/nonexistent /bin/bash provision/00-preflight.sh; echo $?` (direct call, since `just` itself won't resolve) should print `FAILED step 0: …` and `1`.
- [ ] **Step 5:** Commit `chore: scaffold provisioning repo, lib, preflight` (include `pyproject.toml`, `uv.lock`, `.python-version`, `justfile`, `hermes-deck-spec-v3.md` and this plan).

### Task 1: Install Hermes, pinned (spec Step 1; C1–C4)

**Files:** Create `provision/01-install.sh`

**Interfaces:**
- Consumes: `lib.sh`.
- Produces state: `HERMES_TAG`, `HERMES_VERSION` (full `hermes --version` line), `HERMES_INSTALL_DIR`.

- [ ] **Step 1:** Write `01-install.sh`:
  - Tag discovery: `git ls-remote --tags --refs https://github.com/NousResearch/hermes-agent.git | awk -F/ '{print $3}' | grep -vE -- '-(rc|alpha|beta)' | sort -V | tail -1`. If empty or the command fails, `die "tag discovery failed — check official Hermes install docs; not falling back to main"`.
  - Idempotency guard (Review Focus #1): if `command -v hermes` succeeds and `git -C "$HOME/.hermes/hermes-agent" describe --tags --exact-match` equals the tag, print `SKIP step 1: already at $HERMES_TAG`, record state, exit 0.
  - Install: `curl -fsSL ".../${HERMES_TAG}/scripts/install.sh" | bash -s -- --skip-setup --non-interactive --branch "$HERMES_TAG" 2>&1 | tee .state/install.log`.
  - Verify: `hermes --version` exits 0 **and** contains `${HERMES_TAG#v}` **and** the `describe` output equals `$HERMES_TAG`. On failure, print `.state/install.log` and the `--version` output, then `die`.
- [ ] **Step 2:** Run `just install`. Expected: last lines show `Hermes Agent v0.21.5 (2026.9.24)` (or a later tag's equivalent) and `STEP 1 OK`.
- [ ] **Step 3:** Run it again. Expected: `SKIP step 1: already at v2026.9.24`, exit 0, takes under 10 s.
- [ ] **Step 4:** Commit `feat: pinned hermes install step`.

### Task 2: python-pptx in the Hermes venv (spec Step 2; C5–C6)

**Files:** Create `provision/02-pptx.sh`

**Interfaces:**
- Consumes: `discover_hermes_py`.
- Produces state: `HERMES_PY`, `PPTX_VERSION`.

- [ ] **Step 1:** Write `02-pptx.sh`: `HERMES_PY=$(discover_hermes_py) || die "Hermes interpreter not found"`. If `"$HERMES_PY" -c 'import pptx'` already succeeds, skip the install. Otherwise run `uv pip install --python "$HERMES_PY" python-pptx`. Preflight has already confirmed that `uv` is on PATH. Never use `pip` directly. Verify `"$HERMES_PY" -c "import pptx; print('ok', pptx.__version__)"` and parse the version into state.
- [ ] **Step 2:** Run `just pptx`. Expected: `HERMES_PY=/home/<user>/.hermes/hermes-agent/venv/bin/python`, then `ok <version>`.
- [ ] **Step 3:** Commit `feat: install python-pptx into hermes venv`.

### Task 3: Skill-write gates and setup notes (spec Step 3)

**Files:** Create `provision/03-gates.sh`

- [ ] **Step 1:** Write `03-gates.sh`: `hermes config set skills.guard_agent_created true`, `hermes config set skills.write_approval true`, then the spec's Verify verbatim (`GATES OK` / `GATES FAILED`). Write `~/.hermes/SETUP-NOTES.md`: if the file is missing, create it with the spec's "Skill write approval flow" block verbatim; if the file exists but the block's heading isn't there, append the block. Never duplicate it.
- [ ] **Step 2:** Run `just gates` twice. Expected: `GATES OK` both times, and `grep -c '## Skill write approval flow' ~/.hermes/SETUP-NOTES.md` prints `1`.
- [ ] **Step 3 (Review Focus #3):** `env -i HOME="$HOME" PATH=/usr/bin:/bin bash provision/03-gates.sh`. Expected: `GATES OK`.
- [ ] **Step 4:** Commit `feat: enable skill write gates`.

### Task 4: The two skills (spec Step 4; C10–C11)

**Files:**
- Create: `skills/research-brief/SKILL.md`: spec Appendix A, **verbatim**.
- Create: `skills/deck-builder/SKILL.md`: spec Appendix B with **only** the edits listed in Step 2.
- Create: `provision/04-skills.sh`
- Test: `tests/test_skills.py`

**Interfaces:**
- Produces: `~/.hermes/skills/research-brief/SKILL.md` and `~/.hermes/skills/deck-builder/SKILL.md`; state `SKILLS_INSTALLED=research-brief,deck-builder`.

- [ ] **Step 1: Write the failing tests** in `tests/test_skills.py` (run with `uv run pytest`):
  - `test_frontmatter_parses[name]` (parametrized over both skills): the text between the first two `---` lines parses with `yaml.safe_load`; `data["name"] == <dir name>`; `data["description"]` is non-empty.
  - `test_research_brief_is_verbatim`: the file equals the Appendix A fenced block pulled from `hermes-deck-spec-v3.md` (extract the ```` ```markdown ```` block under `# Appendix A`, dropping the fence lines).
  - `test_deck_builder_append_uses_add_slides`: the file contains `--add-slides slides/spec.json` and does not contain `--values slides/spec.json`.
  - `test_deck_builder_no_placeholder_paths`: does not contain `<skill_dir>`, and contains `--set-footer`.
  - `test_deck_builder_rules_preserved`: still contains each of `≤5 columns, ≤8 rows, ≤20 characters per cell`, `Max 4 per slide`, `Never edit, reorder, or delete existing`, and `Do not substitute silently`.
- [ ] **Step 2:** Run `uv run pytest tests/test_skills.py -v`. Expected: FAIL, files missing.
- [ ] **Step 3: Write the skill files.** Appendix A verbatim. Appendix B with only these edits:
  - Before **Process**, add one line: *"Scripts: use the bundled `powerpoint` skill's scripts. Set `S=$(dirname "$(find ~/.hermes/skills -name pptx_create.py | head -1)")` and run them with the Hermes interpreter, `PY=$(find ~/.hermes/hermes-agent \( -path '*/venv/bin/python' -o -path '*/.venv/bin/python' \) | head -1)`."*
  - Replace every `python <skill_dir>/` with `"$PY" "$S"/`.
  - Step 3: if the cached `brand-layouts.json` has `"mode": "builtin-keys"`, map content to built-in keys (per spec Step 6 interpretation).
  - Step 5 Append: `"$PY" "$S"/pptx_from_template.py <base>.pptx out.pptx --add-slides slides/spec.json`.
  - New Step 5a (append mode only): for each appended slide that has a `footer`, run `"$PY" "$S"/pptx_edit.py out.pptx --set-footer <N> "<footer>"`. If that exits non-zero because there's no footer placeholder, add a bottom text box with the same text instead, and report it.
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5:** Write `04-skills.sh`: `mkdir -p` both dirs; `install -m 0644` from `$REPO_ROOT/skills/…`. This writes directly with the editor path, which bypasses staging (as the spec notes). Then the spec's frontmatter Verify loop verbatim. Extra check: `ls ~/.hermes/pending/skills 2>/dev/null` lists nothing named after either skill; otherwise `die "staged skill writes present — run /skills pending in hermes"`.
- [ ] **Step 6:** Run `just skills`. Expected: `OK …/research-brief/SKILL.md` and `OK …/deck-builder/SKILL.md`.
- [ ] **Step 7:** Commit `feat: research-brief and deck-builder skills`.

### Task 5: Smoke test (spec Step 5; C7, C12)

**Files:**
- Create: `fixtures/smoke-brief.md`: the spec's Step 5 brief, verbatim.
- Create: `provision/05-smoke.sh`

**Interfaces:**
- Consumes: state `HERMES_PY`, `RENDER_AVAILABLE`.
- Produces state: `SMOKE_TEST=passed`, `SMOKE_DIR=$HOME/deck-smoke-test`.

- [ ] **Step 1:** Write `05-smoke.sh`:
  - Provider preflight (Review Focus #2). The script only reads `~/.hermes/.env` and never writes to it. The `.env` is **valid** when both of these hold:
    - (a) the file exists and has at least one uncommented line matching `^[A-Z0-9_]+_API_KEY=.+`;
    - (b) `timeout 60 hermes -z "Reply with exactly: PONG"` exits 0 and its output contains `PONG`.
  - Valid → print `PROVIDER OK (<KEY_NAME> from ~/.hermes/.env)`, with the variable name only and never its value, then continue with the smoke test below. On success, `just from` moves on to Task 6's `06-layout.sh`.
  - Not valid, and stdin is a TTY (`[ -t 0 ]`) → print `No working API key in ~/.hermes/.env.` and ask `Run 'hermes setup' now to configure a provider? [y/N]`. On `y`: run `hermes setup` interactively, then repeat (a)+(b) once. If it's still not valid, `die`. On anything else: `die`.
  - Not valid and there's no TTY (e.g. `claude -p`) → `die "NO MODEL PROVIDER: add a provider API key (e.g. OPENROUTER_API_KEY=...) to ~/.hermes/.env, or run 'hermes setup' interactively, then re-run: just from 5"`. Include the captured probe output, plus whether it was (a) or (b) that failed.
  - `rm -rf "$SMOKE" && mkdir -p "$SMOKE/research"`, then copy the fixture to `research/brief.md`.
  - In `$SMOKE`: `timeout 600 hermes -z "Use deck-builder to turn research/brief.md into a 3-slide deck at out.pptx. No template. Append nothing; build fresh."`
  - Verify structure exactly as the spec does (`slides: 3`), then the conditional render check exactly as the spec does.
- [ ] **Step 2 (Review Focus #2):** Check the failure paths against a scratch Hermes home (`HERMES_HOME=$(mktemp -d)`), so the real `~/.hermes/.env` is never touched:
  - Empty home, no TTY: `just smoke </dev/null; echo $?` → the `NO MODEL PROVIDER` message naming (a), exit `1`, in under 60 s.
  - `.env` with `OPENROUTER_API_KEY=invalid`, no TTY → same message naming (b), exit `1`, in under 60 s.
  - `.env` with no key, on a terminal, answer `n` → the setup prompt appears, then exit `1`.
- [ ] **Step 3:** With a valid `~/.hermes/.env` (user-supplied), run `just from 5`. Expected: `PROVIDER OK (...)`, `slides: 3`, `RENDER OK` or `RENDER SKIPPED — …`, then Step 6 starts.
- [ ] **Step 4:** Commit `feat: smoke test with provider preflight`.

### Task 6: Layout mapping probe (spec Step 6; C8, C9, C13)

**Files:**
- Create: `provision/probe_layout_mode.py`
- Create: `provision/06-layout.sh`
- Test: `tests/test_probe_layout_mode.py`

**Interfaces:**
- `probe(template: Path, scripts_dir: Path, python: str = sys.executable) -> dict`, which returns `{"mode": "template-names" | "builtin-keys" | "failed", "layouts_available": list[str], "tested_layout": str}`.
  - Reads `layouts_available` by running `pptx_read.py --outline`.
  - Picks the first layout that isn't blank: the first whose name doesn't contain `blank`, case-insensitive; if every layout is blank, the first one.
  - Writes a spec with `json.dumps` and runs `pptx_from_template.py TEMPLATE OUT --add-slides SPEC` in a temp dir.
  - Mode is `template-names` only when the exit code is 0 **and** `len(Presentation(OUT).slides) == len(Presentation(TEMPLATE).slides) + 1`. Otherwise retries with `"title_content"` under the same rule, which gives `builtin-keys`. Otherwise `failed`.
- CLI: `probe_layout_mode.py TEMPLATE --scripts-dir DIR --out PATH`. Writes `{"mode", "layouts_available"}` to `--out`, prints the dict, exits 1 on `failed`.
- `06-layout.sh` consumes `BRAND_TEMPLATE` (env), state `HERMES_PY`, state `SMOKE_DIR` (default `$HOME/deck-smoke-test`) and `discover_pptx_script`, and produces state `LAYOUT_MAPPING_MODE`. `write_report.py` (Task 7) runs under `uv run python` (repo env). `probe_layout_mode.py` needs pptx, so it runs under `$HERMES_PY`.

- [ ] **Step 1: Write the failing tests.** The fixture `scripts_dir` is `dirname(discover pptx_from_template.py)` under `~/.hermes/skills`; `pytest.skip` if it's missing. The fixture `make_template(tmp_path, rename=None)` builds a template from `Presentation()` with 1 slide, optionally renaming layout 1. Tests:
  - `test_default_template_uses_template_names`: `probe(...)["mode"] == "template-names"`, and `"Title and Content" in result["layouts_available"]`.
  - `test_layout_name_with_quotes_and_ampersand` (Review Focus #4): rename layout 0 to `Title "Quoted" & Content`. It's the first non-blank layout, so the probe picks it. Assert `result["tested_layout"] == 'Title "Quoted" & Content'` and mode is `template-names`.
  - `test_exit_zero_without_new_slide_is_not_success` (Review Focus #5): monkeypatch the subprocess runner so it copies TEMPLATE to OUT and returns 0. Mode is `failed`, not `template-names`.
  - `test_cli_writes_cache_file`: after the CLI runs, `json.load(out)` has the keys `{"mode", "layouts_available"}` and no `slides` key.
- [ ] **Step 2:** `uv run pytest tests/test_probe_layout_mode.py -v`. Expected: FAIL (import error).
- [ ] **Step 3:** Implement `probe` and the CLI in `provision/probe_layout_mode.py`. Run the scripts through an injectable `runner=subprocess.run` parameter so the monkeypatch test works.
- [ ] **Step 4:** Run the tests. Expected: 4 PASS.
- [ ] **Step 5:** Write `06-layout.sh`. If `BRAND_TEMPLATE` is unset, print `STEP 6 SKIPPED — no BRAND_TEMPLATE`, record `LAYOUT_MAPPING_MODE=not-tested`, exit 0. Otherwise copy the template to `$SMOKE_DIR/templates/brand.pptx` and run `"$HERMES_PY" provision/probe_layout_mode.py "$SMOKE_DIR/templates/brand.pptx" --scripts-dir "$(dirname "$PPTX_FROM_TPL")" --out "$SMOKE_DIR/templates/brand-layouts.json"`. Record the mode, and `die` on `failed`.
- [ ] **Step 6:** Make a sample template with `uv run python -c "from pptx import Presentation; Presentation().save('/tmp/brand.pptx')"`, then run `BRAND_TEMPLATE=/tmp/brand.pptx just layout`. Expected: `"mode": "template-names"`. Also run `just layout` with no template. Expected: `STEP 6 SKIPPED`.
- [ ] **Step 7:** Commit `feat: empirical layout-mapping probe`.

### Task 7: Setup report and end-to-end run (spec Step 7, Appendix C)

**Files:**
- Create: `provision/write_report.py`
- Create: `provision/07-report.sh`
- Test: `tests/test_write_report.py`
- Create: `README.md`: what this repo is; prerequisites (`uv`, `just`); `just sync`, `just test`, `just all`, `just from N`, and the per-step recipes; `BRAND_TEMPLATE`; and the Appendix C `claude -p` command adapted to run `just all`. Near the top, a **Before you run** section with this content (copy is fixed):
  > **You must provide a model API key.** The installer runs with `--skip-setup`, so Hermes starts without a model provider. Before running, create `~/.hermes/.env` (after Step 1 has created `~/.hermes/`) with at least one provider key, for example:
  > ```
  > OPENROUTER_API_KEY=sk-or-...
  > ```
  > Any provider Hermes supports works (`ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`, …; see `~/.hermes/hermes-agent/.env.example`). The provisioning scripts read this file but never write to it.
  >
  > If Step 5 finds no working key, it asks you to run `hermes setup` interactively (in a terminal), or stops with instructions (non-interactive, e.g. `claude -p`). After fixing the key, resume with `just from 5`. A valid key lets the run continue through the smoke test to Step 6.
- Test: `tests/test_readme.py::test_readme_documents_api_key`: `README.md` contains `~/.hermes/.env`, `API key`, `hermes setup`, and `just from 5`.

**Interfaces:**
- `build_report(state: dict[str, str], now: datetime) -> dict` returns exactly the spec's Step 7 keys. Fields:
  - `timestamp` = `now` in UTC, ISO-8601 with `Z`.
  - `hermes_tag`, `hermes_version`, `hermes_python`, `python_pptx_version`: copied from state.
  - `security_gates`: both `true` (Step 3's Verify already enforced this).
  - `skills_installed`: `SKILLS_INSTALLED.split(",")`.
  - `smoke_test`: `state.get("SMOKE_TEST", "not-run")`.
  - `render_available`: `RENDER_AVAILABLE == "true"`.
  - `layout_mapping_mode`: `state.get("LAYOUT_MAPPING_MODE", "not-tested")`.
  - Raises `KeyError` naming the missing key if any of `HERMES_TAG`, `HERMES_PY`, `PPTX_VERSION` is absent.
- CLI: `write_report.py --state FILE --out FILE`. Parses `KEY='VALUE'` lines.

- [ ] **Step 1: Write the failing tests:**
  - `test_report_has_exact_spec_keys`: the key set equals the 10 keys in spec Step 7.
  - `test_timestamp_is_utc_z`: `build_report(s, datetime(2026,10,19,12,0,tzinfo=timezone.utc))["timestamp"] == "2026-10-19T12:00:00Z"`.
  - `test_missing_smoke_is_not_run`: `smoke_test == "not-run"` when `SMOKE_TEST` is absent. The report must never claim `passed` for a test that didn't run.
  - `test_render_available_bool`: `RENDER_AVAILABLE='false'` gives `False`, and the value is a `bool`, not a string.
  - `test_missing_required_key_raises`: removing `HERMES_PY` raises `KeyError` that mentions `HERMES_PY`.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3:** Implement `write_report.py`.
- [ ] **Step 4:** Run the tests. Expected: 5 PASS.
- [ ] **Step 5:** Write `07-report.sh`: `uv run --project "$REPO_ROOT" python "$REPO_ROOT/provision/write_report.py" --state "$STATE_FILE" --out ~/hermes-setup-report.json`, then the spec's Verify verbatim (`REPORT OK`).
- [ ] **Step 6:** End to end, with a provider configured: `just from 3`. Expected: Steps 3–7 pass, and `python3 -c "import json; print(json.load(open('$HOME/hermes-setup-report.json'))['smoke_test'])"` prints `passed`.
- [ ] **Step 7:** Full suite: `uv run pytest -v`. Expected: all pass.
- [ ] **Step 8:** Commit `feat: setup report and end-to-end runner`.
