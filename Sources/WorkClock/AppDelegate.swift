import AppKit
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var attendanceWindow: NSWindow?
    private var refreshTimer: Timer?
    private var eventMonitor: Any?
    private var lastState: WorkState?
    private var lastAmountStr: String?

    let store = ScheduleStore()
    let calculator = SalaryCalculator()
    let notifier = NotificationManager()
    let attendanceStore = AttendanceStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        notifier.requestAuthorization()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))
        statusItem.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 480)

        // 点击菜单栏外区域自动收起 popover
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.popover.isShown else { return }
            self.closePopover()
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(refreshTimer!, forMode: .common)
        tick()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        refreshTimer?.invalidate()
    }

    // NSWindowDelegate: 窗口关闭时释放引用，减少内存
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === settingsWindow {
            settingsWindow = nil
        } else if window === attendanceWindow {
            attendanceWindow = nil
        }
    }

    private func tick() {
        calculator.recompute(now: Date(), schedule: store.schedule)
        notifier.checkAndFire(calculator: calculator, schedule: store.schedule)

        // 非工作时段：状态和金额不变时跳过菜单栏更新
        let amountStr = Self.currencyFormatter.string(from: NSNumber(value: calculator.earnedToday)) ?? "¥0.00"
        if calculator.state == lastState && amountStr == lastAmountStr {
            // 只检查状态是否需要切换（如从 beforeWork 进入 morning）
            return
        }
        lastState = calculator.state
        lastAmountStr = amountStr
        updateMenuBarTitle()
    }

    private func updateMenuBarTitle() {
        let button = statusItem.button
        let amountStr = Self.currencyFormatter.string(from: NSNumber(value: calculator.earnedToday)) ?? "¥0.00"
        let isWarning = calculator.isInReminderWindow

        let menuFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
        let textColor: NSColor = isWarning ? .systemOrange : .labelColor

        // 根据状态决定显示模式：非工作时段只显示图标+文字，工作时段才显示倒计时+金额
        switch calculator.state {
        case .weekendOff:
            applySymbolAndText(button: button, symbol: "cup.and.saucer",
                               text: Localization.shared.t("menuBarWeekendRest"),
                               font: menuFont, color: textColor)
        case .beforeWork:
            applySymbolAndText(button: button, symbol: "sun.max",
                               text: Localization.shared.t("menuBarBeforeWork"),
                               font: menuFont, color: textColor)
        case .afterWork:
            applySymbolAndText(button: button, symbol: "checkmark.circle.fill",
                               text: Localization.shared.t("menuBarAfterWork"),
                               font: menuFont, color: textColor)
        case .lunchBreak:
            // 午休时段：图标 + "午休中" + 上午已赚金额
            applySymbolAndText(button: button, symbol: "fork.knife",
                               text: "\(Localization.shared.t("menuBarLunchBreak"))\(amountStr) ",
                               font: menuFont, color: textColor)
        case .morning, .afternoon:
            // 工作时段：两行 H/M 倒计时 + 金额
            let secs = max(0, Int(calculator.secondsUntilOff))
            let hours = secs / 3600
            let minutes = (secs % 3600) / 60
            button?.image = autoreleasepool { makeCountdownImage(hours: hours, minutes: minutes, isWarning: isWarning) }
            button?.imagePosition = .imageLeft
            button?.imageScaling = .scaleProportionallyDown
            button?.attributedTitle = NSAttributedString(string: " \(amountStr) ", attributes: [
                .font: menuFont,
                .foregroundColor: textColor
            ])
        }
        button?.toolTip = (calculator.state == .morning || calculator.state == .afternoon)
            ? Localization.shared.t("toolTipUntilOff", Int(calculator.secondsUntilOff/60))
            : "PayTick"
    }

    /// 工具方法：用 SF Symbol 图标 + 文字标签设置菜单栏按钮（用于非工作时段）
    private func applySymbolAndText(button: NSStatusBarButton?, symbol: String, text: String,
                                     font: NSFont, color: NSColor) {
        let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: "PayTick")
        icon?.isTemplate = true
        button?.image = icon
        button?.imagePosition = .imageLeft
        button?.imageScaling = .scaleProportionallyDown
        button?.attributedTitle = NSAttributedString(string: " \(text) ", attributes: [
            .font: font,
            .foregroundColor: color
        ])
    }

    /// 绘制两行紧凑的倒计时图片：上行 "{hours}H"，下行 "{minutes}M"
    private func makeCountdownImage(hours: Int, minutes: Int, isWarning: Bool) -> NSImage {
        let width: CGFloat = 30
        let height: CGFloat = 22
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()

        let hStr = "\(hours)H"
        let mStr = "\(minutes)M"
        let font = NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .semibold)
        // 警告时绘制橙色，普通时黑色（isTemplate=true 后会被系统 label 色替换，颜色无所谓）
        let drawColor: NSColor = isWarning ? .systemOrange : .black
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: drawColor
        ]
        let hSize = (hStr as NSString).size(withAttributes: attrs)
        let mSize = (mStr as NSString).size(withAttributes: attrs)

        // H 在上
        let hX = (width - hSize.width) / 2
        let hY = height - hSize.height - 1
        (hStr as NSString).draw(at: NSPoint(x: hX, y: hY), withAttributes: attrs)
        // M 在下
        let mX = (width - mSize.width) / 2
        let mY: CGFloat = 1
        (mStr as NSString).draw(at: NSPoint(x: mX, y: mY), withAttributes: attrs)

        image.unlockFocus()
        // 普通状态用 template 跟随系统 label 色（明暗自适应），警告状态用绘制的橙色固定
        image.isTemplate = !isWarning
        return image
    }

    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover()
        } else if let button = statusItem.button {
            // 懒加载：仅打开时创建 SwiftUI 视图树
            let mainView = MainPanelView()
                .environmentObject(store)
                .environmentObject(calculator)
                .environmentObject(notifier)
                .environmentObject(self)
                .environmentObject(attendanceStore)
                .environmentObject(Localization.shared)
            popover.contentViewController = NSHostingController(rootView: mainView)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
        // 销毁视图树释放内存
        popover.contentViewController = nil
    }

    func openSettings() {
        closePopover()
        if settingsWindow == nil {
            let view = SettingsPanelView()
                .environmentObject(store)
                .environmentObject(Localization.shared)
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: controller)
            window.title = Localization.shared.t("settingsWindowTitle")
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = true
            window.delegate = self
            centerWindow(window, defaultSize: NSSize(width: 420, height: 520))
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openAttendance() {
        closePopover()
        if attendanceWindow == nil {
            let view = AttendanceView()
                .environmentObject(attendanceStore)
                .environmentObject(Localization.shared)
                .environmentObject(store)
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: controller)
            window.title = Localization.shared.t("attendanceWindowTitle")
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = true
            window.delegate = self
            centerWindow(window, defaultSize: NSSize(width: 760, height: 620))
            window.minSize = NSSize(width: 600, height: 520)
            attendanceWindow = window
        }
        attendanceWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 通用窗口居中工具：按默认尺寸 + 屏幕可视区域居中
    private func centerWindow(_ window: NSWindow, defaultSize: NSSize) {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let cx = screenFrame.midX - defaultSize.width / 2
        let cy = screenFrame.midY - defaultSize.height / 2
        window.setFrame(NSRect(x: cx, y: cy, width: defaultSize.width, height: defaultSize.height), display: true)
    }

    static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "CNY"
        f.currencySymbol = "¥"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    static let plainNumberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()
}
