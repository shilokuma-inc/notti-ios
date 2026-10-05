//
//  StoredQuietHours.swift
//  notti
//

import SwiftUI

/// 保存済みのおやすみ時間を画面から読み書きする。変わると画面が更新される
@propertyWrapper
struct StoredQuietHours: DynamicProperty {
    @AppStorage(QuietHours.StorageKey.isEnabled) private var isEnabled = QuietHours.default.isEnabled
    @AppStorage(QuietHours.StorageKey.start) private var start = QuietHours.default.start.minutesSinceMidnight
    @AppStorage(QuietHours.StorageKey.end) private var end = QuietHours.default.end.minutesSinceMidnight

    var wrappedValue: QuietHours {
        get {
            QuietHours(isEnabled: isEnabled, startMinutes: start, endMinutes: end)
        }
        nonmutating set {
            isEnabled = newValue.isEnabled
            start = newValue.start.minutesSinceMidnight
            end = newValue.end.minutesSinceMidnight
        }
    }
}
