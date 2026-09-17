#!/usr/bin/env python3
"""Compile AppleScript without running workflow actions or opening terminals."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def compile_script(source: Path, output: Path) -> None:
    """Compile a script with a timeout to catch unresolved app dialogs in CI."""
    subprocess.run(
        ["/usr/bin/osacompile", "-o", str(output), str(source)],
        check=True,
        timeout=60,
    )


def main() -> None:
    """Check the action script and optionally its delayed iTerm script."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--include-iterm", action="store_true")
    parser.add_argument("--source", type=Path, default=ROOT / "src/tmux-action.scpt")
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("AppleScript compilation requires macOS")

    with tempfile.TemporaryDirectory(prefix="alfred-compile-") as directory:
        temporary = Path(directory)
        compile_script(args.source, temporary / "action.scpt")
        if args.include_iterm:
            # The pending iTerm fix defers this string's compilation until runtime.
            match = re.search(
                r'set itermScript to "((?:\\.|[^"\\])*)"',
                args.source.read_text(encoding="utf-8"),
                re.DOTALL,
            )
            if match:
                inner = re.sub(r'\\(["\\])', r'\1', match.group(1))
                inner_source = temporary / "iterm.applescript"
                inner_source.write_text(inner, encoding="utf-8")
                compile_script(inner_source, temporary / "iterm.scpt")
    print("AppleScript compilation passed (no workflow actions executed)")


if __name__ == "__main__":
    main()
