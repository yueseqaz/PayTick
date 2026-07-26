import Foundation
import Combine

enum WorkState: Equatable {
    case beforeWork      // 上午上班前
    case morning        // 上午工作中
    case lunchBreak     // 午休
    case afternoon      // 下午工作中
    case afterWork      // 下班后
    case weekendOff     // 周末不工作（加班模式关闭时）
}

final class SalaryCalculator: ObservableObject {
    @Published var earnedToday: Double = 0
    @Published var workedSeconds: TimeInterval = 0
    @Published var totalSeconds: TimeInterval = 0
    @Published var isInReminderWindow: Bool = false
    @Published var secondsUntilOff: TimeInterval = 0
    @Published var state: WorkState = .beforeWork
    @Published var perSecondRate: Double = 0

    /// 根据当前时间和时间表重新计算所有状态
    func recompute(now: Date, schedule: WorkSchedule) {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        // 周日=1，周六=7
        let isWeekend = (weekday == 1 || weekday == 7)

        if isWeekend && !schedule.overtimeMode {
            state = .weekendOff
            earnedToday = 0
            workedSeconds = 0
            totalSeconds = 0
            isInReminderWindow = false
            secondsUntilOff = 0
            perSecondRate = 0
            return
        }

        let morningStart = schedule.dateForMinute(schedule.morningStartMin, on: now, calendar: calendar)
        let morningEnd = schedule.dateForMinute(schedule.morningEndMin, on: now, calendar: calendar)
        let afternoonStart = schedule.dateForMinute(schedule.afternoonStartMin, on: now, calendar: calendar)
        let afternoonEnd = schedule.dateForMinute(schedule.afternoonEndMin, on: now, calendar: calendar)

        let morningDuration = morningEnd.timeIntervalSince(morningStart)
        let afternoonDuration = afternoonEnd.timeIntervalSince(afternoonStart)
        let total = morningDuration + afternoonDuration
        totalSeconds = total
        perSecondRate = total > 0 ? schedule.dailySalary / total : 0

        let worked: TimeInterval
        if now < morningStart {
            state = .beforeWork
            worked = 0
        } else if now < morningEnd {
            state = .morning
            worked = now.timeIntervalSince(morningStart)
        } else if now < afternoonStart {
            state = .lunchBreak
            worked = morningDuration
        } else if now < afternoonEnd {
            state = .afternoon
            worked = morningDuration + now.timeIntervalSince(afternoonStart)
        } else {
            state = .afterWork
            worked = total
        }
        workedSeconds = worked
        earnedToday = perSecondRate * worked

        let reminderSecs = TimeInterval(schedule.reminderMinutes * 60)
        switch state {
        case .afternoon:
            secondsUntilOff = afternoonEnd.timeIntervalSince(now)
            isInReminderWindow = secondsUntilOff <= reminderSecs && secondsUntilOff > 0
        case .afterWork:
            secondsUntilOff = 0
            isInReminderWindow = false
        default:
            secondsUntilOff = afternoonEnd.timeIntervalSince(now)
            isInReminderWindow = false
        }
    }
}
