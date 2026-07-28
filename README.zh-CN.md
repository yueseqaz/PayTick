# PayTick 💴

一个 macOS 菜单栏应用，实时显示你今天已经赚了多少钱——看着薪水一秒一秒往上涨，还有下班前提醒。

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

[English](README.md) · **简体中文**

## 功能特性

### 实时工资追踪（菜单栏）

- **状态感知菜单栏**——非工作时段菜单栏显示图标 + 状态文字而非数字：上班前显示"还未上班"（太阳图标），下班后显示"已下班"（勾选图标），周末显示"周末休息"（咖啡图标）。进入工作时段（上午 / 午休 / 下午）后切换为两行 H/M 倒计时 + 已赚金额。
- **实时金额刷新**——工作时段内菜单栏每秒更新今日已赚金额
- **两行 H/M 倒计时**——通过 `NSImage` 绘制的紧凑图片，展示距离下班还有多少小时多少分钟
- **可自定义工时**——上午上班 / 下班、下午上班 / 下班各自独立设置
- **日薪 + 自动时薪**——填日薪，时薪按工时自动算出
- **下班提醒**——下班前 N 分钟系统通知 + 菜单栏金额变橙色（提醒分钟数 1–60 可调）
- **加班模式**——开启后周末也累计工资；关闭则周六日显示"周末休息"
- **纯菜单栏**——不占 Dock 图标（LSUIElement），干净不打扰
- **双语 UI**——运行时切换 English / 简体中文，重启保留

### 考勤模块

原生考勤模块，内置于 PayTick。无需数据库连接，所有数据持久化在 `UserDefaults` 中。

- **手动打卡**——通过日期编辑面板选择上午 / 下午状态 + 备注
- **5 种考勤状态**——出勤 / 加班 / 请假 / 休息 / 其他（各有 SF Symbol + 颜色）
- **月历网格**——7×6 稳定布局，今日高亮，支持上 / 下月切换
- **周末自动休息**——周六 / 周日无记录时自动显示"休息"；若手动标为加班则覆盖
- **统计栏**——按状态统计条数 + 当月记录总数
- **Excel 导出（.xlsx）**——纯 Swift 手写 OOXML 生成（无第三方库）：标题合并、蓝色表头、按状态单元格颜色（出勤=#C6EFCE / 加班=#FCE4D6 / 请假=#B4C6E7 / 休息=#E5E7EB / 其他=#FFEB9C）、周末合并单元格（"周末休息"）、底部统计汇总"X 班"（半天数 / 2）、列宽与细边框
- **三种导出模式**——"本月" / "本年" / "指定日期"（通过 DatePicker 面板选择自定义日期范围）
- **JSON 导入**——从 MySQL 导出的一次性数据迁移（snake_case 字段：`record_date` / `period` / `status` / `note` / `created_at` / `updated_at`）

## 安装

### Homebrew

先 tap 仓库一次，然后安装：

```bash
brew tap yueseqaz/paytick https://github.com/yueseqaz/PayTick.git
brew install --cask paytick
```

新版本发布后升级：

```bash
brew upgrade --cask paytick
```

cask 的 `version` 和 `sha256` 由 GitHub Actions 在每次 push `v*` tag 时自动更新，见 [`Casks/paytick.rb`](Casks/paytick.rb) 和 [`.github/workflows/release.yml`](.github/workflows/release.yml)。

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

PayTick 按 `日薪 / 总工作秒数` 计算每秒工资，其中 `总工作秒数 = (上午下班 - 上午上班) + (下午下班 - 下午上班)`，然后根据实际工作时段（不含午休）累计已赚金额。状态机根据当前时间自动判断所处时段（上班前 / 上午 / 午休 / 下午 / 下班后 / 周末休息），非工作时段菜单栏只显示图标 + 状态文字，不显示金额。

菜单栏标签通过 `NSStatusBarButton.image` 渲染两行 H/M 倒计时（用 `NSImage.lockFocus()` 绘制），`attributedTitle` 渲染金额文字。进入下班提醒窗口时整组变橙。

## 技术栈

- Swift 6 + SwiftUI + AppKit
- `NSStatusItem` + `NSPopover`（没用 SwiftUI MenuBarExtra，是为了更灵活的变色控制）
- `UserNotifications` 框架发下班通知
- 纯 `swiftc` 命令行构建（无 Xcode 工程、无 SPM）
- 自实现 i18n 模块（运行时切换 EN / 简体中文，单例 ObservableObject + 字符串表）
- 真 .xlsx 输出：纯 Swift 手写 OOXML + `/usr/bin/zip -X` 打包（无第三方 Swift 包）

## 项目结构

```
Sources/WorkClock/
  WorkClockApp.swift               # @main 入口，隐藏 Dock 图标
  AppDelegate.swift                # 状态项、弹窗、每秒定时器、打开考勤 + 设置窗口
  Localization.swift                # 自实现 i18n 单例（EN / zh-Hans），运行时切换
  Models/
    WorkSchedule.swift             # 时间表模型 + UserDefaults 存储
    SalaryCalculator.swift         # 状态机（上班前/上午/午休/下午/下班后/周末休息）+ 工资计算
    Attendance.swift               # AttendanceRecord / AttendancePeriod / AttendanceStatus / AttendanceStore（UserDefaults）
    XLSXExporter.swift             # 纯 Swift OOXML .xlsx 生成器（zip CLI 打包）
  Managers/
    NotificationManager.swift      # 下班提醒（同日去重）
  Views/
    MainPanelView.swift            # 弹窗 UI（金额、进度、状态徽章、操作栏）
    SettingsPanelView.swift        # 工时 / 工资 / 提醒 / 语言设置
    AttendanceView.swift           # 月历 + 日期编辑面板 + Excel 导出 + JSON 导入
Resources/
  Info.plist                       # LSUIElement=true，bundle 元数据
Casks/
  paytick.rb                       # Homebrew cask（tag push 时 Actions 自动 bump）
build.sh                           # swiftc 编译 + bundle 组装
.github/workflows/
  release.yml                      # tag v* → build DMG → sha256 → bump cask → release
```

## License

MIT——详见 [LICENSE](LICENSE)。
