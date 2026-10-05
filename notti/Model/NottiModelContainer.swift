//
//  NottiModelContainer.swift
//  notti
//

import SwiftData

/// アプリで使う ModelContainer を作る
enum NottiModelContainer {
    static let schema = Schema([NotificationSetting.self])
    /// 起動引数にこれがあれば、保存先をメモリ上にする（UI テスト用）
    static let inMemoryLaunchArgument = "-inMemoryStore"

    /// - Parameter inMemory: true ならディスクに保存しない（テスト・プレビュー用）
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
