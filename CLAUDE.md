# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
xcodebuild -project notti.xcodeproj -scheme notti -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project notti.xcodeproj -scheme notti -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

SwiftLint は Build Tool Plugin として動く。コマンドラインで初回ビルドするときはプラグインの検証を
スキップする（`-skipPackagePluginValidation`）か、Xcode で一度プラグインを信頼しておく。

## アーキテクチャ

shilokuma-inc/template-app-ios から作った SwiftUI アプリ。アプリのコンセプトは見直し中で、
中身はテンプレートの初期状態（`NottiApp` → `ContentView` の Hello World）にリセットしてある。

- `.xcodeproj` はコミットしている。フォルダ同期グループなので、ファイルの追加・削除で pbxproj を触る必要はない。
- 署名情報・Bundle ID・バージョン・Deployment Target は `Configs/Project.xcconfig` に集約し、pbxproj には書かない。
- Swift 6 言語モード（strict concurrency complete）。
- テストは `nottiTests`（Swift Testing）と `nottiUITests`（XCTest）。
- CI は `.github/workflows/_build.yml` / `_archive.yml` を再利用ワークフローとして呼ぶ。
  Archive / Upload は Secrets 未設定のため手動実行のみにしてある。
