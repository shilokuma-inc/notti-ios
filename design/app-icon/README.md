# アプリアイコン（`epic/app-icon`）

アプリアイコンのデザインデータ。**SVG が正本**で、PNG はプレビュー用。

- 採用案: ベル（塗り）＋未読バッジ・白背景（候補 20 案のうちの案 16。PR #162 の ask への回答で採用）
- モチーフは「通知」を表すベル。モノトーン（無彩色）でまとめる
- アイコンに文字（「notti」など）は入れない（Apple のガイドライン）
- 1024 の PNG は不透明（透過なし）にする。プレビューの `app-icon.png` は alpha チャンネルを持つ（全画素 255 で見た目は不透明）ため、App Store に出す 1024 PNG は `Tools/remove_alpha.swift` を通す

```
design/app-icon/
├── README.md                  このファイル
├── app-icon.svg               採用案の元データ（正本）
├── app-icon.png               採用案のプレビュー（1024×1024）
├── icon-layers/               Icon Composer（`.icon`）用のレイヤー素材
│   ├── background.svg         背景（白の全面塗り）
│   └── foreground.svg         モチーフ（ベル＋未読バッジ）
└── scripts/
    ├── make_app_icon.py       `app-icon.svg` とレイヤー素材を組み立てる
    └── export_png.sh          SVG からプレビューの PNG を書き出す
```

画像生成 AI は使っていない（`Discussion #160` の Q4）。幾何学的な図形だけで組んであり、
`scripts/make_app_icon.py` の座標と色を変えて組み立て直せる。

## デザイン

| 要素 | 内容 |
| --- | --- |
| ベル | 上端の丸・胴・下端の打鈴。1024 の座標系で x 236〜788 / y 186〜830 |
| 未読バッジ | 右上（中心 770, 272）の丸（半径 74）＋白いリング（半径 92） |
| 背景 | 全面を白で塗る（角丸は付けず、iOS のマスクに任せる） |

## 使っている色

すべて無彩色。

| 用途 | 値 |
| --- | --- |
| 図形（インク） | `#101010` |
| 背景・バッジのリング | `#FFFFFF` |

## アプリへの適用

- **iOS 17〜25 向け**: `app-icon.svg` から書き出した 1024 の PNG を `notti/Assets.xcassets/AppIcon.appiconset/AppIcon.png` に置く（`Tools/remove_alpha.swift` で透過を落とす）
- **`AccentColor`**: `notti/Assets.xcassets/AccentColor.colorset` にアイコンの基調色を入れる（ライト `#101010` / ダーク `#FFFFFF`）
- **iOS 26（Liquid Glass）向け**: Icon Composer で `.icon` を作る（下記）

## `.icon`（Icon Composer）の作り方

`.icon` は Icon Composer のドキュメント（`com.apple.package`）で、コマンドライン（ループ）では
作れないため、レイヤー素材だけを用意している。次の手順で作る（Icon Composer の版によって
画面の名前は変わりうるので、迷ったら素材と目的から読み替える）。

1. `/Applications/Xcode-26.6.app/Contents/Applications/Icon Composer.app` を開く
2. `icon-layers/background.svg` を背景レイヤー、`icon-layers/foreground.svg` を前景レイヤーとして読み込む（Icon Composer は SVG を読める。`CoreSVG` を同梱している）
3. Liquid Glass の見え方を確かめる（既定の外観に加えて、ダーク・ティンテッド・クリアでの見え方も切り替えて確かめる）
4. `.icon` を `notti/AppIcon.icon` として保存する（`.xcodeproj` はフォルダ同期グループなので、ファイルを置けばターゲットに入る）
5. ターゲットの App Icon の設定をどうするかを決める。いまは `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`（`notti.xcodeproj/project.pbxproj`）でアセットカタログの `AppIcon` を使っている。`.icon` に切り替えるならこの設定を変える（pbxproj に直接書かず `Configs/Project.xcconfig` に集約できるかもあわせて決める）

## 作り方（書き出し手順）

```bash
# app-icon.svg とレイヤー素材を組み立て直す（座標や色を変えたとき）
python3 design/app-icon/scripts/make_app_icon.py

# SVG からプレビューの PNG を書き出す
design/app-icon/scripts/export_png.sh

# SVG と PNG が乖離していないことを確かめる（何も出なければ一致）
design/app-icon/scripts/export_png.sh && git diff --exit-code -- design/app-icon
```

`export_png.sh` は macOS の QuickLook（`qlmanage`）で SVG を描き直す。
`qlmanage` は出力先のディレクトリが無いと何も書かずに終わるので、スクリプト側で先に作っている。
**SVG（`app-icon.svg` と `icon-layers/`）を変えたら `make_app_icon.py` と `export_png.sh` を必ず流す**（PNG は正本ではないため、片方だけを直すと乖離する）。
