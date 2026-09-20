# notti-ios

**おせっかいアプリ** の iOS アプリ。やることを登録しておくと、指定した時刻から一定間隔で
「まだ終わっていませんか？」と通知し続け、完了にするまで催促する。

タスク一覧とカレンダーの 2 画面をタブで切り替える。タスクは SwiftData で永続化し、リマインドは
ローカル通知をまとめて予約することで繰り返しを再現している（iOS の保留通知数の上限に合わせて
タスクあたり最大 60 件）。

## Status

| branch \ workflow | Build | Archive | Upload |
|---|---|---|---|
| main | [![Build](https://github.com/shilokuma-inc/notti-ios/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/shilokuma-inc/notti-ios/actions/workflows/build.yml?query=branch%3Amain) | [![Archive](https://github.com/shilokuma-inc/notti-ios/actions/workflows/archive.yml/badge.svg?branch=main)](https://github.com/shilokuma-inc/notti-ios/actions/workflows/archive.yml?query=branch%3Amain) | — |
| develop | [![Build](https://github.com/shilokuma-inc/notti-ios/actions/workflows/build.yml/badge.svg?branch=develop)](https://github.com/shilokuma-inc/notti-ios/actions/workflows/build.yml?query=branch%3Adevelop) | [![Archive](https://github.com/shilokuma-inc/notti-ios/actions/workflows/archive.yml/badge.svg?branch=develop)](https://github.com/shilokuma-inc/notti-ios/actions/workflows/archive.yml?query=branch%3Adevelop) | — |

## CI

GitHub Actions（`.github/workflows/`）。どのワークフローも最初に `xcodegen generate` で `.xcodeproj` を生成する。

| ワークフロー | トリガー | 内容 |
|---|---|---|
| Build | 全ブランチへの push と PR | シミュレータでビルドしてユニットテストを実行 |
| Archive | 全ブランチへの push | Release 構成で署名せずにアーカイブする |
| Upload | 手動実行のみ | アーカイブを署名して IPA を書き出し、TestFlight へアップロードする |

ビルド番号 (`CFBundleVersion`) はワークフローの `run_number` で上書きする。Upload には次の Secrets が必要で、
未設定のあいだは自動実行できないため `workflow_dispatch` だけにしてある。設定後は main 以外への push を
トリガーに戻す。

| Secret | 内容 |
|---|---|
| `EXPORT_OPTIONS` | `ExportOptions.plist` の中身 |
| `APPLE_API_KEY_BASE64` | App Store Connect API キー (`.p8`) を base64 にしたもの |
| `APPLE_API_KEY_ID` | 同キーの Key ID |
| `APPLE_API_ISSUER_ID` | 同キーの Issuer ID |

署名もアップロードもこの API キーで行う。Upload が通るには、App Store Connect に Bundle ID
`ml.mrs1669.notti` のアプリがあらかじめ登録されている必要がある。

## 環境

- Xcode 27 / iOS 17.0 以上
- Swift 6（strict concurrency: complete）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）

## セットアップ

`.xcodeproj` はコミットせず、`project.yml` から生成する。

```bash
xcodegen generate
open notti.xcodeproj
```

コマンドラインでのビルドとテスト:

```bash
xcodebuild -project notti.xcodeproj -scheme notti \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

```bash
xcodebuild -project notti.xcodeproj -scheme notti \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## 構成

```
notti/
  App/            NottiApp（入口と ModelContainer）, MainTabView（2 タブ）
  Core/           TaskModel（SwiftData のモデル）, NotificationManager（通知の許可と予約）
  Features/
    Task/         TaskListView（未完了の一覧）, TaskCreateView, TaskEditView
    Calendar/     CalendarView（月表示と日別のタスク）
    Settings/     SettingsView（通知の許可状況）
  Resources/      Assets.xcassets
nottiTests/       Swift Testing によるユニットテスト
```

アプリアイコンはまだ用意しておらず、`Assets.xcassets/AppIcon.appiconset` は枠だけ置いてある。

## ライセンス

MIT
