import Foundation
import AppKit
import Combine

final class NotificationManager: ObservableObject {
    @Published var lastFireDates: [String: Date] = [:]
    private let key = "PayTick.smartReminders.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            lastFireDates = decoded
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

        // 周末且非加班模式：跳过所有提醒
        if isWeekend && !schedule.overtimeMode { return }

        // 1. 早安 — 进入上午工作时
        if cfg.morningStart && calculator.state == .morning {
            fireOnce(.morningStart, sound: "Glass")
        }

        // 2. 午休预告 — 午休前 N 分钟
        if cfg.preLunch {
            let lunchStart = schedule.morningEndMin
            let remindBefore = cfg.preLunchMinutes
            if minuteOfDay >= lunchStart - remindBefore && minuteOfDay < lunchStart {
                fireOnce(.preLunch, sound: "Ping")
            }
        }

        // 3. 午休开始 — 进入午休
        if cfg.lunchStart && calculator.state == .lunchBreak {
            fireOnce(.lunchStart, sound: "Pop")
        }

        // 4. 下午开始 — 进入下午工作
        if cfg.afternoonStart && calculator.state == .afternoon {
            fireOnce(.afternoonStart, sound: "Tink")
        }

        // 5. 快下班 — 下班前 N 分钟
        if cfg.clockOut && calculator.isInReminderWindow {
            fireOnce(.clockOut, sound: "Hero")
        }

        // 6. 下班了 — 进入下班后
        if cfg.afterWork && calculator.state == .afterWork {
            fireOnce(.afterWork, sound: "Submarine")
        }

        // 7. 晚安 — 凌晨后
        if cfg.lateNight && hour >= cfg.lateNightHour && hour < 6 {
            fireOnce(.lateNight, sound: "Basso")
        }
    }

    // MARK: - Private

    private func fireOnce(_ type: ReminderType, sound: String) {
        let cal = Calendar.current
        if let last = lastFireDates[type.rawValue], cal.isDateInToday(last) { return }

        NSSound(named: sound)?.play()

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
