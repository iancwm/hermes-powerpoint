---
name: deck-builder
description: Use when the user has a research brief or outline and wants a
  .pptx file, either standalone or appended to an existing branded deck.
  Consumes content; does not generate it. Do NOT use to research a topic.
---

# Deck Builder

Scripts: use the bundled `powerpoint` skill's scripts. Set `S=$(dirname "$(find ~/.hermes/skills -name pptx_create.py | head -1)")` and run them with the Hermes interpreter, `PY=$(find ~/.hermes/hermes-agent \( -path '*/venv/bin/python' -o -path '*/.venv/bin/python' \) | head -1)`.

## Process
1. Read `research/brief.md` (or the outline the user supplies). If missing,
   stop and ask. If the brief has no "Next steps" section with owner and
   date, ask for them before building.
2. Decide the mode:
   - **Append mode** — a base deck was supplied (e.g. `templates/brand.pptx`).
   - **New mode** — no base deck.
3. Append mode only: obtain the layout inventory before writing any slide.
   Use the cached `templates/brand-layouts.json` if it exists. Otherwise:
   `"$PY" "$S"/pptx_read.py <base>.pptx --outline`
   Read `layouts_available` and use those exact strings. Never invent
   PowerPoint UI names like "Title Slide". Never default to a blank layout.
   If the cached `templates/brand-layouts.json` has `"mode": "builtin-keys"`,
   map your content to the built-in keys (`title`, `title_content`, `section`,
   `two_content`, `title_only`, `blank`) instead of the template's own names.
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
   - Append: `"$PY" "$S"/pptx_from_template.py <base>.pptx out.pptx --add-slides slides/spec.json`
   - New:    `"$PY" "$S"/pptx_create.py slides/spec.json out.pptx`
5a. Append mode only: for each appended slide that has a `footer`, run
    `"$PY" "$S"/pptx_edit.py out.pptx --set-footer <N> "<footer>"`. If that
    exits non-zero because the layout has no footer placeholder, add a bottom
    text box with the same text instead, and report it.
6. Render and inspect: `"$PY" "$S"/pptx_render.py out.pptx --outdir render`.
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
