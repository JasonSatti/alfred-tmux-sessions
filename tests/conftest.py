from __future__ import annotations

import importlib.util
from pathlib import Path
import sys

import pytest

ROOT = Path(__file__).resolve().parents[1]


def load_module(name: str, path: Path):
    """Load scripts with filenames that are not Python import identifiers."""
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def sessions():
    return load_module("tmux_sessions", ROOT / "src/tmux-sessions.py")


@pytest.fixture
def builder():
    return load_module("build_workflow", ROOT / "scripts/build_workflow.py")
