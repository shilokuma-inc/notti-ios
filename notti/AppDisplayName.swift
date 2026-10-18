//
//  AppDisplayName.swift
//  notti
//

import Foundation

/// 文言に出すアプリ名。ホーム画面・設定アプリと同じ表示名（日本語では「のっち」、それ以外では「Notti」）を使う
enum AppDisplayName {
    /// 表示名が取れないときに使う名前。アプリ内の文言は日本語なので日本語の表記にする
    static let fallback = "のっち"

    static var current: String {
        name(in: .main)
    }

    /// バンドルの表示名を、アプリの言語に合わせたローカライズ込みで返す
    static func name(in bundle: Bundle) -> String {
        guard let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
              !name.isEmpty else {
            return fallback
        }
        return name
    }
}
