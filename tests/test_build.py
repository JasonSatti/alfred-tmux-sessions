from __future__ import annotations

from pathlib import Path
import plistlib
import shutil
import zipfile

import pytest

ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture
def source_tree(tmp_path: Path) -> Path:
    for directory in ("src", "workflow"):
        shutil.copytree(ROOT / directory, tmp_path / directory)
    return tmp_path


def test_package_uses_current_source_and_preserves_workflow(builder, source_tree: Path) -> None:
    changed_source = source_tree / "src/tmux-action.scpt"
    changed_source.write_text(changed_source.read_text() + "\n-- test source change\n")
    output = source_tree / "dist/test.alfredworkflow"
    builder.build_workflow(source_tree, output)
    with zipfile.ZipFile(output) as archive:
        metadata = plistlib.loads(archive.read("info.plist"))
        template = plistlib.loads((source_tree / "workflow/info.plist").read_bytes())
        for obj in metadata["objects"]:
            filename = builder.SCRIPT_OBJECTS[obj["type"]][1]
            assert obj["config"]["script"] == (source_tree / "src" / filename).read_text()
            obj["config"]["script"] = ""
        assert metadata == template
        assert archive.read("icon.png") == (source_tree / "workflow/icon.png").read_bytes()
    builder.verify_workflow(source_tree, output)


def test_build_is_reproducible(builder, source_tree: Path) -> None:
    first, second = source_tree / "first.zip", source_tree / "second.zip"
    builder.build_workflow(source_tree, first)
    builder.build_workflow(source_tree, second)
    assert first.read_bytes() == second.read_bytes()


def test_verification_rejects_stale_packaged_source(builder, source_tree: Path) -> None:
    output = source_tree / "test.zip"
    builder.build_workflow(source_tree, output)
    (source_tree / "src/tmux-sessions.py").write_text("print('changed')\n")
    with pytest.raises(ValueError, match="does not match"):
        builder.verify_workflow(source_tree, output)


@pytest.mark.parametrize("problem", ["extra", "missing", "duplicate"])
def test_verification_rejects_wrong_archive_entries(builder, source_tree: Path, problem: str) -> None:
    files = builder.workflow_files(source_tree)
    output = source_tree / "test.zip"
    with zipfile.ZipFile(output, "w") as archive:
        for name, content in files.items():
            if problem != "missing" or name != "icon.png":
                archive.writestr(name, content)
        if problem == "extra":
            archive.writestr("unexpected.txt", "unexpected")
        if problem == "duplicate":
            with pytest.warns(UserWarning, match="Duplicate"):
                archive.writestr("info.plist", files["info.plist"])
    with pytest.raises(ValueError, match="Archive entries"):
        builder.verify_workflow(source_tree, output)


@pytest.mark.parametrize("problem", ["missing-object", "wrong-interpreter", "embedded-script", "version"])
def test_invalid_template_fails_before_packaging(builder, source_tree: Path, problem: str) -> None:
    template = source_tree / "workflow/info.plist"
    metadata = plistlib.loads(template.read_bytes())
    if problem == "missing-object":
        metadata["objects"].pop()
    elif problem == "wrong-interpreter":
        metadata["objects"][0]["config"]["type"] = 0
    elif problem == "embedded-script":
        metadata["objects"][0]["config"]["script"] = "old code"
    else:
        metadata["version"] = "not-a-version"
    template.write_bytes(plistlib.dumps(metadata))
    with pytest.raises(ValueError):
        builder.build_workflow(source_tree, source_tree / "invalid.zip")
