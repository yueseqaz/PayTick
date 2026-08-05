import Foundation
import UserNotifications
import Combine

final class NotificationManager: ObservableObject {
    @Published var lastFireDates: [String: Date] = [:]
    private var authorized = false
    private let key = "PayTick.smartReminders.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            lastFireDates = decoded
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            self.authorized = (settings.authorizationStatus == .authorized)
        }
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            self.authorized = granted
        }
    }

    /// 每秒调用：检查全部 7 种智能提醒条件
    func checkAndFire(calculator: SalaryCalculator, schedule: WorkSchedule) {
        let cfg = schedule.reminderConfig
        guard authorized else {
            requestAuthorization()
            return
        }

        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)
        let minuteOfDay = hour * 60 + cal.component(.minute, from: now)
        let weekday = cal.component(.weekday, from: now)
        let isWeekend = (weekday == 1 || weekday == 7)

        // 周末且非加班模式：跳过所有提醒
        if isWeekend && !schedule.overtimeMode { return }

        // 1. 早安 — 进入上午工作时
        if cfg.morningStart && calculator.state == .morning {
            fireOnce(.morningStart, title: l("notifMorningTitle"), body: l("notifMorningBody"))
        }

        // 2. 午休预告 — 午休前 N 分钟
        if cfg.preLunch {
            let lunchStart = schedule.morningEndMin  // 午休开始 = 上午结束
            let remindBefore = cfg.preLunchMinutes
            if minuteOfDay >= lunchStart - remindBefore && minuteOfDay < lunchStart {
                fireOnce(.preLunch, title: l("notifPreLunchTitle"),
                         body: l("notifPreLunchBody", remindBefore))
            }
        }

        // 3. 午休开始 — 进入午休
        if cfg.lunchStart && calculator.state == .lunchBreak {
            fireOnce(.lunchStart, title: l("notifLunchTitle"), body: l("notifLunchBody"))
        }

        // 4. 下午开始 — 进入下午工作
        if cfg.afternoonStart && calculator.state == .afternoon {
            // 避免和早安/午休同秒触发太多，延迟一拍自然由 dedup 控制
            fireOnce(.afternoonStart, title: l("notifAfternoonTitle"), body: l("notifAfternoonBody"))
        }

        // 5. 快下班 — 下班前 N 分钟（原有功能）
        if cfg.clockOut && calculator.isInReminderWindow {
            let totalSecs = Int(calculator.secondsUntilOff.rounded())
            let mins = totalSecs / 60
            let secs = totalSecs % 60
            if mins > 0 {
                fireOnce(.clockOut, title: l("notifTitle"),
                         body: l("notifBodyMinutes", mins, secs))
            } else {
                fireOnce(.clockOut, title: l("notifTitle"),
                         body: l("notifBodySeconds", secs))
            }
        }

        // 6. 下班了 — 进入下班后
        if cfg.afterWork && calculator.state == .afterWork {
            fireOnce(.afterWork, title: l("notifAfterWorkTitle"), body: l("notifAfterWorkBody"))
        }

        // 7. 晚安 — 凌晨后
        if cfg.lateNight && hour >= cfg.lateNightHour && hour < 6 {
            fireOnce(.lateNight, title: l("notifLateNightTitle"), body: l("notifLateNightBody"))
        }
    }

    // MARK: - Private

    private func fireOnce(_ type: ReminderType, title: String, body: String) {
        let cal = Calendar.current
        if let last = lastFireDates[type.rawValue], cal.isDateInToday(last) { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.3, repeats: false)
        let request = UNNotificationRequest(
            identifier: "paytick.\(type.rawValue)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { _ in }

        let now = Date()
        lastFireDates[type.rawValue] = now
        save()
        DispatchQueue.main.async {
            self.lastFireDates[type.rawValue] = now
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(lastFireDates) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func l(_ key: String) -> String {
        Localization.shared.t(key)
    }
    private func l(_ key: String, _ args: CVarArg...) -> String {
        let template = Localization.shared.t(key)
        return String(format: template, arguments: args)
    }
}

// MARK: - Reminder types

enum ReminderType: String, CaseIterable {
    case morningStart
    case preLunch
    case lunchStart
    case afternoonStart
    case clockOut
    case afterWork
    case lateNight
}
