import Foundation
import Combine

/// 智能提醒配置（每个提醒独立开关 + 独立触发时间）
struct ReminderConfig: Codable, Equatable {
    var morningStart: Bool = true
    var morningStartMin: Int = 9 * 60       // 09:00
    var preLunch: Bool = true
    var preLunchMin: Int = 11 * 60          // 11:00
    var lunchStart: Bool = true
    var lunchStartMin: Int = 12 * 60        // 12:00
    var afternoonStart: Bool = true
    var afternoonStartMin: Int = 13 * 60   // 13:00
    var afterWork: Bool = true
    var afterWorkMin: Int = 18 * 60         // 18:00
    var lateNight: Bool = true
    var lateNightMin: Int = 0              // 00:00

    enum CodingKeys: String, CodingKey {
        case morningStart, morningStartMin
        case preLunch, preLunchMin
        case lunchStart, lunchStartMin
        case afternoonStart, afternoonStartMin
        case afterWork, afterWorkMin
        case lateNight, lateNightMin
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        morningStart = try c.decodeIfPresent(Bool.self, forKey: .morningStart) ?? true
        morningStartMin = try c.decodeIfPresent(Int.self, forKey: .morningStartMin) ?? 9 * 60
        preLunch = try c.decodeIfPresent(Bool.self, forKey: .preLunch) ?? true
        preLunchMin = try c.decodeIfPresent(Int.self, forKey: .preLunchMin) ?? 11 * 60
        lunchStart = try c.decodeIfPresent(Bool.self, forKey: .lunchStart) ?? true
        lunchStartMin = try c.decodeIfPresent(Int.self, forKey: .lunchStartMin) ?? 12 * 60
        afternoonStart = try c.decodeIfPresent(Bool.self, forKey: .afternoonStart) ?? true
        afternoonStartMin = try c.decodeIfPresent(Int.self, forKey: .afternoonStartMin) ?? 13 * 60
        afterWork = try c.decodeIfPresent(Bool.self, forKey: .afterWork) ?? true
        afterWorkMin = try c.decodeIfPresent(Int.self, forKey: .afterWorkMin) ?? 18 * 60
        lateNight = try c.decodeIfPresent(Bool.self, forKey: .lateNight) ?? true
        lateNightMin = try c.decodeIfPresent(Int.self, forKey: .lateNightMin) ?? 0
    }
}

/// 工作时间表（用分钟数表示一天内的时间点，0..<24*60）
struct WorkSchedule: Codable, Equatable {
    var morningStartMin: Int = 9 * 60      // 9:00
    var morningEndMin: Int = 12 * 60       // 12:00
    var afternoonStartMin: Int = 13 * 60  // 13:00
    var afternoonEndMin: Int = 18 * 60     // 18:00
    var dailySalary: Double = 300
    var reminderMinutes: Int = 5
    var overtimeMode: Bool = false         // 加班模式：周末也计算
    var reminderConfig: ReminderConfig = ReminderConfig()

    enum CodingKeys: String, CodingKey {
        case morningStartMin, morningEndMin, afternoonStartMin, afternoonEndMin
        case dailySalary, reminderMinutes, overtimeMode, reminderConfig
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        morningStartMin = try c.decodeIfPresent(Int.self, forKey: .morningStartMin) ?? 9 * 60
        morningEndMin = try c.decodeIfPresent(Int.self, forKey: .morningEndMin) ?? 12 * 60
        afternoonStartMin = try c.decodeIfPresent(Int.self, forKey: .afternoonStartMin) ?? 13 * 60
        afternoonEndMin = try c.decodeIfPresent(Int.self, forKey: .afternoonEndMin) ?? 18 * 60
        dailySalary = try c.decodeIfPresent(Double.self, forKey: .dailySalary) ?? 300
        reminderMinutes = try c.decodeIfPresent(Int.self, forKey: .reminderMinutes) ?? 5
        overtimeMode = try c.decodeIfPresent(Bool.self, forKey: .overtimeMode) ?? false
        reminderConfig = try c.decodeIfPresent(ReminderConfig.self, forKey: .reminderConfig) ?? ReminderConfig()
    }

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
