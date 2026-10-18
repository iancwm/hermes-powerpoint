import pathlib

import pytest
import yaml

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = REPO_ROOT / "hermes-deck-spec-v3.md"
SKILLS = REPO_ROOT / "skills"

SKILL_NAMES = ["research-brief", "deck-builder"]


def _skill_path(name: str) -> pathlib.Path:
    return SKILLS / name / "SKILL.md"


def _extract_appendix(label: str) -> str:
    lines = SPEC.read_text().splitlines()
    i = 0
    while i < len(lines) and not lines[i].startswith(f"# {label}"):
        i += 1
    assert i < len(lines), f"appendix {label} not found"
    while i < len(lines) and lines[i].strip() != "```markdown":
        i += 1
    assert i < len(lines), f"markdown fence for {label} not found"
    i += 1
    content = []
    while i < len(lines) and lines[i].strip() != "```":
        content.append(lines[i])
        i += 1
    assert i < len(lines), f"closing fence for {label} not found"
    return "\n".join(content) + "\n"


@pytest.mark.parametrize("name", SKILL_NAMES)
def test_frontmatter_parses(name):
    text = _skill_path(name).read_text()
    parts = text.split("---")
    assert len(parts) >= 3, "expected frontmatter delimited by ---"
    data = yaml.safe_load(parts[1])
    assert data["name"] == name
    assert data["description"]


def test_research_brief_is_verbatim():
    expected = _extract_appendix("Appendix A")
    assert _skill_path("research-brief").read_text() == expected


def test_deck_builder_append_uses_add_slides():
    text = _skill_path("deck-builder").read_text()
    assert "--add-slides slides/spec.json" in text
    assert "--values slides/spec.json" not in text


def test_deck_builder_no_placeholder_paths():
    text = _skill_path("deck-builder").read_text()
    assert "<skill_dir>" not in text
    assert "--set-footer" in text


def test_deck_builder_rules_preserved():
    text = _skill_path("deck-builder").read_text()
    for needle in [
        "≤5 columns, ≤8 rows, ≤20 characters per cell",
        "Max 4 per slide",
        "Never edit, reorder, or delete existing",
        "Do not substitute silently",
    ]:
        assert needle in text
