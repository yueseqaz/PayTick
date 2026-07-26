import AppKit
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var refreshTimer: Timer?
    private var eventMonitor: Any?

    let store = ScheduleStore()
    let calculator = SalaryCalculator()
    let notifier = NotificationManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        notifier.requestAuthorization()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))
        statusItem.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])

        let mainView = MainPanelView()
            .environmentObject(store)
            .environmentObject(calculator)
            .environmentObject(notifier)
            .environmentObject(self)
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: mainView)
        popover.contentSize = NSSize(width: 360, height: 480)

        // 点击菜单栏外区域自动收起 popover
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.popover.isShown else { return }
            self.popover.performClose(nil)
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

    private func tick() {
        calculator.recompute(now: Date(), schedule: store.schedule)
        updateMenuBarTitle()
        notifier.checkAndFire(calculator: calculator, schedule: store.schedule)
    }

    private func updateMenuBarTitle() {
        let button = statusItem.button
        let amountStr = Self.currencyFormatter.string(from: NSNumber(value: calculator.earnedToday)) ?? "¥0.00"
        let isWarning = calculator.isInReminderWindow
        let isWeekend = (calculator.state == .weekendOff)

        // 图标位置：工作日显示两行 H/M 倒计时，周末显示茶杯图标
        if isWeekend {
            let icon = NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: "PayTick")
            icon?.isTemplate = true
            button?.image = icon
        } else {
            let secs = max(0, Int(calculator.secondsUntilOff))
            let hours = secs / 3600
            let minutes = (secs % 3600) / 60
            button?.image = makeCountdownImage(hours: hours, minutes: minutes, isWarning: isWarning)
        }
        button?.imagePosition = .imageLeft
        button?.imageScaling = .scaleProportionallyDown

        // 文字部分：金额或周末提示
        let menuFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
        let color: NSColor = isWarning ? .systemOrange : .labelColor
        let titleText: String
        if isWeekend {
            titleText = " 周末休息 "
        } else {
            titleText = " \(amountStr) "
        }
        button?.attributedTitle = NSAttributedString(string: titleText, attributes: [
            .font: menuFont,
            .foregroundColor: color
        ])
        button?.toolTip = "PayTick · 距下班 \(Int(calculator.secondsUntilOff/60)) 分钟"
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
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    func openSettings() {
        closePopover()
        if settingsWindow == nil {
            let view = SettingsPanelView()
                .environmentObject(store)
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: controller)
            window.title = "PayTick 设置"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
