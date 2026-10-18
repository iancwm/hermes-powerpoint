# `hermes-deck-spec-v3.md` — Consolidated Provisioning Spec

**For:** Claude Code, non-interactive execution via `claude -p`
**Goal:** Provision Hermes with two composable skills — `research-brief` (sources → `research/brief.md`) and `deck-builder` (brief → `.pptx`, optionally appended to a branded deck) — hardened to the point where the first real build does not fail on known footguns.

**Consolidated from:** v1 (initial two-skill design), v2 (pinned install, venv-aware pip, conditional render, path discovery), Qwen IB critique (take table constraint + on-slide footnotes + nuance field; reject WACC/covenant schema as scope creep), Meta critique (test layout mapping empirically, don't legislate it).

**Deliberately excluded** (add only when a specific deck fails on one):
- Custom `validate.py` gate
- Disclaimer injection script
- Template-map files
- WACC / covenant structured fields
- Column-width ratio schema

---

## Execution contract

Run non-interactively. Stop on first failed **Verify**. Print step number, command, full stdout/stderr, exit non-zero. Do not skip ahead. Do not modify `~/.hermes/.env`.

## Preconditions

- Linux, macOS, or WSL2
- `git`, `python3.11+`, `pip`, `find` on PATH
- Write access to `~/.hermes/` and `~/.local/bin/`
- **Optional:** LibreOffice (`soffice`) and poppler (`pdftoppm`) for visual QA. Smoke test handles their absence.

## Known uncertainties (Claude Code must verify, not assume)

- Repository path for Hermes (`NousResearch/hermes-agent` is assumed; confirm from official docs if install fails)
- Tag names available for pinning
- Exact venv path (discovered via `find`, not hardcoded)
- Whether `pptx_from_template.py` accepts template layout names directly or requires built-in keys (resolved by test in Step 6, not by assumption)

---

## Step 1 — Install Hermes (pinned)

Discover an available tag first:

```bash
git ls-remote --tags https://github.com/NousResearch/hermes-agent.git 2>/dev/null | tail -20
```

If the command fails, the repo path is wrong — consult the official Hermes installation docs before proceeding. Do not fall back to `main`.

Pick the most recent stable tag (not `-rc` / `-alpha` / `-beta`) and install from it:

```bash
HERMES_TAG="<tag from above>"
curl -fsSL "https://raw.githubusercontent.com/NousResearch/hermes-agent/${HERMES_TAG}/scripts/install.sh" \
  | bash -s -- --skip-setup --non-interactive

source ~/.bashrc 2>/dev/null || source ~/.zshrc 2>/dev/null || true
```

**Verify:** `hermes --version` exits 0 and the printed version matches `HERMES_TAG`.

**If Verify fails:** stop. Report both the install output and `hermes --version` output. Do not attempt an alternative install method.

---

## Step 2 — Install `python-pptx` into the Hermes venv

Discover the Hermes interpreter (the one that runs skill scripts), not your shell's Python:

```bash
HERMES_PY="$(find "$HOME/.hermes" -path '*/.venv/bin/python' -type f 2>/dev/null | head -1)"
echo "HERMES_PY=$HERMES_PY"
```

If empty, ask Hermes directly:

```bash
hermes -p "Print sys.executable. Nothing else." 2>&1 | grep -oE '/[^ ]*python[0-9.]*'
```

Then install:

```bash
"$HERMES_PY" -m pip install python-pptx
```

**Verify (this is the only check that matters):**

```bash
"$HERMES_PY" -c "import pptx; print('ok', pptx.__version__)"
```

Expect `ok <version>`. Your shell's `python` may not have `pptx` — that is fine.

---

## Step 3 — Enable skill-write gates

Use `hermes config set` rather than hand-editing YAML:

```bash
hermes config set skills.guard_agent_created true
hermes config set skills.write_approval true
```

**Verify:**

```bash
test "$(hermes config get skills.guard_agent_created)" = "true" \
  && test "$(hermes config get skills.write_approval)" = "true" \
  && echo "GATES OK" || { echo "GATES FAILED"; exit 1; }
```

Document the approval flow in `~/.hermes/SETUP-NOTES.md` for future users:

```markdown
## Skill write approval flow
With write_approval enabled, agent-authored skills are staged, not written.
- `/skills pending` — list staged writes
- `/skills diff <id>` — inspect
- `/skills approve <id>` — apply
- `/skills reject <id>` — discard
Skills written directly with an editor bypass staging.
```

---

## Step 4 — Create the two skills

```bash
mkdir -p ~/.hermes/skills/research-brief ~/.hermes/skills/deck-builder
```

Write `~/.hermes/skills/research-brief/SKILL.md` from **Appendix A** (verbatim).
Write `~/.hermes/skills/deck-builder/SKILL.md` from **Appendix B** (verbatim).

**Verify frontmatter:**

```bash
for f in ~/.hermes/skills/{research-brief,deck-builder}/SKILL.md; do
  head -1 "$f" | grep -qx -- '---' \
    && grep -q '^name: ' "$f" \
    && grep -q '^description: ' "$f" \
    && echo "OK $f" || { echo "BAD $f"; exit 1; }
done
```

Both must print `OK`.

If writes are staged by the gate, list and approve:

```bash
hermes -p "/skills pending" 2>&1 | tee /tmp/pending.txt
# Then approve each staged id shown in the output
```

---

## Step 5 — Smoke test

```bash
SMOKE=~/deck-smoke-test
rm -rf "$SMOKE" && mkdir -p "$SMOKE/research" && cd "$SMOKE"
```

Write `research/brief.md`:

```markdown
# Brief: Smoke test

## Scope
Verification of the two-skill handoff.

## Findings

### python-pptx builds decks headlessly
- Claim: python-pptx can create and edit .pptx files without PowerPoint installed.
- Nuance: N/A
- Source: https://python-pptx.readthedocs.io/ — 2026-10-19 — high

## Timeline
- 2026-10-19 — smoke test

## Next steps
- Owner: Setup verification
- Date: 2026-10-19

## Open questions
- None.
```

Build:

```bash
hermes -p "Use deck-builder to turn research/brief.md into a 3-slide deck at out.pptx. No template. Append nothing; build fresh."
```

**Verify structure (mandatory):**

```bash
"$HERMES_PY" -c "from pptx import Presentation; print('slides:', len(Presentation('out.pptx').slides))"
```

Expect `slides: 3`. If not, the deck build failed — report and stop.

**Verify render (conditional):**

```bash
if command -v soffice >/dev/null && command -v pdftoppm >/dev/null; then
  test -n "$(ls -A render 2>/dev/null)" && echo "RENDER OK" || { echo "RENDER MISSING PNGs"; exit 1; }
else
  echo "RENDER SKIPPED — install libreoffice + poppler-utils for visual QA"
fi
```

The deck is valid without PNGs; you just have no visual check.

---

## Step 6 — Layout mapping test (only if a template was supplied)

Skip this step if no `templates/brand.pptx` exists in the target project.

Discover skill scripts (do not hardcode paths — the `productivity/` prefix is not universal):

```bash
PPTX_READ="$(find "$HOME/.hermes/skills" -name pptx_read.py | head -1)"
PPTX_FROM_TPL="$(find "$HOME/.hermes/skills" -name pptx_from_template.py | head -1)"
test -n "$PPTX_READ" && test -n "$PPTX_FROM_TPL" || { echo "SKILL SCRIPTS NOT FOUND"; exit 1; }
```

Inventory the template:

```bash
cd ~/deck-smoke-test
"$HERMES_PY" "$PPTX_READ" templates/brand.pptx --outline > /tmp/layouts.json
```

**Empirical test — does `pptx_from_template.py` accept the template's own layout names?**

```bash
# Extract one layout name from the inventory
LAYOUT_NAME="$(python3 -c "import json,sys; d=json.load(open('/tmp/layouts.json')); print(d['layouts_available'][0] if isinstance(d['layouts_available'][0], str) else d['layouts_available'][0].get('name',''))")"
echo "Testing layout: $LAYOUT_NAME"

cat > /tmp/t.json <<EOF
{"slides":[{"layout":"${LAYOUT_NAME}","title":"Layout test"}]}
EOF

"$HERMES_PY" "$PPTX_FROM_TPL" templates/brand.pptx /tmp/t.pptx --values /tmp/t.json
```

**Interpretation:**

- **Exit 0** → template layout names work directly. Note this in `templates/brand-layouts.json` as `{"mode": "template-names", "layouts": [...]}`. `deck-builder` uses template names.
- **Non-zero exit** → the script requires built-in keys. Retry with `"layout": "title_content"`. If that succeeds, note `{"mode": "builtin-keys", "template_layouts": [...]}` and update `deck-builder`'s prompt in the real build to say "map your content to the built-in keys; the template handles styling."

Whichever result, persist it:

```bash
echo "$("$HERMES_PY" "$PPTX_READ" templates/brand.pptx --outline)" > templates/brand-layouts.json
```

This cached file is what subsequent `deck-builder` runs read instead of re-inventorying.

---

## Step 7 — Report state

Write `~/hermes-setup-report.json`:

```json
{
  "timestamp": "<ISO-8601 UTC>",
  "hermes_tag": "<HERMES_TAG>",
  "hermes_version": "<from hermes --version>",
  "hermes_python": "<HERMES_PY>",
  "python_pptx_version": "<from Step 2 verify>",
  "security_gates": { "guard_agent_created": true, "write_approval": true },
  "skills_installed": ["research-brief", "deck-builder"],
  "smoke_test": "passed",
  "render_available": true,
  "layout_mapping_mode": "<template-names | builtin-keys | not-tested>"
}
```

**Verify:**

```bash
python3 -c "import json; json.load(open('$HOME/hermes-setup-report.json')); print('REPORT OK')"
```

---

# Appendix A — `research-brief/SKILL.md`

```markdown
---
name: research-brief
description: Use when the user needs sourced research before a deliverable.
  Reads provided documents and websites and writes research/brief.md with
  atomic, individually citable findings. Do NOT use for quick lookups, or
  when the user already has a usable brief.
---

# Research Brief

## Process
1. Confirm topic, scope, audience, and time window. Ask at most 3 questions.
2. Read every source the user provided. If the topic is regulatory, go to
   each regulator's own publications page before trusting secondary coverage.
3. Write `research/brief.md` in exactly this shape:

   # Brief: <topic>

   ## Scope
   What is in and out of bounds.

   ## Findings

   ### <short finding title>
   - Claim: <one sentence>
   - Nuance: <jurisdiction, instrument type, and effective date, or any
     qualifier that changes how the claim applies. E.g.
     "Onshore UAE, Federal Decree-Law, effective 1 Jan 2026."
     Write "N/A" only if the claim has no qualifier.>
   - Source: <URL or document path> — <YYYY-MM-DD> — <high|medium|low>

   (repeat per finding; one claim per entry)

   ## Timeline
   - <YYYY-MM-DD> — <event>

   ## Next steps
   - Owner: <named person or role>
   - Date: <YYYY-MM-DD>

   ## Open questions
   - [UNVERIFIED: <what could not be confirmed>]

## Rules
- Every claim carries a source. No source, no claim.
- Atomic findings only. The deck skill cites these individually; a paragraph
  of prose is unusable downstream.
- Do not write slides. Do not suggest deck structure.
- Do not pad. Ten solid findings beat thirty thin ones.
- "Next steps" is required. The deck skill refuses to build without it.
```

---

# Appendix B — `deck-builder/SKILL.md`

```markdown
---
name: deck-builder
description: Use when the user has a research brief or outline and wants a
  .pptx file, either standalone or appended to an existing branded deck.
  Consumes content; does not generate it. Do NOT use to research a topic.
---

# Deck Builder

## Process
1. Read `research/brief.md` (or the outline the user supplies). If missing,
   stop and ask. If the brief has no "Next steps" section with owner and
   date, ask for them before building.
2. Decide the mode:
   - **Append mode** — a base deck was supplied (e.g. `templates/brand.pptx`).
   - **New mode** — no base deck.
3. Append mode only: obtain the layout inventory before writing any slide.
   Use the cached `templates/brand-layouts.json` if it exists. Otherwise:
   `python <skill_dir>/pptx_read.py <base>.pptx --outline`
   Read `layouts_available` and use those exact strings. Never invent
   PowerPoint UI names like "Title Slide". Never default to a blank layout.
4. Write `slides/spec.json`. Minimal shape:

   {
     "slide_size": "16:9",
     "slides": [
       {
         "layout": "<from layouts_available, or title_content in new mode>",
         "title": "<slide title>",
         "bullets": ["...", "..."],
         "notes": "Source: <URL> — <date>. <one-line context>.",
         "footer": "Source: <name>, <YYYY-MM-DD>."
       }
     ]
   }

5. Build:
   - Append: `python <skill_dir>/pptx_from_template.py <base>.pptx out.pptx --values slides/spec.json`
   - New:    `python <skill_dir>/pptx_create.py slides/spec.json out.pptx`
6. Render and inspect: `python <skill_dir>/pptx_render.py out.pptx --outdir render`.
   If render reports `{"rendered": false}`, note the missing dependency and
   proceed — the deck is valid, it just has not been visually checked.

## Rules
- **Traceability:** Every bullet traces to a finding in the brief. Add no
  new facts.
- **Footnotes:** Every slide stating an obligation, date, penalty, threshold,
  or number carries a one-line source in the `footer` field or a bottom text
  box: "Source: <name>, <YYYY-MM-DD>." Speaker notes supplement this; they
  do not replace it.
- **Tables:** ≤5 columns, ≤8 rows, ≤20 characters per cell. If the content
  exceeds this, split across two slides. Never put full sentences in cells —
  they overflow in python-pptx and cannot be auto-fitted.
- **Bullets:** Max 4 per slide.
- **Append mode:** append only. Never edit, reorder, or delete existing
  slides.
- **Final slide:** "Next steps" sourced from the brief's Next steps section
  (owner + date).
- **Charts:** python-pptx charts are static and cannot link to an Excel
  model. Say so when the user expects live linkage.
- **Layout fallback:** If a required layout does not exist in the base deck,
  report it. Do not substitute silently.
```

---

# Appendix C — Execution command

Save the spec to `hermes-deck-spec-v3.md`, then:

```bash
claude -p "$(cat hermes-deck-spec-v3.md)" \
  --allowedTools "Read,Edit,Write,Bash" \
  --permission-mode acceptEdits \
  --output-format json \
  > setup-run.json 2>&1

# Inspect result
python3 -c "import json; r=json.load(open('setup-run.json')); print(r.get('result', r))"
```

Expected exit code 0 with `"smoke_test": "passed"` in `~/hermes-setup-report.json`.

If the run exits non-zero, the failing step is identified in stdout. Re-run **from that step forward only** — Steps 3–7 are idempotent; Steps 1–2 are not (reinstalling Hermes or re-pipping is only appropriate if those steps actually failed).

---

## What V3 changes from V2

| Change | Source | Why |
|---|---|---|
| Pinned installer with tag discovery + failure policy | Meta critique | Unpinned `main` breaks smoke tests on upstream commits |
| Venv-interpreter discovery before `pip install` | Meta critique | Shell pip silently installs to wrong Python |
| `hermes config set` instead of YAML merge | Meta critique | Manual merge causes indentation errors |
| Conditional render check | Meta critique | Missing LibreOffice/poppler is not a deck failure |
| Skill path via `find` | Meta critique | `productivity/` prefix is not universal |
| `Nuance` field in findings | Qwen critique, calibrated to regulatory content | Captures jurisdiction + effective date, not WACC |
| Table constraint (≤5×8, ≤20 chars) | Qwen critique | Prevents the #1 python-pptx render failure without new schema |
| `footer` field + on-slide footnote rule | Qwen critique | Speaker notes don't satisfy review; `pptx_edit --set-footer` is the mechanism |
| `notes` field in spec.json example | Meta critique | Makes the "source in speaker notes" rule executable |
| Layout-mapping test (Step 6, empirical) | Meta critique + Qwen critique | Resolves the ambiguity by test, not prose |

## What V3 refuses to add

- **WACC / covenant structured fields.** Irrelevant to a UAE regulatory update. Add when an IB valuation deck is actually on the roadmap.
- **`validate.py` gate.** The render-and-look step plus the brief's `Open questions` section catch the same failures with less machinery.
- **Disclaimer injection.** Add after the first compliance review flags the deck.
- **Column-width ratio schema.** Constrain the agent's table content today; add the schema only if the constraint proves insufficient in practice.
