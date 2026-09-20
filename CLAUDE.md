# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
xcodegen generate   # project.yml から notti.xcodeproj を生成（.xcodeproj は git 管理外）
xcodebuild -project notti.xcodeproj -scheme notti -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project notti.xcodeproj -scheme notti -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

ファイルを追加・削除したら `xcodegen generate` を再実行する（`project.yml` はディレクトリ単位で sources を拾う）。

## アーキテクチャ

**おせっかいアプリ** の iOS アプリ。登録したタスクを、完了にするまで一定間隔で催促し続けるリマインダー。

- SwiftUI + SwiftData（iOS 17+）。永続化するモデルは `TaskModel` だけで、`NottiApp` が
  `ModelContainer` を組み立てて `MainTabView` に渡す。
- 画面は `Features/` 配下に機能ごとに置き、モデルと通知まわりのロジックは `Core/` に寄せる。
- 一覧は `@Query` で未完了のタスクだけを作成日の新しい順に取る。完了・削除のときは必ず
  `NotificationManager.cancelNotifications(for:)` を呼んでから `modelContext` を更新する。
- Swift 6 の strict concurrency を complete で有効にしている。`NotificationManager` は `@MainActor` で、
  `UNUserNotificationCenterDelegate` のコールバックだけ `nonisolated` にしてある。

### 繰り返し通知の作り方

iOS のローカル通知に「完了するまで鳴らし続ける」トリガーは無いので、
`NotificationManager.scheduleNotifications(for:)` が開始時刻から `reminderIntervalMinutes` おきの
`UNCalendarNotificationTrigger` を最大 60 件まとめて予約する（保留できる通知は 1 アプリ 64 件まで）。
識別子は `"<task.id>-<連番>"` で、取り消すときは同じ連番を組み立てて一括で消す。
この上限はユーザにも見える仕様なので、設定画面のフッターの説明と合わせて変更する。
