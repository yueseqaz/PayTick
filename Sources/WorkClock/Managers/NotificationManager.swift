import Foundation
import AppKit
import SwiftUI
import Combine

final class NotificationManager: ObservableObject {
    @Published var lastFireDates: [String: Date] = [:]
    private let key = "PayTick.smartReminders.v1"
    private var overlayWindow: NSWindow?
    private var sound: NSSound?

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            lastFireDates = decoded
        }
        // 从 bundle 加载自定义音效
        if let url = Bundle.main.url(forResource: "notif", withExtension: "mp3") {
            sound = NSSound(contentsOf: url, byReference: true)
        }
    }

    /// 每秒调用：检查全部 7 种智能提醒条件
    func checkAndFire(calculator: SalaryCalculator, schedule: WorkSchedule) {
        let cfg = schedule.reminderConfig
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)
        let minuteOfDay = hour * 60 + cal.component(.minute, from: now)
        let weekday = cal.component(.weekday, from: now)
        let isWeekend = (weekday == 1 || weekday == 7)
        if isWeekend && !schedule.overtimeMode { return }

        if cfg.morningStart && calculator.state == .morning {
            fireOnce(.morningStart, icon: "sun.max.fill",
                     title: L("notifMorningTitle"), body: L("notifMorningBody"))
        }
        if cfg.preLunch {
            let lunchStart = schedule.morningEndMin
            let remindBefore = cfg.preLunchMinutes
            if minuteOfDay >= lunchStart - remindBefore && minuteOfDay < lunchStart {
                fireOnce(.preLunch, icon: "fork.knife",
                         title: L("notifPreLunchTitle"), body: L("notifPreLunchBody", remindBefore))
            }
        }
        if cfg.lunchStart && calculator.state == .lunchBreak {
            fireOnce(.lunchStart, icon: "cup.and.saucer.fill",
                     title: L("notifLunchTitle"), body: L("notifLunchBody"))
        }
        if cfg.afternoonStart && calculator.state == .afternoon {
            fireOnce(.afternoonStart, icon: "flame.fill",
                     title: L("notifAfternoonTitle"), body: L("notifAfternoonBody"))
        }
        if cfg.clockOut && calculator.isInReminderWindow {
            fireOnce(.clockOut, icon: "clock.badge.checkmark.fill",
                     title: L("notifTitle"), body: L("notifBodyMinutes",
                     Int(calculator.secondsUntilOff/60),
                     Int(calculator.secondsUntilOff.truncatingRemainder(dividingBy: 60))))
        }
        if cfg.afterWork && calculator.state == .afterWork {
            fireOnce(.afterWork, icon: "party.popper.fill",
                     title: L("notifAfterWorkTitle"), body: L("notifAfterWorkBody"))
        }
        if cfg.lateNight && hour >= cfg.lateNightHour && hour < 6 {
            fireOnce(.lateNight, icon: "moon.zzz.fill",
                     title: L("notifLateNightTitle"), body: L("notifLateNightBody"))
        }
    }

    // MARK: - Test mode

    func testAllReminders() {
        let tests: [(ReminderType, String, String, String)] = [
            (.morningStart, "sun.max.fill", L("notifMorningTitle"), L("notifMorningBody")),
            (.preLunch, "fork.knife", L("notifPreLunchTitle"), L("notifPreLunchBody", 60)),
            (.lunchStart, "cup.and.saucer.fill", L("notifLunchTitle"), L("notifLunchBody")),
            (.afternoonStart, "flame.fill", L("notifAfternoonTitle"), L("notifAfternoonBody")),
            (.clockOut, "clock.badge.checkmark.fill", L("notifTitle"), L("notifBodyMinutes", 3, 45)),
            (.afterWork, "party.popper.fill", L("notifAfterWorkTitle"), L("notifAfterWorkBody")),
            (.lateNight, "moon.zzz.fill", L("notifLateNightTitle"), L("notifLateNightBody")),
        ]
        for (i, item) in tests.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 3.0) {
                print("[\(i+1)/\(tests.count)] \(item.0.rawValue)")
                self.playSound()
                self.showOverlay(icon: item.1, title: item.2, body: item.3)
            }
        }
    }

    // MARK: - Private

    private func fireOnce(_ type: ReminderType, icon: String, title: String, body: String) {
        let cal = Calendar.current
        if let last = lastFireDates[type.rawValue], cal.isDateInToday(last) { return }

        playSound()
        showOverlay(icon: icon, title: title, body: body)

        let now = Date()
        lastFireDates[type.rawValue] = now
        save()
        DispatchQueue.main.async {
            self.lastFireDates[type.rawValue] = now
        }
    }

    private func playSound() {
        sound?.currentTime = 0
        sound?.play()
    }

    private func showOverlay(icon: String, title: String, body: String) {
        if let existing = overlayWindow {
            existing.orderOut(nil)
            overlayWindow = nil
        }

        let view = VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            Text(title).font(.system(size: 17, weight: .heavy))
                .foregroundStyle(.white)
            Text(body).font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 280, height: 150)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.black.opacity(0.85))
        )

        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = .borderless
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isReleasedWhenClosed = false

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = NSRect(x: screen.midX - 140, y: screen.midY - 75, width: 280, height: 150)
        window.setFrame(frame, display: true)

        window.alphaValue = 0
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            window.animator().alphaValue = 1
        }, completionHandler: nil)

        overlayWindow = window

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let w = self?.overlayWindow, w === window else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.5
                w.animator().alphaValue = 0
            }, completionHandler: {
                w.orderOut(nil)
                if self?.overlayWindow === window {
                    self?.overlayWindow = nil
                }
            })
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(lastFireDates) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func L(_ key: String) -> String {
        Localization.shared.t(key)
    }
    private func L(_ key: String, _ args: CVarArg...) -> String {
        let template = Localization.shared.t(key)
        return String(format: template, arguments: args)
    }
}

enum ReminderType: String, CaseIterable {
    case morningStart, preLunch, lunchStart, afternoonStart, clockOut, afterWork, lateNight
}
