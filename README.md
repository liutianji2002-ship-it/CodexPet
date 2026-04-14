# CodexPet

CodexPet is a macOS desktop pet that watches Codex for you.

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
- Stays always-on-top so you do not have to keep checking Codex manually
- Supports multiple pet styles, palettes, and expressions
- Can be launched from Launchpad like a normal `.app`

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

### 2. Local Codex state

It reads local Codex state files under `~/.codex` to improve running-thread detection when the UI alone is not enough.

### 3. Logs and direct events

It tails Codex-related logs and direct event sources to capture task completion and trigger pet reactions.

These signals are reconciled into a single status model, which then drives the pet bubble, counters, and animation state.

## Requirements

- macOS 13 or later
- Codex desktop app installed
- Accessibility permission granted to `CodexPet.app`

Without Accessibility permission, CodexPet cannot reliably inspect the Codex sidebar.

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

- Detection depends partly on Codex UI structure, so large upstream UI changes may break parts of the monitor.
- Running-thread inference still combines multiple heuristics and may need recalibration across Codex versions.
- The app is currently optimized around my own Codex workflow and desktop layout.

## Notes

This is an unofficial companion project for the Codex desktop workflow, not an official OpenAI app.
