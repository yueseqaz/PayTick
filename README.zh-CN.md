# PayTick 💴

一个 macOS 菜单栏应用，实时显示你今天已经赚了多少钱——看着薪水一秒一秒往上涨，还有下班前提醒。

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

[English](README.md) · **简体中文**

## 功能特性

- **实时金额刷新**——菜单栏每秒更新今日已赚金额
- **两行 H/M 倒计时**——紧凑展示距离下班还有多少小时多少分钟
- **可自定义工时**——上午 / 下午的上下班时间各自独立设置
- **日薪 + 自动时薪**——填日薪，时薪按工时自动算出
- **下班提醒**——下班前 N 分钟系统通知 + 菜单栏金额变橙色（提醒分钟数 1–60 可调）
- **加班模式**——开启后周末也累计工资；关闭则周六日显示"周末休息"
- **周末感知**——周末不会假显示工资
- **纯菜单栏**——不占 Dock 图标（LSUIElement），干净不打扰

## 安装

### Homebrew

cask 源文件在 [`Casks/paytick.rb`](Casks/paytick.rb)。等 v1.0.0 GitHub release（附带 `PayTick-1.0.0.dmg`）发布后：

```bash
brew install --cask https://raw.githubusercontent.com/yueseqaz/PayTick/main/Casks/paytick.rb
```

新版本发布后升级：

```bash
brew uninstall --cask paytick
brew install --cask https://raw.githubusercontent.com/yueseqaz/PayTick/main/Casks/paytick.rb
```

> cask 的 `sha256` 字段每次 release 后由 GitHub Actions 自动填回，见 [`Casks/paytick.rb`](Casks/paytick.rb)。

### 源码构建

需要 macOS 13+ 和 Swift Command Line Tools（无需 Xcode）。

```bash
git clone https://github.com/yueseqaz/PayTick.git
cd PayTick
./build.sh
open PayTick.app
```

`build.sh` 用 `swiftc` 编译所有 Swift 源文件，组装 `.app` bundle，开箱即用。永久安装把 `PayTick.app` 拖到 `/Applications` 即可。

## 配置

点击菜单栏图标 → **设置**（齿轮按钮）：

- 上午上班 / 下班时间
- 下午上班 / 下班时间
- 日薪（时薪自动算）
- 下班前多少分钟提醒（1–60）
- 加班模式（是否把周末算进去）
- 语言（English / 简体中文）

所有设置通过 `UserDefaults` 持久化，重启保留。

## 工作原理

PayTick 按 `日薪 / 总工作秒数` 计算每秒工资，其中 `总工作秒数 = (上午下班 - 上午上班) + (下午下班 - 下午上班)`，然后根据实际工作时段（不含午休）累计已赚金额。

菜单栏标签通过 `NSStatusBarButton.image` 渲染两行 H/M 倒计时（用 `NSImage.lockFocus()` 绘制），`attributedTitle` 渲染金额文字。进入下班提醒窗口时整组变橙。

## 技术栈

- Swift 6 + SwiftUI + AppKit
- `NSStatusItem` + `NSPopover`（没用 SwiftUI MenuBarExtra，是为了更灵活的变色控制）
- `UserNotifications` 框架发下班通知
- 纯 `swiftc` 命令行构建（无 Xcode 工程、无 SPM）
- 自实现 i18n 模块（运行时切换 EN / 简体中文，单例 ObservableObject + 字符串表）

## 项目结构

```
Sources/WorkClock/
  WorkClockApp.swift               # @main 入口，隐藏 Dock 图标
  AppDelegate.swift                # 状态项、弹窗、每秒定时器
  Localization.swift                # 中英文 i18n 单例 + 字符串表
  Models/
    WorkSchedule.swift             # 时间表模型 + UserDefaults 存储
    SalaryCalculator.swift         # 状态机 + 工资计算
  Managers/
    NotificationManager.swift      # 下班提醒（同日去重）
  Views/
    MainPanelView.swift            # 弹窗 UI（金额、进度、倒计时）
    SettingsPanelView.swift        # 工时 / 工资 / 提醒 / 语言设置
Resources/
  Info.plist                       # LSUIElement=true，bundle 元数据
Casks/
  paytick.rb                       # Homebrew cask
build.sh                           # swiftc 编译 + bundle 组装
```

## License

MIT——详见 [LICENSE](LICENSE)。
