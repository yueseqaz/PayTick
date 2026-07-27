import SwiftUI
import AppKit

// MARK: - Main view

struct AttendanceView: View {
    @EnvironmentObject var store: AttendanceStore
    @EnvironmentObject var l10n: Localization

    @State private var displayedMonth: Date = AttendanceView.firstDayOfMonth(Date())
    @State private var editingDay: Date? = nil
    @State private var importMessage: String? = nil
    @State private var importError: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            monthToolbar
            Divider()
            weekdayHeader
            calendarGrid
            Divider()
            statsBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: Binding(
            get: { editingDay.map { IdentifiableDate(date: $0) } },
            set: { editingDay = $0?.date }
        )) { item in
            AttendanceDayEditorView(day: item.date)
                .environmentObject(store)
                .environmentObject(l10n)
        }
        .alert(importError ? l10n.t("attendanceImportError", importMessage ?? "")
                            : (importMessage ?? ""),
               isPresented: Binding(
                   get: { importMessage != nil },
                   set: { if !$0 { importMessage = nil; importError = false } }
               )) {
            Button(l10n.t("attendanceClose")) { importMessage = nil; importError = false }
        }
    }

    // MARK: - Toolbar

    private var monthToolbar: some View {
        HStack(spacing: 8) {
            Button {
                displayedMonth = stepMonth(displayedMonth, by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .help(l10n.t("attendancePrevMonth"))

            Text(monthTitleText)
                .font(.headline)
                .frame(minWidth: 140)

            Button {
                displayedMonth = stepMonth(displayedMonth, by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .help(l10n.t("attendanceNextMonth"))

            Button {
                displayedMonth = AttendanceView.firstDayOfMonth(Date())
            } label: {
                Label(l10n.t("attendanceToday"), systemImage: "calendar")
                    .font(.caption)
            }

            Spacer()

            Button {
                importJSON()
            } label: {
                Label(l10n.t("attendanceImport"), systemImage: "square.and.arrow.down")
                    .font(.caption)
            }

            Menu {
                Button(l10n.t("attendanceExportMonth")) { exportExcel(month: true) }
                Button(l10n.t("attendanceExportYear")) { exportExcel(month: false) }
            } label: {
                Label(l10n.t("attendanceExportExcel"), systemImage: "square.and.arrow.up")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var monthTitleText: String {
        let fmt = DateFormatter()
        let cal = Calendar.current
        let year = cal.component(.year, from: displayedMonth)
        let month = cal.component(.month, from: displayedMonth)
        if l10n.language == .chineseSimplified {
            return String(format: "%d年%d月", year, month)
        } else {
            fmt.locale = Locale(identifier: "en_US")
            fmt.dateFormat = "MMMM yyyy"
            return fmt.string(from: displayedMonth)
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(weekdayLabels, id: \.self) { label in
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var weekdayLabels: [String] {
        if l10n.language == .chineseSimplified {
            return ["日", "一", "二", "三", "四", "五", "六"]
        } else {
            return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        }
    }

    // MARK: - Calendar grid

    private var calendarGrid: some View {
        let days = buildMonthDays()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(days, id: \.self) { day in
                DayCellView(day: day, month: displayedMonth, records: store.recordsFor(date: day))
                    .onTapGesture { editingDay = day }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    // MARK: - Stats bar

    private var statsBar: some View {
        let stats = store.statsFor(year: Calendar.current.component(.year, from: displayedMonth),
                                   month: Calendar.current.component(.month, from: displayedMonth))
        let totalCount = stats.values.reduce(0, +)
        return HStack(spacing: 12) {
            ForEach(AttendanceStatus.allCases, id: \.self) { status in
                let count = stats[status, default: 0]
                HStack(spacing: 4) {
                    Image(systemName: status.symbol)
                        .font(.caption2)
                        .foregroundStyle(status.color)
                    Text("\(status.displayName) \(count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(l10n.t("attendanceRecordsCount", totalCount))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Actions

    private func exportExcel(month: Bool) {
        let cal = Calendar.current
        let year = cal.component(.year, from: displayedMonth)
        let monthNum = cal.component(.month, from: displayedMonth)
        let suggested: String
        if month {
            suggested = String(format: "考勤记录_%04d-%02d.xlsx", year, monthNum)
        } else {
            suggested = "考勤记录_\(year).xlsx"
        }

        let panel = NSSavePanel()
        panel.title = l10n.t("attendanceExportExcel")
        panel.nameFieldStringValue = suggested
        panel.allowedContentTypes = [.spreadsheet]
        if panel.runModal() == .OK, let url = panel.url {
            let ok: Bool
            if month {
                ok = store.exportXLSX(year: year, month: monthNum, to: url)
            } else {
                ok = store.exportXLSX(year: year, to: url)
            }
            if ok {
                importMessage = "✓ \(url.lastPathComponent)"
                importError = false
            } else {
                importMessage = "✗ 导出失败"
                importError = true
            }
        }
    }

    private func importJSON() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        panel.title = l10n.t("attendanceImport")
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let count = try store.importFromAttendanceJSON(data)
                importMessage = l10n.t("attendanceImportSuccess", count)
                importError = false
            } catch {
                importMessage = error.localizedDescription
                importError = true
            }
        }
    }

    // MARK: - Calendar math

    static func firstDayOfMonth(_ date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? date
    }

    private func stepMonth(_ date: Date, by delta: Int) -> Date {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.month = delta
        return cal.date(byAdding: comps, to: date) ?? date
    }

    private func buildMonthDays() -> [Date] {
        let cal = Calendar.current
        let firstOfMonth = Self.firstDayOfMonth(displayedMonth)
        let weekdayOfFirst = cal.component(.weekday, from: firstOfMonth)  // 1=Sun
        // 始终返回 42 格（6 行 × 7 列）保证日历视觉稳定
        // 前导格用上月日期填充（DayCellView 会把它们标灰）
        var days: [Date] = []
        for i in 0..<42 {
            let offset = i - (weekdayOfFirst - 1)
            var comps = DateComponents()
            comps.day = offset
            if let d = cal.date(byAdding: comps, to: firstOfMonth) {
                days.append(d)
            }
        }
        return days
    }
}

// MARK: - Day cell

private struct DayCellView: View {
    let day: Date
    let month: Date
    let records: [AttendanceRecord]

    private var isInMonth: Bool {
        Calendar.current.component(.month, from: day) == Calendar.current.component(.month, from: month)
    }
    private var isToday: Bool { Calendar.current.isDateInToday(day) }
    private var isWeekend: Bool {
        let w = Calendar.current.component(.weekday, from: day)
        return w == 1 || w == 7  // Sun or Sat
    }

    var body: some View {
        VStack(spacing: 3) {
            Text("\(Calendar.current.component(.day, from: day))")
                .font(.caption.weight(isToday ? .bold : .regular))
                .foregroundStyle(isInMonth ? .primary : .tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(AttendancePeriod.allCases, id: \.self) { period in
                if let rec = records.first(where: { $0.period == period }) {
                    // 用户已设记录（含加班/请假等），原样显示
                    HStack(spacing: 2) {
                        Image(systemName: rec.status.symbol)
                            .font(.system(size: 8))
                            .foregroundStyle(rec.status.color)
                        Text(rec.status.displayName)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        if !rec.note.isEmpty {
                            Image(systemName: "note.text")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if isWeekend && isInMonth {
                    // 周末无记录：自动显示"休息"
                    HStack(spacing: 2) {
                        Image(systemName: AttendanceStatus.rest.symbol)
                            .font(.system(size: 8))
                            .foregroundStyle(AttendanceStatus.rest.color.opacity(0.7))
                        Text(AttendanceStatus.rest.displayName)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // 工作日无记录：占位
                    HStack(spacing: 2) {
                        Image(systemName: period.symbol)
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                        Text("—")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .top)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isToday ? Color.accentColor.opacity(0.12) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isInMonth ? Color.clear : Color.gray.opacity(0.06), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Day editor

struct AttendanceDayEditorView: View {
    let day: Date
    @EnvironmentObject var store: AttendanceStore
    @EnvironmentObject var l10n: Localization
    @Environment(\.dismiss) private var dismiss

    @State private var morningStatus: AttendanceStatus = .work
    @State private var afternoonStatus: AttendanceStatus = .work
    @State private var morningNote: String = ""
    @State private var afternoonNote: String = ""
    @State private var hasMorning: Bool = false
    @State private var hasAfternoon: Bool = false
    @State private var showDelete: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(formattedDate)
                    .font(.headline)
                Spacer()
                Button(l10n.t("attendanceClose")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            Form {
                Section(l10n.t("periodMorning")) {
                    Picker("", selection: $morningStatus) {
                        ForEach(AttendanceStatus.allCases, id: \.self) { s in
                            Label(s.displayName, systemImage: s.symbol)
                                .foregroundStyle(s.color)
                                .tag(s)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)

                    if hasMorning {
                        Button(role: .destructive) {
                            if let r = store.recordsFor(date: day).first(where: { $0.period == .morning }) {
                                store.delete(id: r.id)
                                hasMorning = false
                                morningNote = ""
                            }
                        } label: {
                            Label(l10n.t("attendanceDelete"), systemImage: "trash")
                                .font(.caption)
                        }
                    }

                    TextField(l10n.t("attendanceNote"), text: $morningNote, axis: .vertical)
                        .lineLimit(2)
                }

                Section(l10n.t("periodAfternoon")) {
                    Picker("", selection: $afternoonStatus) {
                        ForEach(AttendanceStatus.allCases, id: \.self) { s in
                            Label(s.displayName, systemImage: s.symbol)
                                .foregroundStyle(s.color)
                                .tag(s)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)

                    if hasAfternoon {
                        Button(role: .destructive) {
                            if let r = store.recordsFor(date: day).first(where: { $0.period == .afternoon }) {
                                store.delete(id: r.id)
                                hasAfternoon = false
                                afternoonNote = ""
                            }
                        } label: {
                            Label(l10n.t("attendanceDelete"), systemImage: "trash")
                                .font(.caption)
                        }
                    }

                    TextField(l10n.t("attendanceNote"), text: $afternoonNote, axis: .vertical)
                        .lineLimit(2)
                }
            }
            .formStyle(.grouped)
            .onAppear(perform: loadInitial)

            HStack {
                Spacer()
                Button(l10n.t("attendanceSave")) {
                    saveRecords()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 420, height: 520)
    }

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.locale = l10n.language == .chineseSimplified ? Locale(identifier: "zh_Hans") : Locale(identifier: "en_US")
        return fmt.string(from: day)
    }

    private func loadInitial() {
        let records = store.recordsFor(date: day)
        if let m = records.first(where: { $0.period == .morning }) {
            morningStatus = m.status
            morningNote = m.note
            hasMorning = true
        }
        if let a = records.first(where: { $0.period == .afternoon }) {
            afternoonStatus = a.status
            afternoonNote = a.note
            hasAfternoon = true
        }
    }

    private func saveRecords() {
        store.upsert(date: day, period: .morning, status: morningStatus, note: morningNote)
        store.upsert(date: day, period: .afternoon, status: afternoonStatus, note: afternoonNote)
    }
}

// MARK: - Helpers

private struct IdentifiableDate: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}
