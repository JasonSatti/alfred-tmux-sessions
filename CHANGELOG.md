# Changelog

All notable changes to Alfred Tmux Sessions will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.2.3] - 2026-04-27

### Fixed
- **Ghostty Duplicate Window** - Same cold-launch double-window issue as v2.2.2, but for Ghostty: `activate` created a default window and the cmd+n keystroke created a second. Now detects whether Ghostty is already running and reuses the auto-created window on cold launch.

## [2.2.2] - 2026-04-23

### Fixed
- **iTerm Duplicate Window** - Opening a session while iTerm was not running created two windows (one from `activate`, one from `create window`). Now detects whether iTerm is already running and reuses the auto-created window on cold launch.

## [2.2.1] - 2026-03-19

### Fixed
- **Shell Environment** - New sessions now detect and use the terminal's actual shell instead of defaulting to macOS `/bin/zsh`. Adds `default_shell` workflow variable as an optional override.
- **Linked Session Error Handling** - Removed unreachable duplicate session catch that would have attached to the wrong (base) session
- **Activity Timestamp Parsing** - Added missing guard for non-numeric activity timestamps to prevent sessions from being silently dropped

## [2.2.0] - 2025-12-18

### Added
- **Linked Sessions** - New SHIFT modifier creates grouped sessions with independent window navigation
  - Smart numbering system (`session@2`, `@3`, etc.) for linked session names
  - Perfect for multi-monitor setups and viewing different windows simultaneously
  - Each linked session shares the same content but can navigate independently

### Improved
- **Documentation** - Added comprehensive linked sessions guide with use cases
- **Session Naming** - Clean `@2` suffix convention recommended by Codex for clarity

## [2.1.0] - 2025-10-13

### Added
- **Focus Window Reuse** - Sessions now open in the currently focused terminal window instead of always creating new windows
- **Session Name Length Validation** - Maximum 100 character limit with clear error messages
- **Enhanced Character Validation** - Restricted single quotes and backslashes in session names

### Improved
- **Security** - Strengthened input validation prevents command injection vulnerabilities
- **Code Quality** - Added Python future annotations for better type compatibility
- **Error Messages** - More specific feedback for validation failures (length vs invalid characters)

### Fixed
- **Ghostty Logic** - Cleaned up redundant window creation checks

## [2.0.0] - 2025-08-20

### Added
- **Multi-Terminal Support** - Works with iTerm2, Ghostty, and Terminal.app
- **Auto-Detection** - Automatically finds your preferred terminal
- **Manual Configuration** - Override terminal selection in workflow settings
- **Enhanced Security** - Protection against command injection

### Improved
- **Session Creation** - New sessions start in home directory
- **Error Messages** - More helpful and specific error feedback
- **Session Sorting** - Deterministic ordering prevents UI flicker
- **Notifications** - Removed redundant success notifications (errors still shown)

### Fixed
- **Terminal Detection** - Fixed iTerm2 detection issues

### Changed
- **Requirements** - Now requires macOS 10.14+ and Alfred 4.0+
- **Documentation** - Complete setup guide with troubleshooting

## [1.0.0] - 2025-08-06

### Added
- Initial release with iTerm2 support
- Core tmux session management (list, create, attach, detach, delete)
- Rich status indicators with emoji
- Smart session sorting by attachment status and activity
- Input validation and error handling
- Alfred keyword interface with modifier key shortcuts

---

For more details about any release, see the [GitHub Releases](https://github.com/JasonSatti/alfred-tmux-sessions/releases) page.