import Foundation
import Combine
import SwiftUI

// MARK: - Enums

enum AttendancePeriod: String, Codable, CaseIterable {
    case morning
    case afternoon

    var displayName: String {
        switch self {
        case .morning: return Localization.shared.t("periodMorning")
        case .afternoon: return Localization.shared.t("periodAfternoon")
        }
    }

    var symbol: String {
        switch self {
        case .morning: return "sun.max"
        case .afternoon: return "moon"
        }
    }
}

enum AttendanceStatus: String, Codable, CaseIterable {
    case work
    case overtime
    case leave
    case rest
    case other

    var displayName: String {
        switch self {
        case .work: return Localization.shared.t("statusWork")
        case .overtime: return Localization.shared.t("statusOvertime")
        case .leave: return Localization.shared.t("statusLeave")
        case .rest: return Localization.shared.t("statusRest")
        case .other: return Localization.shared.t("statusOther")
        }
    }

    var symbol: String {
        switch self {
        case .work: return "checkmark.circle.fill"
        case .overtime: return "clock.badge.checkmark.fill"
        case .leave: return "person.crop.circle.badge.exclamationmark"
        case .rest: return "cup.and.saucer.fill"
        case .other: return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .work: return .blue
        case .overtime: return .purple
        case .leave: return .orange
        case .rest: return .gray
        case .other: return .yellow
        }
    }
}

// MARK: - Record

struct AttendanceRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var recordDate: Date      // 归一化到当天 00:00:00
    var period: AttendancePeriod
    var status: AttendanceStatus
    var note: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         recordDate: Date,
         period: AttendancePeriod,
         status: AttendanceStatus,
         note: String = "",
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.recordDate = Self.normalize(recordDate)
        self.period = period
        self.status = status
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    static func normalize(_ date: Date, calendar: Calendar = .current) -> Date {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(from: comps) ?? date
    }
}

// MARK: - Store

final class AttendanceStore: ObservableObject {
    @Published var records: [AttendanceRecord] = [] {
        didSet { save() }
    }

    private let key = "PayTick.attendanceRecords.v1"

    init() {
        load()
    }

    // MARK: 持久化

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([AttendanceRecord].self, from: data) else { return }
        records = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: CRUD

    /// Upsert: 同一天同一时段只保留一条
    func upsert(date: Date, period: AttendancePeriod, status: AttendanceStatus, note: String) {
        let normalized = AttendanceRecord.normalize(date)
        if let idx = records.firstIndex(where: {
            $0.recordDate == normalized && $0.period == period
        }) {
            records[idx].status = status
            records[idx].note = note
            records[idx].updatedAt = Date()
        } else {
            records.append(AttendanceRecord(
                recordDate: normalized,
                period: period,
                status: status,
                note: note
            ))
        }
    }

    func delete(id: UUID) {
        records.removeAll { $0.id == id }
    }

    // MARK: 查询

    func recordsFor(year: Int, month: Int) -> [AttendanceRecord] {
        let calendar = Calendar.current
        return records.filter { record in
            let comps = calendar.dateComponents([.year, .month], from: record.recordDate)
            return comps.year == year && comps.month == month
        }.sorted { lhs, rhs in
            if lhs.recordDate != rhs.recordDate {
                return lhs.recordDate < rhs.recordDate
            }
            return lhs.period.rawValue < rhs.period.rawValue
        }
    }

    func recordsFor(date: Date) -> [AttendanceRecord] {
        let normalized = AttendanceRecord.normalize(date)
        return records.filter { $0.recordDate == normalized }
    }

    /// 月度统计：按 status 分组计数
    func statsFor(year: Int, month: Int) -> [AttendanceStatus: Int] {
        let monthRecords = recordsFor(year: year, month: month)
        var counts: [AttendanceStatus: Int] = [:]
        for r in monthRecords {
            counts[r.status, default: 0] += 1
        }
        return counts
    }

    // MARK: 导入 attendance MySQL JSON

    /// 兼容 attendance 项目 MySQL 导出的 JSON 格式
    /// 字段名 snake_case: record_date(YYYY-MM-DD), period, status, note, created_at, updated_at
    /// 注意：record_date 是无时区的纯日历日期，直接按 year/month/day 组件解析，
    /// 不走 DateFormatter 避免 UTC 偏移导致日期错位（例如西半球会把 6-24 解析成 6-23）。
    func importFromAttendanceJSON(_ data: Data) throws -> Int {
        struct ImportedRecord: Decodable {
            let record_date: String
            let period: String
            let status: String
            let note: String?
            let created_at: String?
            let updated_at: String?
        }

        let decoder = JSONDecoder()
        let imported: [ImportedRecord] = try decoder.decode([ImportedRecord].self, from: data)

        let calendar = Calendar.current
        let tsFormatter = DateFormatter()
        tsFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        tsFormatter.locale = Locale(identifier: "en_US_POSIX")
        tsFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        var importedCount = 0
        for r in imported {
            // 解析 YYYY-MM-DD → 直接拆组件，不用时区
            let parts = r.record_date.split(separator: "-")
            guard parts.count == 3,
                  let year = Int(parts[0]),
                  let month = Int(parts[1]),
                  let day = Int(parts[2]) else { continue }
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = day
            guard let date = calendar.date(from: comps) else { continue }
            guard let period = AttendancePeriod(rawValue: r.period),
                  let status = AttendanceStatus(rawValue: r.status) else { continue }
            let noteText = r.note ?? ""
            let createdAt = r.created_at.flatMap { tsFormatter.date(from: $0) } ?? Date()
            let updatedAt = r.updated_at.flatMap { tsFormatter.date(from: $0) } ?? Date()
            upsert(date: date, period: period, status: status, note: noteText)
            // 还原原始时间戳
            if let idx = records.firstIndex(where: {
                $0.recordDate == AttendanceRecord.normalize(date) && $0.period == period
            }) {
                records[idx].createdAt = createdAt
                records[idx].updatedAt = updatedAt
            }
            importedCount += 1
        }
        return importedCount
    }

    // MARK: 导出 Excel (.xlsx)

    /// 导出某月考勤为 .xlsx 文件，100% 复刻原 PHP 项目样式
    /// - Parameters:
    ///   - year: 年份（如 2026）
    ///   - month: 月份（1-12）
    ///   - url: 目标文件 URL（NSSavePanel 由调用方传入）
    /// - Returns: 成功与否
    func exportXLSX(year: Int, month: Int, to url: URL) -> Bool {
        let cal = Calendar.current
        var startComps = DateComponents()
        startComps.year = year
        startComps.month = month
        startComps.day = 1
        guard let start = cal.date(from: startComps),
              let range = cal.range(of: .day, in: .month, for: start) else { return false }
        var endComps = startComps
        endComps.day = range.count
        guard let end = cal.date(from: endComps) else { return false }

        let title = String(format: "%04d-%02d 考勤记录", year, month)
        let monthRecords = recordsFor(year: year, month: month)
        return XLSXExporter.export(records: monthRecords, rangeStart: start, rangeEnd: end,
                                    title: title, to: url)
    }

    /// 导出某年考勤为 .xlsx 文件
    /// - Parameters:
    ///   - year: 年份
    ///   - url: 目标文件 URL
    /// - Returns: 成功与否
    func exportXLSX(year: Int, to url: URL) -> Bool {
        let cal = Calendar.current
        var startComps = DateComponents()
        startComps.year = year
        startComps.month = 1
        startComps.day = 1
        var endComps = DateComponents()
        endComps.year = year
        endComps.month = 12
        endComps.day = 31
        guard let start = cal.date(from: startComps),
              let end = cal.date(from: endComps) else { return false }

        let title = "\(year) 年度考勤记录"
        let yearRecords = records.filter {
            cal.component(.year, from: $0.recordDate) == year
        }
        return XLSXExporter.export(records: yearRecords, rangeStart: start, rangeEnd: end,
                                    title: title, to: url)
    }
}
