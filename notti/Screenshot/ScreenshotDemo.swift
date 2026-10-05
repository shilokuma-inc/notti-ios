//
//  ScreenshotDemo.swift
//  notti
//

import SwiftUI

/// App Store 用スクリーンショットの撮影モード（Issue #62）。
///
/// 起動引数 `-screenshot-demo` で有効になり、`-screenshot-scene <名前>` で最初に開く画面を選ぶ。
/// 撮影は `Tools/capture_screenshots.sh` が言語・画面ごとにアプリを起動し直して行う。
/// 有効なあいだは、端末やテーマ設定によらず同じ配色で撮る。通常の起動では何も変えない。
enum ScreenshotDemo {
    /// 撮影する画面。並び順は `AppStore/screenshots.json` で決める。
    /// `Tools/app_store_config.py` がこの enum の case を読んで設定と突き合わせるので、書式（1 行 1 case）を崩さない
    enum Scene: String {
        /// 最初の画面（ContentView）
        case main
    }

    static let isEnabled = Self.isEnabled(launchArguments: ProcessInfo.processInfo.arguments)

    /// 起動引数は UserDefaults の引数ドメインに入るので、`-screenshot-scene main` をここで読める
    static let scene = resolveScene(isEnabled: isEnabled, rawValue: UserDefaults.standard.string(forKey: "screenshot-scene"))

    /// 撮影モードで固定する配色。撮影モードでなければ nil（アプリの既定のまま）
    static var colorScheme: ColorScheme? {
        preferredColorScheme(isEnabled: isEnabled)
    }

    static func isEnabled(launchArguments arguments: [String]) -> Bool {
        arguments.contains("-screenshot-demo")
    }

    /// 撮影モードのときだけ画面を選ぶ。知らない名前なら nil（最初の画面のまま）
    static func resolveScene(isEnabled: Bool, rawValue: String?) -> Scene? {
        guard isEnabled else { return nil }
        return rawValue.flatMap(Scene.init(rawValue:))
    }

    static func preferredColorScheme(isEnabled: Bool) -> ColorScheme? {
        isEnabled ? .light : nil
    }
}
