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
| main | [![Build](https://github.com/shilokuma-inc/notti-ios/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/shilokuma-inc/notti-ios/actions/workflows/build.yml?query=branch%3Amain) | [![Archive](https://github.com/shilokuma-inc/notti-ios/actions/workflows/archive.yml/badge.svg?branch=main)](https://github.com/shilokuma-inc/notti-ios/actions/workflows/archive.yml?query=branch%3Amain) | — |
| develop | [![Build](https://github.com/shilokuma-inc/notti-ios/actions/workflows/build.yml/badge.svg?branch=develop)](https://github.com/shilokuma-inc/notti-ios/actions/workflows/build.yml?query=branch%3Adevelop) | — | [![Upload](https://github.com/shilokuma-inc/notti-ios/actions/workflows/upload.yml/badge.svg?branch=develop)](https://github.com/shilokuma-inc/notti-ios/actions/workflows/upload.yml?query=branch%3Adevelop) |

## セットアップ

```bash
open notti.xcodeproj
```

署名情報やバージョンは pbxproj ではなく [Configs/Project.xcconfig](Configs/Project.xcconfig) に集約しています。

| 設定 | 値 |
|---|---|
| `DEVELOPMENT_TEAM` | `XU74X3434S` |
| `APP_BUNDLE_IDENTIFIER` | `jp.shilokuma.notti`（テストターゲットは `.Tests` / `.UITests` を付けて派生） |
| `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` | アプリのバージョン / ビルド番号 |
| `IPHONEOS_DEPLOYMENT_TARGET` | 最低サポート OS |

## CI

| ブランチ・イベント | Build（ビルド + テスト + SwiftLint） | Archive（IPA Export） | Upload（App Store Connect） |
|---|:-:|:-:|:-:|
| `main` | ✅ | ✅ | |
| `develop` | ✅ | | ✅ |
| `release/**` | ✅ | | ✅ |
| その他の作業ブランチ（`epic/**` を含む） | ✅（Unit テストのみ） | | |
| Pull Request の作成時（opened / reopened / ready_for_review） | ✅ | | |
| Fork からの Pull Request | ✅ | | |
| 手動実行（workflow_dispatch） | | ✅ | ✅ |
| `assets/**`（PR 用スクリーンショット置き場） | | | |

- Upload は Archive → IPA Export を含むため、`develop` / `release/**` では Archive を別途実行しません
- ドキュメントだけの変更（`**/*.md`、`docs/**`）では Build を実行しません。Upload（`develop` / `release/**` への push）と Archive（`main` への push）は、ドキュメントだけの変更でも実行します
- 作業ブランチへの push では、時間のかかる UI テスト（`nottiUITests`）を省いて Unit テストだけ実行します。UI テストは Pull Request の作成時と `main` / `develop` / `release/**` への push で実行します。Fork からの Pull Request は push で実行されないため、更新（synchronize）を含むすべてのイベントで UI テストまで実行します
- Xcode のバージョンは [.github/workflows/_build.yml](.github/workflows/_build.yml) と [.github/workflows/_archive.yml](.github/workflows/_archive.yml) の `xcode-version` で固定しています

そのほかのワークフロー:

| ワークフロー | トリガー | 内容 |
|---|---|---|
| Cleanup assets branch | PR のマージ | PR 本文が参照している `assets/issue-<番号>` ブランチを削除 |
| Close goal Discussion | `epic-final` ラベルの PR が `develop` にマージされたとき | PR 本文の目印で指定されたゴール元の Discussion を解決済みで閉じる |

### Secrets

Archive / Upload は App Store Connect API Key で認証します。Secrets は shilokuma-inc の **org Secrets** を `secrets: inherit` で使うため、リポジトリに Secrets を登録する必要はありません。

| Secret | 内容 |
|---|---|
| `EXPORT_OPTIONS` | `ExportOptions.plist` の内容（[docs/ExportOptions.sample.plist](docs/ExportOptions.sample.plist) が雛形） |
| `APPLE_API_KEY_BASE64` | App Store Connect の API Key（`.p8`）を base64 エンコードした文字列 |
| `APPLE_API_KEY_ID` | API Key の Key ID |
| `APPLE_API_ISSUER_ID` | API Key の Issuer ID |

### App Store Connect のアプリ

Bundle ID・証明書・プロビジョニングプロファイルは、Export のときに API Key で自動的に作成されます（`-allowProvisioningUpdates`）。
App Store Connect でのアプリ作成だけは API で行えないため、チーム `XU74X3434S` で Web 画面から作成します。

Upload ワークフローはアップロードの前にアプリの有無を確認し（[.github/scripts/check-app-store-app.rb](.github/scripts/check-app-store-app.rb)）、`jp.shilokuma.notti` のアプリが無ければ「新規アプリ」画面に入力する値（名前・バンドル ID・SKU など）を Job Summary に表示して止まります。表示された値でアプリを作成してから、ワークフローを再実行してください。

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
    ├── scripts/        # check-app-store-app.rb（App Store Connect のアプリの有無を確認）
    └── workflows/
```

- プロジェクトはフォルダ同期グループ（Xcode 16 以降の形式）で管理しているため、ファイルの追加・削除で pbxproj は変わりません
- SwiftLint は Build Tool Plugin として全ターゲットに適用され、CI では `swiftlint lint --strict` としても実行されます

## License

[MIT License](LICENSE)
