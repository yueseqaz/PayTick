import SwiftUI
import AppKit

struct MainPanelView: View {
    @EnvironmentObject var store: ScheduleStore
    @EnvironmentObject var calculator: SalaryCalculator
    @EnvironmentObject var notifier: NotificationManager
    @EnvironmentObject var appDelegate: AppDelegate
    @EnvironmentObject var l10n: Localization

    var body: some View {
        VStack(spacing: 0) {
            headerCard
            Divider()
            progressCard
            Divider()
            statusCard
            Divider()
            actionsBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - 头部：今日已赚大字
    private var headerCard: some View {
        VStack(spacing: 6) {
            Text(stateBadgeText)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(stateBadgeColor.opacity(0.15))
                )

            Text(l10n.t("earnedToday"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(AppDelegate.currencyFormatter.string(from: NSNumber(value: calculator.earnedToday)) ?? "¥0.00")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(calculator.isInReminderWindow ? Color.orange : Color.primary)
                .contentTransition(.numericText())

            Text(l10n.t("dailySalaryWithWorked",
                        AppDelegate.currencyFormatter.string(from: NSNumber(value: store.schedule.dailySalary)) ?? "¥0",
                        Int(calculator.workedSeconds/60)))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            LinearGradient(
                colors: [
                    stateBadgeColor.opacity(0.12),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - 进度条
    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(l10n.t("progress"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(l10n.t("minutesTotalFormat",
                            Int(calculator.workedSeconds/60),
                            Int(calculator.totalSeconds/60)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(
                value: calculator.totalSeconds > 0 ? calculator.workedSeconds / calculator.totalSeconds : 0
            )
            .tint(calculator.isInReminderWindow ? .orange : .blue)
            .animation(.easeInOut(duration: 0.3), value: calculator.workedSeconds)

            HStack {
                Text(formatTimeFromMinute(store.schedule.morningStartMin))
                Spacer()
                Text(formatTimeFromMinute(store.schedule.afternoonEndMin))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - 倒计时 / 状态
    private var statusCard: some View {
        VStack(spacing: 8) {
            switch calculator.state {
            case .afternoon where calculator.secondsUntilOff > 0:
                statusRow(
                    icon: "clock.fill",
                    color: calculator.isInReminderWindow ? .orange : .blue,
                    title: l10n.t("untilClockOut"),
                    value: formatCountdown(calculator.secondsUntilOff),
                    valueColor: calculator.isInReminderWindow ? .orange : .primary
                )
            case .afterWork:
                statusRow(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    title: l10n.t("doneToday"),
                    value: AppDelegate.currencyFormatter.string(from: NSNumber(value: store.schedule.dailySalary)) ?? "¥0",
                    valueColor: .green
                )
            case .weekendOff:
                statusRow(
                    icon: "cup.and.saucer.fill",
                    color: .purple,
                    title: l10n.t("weekendOff"),
                    value: "¥0",
                    valueColor: .secondary
                )
            case .beforeWork:
                statusRow(
                    icon: "sun.max.fill",
                    color: .yellow,
                    title: l10n.t("notStartedYet"),
                    value: formatTimeFromMinute(store.schedule.morningStartMin),
                    valueColor: .secondary
                )
            case .morning:
                statusRow(
                    icon: "sun.max.fill",
                    color: .yellow,
                    title: l10n.t("morningShift"),
                    value: formatCountdown(store.schedule.dateForMinute(store.schedule.morningEndMin, on: Date(), calendar: .current).timeIntervalSinceNow),
                    valueColor: .primary
                )
            case .lunchBreak:
                statusRow(
                    icon: "fork.knife",
                    color: .orange,
                    title: l10n.t("lunchBreak"),
                    value: formatCountdown(store.schedule.dateForMinute(store.schedule.afternoonStartMin, on: Date(), calendar: .current).timeIntervalSinceNow),
                    valueColor: .primary
                )
            default:
                EmptyView()
            }

            if let last = notifier.lastReminderDate,
               Calendar.current.isDateInToday(last) {
                HStack(spacing: 4) {
                    Image(systemName: "bell.badge.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text(l10n.t("reminderSentToday"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusRow(icon: String, color: Color, title: String, value: String, valueColor: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 22)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(valueColor)
        }
    }

    // MARK: - 底部按钮
    private var actionsBar: some View {
        VStack(spacing: 10) {
            HStack {
                Label(l10n.t("overtime"), systemImage: "moon.fill")
                    .font(.caption)
                Spacer()
                Toggle(isOn: $store.schedule.overtimeMode) {
                    EmptyView()
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            }

            HStack {
                Spacer()
                Button {
                    appDelegate.openAttendance()
                } label: {
                    Label(l10n.t("attendanceWindowTitle"), systemImage: "calendar.badge.clock")
                        .font(.caption)
                }

                Button {
                    appDelegate.openSettings()
                } label: {
                    Label(l10n.t("settings"), systemImage: "gearshape")
                        .font(.caption)
                }

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label(l10n.t("quit"), systemImage: "power")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - 状态文字
    private var stateBadgeText: String {
        switch calculator.state {
        case .beforeWork: return l10n.t("stateBeforeWork")
        case .morning: return l10n.t("stateMorning")
        case .lunchBreak: return l10n.t("stateLunchBreak")
        case .afternoon: return l10n.t("stateAfternoon")
        case .afterWork: return l10n.t("stateAfterWork")
        case .weekendOff: return l10n.t("stateWeekendOff")
        }
    }

    private var stateBadgeColor: Color {
        switch calculator.state {
        case .beforeWork: return .gray
        case .morning: return .yellow
        case .lunchBreak: return .orange
        case .afternoon: return calculator.isInReminderWindow ? .orange : .blue
        case .afterWork: return .green
        case .weekendOff: return .purple
        }
    }

    // MARK: - 工具方法
    private func formatTimeFromMinute(_ minuteOfDay: Int) -> String {
        let h = minuteOfDay / 60
        let m = minuteOfDay % 60
        return String(format: "%02d:%02d", h, m)
    }

    private func formatCountdown(_ secs: TimeInterval) -> String {
        let total = Int(secs.rounded())
        guard total > 0 else { return "00:00:00" }
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
