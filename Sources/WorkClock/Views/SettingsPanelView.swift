import SwiftUI

struct SettingsPanelView: View {
    @EnvironmentObject var store: ScheduleStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("上午时段") {
                    timeRow(title: "上班时间", minute: $store.schedule.morningStartMin)
                    timeRow(title: "下班时间", minute: $store.schedule.morningEndMin)
                }
                Section("下午时段") {
                    timeRow(title: "上班时间", minute: $store.schedule.afternoonStartMin)
                    timeRow(title: "下班时间", minute: $store.schedule.afternoonEndMin)
                }
                Section {
                    HStack {
                        Text("日薪")
                        Spacer()
                        TextField("",
                            text: Binding(
                                get: { String(format: "%.0f", store.schedule.dailySalary) },
                                set: { newValue in
                                    let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                    if let v = Double(filtered) {
                                        store.schedule.dailySalary = v
                                    } else if filtered.isEmpty {
                                        store.schedule.dailySalary = 0
                                    }
                                }
                            )
                        )
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                        .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("时薪（自动计算）")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(computedHourlyRate)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("工资")
                }
                Section {
                    Stepper(value: $store.schedule.reminderMinutes, in: 1...60) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundStyle(.orange)
                            Text("下班前 \(store.schedule.reminderMinutes) 分钟提醒")
                        }
                    }
                } header: {
                    Text("提醒")
                } footer: {
                    Text("提醒方式：系统通知 + 菜单栏金额变橙色")
                }
                Section {
                    Toggle(isOn: $store.schedule.overtimeMode) {
                        Label("加班模式", systemImage: "moon.fill")
                    }
                    Text("开启后周末也会按工作时间累计工资并发送下班提醒。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("周末")
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("完成") {
                    dismiss()
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 380, height: 560)
    }

    private func timeRow(title: String, minute: Binding<Int>) -> some View {
        HStack {
            Text(title)
            Spacer()
            DatePicker(
                "",
                selection: Binding(
                    get: { minuteToDate(minute.wrappedValue) },
                    set: { minute.wrappedValue = dateToMinute($0) }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
    }

    private var computedHourlyRate: String {
        let total = (store.schedule.morningEndMin - store.schedule.morningStartMin)
            + (store.schedule.afternoonEndMin - store.schedule.afternoonStartMin)
        guard total > 0 else { return "¥0.00/时" }
        let hourly = store.schedule.dailySalary / Double(total / 60)
        return "¥" + String(format: "%.2f", hourly) + "/时"
    }

    private func minuteToDate(_ minuteOfDay: Int) -> Date {
        let hour = minuteOfDay / 60
        let minute = minuteOfDay % 60
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let calendar = Calendar.current
        return calendar.date(from: components) ?? Date()
    }

    private func dateToMinute(_ date: Date) -> Int {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
}
