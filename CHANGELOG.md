# Changelog

All notable changes to Alfred Tmux Sessions will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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