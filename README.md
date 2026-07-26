# PayTick 💴

A macOS menu bar app that ticks your earnings in real time — watch your salary grow second by second, with end-of-day reminders.

**English** · [简体中文](README.zh-CN.md)

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Features

- **Live earnings ticker** — menu bar updates every second with the amount you've earned today
- **Two-line H/M countdown** — compact indicator shows hours and minutes left until clock-out
- **Custom work hours** — set morning start/end and afternoon start/end independently
- **Daily salary + auto hourly rate** — enter your daily wage, hourly rate is computed automatically
- **Clock-out reminder** — system notification + orange accent N minutes before end of shift (configurable 1–60 min)
- **Overtime mode** — toggle to count weekends; otherwise Sat/Sun show "周末休息"
- **Weekend-aware** — no fake earnings on weekends
- **Menu bar only** — no Dock icon (LSUIElement), clean and unobtrusive

## Installation

### Homebrew

The cask source lives in [`Casks/paytick.rb`](Casks/paytick.rb). Once the v1.0.0 GitHub release (with `PayTick-1.0.0.dmg` attached) is published:

```bash
brew install --cask https://raw.githubusercontent.com/yueseqaz/PayTick/main/Casks/paytick.rb
```

To upgrade after a new release:

```bash
brew uninstall --cask paytick
brew install --cask https://raw.githubusercontent.com/yueseqaz/PayTick/main/Casks/paytick.rb
```

> The cask's `sha256` must be updated to match each release's DMG. See [`Casks/paytick.rb`](Casks/paytick.rb).

### Build from source

Requires macOS 13+ and Swift Command Line Tools (no Xcode needed).

```bash
git clone https://github.com/yueseqaz/PayTick.git
cd PayTick
./build.sh
open PayTick.app
```

The build script compiles all Swift sources with `swiftc`, assembles the `.app` bundle, and is ready to run. To install permanently, drag `PayTick.app` to `/Applications`.

## Configuration

Click the menu bar item → **Settings** (gear icon):

- Morning start / end time
- Afternoon start / end time
- Daily salary (hourly rate auto-computed)
- Reminder minutes before clock-out (1–60)
- Overtime mode (count weekends or not)

All settings persist across launches via `UserDefaults`.

## How it works

PayTick computes your per-second wage as `daily_salary / total_work_seconds`, where `total_work_seconds = (morning_end − morning_start) + (afternoon_end − afternoon_start)`. It then accumulates earnings based on the actual time elapsed within work segments (lunch break excluded).

The menu bar label is rendered with `NSStatusBarButton.image` for the compact two-line H/M countdown (drawn into an `NSImage` via `lockFocus()`) and `attributedTitle` for the amount text. The countdown turns orange when entering the reminder window.

## Tech stack

- Swift 6 + SwiftUI + AppKit
- `NSStatusItem` + `NSPopover` (no SwiftUI MenuBarExtra — for finer color control)
- `UserNotifications` framework for clock-out alerts
- Pure `swiftc` CLI build (no Xcode project, no SPM)

## Project structure

```
Sources/WorkClock/
  WorkClockApp.swift              # @main entry, hides Dock icon
  AppDelegate.swift               # status item, popover, per-second timer
  Models/
    WorkSchedule.swift            # schedule model + UserDefaults store
    SalaryCalculator.swift       # state machine + earnings math
  Managers/
    NotificationManager.swift    # deduplicated clock-out reminders
  Views/
    MainPanelView.swift          # popover UI (earnings, progress, countdown)
    SettingsPanelView.swift      # work hours / salary / reminder config
Resources/
  Info.plist                     # LSUIElement=true, bundle metadata
build.sh                         # swiftc compile + bundle assembly
```

## License

MIT — see [LICENSE](LICENSE).
