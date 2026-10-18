//
//  BundleDisplayNameTests.swift
//  nottiTests
//

import Foundation
import Testing

/// ホーム画面の表示名が、日本語では「のっち」・それ以外の言語では「Notti」になることを確かめる。
/// 既定値は notti/Info.plist、言語ごとの値は notti/InfoPlist.xcstrings にある
struct BundleDisplayNameTests {
    /// ローカライズの無い言語で使われる既定の表示名
    @Test
    func defaultDisplayNameIsNotti() throws {
        let name = try #require(Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
        #expect(name == "Notti")
    }

    /// 識別子として使う PRODUCT_NAME（バイナリ名・モジュール名）は変えていない
    @Test
    func executableNameIsUnchanged() {
        #expect(Bundle.main.infoDictionary?["CFBundleExecutable"] as? String == "notti")
        #expect(Bundle.main.bundleIdentifier == "jp.shilokuma.notti")
    }

    @Test
    func bundleHasJapaneseLocalization() {
        #expect(Bundle.main.localizations.contains("ja"))
    }

    @Test(arguments: [("ja", "のっち"), ("en", "Notti")])
    func localizedDisplayName(localization: String, expected: String) throws {
        let strings = try infoPlistStrings(localization: localization)
        #expect(strings["CFBundleDisplayName"] == expected)
        #expect(strings["CFBundleName"] == expected)
    }

    private func infoPlistStrings(localization: String) throws -> [String: String] {
        let path = try #require(
            Bundle.main.path(
                forResource: "InfoPlist",
                ofType: "strings",
                inDirectory: nil,
                forLocalization: localization
            ),
            "\(localization).lproj/InfoPlist.strings がアプリのバンドルに無い"
        )
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String])
    }
}
