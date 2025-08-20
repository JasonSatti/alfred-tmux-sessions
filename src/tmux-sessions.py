#!/usr/bin/env python3
"""Alfred workflow script for listing and managing tmux sessions."""

import json
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from typing import Any, Dict, List, Optional

INVALID_SESSION_CHARS = {".", ":", " ", "\n", "\t"}
TMUX_FORMAT = "#{session_name}|#{session_windows}|#{session_created}|#{session_attached}|#{session_activity}"


@dataclass
class Session:
    """Represents a tmux session with its metadata.

    Attributes
    ----------
    name : str
        The unique identifier for the tmux session
    windows : int
        Number of windows in the session
    created_timestamp : int
        Unix timestamp when the session was created
    is_attached : bool
        Whether a client is currently attached to this session
    activity_timestamp : int
        Unix timestamp of the last activity in the session
    """

    name: str
    windows: int
    created_timestamp: int
    is_attached: bool
    activity_timestamp: int

    @property
    def status_emoji(self) -> str:
        """Get the visual status indicator for the session.

        Returns
        -------
        str
            Green circle emoji if attached, white circle if detached
        """
        return "🟢 attached" if self.is_attached else "⚪ detached"

    @property
    def created_ago(self) -> str:
        """Get human-readable time since session creation.

        Returns
        -------
        str
            Relative time string (e.g., '2d ago', '3h ago')
        """
        return format_time_ago(self.created_timestamp)

    @property
    def activity_ago(self) -> str:
        """Get human-readable time since last activity.

        Returns
        -------
        str
            Relative time string (e.g., '2d ago', '3h ago')
        """
        return format_time_ago(self.activity_timestamp)

    @property
    def subtitle(self) -> str:
        """Generate the Alfred subtitle with session metadata.

        Returns
        -------
        str
            Formatted string with status, window count, and timestamps
        """
        return f"{self.status_emoji} • {self.windows} windows • created {self.created_ago} • active {self.activity_ago}"

    def to_alfred_item(self) -> Dict[str, Any]:
        """Convert session to Alfred JSON item format.

        Returns
        -------
        Dict[str, Any]
            Alfred-compatible JSON structure with title, subtitle,
            argument, and modifier keys for actions
        """
        return {
            "title": self.name,
            "subtitle": self.subtitle,
            "arg": self.name,
            "mods": {
                "cmd": {
                    "subtitle": f"Delete session {self.name}",
                    "arg": f"delete:{self.name}",
                },
                "ctrl": {
                    "subtitle": (
                        f"Detach from session {self.name}"
                        if self.is_attached
                        else f"Session {self.name} already detached"
                    ),
                    "arg": f"detach:{self.name}",
                    "valid": self.is_attached,
                },
            },
        }


def format_time_ago(timestamp: int) -> str:
    """Convert Unix timestamp to human-readable relative time.

    Parameters
    ----------
    timestamp : int
        Unix timestamp to convert

    Returns
    -------
    str
        Human-readable time string (e.g., '2d ago', '3h ago', 'just now')
        Returns 'unknown' if timestamp is invalid
    """
    try:
        delta = datetime.now() - datetime.fromtimestamp(timestamp)

        if delta.days > 0:
            return f"{delta.days}d ago"

        hours = delta.seconds // 3600
        if hours > 0:
            return f"{hours}h ago"

        minutes = delta.seconds // 60
        if minutes > 0:
            return f"{minutes}m ago"

        return "just now"
    except (ValueError, OSError, OverflowError):
        return "unknown"


def parse_session_line(line: str) -> Optional[Session]:
    """Parse a tmux list-sessions output line into a Session object.

    Parameters
    ----------
    line : str
        Pipe-delimited line from tmux list-sessions output

    Returns
    -------
    Optional[Session]
        Session object if parsing succeeds, None otherwise
    """
    if not line:
        return None

    parts = line.split("|")
    if len(parts) < 5:
        return None

    try:
        return Session(
            name=parts[0],
            windows=int(parts[1]) if parts[1].isdigit() else 1,
            created_timestamp=int(parts[2]) if parts[2].isdigit() else 0,
            is_attached=parts[3] == "1",
            activity_timestamp=int(parts[4]) if parts[4].isdigit() else int(parts[2]),
        )
    except (ValueError, IndexError):
        return None


def get_tmux_sessions() -> List[Session]:
    """Fetch all tmux sessions from the system.

    Returns
    -------
    List[Session]
        List of all active tmux sessions

    Raises
    ------
    FileNotFoundError
        If tmux is not installed on the system
    """
    try:
        result = subprocess.run(
            ["tmux", "list-sessions", "-F", TMUX_FORMAT],
            capture_output=True,
            text=True,
            check=True,
            timeout=5,
        )

        if not result.stdout.strip():
            return []

        sessions = []
        for line in result.stdout.strip().split("\n"):
            session = parse_session_line(line)
            if session:
                sessions.append(session)

        return sessions
    except subprocess.CalledProcessError:
        return []
    except subprocess.TimeoutExpired:
        return []
    except FileNotFoundError:
        raise


def is_valid_session_name(name: str) -> bool:
    """Check if a session name follows tmux naming rules.

    Parameters
    ----------
    name : str
        Proposed session name to validate

    Returns
    -------
    bool
        True if name is valid for tmux, False otherwise
    """
    return bool(name) and not any(char in name for char in INVALID_SESSION_CHARS)


def create_session_prompt(query: str) -> Dict[str, Any]:
    """Create an Alfred item for creating a new session.

    Parameters
    ----------
    query : str
        The proposed session name from user input

    Returns
    -------
    Dict[str, Any]
        Alfred item offering to create session or showing validation error
    """
    if is_valid_session_name(query):
        return {
            "title": f'Create new session "{query}"',
            "subtitle": "Press Enter to create this tmux session",
            "arg": f"create:{query}",
            "icon": {"path": "icon.png"},
        }

    return {
        "title": f'Invalid session name "{query}"',
        "subtitle": "Session names cannot contain spaces, dots, or colons",
        "valid": False,
    }


def create_empty_state_prompt() -> Dict[str, Any]:
    """Create an Alfred item for when no sessions exist.

    Returns
    -------
    Dict[str, Any]
        Alfred item with instructions for creating first session
    """
    return {
        "title": "No tmux sessions found",
        "subtitle": "Start typing to create a new session",
        "valid": False,
    }


def filter_and_sort_sessions(sessions: List[Session], query: str) -> List[Session]:
    """Filter sessions by query and sort by attachment status and activity.

    Parameters
    ----------
    sessions : List[Session]
        All available tmux sessions
    query : str
        Search string to filter session names

    Returns
    -------
    List[Session]
        Filtered and sorted sessions (attached first, then by recent activity)
    """
    filtered = [s for s in sessions if not query or query.lower() in s.name.lower()]

    return sorted(
        filtered,
        key=lambda s: (not s.is_attached, -s.activity_timestamp, s.name.lower()),
    )


def main() -> None:
    """Main entry point for the Alfred workflow.

    Reads query from command line arguments, fetches tmux sessions,
    filters and sorts them, then outputs Alfred-compatible JSON.
    Handles various error cases gracefully with user-friendly messages.
    """
    query = sys.argv[1].strip() if len(sys.argv) > 1 else ""

    try:
        sessions = get_tmux_sessions()
        filtered_sessions = filter_and_sort_sessions(sessions, query)

        items: List[Dict[str, Any]] = [s.to_alfred_item() for s in filtered_sessions]

        if not items:
            if query:
                items = [create_session_prompt(query)]
            else:
                items = [create_empty_state_prompt()]

        print(json.dumps({"items": items}, ensure_ascii=False))

    except FileNotFoundError:
        print(
            json.dumps(
                {
                    "items": [
                        {
                            "title": "tmux not found",
                            "subtitle": "Install tmux: brew install tmux",
                            "valid": False,
                        }
                    ]
                },
                ensure_ascii=False,
            )
        )
    except Exception as e:
        print(
            json.dumps(
                {
                    "items": [
                        {
                            "title": "Unexpected error",
                            "subtitle": str(e),
                            "valid": False,
                        }
                    ]
                },
                ensure_ascii=False,
            )
        )


if __name__ == "__main__":
    main()
