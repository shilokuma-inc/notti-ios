//
//  ScreenshotDemoTests.swift
//  nottiTests
//

@testable import notti
import SwiftUI
import Testing

/// 撮影モードは起動引数 `-screenshot-demo` が無い通常の起動では何も変えないことを確かめる
struct ScreenshotDemoTests {
    @Test
    func isDisabledWithoutLaunchArgument() {
        #expect(!ScreenshotDemo.isEnabled(launchArguments: ["notti"]))
        #expect(!ScreenshotDemo.isEnabled(launchArguments: ["notti", "-screenshot-scene", "main"]))
    }

    @Test
    func isEnabledWithLaunchArgument() {
        #expect(ScreenshotDemo.isEnabled(launchArguments: ["notti", "-screenshot-demo"]))
    }

    /// テストの実行時は起動引数を付けていないので、アプリ全体でも無効になっている
    @Test
    func isDisabledInTestRun() {
        #expect(!ScreenshotDemo.isEnabled)
        #expect(ScreenshotDemo.scene == nil)
        #expect(ScreenshotDemo.colorScheme == nil)
    }

    @Test
    func sceneIsIgnoredWhenDisabled() {
        #expect(ScreenshotDemo.resolveScene(isEnabled: false, rawValue: "main") == nil)
    }

    @Test
    func sceneIsResolvedWhenEnabled() {
        #expect(ScreenshotDemo.resolveScene(isEnabled: true, rawValue: "main") == .main)
        #expect(ScreenshotDemo.resolveScene(isEnabled: true, rawValue: "unknown") == nil)
        #expect(ScreenshotDemo.resolveScene(isEnabled: true, rawValue: nil) == nil)
    }

    @Test
    func colorSchemeIsFixedOnlyWhenEnabled() {
        #expect(ScreenshotDemo.preferredColorScheme(isEnabled: true) == .light)
        #expect(ScreenshotDemo.preferredColorScheme(isEnabled: false) == nil)
    }
}
