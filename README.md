# CodexPet

[English](./README.md) | [简体中文](./README.zh-CN.md)

CodexPet is a macOS desktop pet that watches Codex APP for you.

It stays above your desktop, shows unread completed threads, reacts when any thread is running, and lets you jump back into Codex with one click.

## Screenshots

### Running state

![CodexPet running state](./hero.png)

The pet switches into a visible working state when Codex has active threads, while still keeping unread counters lightweight and ambient.

### Style panel

![CodexPet style panel](./styles.png)

You can switch the mascot, palette, and overall vibe from the built-in style panel.

## What it does

- Shows how many Codex threads have finished but are still unread
- Detects running threads and switches the pet into a working state
- Pops lightweight completion feedback when a task finishes
- Shows lightweight system stats in the bubble, including CPU usage and memory used/total
- Stays always-on-top so you do not have to keep checking Codex manually
- Supports multiple pet styles, palettes, and expressions
- Can be launched from Launchpad like a normal `.app`

## Recent changes

- Added a vision-based unread-dot fallback so unread counting can follow visible blue dots more closely when the latest Codex AX structure is not enough
- Tightened the foreground cleanup path so completion bonus badges do not linger after the active Codex thread has no unread marker
- Added a compact resource line in the bubble: CPU usage plus memory used/total
- Clarified the new permission model: unread detection is most accurate when `CodexPet.app` has both Accessibility and Screen Recording permission

## Why I built it

Codex is great at running work in the background, but the feedback loop is still window-bound: you usually need to switch back to the app to see whether something finished.

I wanted a calmer interface:

- if a thread is still running, the pet looks busy
- if a thread is done and unread, the count stays visible
- if everything is quiet, it gets out of the way

The goal is not to add another dashboard. The goal is to turn Codex thread state into ambient desktop feedback.

## How it works

CodexPet combines several local signals and merges them into one UI snapshot.

### 1. Accessibility inspection

It reads the Codex window through the macOS Accessibility API to inspect:

- unread blue-dot markers in the sidebar
- running spinners in the thread list
- the currently active thread

### 1.5. Visual unread fallback

When Codex's latest AX tree no longer exposes unread state clearly enough, CodexPet can also sample the actual sidebar pixels and count visible blue dots directly from the window image.

### 2. Local Codex state

It reads local Codex state files under `~/.codex` to improve running-thread detection when the UI alone is not enough.

### 3. Logs and direct events

It tails Codex-related logs and direct event sources to capture task completion and trigger pet reactions.

These signals are reconciled into a single status model, which then drives the pet bubble, counters, and animation state.

## Requirements

- macOS 13 or later
- Codex desktop app installed
- Accessibility permission granted to `CodexPet.app`
- Screen Recording permission granted to `CodexPet.app` for the most accurate unread blue-dot detection

Without Accessibility permission, CodexPet cannot reliably inspect the Codex sidebar.
Without Screen Recording permission, the new visual unread fallback cannot inspect visible blue dots and the app will fall back to AX-only heuristics.

## Grant permissions

CodexPet currently depends on two macOS permissions:

- `Accessibility`: required for sidebar inspection, running-thread detection, and active-thread tracking
- `Screen Recording`: required for the visual blue-dot fallback when Codex's AX tree is incomplete

Grant them like this:

1. Open `System Settings`
2. Go to `Privacy & Security`
3. Open `Accessibility`, then enable `CodexPet.app`
4. Open `Screen Recording`, then enable `CodexPet.app`
5. Fully quit and reopen `CodexPet.app`

If `CodexPet.app` does not appear in the list yet:

1. Launch `/Users/<your-user>/Applications/CodexPet.app` once
2. If needed, remove the old disabled entry and add the current app again
3. Reopen the permission page and enable it

Important:

- Replacing or reinstalling `CodexPet.app` can cause macOS to treat it as a new app for permissions
- If the top chip shows `AX Off`, re-check the `Accessibility` page
- If unread blue-dot counting becomes worse after an app update, re-check the `Screen Recording` page

## Scope

CodexPet is built specifically for the macOS Codex desktop app workflow.

It is not designed for:

- Codex CLI-only usage
- terminal-only workflows without the Codex desktop window
- non-macOS platforms

The current unread and running-state logic depends on the desktop app's sidebar and window structure, so the project should be understood as a macOS desktop companion, not a generic Codex monitor.

## Run locally

```bash
swift build
zsh Scripts/build-app.sh
open dist/CodexPet.app
```

Install into Launchpad:

```bash
zsh Scripts/install-to-launchpad.sh
```

## Project structure

```text
CodexPet/
├── AppBundle/       # App icon, bundle metadata
├── LaunchAgents/    # Optional launch-on-login support
├── Scripts/         # Build and installation scripts
├── Sources/         # SwiftUI app, monitors, state aggregation
├── Tests/           # Snapshot and detector tests
└── Package.swift
```

## Current focus

This project is optimized around one practical question: can a small always-on-top companion make Codex feel more alive and less interrupt-driven?

That means most of the implementation effort goes into:

- accurate unread detection
- stable running-state detection
- low-noise UI feedback
- a pet that feels expressive without becoming distracting

## Known limitations

- This project currently targets the macOS Codex desktop app only. It does not support Codex CLI as a primary integration surface.
- Detection depends partly on Codex UI structure, so large upstream UI changes may break parts of the monitor.
- Running-thread inference still combines multiple heuristics and may need recalibration across Codex versions.
- Blue-dot unread detection is most accurate only after Screen Recording permission is granted. Without it, the app falls back to less reliable AX-only unread inference.
- Reinstalling or replacing `CodexPet.app` may cause macOS Accessibility permission to reset. When that happens, the `AX` chip will turn `Off` and sidebar-based unread detection will stop being trustworthy until permission is granted again.
- The app is currently optimized around my own Codex workflow and desktop layout.

## Notes

This is an unofficial companion project for the Codex desktop workflow, not an official OpenAI app.
