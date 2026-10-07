//
//  NotificationEditView.swift
//  notti
//

import SwiftData
import SwiftUI

/// 通知の追加・編集画面。文言と、間隔か時刻（繰り返し）を入力して保存する
struct NotificationEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.notificationScheduler) private var scheduler
    @StoredQuietHours private var quietHours

    /// 編集する設定。nil なら追加
    private let setting: NotificationSetting?
    @State private var draft: NotificationDraft
    /// 1 回だけの日時の入力。繰り返しが 1 回だけのときだけ `draft` に書き写す
    @State private var onceDate: Date

    init(setting: NotificationSetting? = nil) {
        self.setting = setting
        _draft = State(initialValue: setting?.draft ?? NotificationDraft(message: ""))
        _onceDate = State(initialValue: setting?.onceDate ?? Self.nextHour(after: .now))
    }

    /// 保存する内容。1 回だけの日時は、繰り返しが 1 回だけのときだけ入力の値にする
    /// （それ以外は保存済みの値のままにして、変更が無い編集を「変更あり」にしない）
    private var savingDraft: NotificationDraft {
        var draft = draft
        draft.schedule.onceDate = draft.kind == .timeOfDay && draft.schedule.repeatRule == .once ? onceDate : setting?.onceDate
        return draft
    }

    /// 保存すると、おやすみ時間のせいで一度も鳴らなくなる（間隔の通知だけ。時刻指定の通知はおやすみ時間を適用しない）
    ///
    /// 追加・変更して保存すると保存した時刻が起点になる。変更が無ければ起点は今のまま。
    private var isSilentAfterSave: Bool {
        guard draft.kind == .interval else {
            return false
        }
        var trimmed = savingDraft
        trimmed.message = trimmed.message.trimmingCharacters(in: .whitespacesAndNewlines)
        let isChanged = setting.map { $0.draft != trimmed } ?? true
        let startDate = isChanged ? .now : setting?.startDate ?? .now
        let calendar = Calendar.current
        let plan = NotificationTriggerPlan.make(
            startDate: startDate,
            interval: draft.interval,
            quietHours: quietHours,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
        return plan.isSilent
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("文言") {
                    TextField("例: 水を飲む", text: $draft.message, axis: .vertical)
                        .accessibilityIdentifier("messageField")
                }
                Section("種類") {
                    Picker("種類", selection: $draft.kind) {
                        ForEach(NotificationKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                switch draft.kind {
                case .interval:
                    intervalSection
                case .timeOfDay:
                    timeOfDaySection
                }
            }
            .navigationTitle(setting == nil ? "通知を追加" : "通知を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        NotificationSettingActions(scheduler: scheduler)
                            .save(savingDraft, to: setting, in: modelContext)
                        dismiss()
                    }
                    .disabled(savingDraft.problem() != nil)
                }
            }
        }
    }

    private var intervalSection: some View {
        Section {
            Picker("間隔", selection: $draft.interval) {
                ForEach(NotificationInterval.allCases) { interval in
                    Text(interval.label).tag(interval)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("間隔")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("保存した時刻から数えて、この間隔で繰り返し通知します")
                if isSilentAfterSave {
                    Label("起点の時刻がおやすみ時間に入るため、この通知は鳴りません", systemImage: "moon.zzz")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var timeOfDaySection: some View {
        Section {
            Picker("繰り返し", selection: $draft.schedule.repeatRule) {
                ForEach(NotificationRepeat.allCases) { repeatRule in
                    Text(repeatRule.label).tag(repeatRule)
                }
            }
            .pickerStyle(.segmented)
            switch draft.schedule.repeatRule {
            case .daily:
                timePicker
            case .weekdays:
                timePicker
                weekdayPicker
            case .once:
                DatePicker("日時", selection: $onceDate, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                    .accessibilityIdentifier("onceDatePicker")
            }
        } header: {
            Text("時刻と繰り返し")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("端末の時刻で通知します。おやすみ時間のあいだでも通知します")
                switch savingDraft.problem() {
                case .noWeekday:
                    Label("曜日を 1 つ以上選んでください", systemImage: "exclamationmark.circle")
                        .foregroundStyle(.orange)
                case .pastOnceDate:
                    Label("過ぎた日時は登録できません", systemImage: "exclamationmark.circle")
                        .foregroundStyle(.orange)
                case .emptyMessage, nil:
                    EmptyView()
                }
            }
        }
    }

    private var timePicker: some View {
        DatePicker(
            "時刻",
            selection: Binding(
                get: { Self.date(from: draft.schedule.time) },
                set: { draft.schedule.time = Self.time(from: $0) }
            ),
            displayedComponents: .hourAndMinute
        )
        .accessibilityIdentifier("timePicker")
    }

    private var weekdayPicker: some View {
        HStack {
            ForEach(Weekday.allCases) { weekday in
                let isSelected = draft.schedule.weekdays.contains(weekday)
                Button {
                    if isSelected {
                        draft.schedule.weekdays.remove(weekday)
                    } else {
                        draft.schedule.weekdays.insert(weekday)
                    }
                } label: {
                    Text(weekday.shortLabel)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(isSelected ? .accentColor : .secondary)
                .accessibilityLabel("\(weekday.shortLabel)曜")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private static func date(from time: TimeOfDay) -> Date {
        Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: .now) ?? .now
    }

    private static func time(from date: Date) -> TimeOfDay {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }

    /// `date` の次の正時（1 回だけの日時の初期値）
    private static func nextHour(after date: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.dateInterval(of: .hour, for: date)?.start ?? date
        return calendar.date(byAdding: .hour, value: 1, to: hour) ?? date
    }
}

#Preview {
    NotificationEditView()
        .modelContainer(for: NotificationSetting.self, inMemory: true)
}
