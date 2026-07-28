# PayTick 💴

A macOS menu bar app that ticks your earnings in real time — watch your salary grow second by second, with end-of-day reminders.

**English** · [简体中文](README.zh-CN.md)

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Features

### Live salary tracking (menu bar)

- **State-aware menu bar** — outside work hours the bar shows an icon + status text instead of numbers: "还未上班" before morning start (sun icon), "已下班" after afternoon end (checkmark icon), "周末休息" on weekends (coffee icon). During work periods (morning / lunch break / afternoon) it switches to the two-line H/M countdown + earned amount.
- **Live earnings ticker** — during work periods the menu bar updates every second with the amount you've earned today
- **Two-line H/M countdown** — compact image rendered into an `NSImage` shows hours and minutes left until clock-out
- **Custom work hours** — set morning start/end and afternoon start/end independently
- **Daily salary + auto hourly rate** — enter your daily wage, hourly rate is computed automatically
- **Clock-out reminder** — system notification + orange accent N minutes before end of shift (configurable 1–60 min)
- **Overtime mode** — toggle to count weekends; otherwise Sat/Sun show "周末休息"
- **Menu bar only** — no Dock icon (LSUIElement), clean and unobtrusive
- **Bilingual UI** — runtime switch between English / 简体中文, persisted across launches

### Attendance module (independent of MySQL)

A standalone replication of a PHP+MySQL attendance-tracking web app, built natively into PayTick. No database connection — all data persists in `UserDefaults`.

- **Manual clock-in** — pick morning/afternoon status + note for any day via a day-editor sheet
- **5 attendance statuses** — work / overtime / leave / rest / other (each with SF Symbol + color)
- **Monthly calendar grid** — 7×6 stable layout with today highlight and prev/next month navigation
- **Weekend auto-rest** — Saturday/Sunday cells with no record automatically display "休息"; if you mark a weekend day as overtime, that overrides
- **Stats bar** — per-status counts + total record count for the displayed month
- **Excel export (.xlsx)** — true OOXML generated in pure Swift (no third-party libraries), 100% matching the reference PHP project's PhpSpreadsheet output: title merge, blue header, per-status cell colors (work=#C6EFCE / overtime=#FCE4D6 / leave=#B4C6E7 / rest=#E5E7EB / other=#FFEB9C), merged weekend cells ("周末休息"), bottom stats summary with "X 班" shift counts (half-day count / 2), proper column widths and thin borders
- **Three export modes** — "本月" (this month) / "本年" (this year) / "指定日期" (custom date range via DatePicker sheet)
- **JSON import** — one-time data migration from MySQL export (snake_case schema: `record_date` / `period` / `status` / `note` / `created_at` / `updated_at`)

## Installation

### Homebrew

Tap the repo once, then install:

```bash
brew tap yueseqaz/paytick https://github.com/yueseqaz/PayTick.git
brew install --cask paytick
```

To upgrade after a new release:

```bash
brew upgrade --cask paytick
```

The cask's `version` and `sha256` are auto-updated by GitHub Actions on every `v*` tag push. See [`Casks/paytick.rb`](Casks/paytick.rb) and [`.github/workflows/release.yml`](.github/workflows/release.yml).

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
- Real .xlsx output via hand-written OOXML + `/usr/bin/zip -X` (no PhpSpreadsheet, no third-party Swift packages)

## Project structure

```
Sources/WorkClock/
  WorkClockApp.swift              # @main entry, hides Dock icon
  AppDelegate.swift              # status item, popover, per-second timer, opens attendance + settings windows
  Localization.swift             # custom i18n singleton (EN / zh-Hans) with runtime switch
  Models/
    WorkSchedule.swift           # schedule model + UserDefaults store
    SalaryCalculator.swift       # state machine (beforeWork/morning/lunchBreak/afternoon/afterWork/weekendOff) + earnings math
    Attendance.swift             # AttendanceRecord / AttendancePeriod / AttendanceStatus / AttendanceStore (UserDefaults)
    XLSXExporter.swift           # pure-Swift OOXML .xlsx generator (zip CLI package)
  Managers/
    NotificationManager.swift    # deduplicated clock-out reminders
  Views/
    MainPanelView.swift          # popover UI (earnings, progress, state badge, actions bar)
    SettingsPanelView.swift      # work hours / salary / reminder / language config
    AttendanceView.swift         # monthly calendar + day editor sheet + Excel export + JSON import
Resources/
  Info.plist                     # LSUIElement=true, bundle metadata
Casks/
  paytick.rb                     # Homebrew cask (auto-bumped by Actions on tag push)
build.sh                         # swiftc compile + bundle assembly
.github/workflows/
  release.yml                    # tag v* → build DMG → sha256 → bump cask → release
```

## License

MIT — see [LICENSE](LICENSE).
