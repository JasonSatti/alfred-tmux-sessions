from __future__ import annotations

import json
import subprocess
import sys
from unittest.mock import Mock

import pytest


def test_parses_session_metadata(sessions) -> None:
    session = sessions.parse_session_line("work|3|1700000000|1|1700000060")
    assert (session.name, session.windows, session.is_attached) == ("work", 3, True)
    assert session.created_timestamp == 1700000000
    assert session.activity_timestamp == 1700000060


@pytest.mark.parametrize("line", ["", "work|3|1700000000|1"])
def test_ignores_incomplete_records(sessions, line: str) -> None:
    assert sessions.parse_session_line(line) is None


def test_invalid_activity_falls_back_to_creation_time(sessions) -> None:
    session = sessions.parse_session_line("work|1|1700000000|0|not-a-number")
    assert session.activity_timestamp == 1700000000


def test_filters_case_insensitively_and_sorts_attached_first(sessions) -> None:
    rows = [
        sessions.Session("Work-z", 1, 100, False, 999),
        sessions.Session("work-b", 1, 100, True, 200),
        sessions.Session("work-a", 1, 100, True, 200),
        sessions.Session("work-old", 1, 100, True, 150),
        sessions.Session("unrelated", 1, 100, True, 300),
    ]
    assert [s.name for s in sessions.filter_and_sort_sessions(rows, "WORK")] == [
        "work-a", "work-b", "work-old", "Work-z",
    ]


@pytest.mark.parametrize("name", ["work", "work-feature_2", "work@2", "a" * 100])
def test_accepts_supported_session_names(sessions, name: str) -> None:
    assert sessions.is_valid_session_name(name)


@pytest.mark.parametrize(
    "name", ["", "a" * 101, "a.b", "a:b", "a b", "a\nb", "a\tb", "a'b", "a\\b"]
)
def test_rejects_invalid_session_names(sessions, name: str) -> None:
    assert not sessions.is_valid_session_name(name)
    assert sessions.create_session_prompt(name)["valid"] is False


@pytest.mark.parametrize("attached", [False, True])
def test_alfred_modifiers_target_the_selected_session(sessions, attached: bool) -> None:
    item = sessions.Session("work", 2, 1700000000, attached, 1700000000).to_alfred_item()
    assert item["arg"] == "work"
    assert item["mods"]["cmd"]["arg"] == "delete:work"
    assert item["mods"]["shift"]["arg"] == "attach-linked:work"
    assert item["mods"]["ctrl"]["arg"] == "detach:work"
    assert item["mods"]["ctrl"]["valid"] is attached


@pytest.mark.parametrize(
    "error", [subprocess.CalledProcessError(1, "tmux"), subprocess.TimeoutExpired("tmux", 5)]
)
def test_unavailable_server_returns_no_sessions(sessions, monkeypatch, error) -> None:
    monkeypatch.setattr(sessions.subprocess, "run", Mock(side_effect=error))
    assert sessions.get_tmux_sessions() == []


def test_tmux_output_ignores_malformed_lines(sessions, monkeypatch) -> None:
    run = Mock(return_value=subprocess.CompletedProcess([], 0, "work|1|100|0|200\ninvalid\n"))
    monkeypatch.setattr(sessions.subprocess, "run", run)
    assert [s.name for s in sessions.get_tmux_sessions()] == ["work"]
    assert run.call_args.kwargs["timeout"] == 5
    assert run.call_args.kwargs["check"] is True


@pytest.mark.parametrize(
    "query,output,title,arg,valid",
    [
        ("", "", "No tmux sessions found", None, False),
        (" new-work ", "", 'Create new session "new-work"', "create:new-work", True),
        ("bad.name", "", 'Invalid session name "bad.name"', None, False),
        ("WoRk", "work|1|100|0|200\n", "work", "work", True),
    ],
)
def test_cli_emits_expected_alfred_json(
    sessions, monkeypatch, capsys, query, output, title, arg, valid
) -> None:
    monkeypatch.setattr(sys, "argv", ["tmux-sessions.py", query])
    monkeypatch.setattr(
        sessions.subprocess, "run", Mock(return_value=subprocess.CompletedProcess([], 0, output))
    )
    sessions.main()
    items = json.loads(capsys.readouterr().out)["items"]
    assert len(items) == 1
    assert items[0]["title"] == title
    assert items[0].get("arg") == arg
    assert items[0].get("valid", True) is valid


def test_missing_tmux_is_an_alfred_error(sessions, monkeypatch, capsys) -> None:
    monkeypatch.setattr(sys, "argv", ["tmux-sessions.py"])
    monkeypatch.setattr(sessions.subprocess, "run", Mock(side_effect=FileNotFoundError()))
    sessions.main()
    item = json.loads(capsys.readouterr().out)["items"][0]
    assert item["title"] == "tmux not found"
    assert item["valid"] is False
