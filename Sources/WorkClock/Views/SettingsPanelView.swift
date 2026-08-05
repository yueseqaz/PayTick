import SwiftUI

struct SettingsPanelView: View {
    @EnvironmentObject var store: ScheduleStore
    @EnvironmentObject var l10n: Localization
    @Environment(\.dismiss) private var dismiss
    @FocusState private var salaryFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                // Tab 1: 通用
                Form {
                    Section(l10n.t("languageSection")) {
                        Picker(l10n.t("languageSection"), selection: $l10n.language) {
                            ForEach(AppLanguage.allCases, id: \.self) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    Section {
                        HStack {
                            Text(l10n.t("dailySalary"))
                            Spacer()
                            HStack(spacing: 4) {
                                Text("¥")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.secondary)
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
                                .frame(width: 90)
                                .textFieldStyle(.roundedBorder)
                                .focused($salaryFocused)
                            }
                        }
                        HStack {
                            Text(l10n.t("hourlyRateAuto"))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(computedHourlyRate)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text(l10n.t("salarySection"))
                    }
                    Section {
                        Toggle(isOn: $store.schedule.overtimeMode) {
                            Label(l10n.t("overtimeMode"), systemImage: "moon.fill")
                        }
                        Text(l10n.t("overtimeDescription"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text(l10n.t("weekendSection"))
                    }
                }
                .formStyle(.grouped)
                .tabItem {
                    Label(l10n.t("settingsTabGeneral"), systemImage: "gearshape")
                }

                // Tab 2: 工作时间
                Form {
                    Section(l10n.t("morningSection")) {
                        timeRow(title: l10n.t("startTime"), minute: $store.schedule.morningStartMin)
                        timeRow(title: l10n.t("endTime"), minute: $store.schedule.morningEndMin)
                    }
                    Section(l10n.t("afternoonSection")) {
                        timeRow(title: l10n.t("startTime"), minute: $store.schedule.afternoonStartMin)
                        timeRow(title: l10n.t("endTime"), minute: $store.schedule.afternoonEndMin)
                    }
                }
                .formStyle(.grouped)
                .tabItem {
                    Label(l10n.t("settingsTabSchedule"), systemImage: "clock")
                }

                // Tab 3: 智能提醒
                Form {
                    Section {
                        reminderRow(icon: "sun.max.fill", iconColor: .orange,
                                    title: l10n.t("reminderMorningStart"),
                                    isOn: $store.schedule.reminderConfig.morningStart,
                                    minute: $store.schedule.reminderConfig.morningStartMin)
                        reminderRow(icon: "fork.knife", iconColor: .blue,
                                    title: l10n.t("reminderPreLunch"),
                                    isOn: $store.schedule.reminderConfig.preLunch,
                                    minute: $store.schedule.reminderConfig.preLunchMin)
                        reminderRow(icon: "cup.and.saucer.fill", iconColor: .pink,
                                    title: l10n.t("reminderLunchStart"),
                                    isOn: $store.schedule.reminderConfig.lunchStart,
                                    minute: $store.schedule.reminderConfig.lunchStartMin)
                        reminderRow(icon: "flame.fill", iconColor: .red,
                                    title: l10n.t("reminderAfternoonStart"),
                                    isOn: $store.schedule.reminderConfig.afternoonStart,
                                    minute: $store.schedule.reminderConfig.afternoonStartMin)
                        reminderRow(icon: "party.popper.fill", iconColor: .green,
                                    title: l10n.t("reminderAfterWork"),
                                    isOn: $store.schedule.reminderConfig.afterWork,
                                    minute: $store.schedule.reminderConfig.afterWorkMin)
                        reminderRow(icon: "moon.zzz.fill", iconColor: .indigo,
                                    title: l10n.t("reminderLateNight"),
                                    isOn: $store.schedule.reminderConfig.lateNight,
                                    minute: $store.schedule.reminderConfig.lateNightMin)
                    } header: {
                        Text(l10n.t("smartReminders"))
                    }
                }
                .formStyle(.grouped)
                .tabItem {
                    Label(l10n.t("settingsTabReminders"), systemImage: "bell")
                }
            }

            HStack {
                Spacer()
                Button(l10n.t("done")) {
                    dismiss()
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 420, height: 520)
        .onAppear {
            DispatchQueue.main.async {
                salaryFocused = false
            }
        }
    }

    // MARK: - Reminder row

    private func reminderRow(icon: String, iconColor: Color, title: String, isOn: Binding<Bool>, minute: Binding<Int>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 22)
            Toggle(isOn: isOn) {
                Text(title)
            }
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
            .disabled(!isOn.wrappedValue)
        }
    }

    // MARK: - Helpers

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
        guard total > 0 else { return String(format: l10n.t("hourlyRateFormat"), 0.0) }
        let hourly = store.schedule.dailySalary / Double(total / 60)
        return String(format: l10n.t("hourlyRateFormat"), hourly)
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
