# Changelog

## 2026-04-17

### Added

- Added a vision-based unread-dot fallback for the Codex sidebar, so `CodexPet` can count unread blue dots from the window image when AX structure alone is not enough.
- Added lightweight system resource stats in the bubble: CPU usage and memory used/total.
- Added test coverage for unread-dot vision detection, resource text formatting, and unread state cleanup behavior.

### Changed

- Switched unread counting to prefer visual blue-dot detection when screen capture is available, with AX kept as a fallback.
- Tightened the focused-thread completion bonus cleanup logic so the badge is cleared when Codex is frontmost and the active unread count is truly zero.
- Adjusted memory display to use a more intuitive macOS-style approximation:
  used memory now tracks `active + wired + compressed`, and total memory is shown in GiB-style units such as `16.0G`.

### Notes

- For the new visual unread fallback to work, `CodexPet.app` also needs macOS Screen Recording permission in addition to Accessibility permission.
