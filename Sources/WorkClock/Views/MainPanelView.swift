import SwiftUI
import AppKit

struct MainPanelView: View {
    @EnvironmentObject var store: ScheduleStore
    @EnvironmentObject var calculator: SalaryCalculator
    @EnvironmentObject var notifier: NotificationManager
    @EnvironmentObject var appDelegate: AppDelegate

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

            Text("今日已赚")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(AppDelegate.currencyFormatter.string(from: NSNumber(value: calculator.earnedToday)) ?? "¥0.00")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(calculator.isInReminderWindow ? Color.orange : Color.primary)
                .contentTransition(.numericText())

            Text("日薪 \(AppDelegate.currencyFormatter.string(from: NSNumber(value: store.schedule.dailySalary)) ?? "¥0") · 已工作 \(formatMinutes(Int(calculator.workedSeconds/60)))")
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
                Text("工作进度")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(calculator.workedSeconds/60))/\(Int(calculator.totalSeconds/60)) 分钟")
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
                    title: "距离下班",
                    value: formatCountdown(calculator.secondsUntilOff),
                    valueColor: calculator.isInReminderWindow ? .orange : .primary
                )
            case .afterWork:
                statusRow(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    title: "今日完成",
                    value: AppDelegate.currencyFormatter.string(from: NSNumber(value: store.schedule.dailySalary)) ?? "¥0",
                    valueColor: .green
                )
            case .weekendOff:
                statusRow(
                    icon: "cup.and.saucer.fill",
                    color: .purple,
                    title: "今日周末休息",
                    value: "0 元",
                    valueColor: .secondary
                )
            case .beforeWork:
                statusRow(
                    icon: "sun.max.fill",
                    color: .yellow,
                    title: "还没开始上班",
                    value: formatTimeFromMinute(store.schedule.morningStartMin),
                    valueColor: .secondary
                )
            case .morning:
                statusRow(
                    icon: "sun.max.fill",
                    color: .yellow,
                    title: "上午工作中",
                    value: formatCountdown(store.schedule.dateForMinute(store.schedule.morningEndMin, on: Date(), calendar: .current).timeIntervalSinceNow),
                    valueColor: .primary
                )
            case .lunchBreak:
                statusRow(
                    icon: "fork.knife",
                    color: .orange,
                    title: "午休中",
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
                    Text("今日已发送下班提醒")
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
        HStack {
            Toggle(isOn: $store.schedule.overtimeMode) {
                Label("加班", systemImage: "moon.fill")
                    .font(.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Spacer()

            Button {
                appDelegate.openSettings()
            } label: {
                Label("设置", systemImage: "gearshape")
                    .font(.caption)
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("退出", systemImage: "power")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - 状态文字
    private var stateBadgeText: String {
        switch calculator.state {
        case .beforeWork: return "未开始"
        case .morning: return "上午"
        case .lunchBreak: return "午休"
        case .afternoon: return "下午"
        case .afterWork: return "已下班"
        case .weekendOff: return "周末休息"
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
    private func formatMinutes(_ totalMin: Int) -> String {
        let h = totalMin / 60
        let m = totalMin % 60
        if h > 0 { return "\(h)时\(m)分" }
        return "\(m)分"
    }

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
