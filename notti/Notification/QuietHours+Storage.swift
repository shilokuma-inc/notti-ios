//
//  QuietHours+Storage.swift
//  notti
//

import Foundation

/// おやすみ時間を UserDefaults に保存する。画面からは同じキーを `@AppStorage` で読み書きする
nonisolated extension QuietHours {
    enum StorageKey {
        static let isEnabled = "quietHours.isEnabled"
        /// 0 時 0 分からの分数
        static let start = "quietHours.startMinutes"
        /// 0 時 0 分からの分数
        static let end = "quietHours.endMinutes"
    }

    init(isEnabled: Bool, startMinutes: Int, endMinutes: Int) {
        self.init(
            isEnabled: isEnabled,
            start: TimeOfDay(minutesSinceMidnight: startMinutes),
            end: TimeOfDay(minutesSinceMidnight: endMinutes)
        )
    }

    /// 保存済みのおやすみ時間。保存されていなければ既定値（無効）
    static func load(from defaults: UserDefaults) -> Self {
        let isEnabled = defaults.object(forKey: StorageKey.isEnabled) as? Bool ?? Self.default.isEnabled
        let start = defaults.object(forKey: StorageKey.start) as? Int ?? Self.default.start.minutesSinceMidnight
        let end = defaults.object(forKey: StorageKey.end) as? Int ?? Self.default.end.minutesSinceMidnight
        return Self(isEnabled: isEnabled, startMinutes: start, endMinutes: end)
    }

    func save(to defaults: UserDefaults) {
        defaults.set(isEnabled, forKey: StorageKey.isEnabled)
        defaults.set(start.minutesSinceMidnight, forKey: StorageKey.start)
        defaults.set(end.minutesSinceMidnight, forKey: StorageKey.end)
    }
}

nonisolated extension TimeOfDay {
    /// 0 時 0 分からの分数から作る。1 日を超える分は切り捨てる
    init(minutesSinceMidnight: Int) {
        let minutes = ((minutesSinceMidnight % 1440) + 1440) % 1440
        self.init(hour: minutes / 60, minute: minutes % 60)
    }
}
