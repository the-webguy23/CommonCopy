"""Exercise the packaged helper protocol against disposable libraries only."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

helper = str(Path(sys.argv[1]).resolve())
checks = 0

with tempfile.TemporaryDirectory(prefix="CommonCopy-bridge-test-") as temporary:
    directory = Path(temporary)

    def request(operation, *, ok=True, **fields):
        global checks
        result = subprocess.run([helper, str(directory / "data")],
                                input=json.dumps(dict(operation=operation, **fields)),
                                text=True, capture_output=True, timeout=30)
        response = json.loads(result.stdout)
        assert response["ok"] is ok
        assert (result.returncode == 0) is ok
        assert not result.stderr, "The helper must not log library contents."
        checks += 1
        return response.get("state")

    state = request("snapshot")
    prompts = next(c for c in state["document"]["categories"] if c["name"] == "Prompts")
    state = request("saveCategory", name="GPT", parentId=prompts["id"])
    gpt = next(c for c in state["document"]["categories"] if c["name"] == "GPT")
    state = request("savePhrase", categoryId=gpt["id"], title="Protocol fixture",
                    text="Line one\nLine two 🧠", isFavorite=True)
    phrase = next(p for p in state["document"]["phrases"] if p["title"] == "Protocol fixture")
    assert phrase["id"] in state["categoryPhrases"][prompts["id"]]
    assert phrase["id"] in state["favourites"]
    state = request("recordUse", id=phrase["id"])
    assert state["commonlyUsed"][0] == phrase["id"]
    state = request("appearance", appearance="Dark")
    assert state["document"]["settings"]["appearance"] == "Dark"
    before = (directory / "data/phrases.json").read_bytes()
    request("saveCategory", ok=False, id=prompts["id"], name="Prompts", parentId=gpt["id"])
    request("appearance", ok=False, appearance="Unknown")
    request("unsupported", ok=False)
    assert (directory / "data/phrases.json").read_bytes() == before
    exported = directory / "export.json"
    request("export", path=str(exported))
    request("deleteCategory", id=prompts["id"])
    state = request("import", path=str(exported))
    restored = next(p for p in state["document"]["phrases"] if p["id"] == phrase["id"])
    assert restored["text"] == "Line one\nLine two 🧠"
    assert restored["useCount"] == 1
    result = subprocess.run([helper, str(directory / "data")], input="{",
                            text=True, capture_output=True, timeout=30)
    assert result.returncode == 1 and json.loads(result.stdout)["ok"] is False
    assert "Protocol fixture" not in result.stdout + result.stderr
    checks += 1

print(f"Packaged bridge: {checks} protocol checks passed; disposable data removed.")
