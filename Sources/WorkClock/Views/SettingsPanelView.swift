import SwiftUI

struct SettingsPanelView: View {
    @EnvironmentObject var store: ScheduleStore
    @EnvironmentObject var l10n: Localization
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
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

                Section(l10n.t("morningSection")) {
                    timeRow(title: l10n.t("startTime"), minute: $store.schedule.morningStartMin)
                    timeRow(title: l10n.t("endTime"), minute: $store.schedule.morningEndMin)
                }
                Section(l10n.t("afternoonSection")) {
                    timeRow(title: l10n.t("startTime"), minute: $store.schedule.afternoonStartMin)
                    timeRow(title: l10n.t("endTime"), minute: $store.schedule.afternoonEndMin)
                }
                Section {
                    HStack {
                        Text(l10n.t("dailySalary"))
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
                    Stepper(l10n.t("remindMinutesBefore", store.schedule.reminderMinutes),
                            value: $store.schedule.reminderMinutes, in: 1...60)
                } header: {
                    Text(l10n.t("reminderSection"))
                } footer: {
                    Text(l10n.t("reminderMethodNote"))
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
        .frame(width: 380, height: 620)
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
