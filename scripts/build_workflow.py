#!/usr/bin/env python3
"""Build an Alfred workflow using the checked-in metadata and current source."""

from __future__ import annotations

import argparse
from pathlib import Path
import plistlib
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_OBJECTS = {
    "alfred.workflow.input.scriptfilter": (9, "tmux-sessions.py"),
    "alfred.workflow.action.script": (6, "tmux-action.scpt"),
}
DEFAULT_OUTPUT = ROOT / "dist" / "Tmux Sessions.alfredworkflow"


def workflow_files(root: Path) -> dict[str, bytes]:
    """Return package contents after validating metadata and injecting scripts."""
    template = root / "workflow"
    with (template / "info.plist").open("rb") as stream:
        metadata = plistlib.load(stream)
    if not re.fullmatch(r"\d+\.\d+\.\d+", metadata.get("version", "")):
        raise ValueError("workflow/info.plist must contain a version such as 2.2.3")

    for object_type, (script_type, filename) in SCRIPT_OBJECTS.items():
        matches = [obj for obj in metadata["objects"] if obj["type"] == object_type]
        if len(matches) != 1:
            raise ValueError(f"Expected exactly one {object_type} object")
        config = matches[0]["config"]
        if config["type"] != script_type or config.get("scriptfile"):
            raise ValueError(f"Unexpected interpreter or external script for {filename}")
        if config.get("script"):
            raise ValueError("Keep template scripts empty; edit the files in src/ instead")
        config["script"] = (root / "src" / filename).read_text(encoding="utf-8")

    files = {path.name: path.read_bytes() for path in sorted(template.glob("*.png"))}
    if "icon.png" not in files:
        raise ValueError("workflow/icon.png is missing")
    files["info.plist"] = plistlib.dumps(metadata, sort_keys=False)
    return files


def build_workflow(root: Path, output: Path) -> None:
    """Write a reproducible archive, independent of source modification times."""
    files = workflow_files(root)
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w") as archive:
        for name, data in sorted(files.items()):
            entry = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            entry.create_system = 3
            entry.external_attr = 0o100644 << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, data)


def verify_workflow(root: Path, archive_path: Path) -> None:
    """Reject missing, extra, duplicate, or stale archive contents."""
    expected = workflow_files(root)
    with zipfile.ZipFile(archive_path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or set(names) != set(expected):
            raise ValueError("Archive entries do not match workflow metadata and assets")
        for name, content in expected.items():
            if archive.read(name) != content:
                raise ValueError(f"Packaged {name} does not match the current source")


def main() -> None:
    """Build a workflow or verify an existing package against the source tree."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", type=Path, metavar="ARCHIVE")
    args = parser.parse_args()
    if args.check:
        verify_workflow(ROOT, args.check)
        print(f"Verified {args.check}")
    else:
        build_workflow(ROOT, args.output)
        verify_workflow(ROOT, args.output)
        print(f"Built and verified {args.output}")


if __name__ == "__main__":
    main()
