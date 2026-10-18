from datetime import datetime, timezone

import pytest

from provision.write_report import build_report

SPEC_KEYS = {
    "timestamp",
    "hermes_tag",
    "hermes_version",
    "hermes_python",
    "python_pptx_version",
    "security_gates",
    "skills_installed",
    "smoke_test",
    "render_available",
    "layout_mapping_mode",
}


def _state(**overrides):
    base = {
        "HERMES_TAG": "v2026.9.24",
        "HERMES_VERSION": "Hermes Agent v0.21.5 (2026.9.24)",
        "HERMES_PY": "/home/u/.hermes/hermes-agent/venv/bin/python",
        "PPTX_VERSION": "1.0.2",
        "SKILLS_INSTALLED": "research-brief,deck-builder",
        "SMOKE_TEST": "passed",
        "RENDER_AVAILABLE": "true",
        "LAYOUT_MAPPING_MODE": "template-names",
    }
    base.update(overrides)
    return base


def test_report_has_exact_spec_keys():
    report = build_report(_state(), datetime.now(timezone.utc))
    assert set(report.keys()) == SPEC_KEYS


def test_timestamp_is_utc_z():
    report = build_report(_state(), datetime(2026, 10, 19, 12, 0, tzinfo=timezone.utc))
    assert report["timestamp"] == "2026-10-19T12:00:00Z"


def test_missing_smoke_is_not_run():
    s = _state()
    del s["SMOKE_TEST"]
    report = build_report(s, datetime.now(timezone.utc))
    assert report["smoke_test"] == "not-run"


def test_render_available_bool():
    report = build_report(_state(RENDER_AVAILABLE="false"), datetime.now(timezone.utc))
    assert report["render_available"] is False
    assert isinstance(report["render_available"], bool)


def test_missing_required_key_raises():
    s = _state()
    del s["HERMES_PY"]
    with pytest.raises(KeyError) as exc:
        build_report(s, datetime.now(timezone.utc))
    assert "HERMES_PY" in str(exc.value)
