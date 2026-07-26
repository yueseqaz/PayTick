import Foundation
import UserNotifications
import Combine

final class NotificationManager: ObservableObject {
    @Published var lastReminderDate: Date?
    private var authorized = false
    private let lastKey = "PayTick.lastReminderDate"

    init() {
        if let data = UserDefaults.standard.data(forKey: lastKey),
           let date = try? JSONDecoder().decode(Date.self, from: data) {
            lastReminderDate = date
        }
        // 检查已有授权状态
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            self.authorized = (settings.authorizationStatus == .authorized)
        }
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            self.authorized = granted
        }
    }

    /// 检查并触发下班提醒（同一天最多触发一次）
    func checkAndFire(calculator: SalaryCalculator, schedule: WorkSchedule) {
        guard calculator.isInReminderWindow else { return }
        let calendar = Calendar.current
        if let last = lastReminderDate, calendar.isDateInToday(last) {
            return
        }
        guard authorized else {
            requestAuthorization()
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "快下班了 ⏰"
        let totalSecs = Int(calculator.secondsUntilOff.rounded())
        let minutes = totalSecs / 60
        let seconds = totalSecs % 60
        if minutes > 0 {
            content.body = "还有 \(minutes) 分 \(seconds) 秒下班，准备收拾东西吧～"
        } else {
            content.body = "还有 \(seconds) 秒就下班啦，准备冲！"
        }
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "workclock.offreminder",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { _ in }
        let now = Date()
        lastReminderDate = now
        if let data = try? JSONEncoder().encode(now) {
            UserDefaults.standard.set(data, forKey: lastKey)
        }
        DispatchQueue.main.async {
            self.lastReminderDate = now
        }
    }
}
