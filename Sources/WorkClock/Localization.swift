import Foundation
import Combine

/// App 支持的语言
enum AppLanguage: String, Codable, CaseIterable {
    case english = "en"
    case chineseSimplified = "zh-Hans"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .chineseSimplified: return "简体中文"
        }
    }
}

/// 字符串表（按 key 查找翻译）
enum L10n {
    static let english: [String: String] = [
        "earnedToday": "Earned today",
        "dailySalaryWithWorked": "Daily %@ · Worked %d min",
        "progress": "Progress",
        "minutesUnit": "min",
        "minutesTotalFormat": "%d / %d min",
        "untilClockOut": "Until clock-out",
        "doneToday": "Done today",
        "weekendOff": "Weekend off",
        "notStartedYet": "Not started yet",
        "morningShift": "Morning shift",
        "lunchBreak": "Lunch break",
        "afternoonShift": "Afternoon shift",
        "reminderSentToday": "Reminder sent today",
        "overtime": "Overtime",
        "settings": "Settings",
        "quit": "Quit",
        "stateBeforeWork": "Before work",
        "stateMorning": "Morning",
        "stateLunchBreak": "Lunch",
        "stateAfternoon": "Afternoon",
        "stateAfterWork": "Done",
        "stateWeekendOff": "Weekend off",
        "morningSection": "Morning",
        "afternoonSection": "Afternoon",
        "startTime": "Start",
        "endTime": "End",
        "salarySection": "Salary",
        "dailySalary": "Daily wage",
        "hourlyRateAuto": "Hourly rate (auto)",
        "hourlyRateFormat": "¥%.2f/hr",
        "reminderSection": "Reminder",
        "remindMinutesBefore": "Remind %d min before clock-out",
        "reminderMethodNote": "Via system notification + orange amount in menu bar",
        "weekendSection": "Weekend",
        "overtimeMode": "Overtime mode",
        "overtimeDescription": "When enabled, weekends also count earnings and reminders.",
        "done": "Done",
        "languageSection": "Language",
        "menuBarWeekendRest": " Weekend off ",
        "menuBarBeforeWork": " Not started ",
        "menuBarAfterWork": " Done for today ",
        "menuBarLunchBreak": " On break ",
        "periodMorning": "Morning",
        "periodAfternoon": "Afternoon",
        "statusWork": "Work",
        "statusOvertime": "Overtime",
        "statusLeave": "Leave",
        "statusRest": "Rest",
        "statusOther": "Other",
        "attendanceWindowTitle": "Attendance",
        "attendanceStats": "Statistics",
        "attendanceCalendar": "Calendar",
        "attendanceExport": "Export CSV",
        "attendanceImport": "Import JSON",
        "attendanceDelete": "Delete",
        "attendanceNote": "Note",
        "attendanceSave": "Save",
        "attendanceClose": "Close",
        "attendanceToday": "Today",
        "attendancePrevMonth": "Previous month",
        "attendanceNextMonth": "Next month",
        "attendanceNoRecords": "No records",
        "attendanceImportSuccess": "Imported %d records",
        "attendanceImportError": "Import failed: %@",
        "attendanceConfirmDelete": "Delete this record?",
        "attendanceRecordsCount": "%d records",
        "attendanceEditorTitle": "Edit Attendance",
        "attendanceExportExcel": "Export Excel",
        "attendanceExportMonth": "This month",
        "attendanceExportYear": "This year",
        "statusWeekendRest": "Weekend rest",
        "monthlyEarnings": "This month",
        "monthlyWorkedDays": "Worked %d days",
        "attendanceExportCustom": "Custom date range",
        "attendanceExportStart": "Start date",
        "attendanceExportEnd": "End date",
        "attendanceExportConfirm": "Export",
        "settingsWindowTitle": "PayTick Settings",
        "toolTipUntilOff": "PayTick · %d min until clock-out",
        "notifTitle": "Almost off ⏰",
        "notifBodyMinutes": "%d min %d sec until clock-out — time to wrap up!",
        "notifBodySeconds": "%d sec until clock-out — go!"
    ]

    static let chineseSimplified: [String: String] = [
        "earnedToday": "今日已赚",
        "dailySalaryWithWorked": "日薪 %@ · 已工作 %d 分",
        "progress": "工作进度",
        "minutesUnit": "分钟",
        "minutesTotalFormat": "%d / %d 分钟",
        "untilClockOut": "距离下班",
        "doneToday": "今日完成",
        "weekendOff": "今日周末休息",
        "notStartedYet": "还没开始上班",
        "morningShift": "上午工作中",
        "lunchBreak": "午休中",
        "afternoonShift": "下午工作中",
        "reminderSentToday": "今日已发送下班提醒",
        "overtime": "加班",
        "settings": "设置",
        "quit": "退出",
        "stateBeforeWork": "未开始",
        "stateMorning": "上午",
        "stateLunchBreak": "午休",
        "stateAfternoon": "下午",
        "stateAfterWork": "已下班",
        "stateWeekendOff": "周末休息",
        "morningSection": "上午时段",
        "afternoonSection": "下午时段",
        "startTime": "上班时间",
        "endTime": "下班时间",
        "salarySection": "工资",
        "dailySalary": "日薪",
        "hourlyRateAuto": "时薪（自动计算）",
        "hourlyRateFormat": "¥%.2f/时",
        "reminderSection": "提醒",
        "remindMinutesBefore": "下班前 %d 分钟提醒",
        "reminderMethodNote": "提醒方式：系统通知 + 菜单栏金额变橙色",
        "weekendSection": "周末",
        "overtimeMode": "加班模式",
        "overtimeDescription": "开启后周末也会按工作时间累计工资并发送下班提醒。",
        "done": "完成",
        "languageSection": "语言",
        "menuBarWeekendRest": " 周末休息 ",
        "menuBarBeforeWork": " 还未上班 ",
        "menuBarAfterWork": " 已下班 ",
        "menuBarLunchBreak": " 午休中 ",
        "periodMorning": "上午",
        "periodAfternoon": "下午",
        "statusWork": "出勤",
        "statusOvertime": "加班",
        "statusLeave": "请假",
        "statusRest": "休息",
        "statusOther": "其他",
        "attendanceWindowTitle": "考勤",
        "attendanceStats": "统计",
        "attendanceCalendar": "日历",
        "attendanceExport": "导出 CSV",
        "attendanceImport": "导入 JSON",
        "attendanceDelete": "删除",
        "attendanceNote": "备注",
        "attendanceSave": "保存",
        "attendanceClose": "关闭",
        "attendanceToday": "今天",
        "attendancePrevMonth": "上个月",
        "attendanceNextMonth": "下个月",
        "attendanceNoRecords": "暂无记录",
        "attendanceImportSuccess": "已导入 %d 条记录",
        "attendanceImportError": "导入失败：%@",
        "attendanceConfirmDelete": "确认删除此记录？",
        "attendanceRecordsCount": "共 %d 条",
        "attendanceEditorTitle": "编辑考勤",
        "attendanceExportExcel": "导出 Excel",
        "attendanceExportMonth": "本月",
        "attendanceExportYear": "本年",
        "statusWeekendRest": "周末休息",
        "monthlyEarnings": "本月已赚",
        "monthlyWorkedDays": "出勤 %d 天",
        "attendanceExportCustom": "指定日期",
        "attendanceExportStart": "开始日期",
        "attendanceExportEnd": "结束日期",
        "attendanceExportConfirm": "导出",
        "settingsWindowTitle": "PayTick 设置",
        "toolTipUntilOff": "PayTick · 距下班 %d 分钟",
        "notifTitle": "快下班了 ⏰",
        "notifBodyMinutes": "还有 %d 分 %d 秒下班，准备收拾东西吧～",
        "notifBodySeconds": "还有 %d 秒就下班啦，准备冲！"
    ]
}

/// 本地化管理器（单例 + ObservableObject，SwiftUI 监听 language 变化自动刷新）
final class Localization: ObservableObject {
    static let shared = Localization()

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "PayTick.language")
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "PayTick.language") ?? AppLanguage.english.rawValue
        language = AppLanguage(rawValue: saved) ?? .english
    }

    private var table: [String: String] {
        switch language {
        case .english: return L10n.english
        case .chineseSimplified: return L10n.chineseSimplified
        }
    }

    /// 普通翻译
    func t(_ key: String) -> String {
        table[key] ?? L10n.english[key] ?? key
    }

    /// 带参数的翻译（String(format:) 风格）
    func t(_ key: String, _ args: CVarArg...) -> String {
        let template = table[key] ?? L10n.english[key] ?? key
        return String(format: template, arguments: args)
    }
}
