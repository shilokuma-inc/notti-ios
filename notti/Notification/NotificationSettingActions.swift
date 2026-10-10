//
//  NotificationSettingActions.swift
//  notti
//

import Foundation
import OSLog
import SwiftData

/// 画面での通知設定の操作を、保存内容と通知センターの登録に反映する
///
/// 保存内容はその場で書き換え（画面がすぐ追従するように）、通知センターへの反映は戻り値の `Task` で行う。
struct NotificationSettingActions {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "notti", category: "Notification")

    let scheduler: NotificationScheduler

    /// 最後に積んだ通知センターへの反映。反映は呼んだ順に 1 つずつ行う
    ///
    /// 反映の途中（`await` の間）に次の操作が来ると、登録と削除が入り混じって、後の操作の結果が前の操作に上書きされるため
    /// （例: 完了の反映が終わる前に取り消すと、取り消した期間の催促が消える）
    private static var lastSync: Task<Void, Never>?

    /// 通知の ON/OFF を切り替える。ON にした時刻を新しい起点日時にする（Q1「設定した時刻から N 時間ごと」）
    @discardableResult
    func setEnabled(_ isEnabled: Bool, for setting: NotificationSetting, now: Date = .now) -> Task<Void, Never> {
        setting.isEnabled = isEnabled
        if isEnabled {
            setting.startDate = now
            // 日時を過ぎた 1 回だけの通知は鳴らないので ON にしない（日時を変えてから ON にする）
            if isEnabledOnce(setting) && scheduler.plan(for: setting, now: now).requestCount == 0 {
                setting.isEnabled = false
            }
        }
        return enqueue {
            await sync(setting, now: now)
        }
    }

    /// 追加・編集画面の入力を保存し、通知を登録し直す
    ///
    /// 編集で内容（文言・種類・間隔・時刻・繰り返し）が変わった ON の通知は、保存した時刻を新しい起点にする。変更が無ければ登録し直さない。
    ///
    /// - Parameter setting: 編集中の設定。nil なら新しく追加する（追加した通知は ON で、追加した時刻が起点になる）
    /// - Returns: 保存した設定と、通知センターへの反映
    @discardableResult
    func save(
        _ draft: NotificationDraft,
        to setting: NotificationSetting?,
        in context: ModelContext,
        now: Date = .now
    ) -> (setting: NotificationSetting, task: Task<Void, Never>) {
        var draft = draft
        draft.message = draft.message.trimmingCharacters(in: .whitespacesAndNewlines)
        let target: NotificationSetting
        if let setting {
            // 間隔の通知は登録し直すと登録した時刻から数え直しになるため、変更が無ければ何もしない
            guard setting.draft != draft else {
                return (setting, Task {})
            }
            target = setting
            target.apply(draft)
            if target.isEnabled {
                target.startDate = now
            }
        } else {
            target = NotificationSetting(message: draft.message, startDate: now, createdAt: now)
            target.apply(draft)
            context.insert(target)
        }
        save(context)
        let task = enqueue {
            await sync(target, now: now)
        }
        return (target, task)
    }

    /// 間隔の通知として、文言と間隔だけを保存する。時刻指定の項目は今の値のまま（新しく追加するなら既定値）
    @discardableResult
    func save(
        message: String,
        interval: NotificationInterval,
        to setting: NotificationSetting?,
        in context: ModelContext,
        now: Date = .now
    ) -> (setting: NotificationSetting, task: Task<Void, Never>) {
        var draft = setting?.draft ?? NotificationDraft(message: message)
        draft.message = message
        draft.kind = .interval
        draft.interval = interval
        return save(draft, to: setting, in: context, now: now)
    }

    /// 「完了するまで繰り返す」通知の、`date`（省略したら `now`）を含む期間を完了にする
    ///
    /// 完了の記録を保存し、通知を登録し直す（その期間の残りの催促を消して、次の期間の催促を補充する）。
    /// スヌーズで予約した通知と、通知センターに表示中のこの設定の通知も消す（完了したのにもう一度鳴らないように）。
    /// 完了するまで繰り返さない通知や、すでに完了済みの期間なら何もしない
    ///
    /// - Parameter date: どの期間を完了にするか。通知のアクションからは通知が届いた日時を渡す（日付が変わってから押しても、届いた日の完了にする）
    /// - Returns: 通知センターへの反映
    @discardableResult
    func complete(
        _ setting: NotificationSetting,
        in context: ModelContext,
        periodContaining date: Date? = nil,
        now: Date = .now
    ) -> Task<Void, Never> {
        let date = date ?? now
        guard let period = setting.completionPeriod(containing: date, calendar: scheduler.calendar), !setting.isCompleted(period) else {
            return Task {}
        }
        let record = CompletionRecord(periodStart: period.start, completedAt: now, setting: setting)
        context.insert(record)
        // 保存できなかったら完了にしない（催促を消したまま、完了の記録が残らない状態にしないため）
        guard save(context) else {
            context.delete(record)
            return Task {}
        }
        return enqueue {
            await scheduler.remove(id: setting.id)
            await sync(setting, now: now)
        }
    }

    /// `now` を含む期間の完了を取り消す。完了の記録を消し、その期間の残りの催促を登録し直す
    ///
    /// - Returns: 通知センターへの反映
    @discardableResult
    func undoCompletion(_ setting: NotificationSetting, in context: ModelContext, now: Date = .now) -> Task<Void, Never> {
        guard let period = setting.completionPeriod(containing: now, calendar: scheduler.calendar) else {
            return Task {}
        }
        let records = setting.completions.filter { period.contains($0.periodStart) }
        guard !records.isEmpty else {
            return Task {}
        }
        for record in records {
            context.delete(record)
        }
        save(context)
        return enqueue {
            await sync(setting, now: now)
        }
    }

    /// 通知設定を削除し、登録済みの通知も止める
    @discardableResult
    func delete(_ settings: [NotificationSetting], from context: ModelContext) -> Task<Void, Never> {
        let ids = settings.map(\.id)
        for setting in settings {
            context.delete(setting)
        }
        save(context)
        return enqueue {
            for id in ids {
                await scheduler.remove(id: id)
            }
        }
    }

    /// おやすみ時間を変えたときに、すべての通知を登録し直す
    ///
    /// おやすみ時間が無くなって登録時刻から数え直しになる通知は、起点日時を登録し直した時刻にする。
    /// おやすみ時間がある通知は時計の時刻で鳴るので、起点日時は変えない。
    @discardableResult
    func rescheduleAll(_ settings: [NotificationSetting], in context: ModelContext, now: Date = .now) -> Task<Void, Never> {
        for setting in settings where setting.isEnabled {
            if case .repeatingInterval = scheduler.plan(for: setting, now: now) {
                setting.startDate = now
            }
        }
        save(context)
        let count = requestCount(for: settings, now: now)
        if count > NotificationScheduler.pendingLimit {
            Self.logger.warning("登録する通知が上限を超えています: \(count) 件")
        }
        return enqueue {
            for setting in settings {
                await sync(setting, now: now)
            }
        }
    }

    /// 日時を過ぎた ON の 1 回だけの通知を OFF にする。もう鳴らないため。削除はせず、日時を変えて使い直せるようにする
    ///
    /// 届いた通知は OS が保留から外すので、通知センターには何もしない。
    /// - Parameter now: 日時が過ぎたかどうかの基準。分未満は切り捨てて比べる
    /// - Returns: OFF にした設定
    @discardableResult
    func disableExpiredOnce(_ settings: [NotificationSetting], in context: ModelContext, now: Date = .now) -> [NotificationSetting] {
        let expired = settings.filter { isEnabledOnce($0) && scheduler.plan(for: $0, now: now).requestCount == 0 }
        guard !expired.isEmpty else {
            return []
        }
        for setting in expired {
            setting.isEnabled = false
        }
        save(context)
        return expired
    }

    /// ON の 1 回だけの通知のうち、次に日時を迎えるもの。過ぎたものは含めない
    func nextOnceDate(in settings: [NotificationSetting], now: Date = .now) -> Date? {
        settings
            .filter { isEnabledOnce($0) && scheduler.plan(for: $0, now: now).requestCount > 0 }
            .compactMap(\.onceDate)
            .min()
    }

    /// ON の通知をすべて登録したときの通知の数。`NotificationScheduler.pendingLimit` を超えると一部が鳴らない
    func requestCount(for settings: [NotificationSetting], now: Date = .now) -> Int {
        settings
            .filter(\.isEnabled)
            .map { scheduler.plan(for: $0, now: now).requestCount }
            .reduce(0, +)
    }

    /// 設定の内容どおりに通知を登録する（OFF なら止める）
    ///
    /// - Parameter now: 1 回だけの通知の日時が過ぎたかどうかの基準
    func sync(_ setting: NotificationSetting, now: Date = .now) async {
        guard setting.isEnabled else {
            await scheduler.remove(id: setting.id)
            return
        }
        do {
            try await scheduler.schedule(setting, now: now)
        } catch {
            Self.logger.error("通知を登録できません: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 通知センターへの反映を、前に積んだ反映が終わってから行う
    private func enqueue(_ operation: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        let previous = Self.lastSync
        let task = Task {
            await previous?.value
            await operation()
        }
        Self.lastSync = task
        return task
    }

    /// ON の、時刻指定で 1 回だけの通知
    private func isEnabledOnce(_ setting: NotificationSetting) -> Bool {
        setting.isEnabled && setting.kind == .timeOfDay && setting.repeatRule == .once
    }

    /// - Returns: 保存できたかどうか
    @discardableResult
    private func save(_ context: ModelContext) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            Self.logger.error("通知設定を保存できません: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
