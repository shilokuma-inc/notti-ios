//
//  AppDisplayNameTests.swift
//  nottiTests
//

import Foundation
@testable import notti
import Testing

/// 文言に出すアプリ名が、バンドルの表示名（無ければ「のっち」）になることを確かめる
struct AppDisplayNameTests {
    @Test
    func usesBundleDisplayName() {
        let expected = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        #expect(AppDisplayName.current == expected ?? AppDisplayName.fallback)
        #expect(!AppDisplayName.current.isEmpty)
    }

    /// 表示名を持たないバンドルでは日本語の表記「のっち」にする
    @Test
    func fallsBackToJapaneseName() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppDisplayNameTests-\(UUID().uuidString).bundle")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bundle = try #require(Bundle(url: directory))
        #expect(AppDisplayName.name(in: bundle) == "のっち")
    }
}
