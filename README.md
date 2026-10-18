# hermes-powerpoint

Provisions [Hermes Agent](https://github.com/NousResearch/hermes-agent) with two composable skills — `research-brief` (sources → `research/brief.md`) and `deck-builder` (brief → `.pptx`, optionally appended to a branded deck) — and proves the handoff with a smoke test. Each spec step is a numbered script in `provision/` that stops on the first failed Verify and can be re-run from any step.

The goal and the two-skill split are described in [`hermes-deck-spec-v3.md`](hermes-deck-spec-v3.md). The task-by-task plan — including a corrections table (C1–C13) verified against the Hermes source at `v2026.9.24` — is in [`docs/superpowers/plans/2026-10-19-hermes-deck-provisioning.md`](docs/superpowers/plans/2026-10-19-hermes-deck-provisioning.md).

## Before you run

> **You must provide a model API key.** The installer runs with `--skip-setup`, so Hermes starts without a model provider. Before running, create `~/.hermes/.env` (after Step 1 has created `~/.hermes/`) with at least one provider key, for example:
> ```
> OPENROUTER_API_KEY=sk-or-...
> ```
> Any provider Hermes supports works (`ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`, …; see `~/.hermes/hermes-agent/.env.example`). The provisioning scripts read this file but never write to it.
>
> If Step 5 finds no working key, it asks you to run `hermes setup` interactively (in a terminal), or stops with instructions (non-interactive, e.g. `claude -p`). After fixing the key, resume with `just from 5`. A valid key lets the run continue through the smoke test to Step 6.

## Prerequisites

- Linux, macOS, or WSL2
- `git`, `python3` ≥ 3.11, `curl`, `find`
- [`uv`](https://docs.astral.sh/uv/) and [`just`](https://just.systems/)

## Usage

```sh
just sync            # install dev deps via uv
just test            # full pytest suite
just all             # provision from Step 0 through Step 7
just from N          # resume from Step N (e.g. just from 5)
just step N          # run a single step
```

Per-step aliases: `just preflight` (0), `just install` (1), `just pptx` (2), `just gates` (3), `just skills` (4), `just smoke` (5), `just layout` (6), `just report` (7).

### Steps

| Step | Recipe | What it does |
|------|--------|--------------|
| 0 | `preflight` | Checks required tools and records render availability |
| 1 | `install` | Installs Hermes pinned to the latest stable tag |
| 2 | `pptx` | Installs `python-pptx` into the Hermes venv |
| 3 | `gates` | Enables skill-write approval gates and writes setup notes |
| 4 | `skills` | Installs the two skills into `~/.hermes/skills/` |
| 5 | `smoke` | Provider preflight + 3-slide smoke-test build |
| 6 | `layout` | Empirical layout-mapping probe (needs `BRAND_TEMPLATE`) |
| 7 | `report` | Writes `~/hermes-setup-report.json` |

Steps 1–2 are not idempotent (reinstall only after they fail). Steps 3–7 are safe to repeat.

### Brand template

Step 6 only runs when a branded template is supplied via the environment variable:

```sh
BRAND_TEMPLATE=/path/to/brand.pptx just layout
```

Without it, Step 6 records `layout_mapping_mode: not-tested` and exits cleanly.

## Non-interactive execution

The original Appendix C command has been codified into the recipes. The equivalent of the spec's `claude -p` run is now:

```sh
just all
```

State flows between steps through `.state/provision.env` (gitignored). The report lands at `~/hermes-setup-report.json` with `"smoke_test": "passed"` on a full successful run.
