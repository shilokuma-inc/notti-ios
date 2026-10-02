# notti

notti の iOS アプリ（SwiftUI）。

アプリのコンセプトを見直し中のため、[shilokuma-inc/template-app-ios](https://github.com/shilokuma-inc/template-app-ios) の初期状態（Hello World）にリセットしています。
以前の「おせっかいアプリ」（タスクを完了するまで催促し続けるリマインダー）は別リポジトリで作り直します。

## Environment

- Xcode 26.3
- iOS 17.0 以上
- Swift 6（Swift 6 言語モード / Strict Concurrency）
- SwiftUI / Swift Testing / XCTest（UI テスト）
- SwiftLint 0.65.1（Build Tool Plugin）

## Status

| branch \ workflow | Build | Archive | Upload |
|---|---|---|---|
| main | [![Build](https://github.com/shilokuma-inc/notti-ios/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/shilokuma-inc/notti-ios/actions/workflows/build.yml?query=branch%3Amain) | — | — |
| develop | [![Build](https://github.com/shilokuma-inc/notti-ios/actions/workflows/build.yml/badge.svg?branch=develop)](https://github.com/shilokuma-inc/notti-ios/actions/workflows/build.yml?query=branch%3Adevelop) | — | — |

Archive / Upload は Secrets の設定待ちのため、現在は手動実行のみです（[CI](#ci) を参照）。

## セットアップ

```bash
open notti.xcodeproj
```

署名情報やバージョンは pbxproj ではなく [Configs/Project.xcconfig](Configs/Project.xcconfig) に集約しています。

| 設定 | 値 |
|---|---|
| `DEVELOPMENT_TEAM` | `CKJU28R49D` |
| `APP_BUNDLE_IDENTIFIER` | `jp.shilokuma.notti`（テストターゲットは `.Tests` / `.UITests` を付けて派生） |
| `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` | アプリのバージョン / ビルド番号 |
| `IPHONEOS_DEPLOYMENT_TARGET` | 最低サポート OS |

## CI

| ワークフロー | トリガー | 内容 |
|---|---|---|
| Build | 全ブランチ（`assets/**` を除く）への push / Fork からの PR | ビルド + テスト + SwiftLint |
| Archive | 手動実行のみ | Archive → IPA Export |
| Upload | 手動実行のみ | Archive → IPA Export → App Store Connect へアップロード |
| Cleanup assets branch | PR のマージ | PR 本文が参照している `assets/issue-<番号>` ブランチを削除 |

Archive / Upload は App Store Connect API Key で認証します。リポジトリの Settings → Secrets and variables → Actions に以下を登録したら、
template-app-ios と同じく Archive は `main`、Upload は `develop` / `release/**` への push をトリガーに戻してください。

| Secret | 内容 |
|---|---|
| `EXPORT_OPTIONS` | `ExportOptions.plist` の内容。[docs/ExportOptions.sample.plist](docs/ExportOptions.sample.plist) の `teamID` を書き換えて登録します |
| `APPLE_API_KEY_BASE64` | App Store Connect の API Key（`.p8`）を base64 エンコードした文字列 |
| `APPLE_API_KEY_ID` | API Key の Key ID |
| `APPLE_API_ISSUER_ID` | API Key の Issuer ID |

アップロード先として、App Store Connect に Bundle ID `jp.shilokuma.notti` のアプリをあらかじめ登録しておく必要があります。

## 構成

```
.
├── Configs/            # xcconfig（署名情報・バージョン・Deployment Target）
├── notti/              # アプリ本体（SwiftUI）
├── nottiTests/         # Unit テスト（Swift Testing）
├── nottiUITests/       # UI テスト（XCTest）
├── notti.xcodeproj     # 共有スキーム notti を含む
├── docs/               # ExportOptions.plist のサンプル
├── scripts/            # ralph ループ用スクリプト
├── .claude/ralph/      # ralph ループのテンプレート
├── .swiftlint.yml      # SwiftLint 設定
└── .github/
    ├── ISSUE_TEMPLATE/
    ├── pull_request_template.md
    └── workflows/
```

- プロジェクトはフォルダ同期グループ（Xcode 16 以降の形式）で管理しているため、ファイルの追加・削除で pbxproj は変わりません
- SwiftLint は Build Tool Plugin として全ターゲットに適用され、CI では `swiftlint lint --strict` としても実行されます

## License

[MIT License](LICENSE)
