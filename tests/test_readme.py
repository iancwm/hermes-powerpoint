import pathlib

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent


def test_readme_documents_api_key():
    text = (REPO_ROOT / "README.md").read_text()
    for needle in ["~/.hermes/.env", "API key", "hermes setup", "just from 5"]:
        assert needle in text
