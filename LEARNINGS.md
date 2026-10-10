# LEARNINGS

ループで作業して分かった、繰り返しハマりそうなことを残す。既存の行は書き換えずに追記する。

- コマンドラインの `xcodebuild test` が `Failed to clone device named 'iPhone 17 Pro'`（device remained in Creating state）で落ちることがある。テストの失敗ではなく並列テストの Simulator の複製の失敗なので、`-parallel-testing-enabled NO` を付けて流し直す
