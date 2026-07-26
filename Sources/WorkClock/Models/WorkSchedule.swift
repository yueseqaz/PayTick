import Foundation
import Combine

/// 工作时间表（用分钟数表示一天内的时间点，0..<24*60）
struct WorkSchedule: Codable, Equatable {
    var morningStartMin: Int = 9 * 60      // 9:00
    var morningEndMin: Int = 12 * 60       // 12:00
    var afternoonStartMin: Int = 13 * 60  // 13:00
    var afternoonEndMin: Int = 18 * 60     // 18:00
    var dailySalary: Double = 300
    var reminderMinutes: Int = 5
    var overtimeMode: Bool = false         // 加班模式：周末也计算

    /// 把"分钟数"投影到指定日期的具体 Date（时分秒=0）
    func dateForMinute(_ minuteOfDay: Int, on day: Date, calendar: Calendar) -> Date {
        let hour = minuteOfDay / 60
        let minute = minuteOfDay % 60
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? day
    }

    var isValidSchedule: Bool {
        morningStartMin < morningEndMin &&
        afternoonStartMin < afternoonEndMin &&
        morningEndMin <= afternoonStartMin
    }
}

final class ScheduleStore: ObservableObject {
    @Published var schedule: WorkSchedule {
        didSet { save() }
    }

    private let key = "PayTick.schedule.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(WorkSchedule.self, from: data) {
            schedule = decoded
        } else {
            schedule = WorkSchedule()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(schedule) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
