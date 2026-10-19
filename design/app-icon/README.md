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
│                             （`make_app_icon.py` の出力。`notti/AppIcon.icon/Assets/` へコピーする）
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
- **iOS 26（Liquid Glass）向け**: Icon Composer の `.icon` を `notti/AppIcon.icon` としてリポジトリに含めている（下記）

## `.icon`（Icon Composer）の作り方

`.icon` は Icon Composer のドキュメント（`com.apple.package`）で、`notti/AppIcon.icon` として
リポジトリに含めている。中身は `icon.json` と `Assets/`（レイヤー画像）だけなので、
Icon Composer の GUI を使わずコマンドラインでも作り直せる。

- `groups` は**先頭が最前面**の順。逆にすると背景レイヤーがモチーフを覆って真っ白になる
- レイヤー画像は SVG のままでよい（PNG 化は不要。Icon Composer は `CoreSVG` を同梱している）
- `fill` は背景レイヤーの下に隠れて見えないため、背景の色は背景レイヤーの SVG で決める

作り直すときは、`make_app_icon.py` で作ったレイヤー素材を `Assets/` へコピーする:

```bash
mkdir -p notti/AppIcon.icon/Assets
cp design/app-icon/icon-layers/foreground.svg design/app-icon/icon-layers/background.svg notti/AppIcon.icon/Assets/
```

`notti/AppIcon.icon/icon.json` はリポジトリにあるものをそのまま使う（`groups` の順番は変えない）。

GUI なしで見た目を確かめるには `ictool` の `--export-image` を使う（真っ白ならグループ順のミス）:

```bash
"/Applications/Xcode-26.6.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" \
  notti/AppIcon.icon --export-image --output-file /tmp/appicon-check.png \
  --platform iOS --rendition Default --width 1024 --height 1024 --scale 1
```

`/tmp/appicon-check.png` に白地・黒のベル・未読バッジ（右上）が出ること
（画像を目視できないときの目安: ベルが出ていれば 270KB 前後、真っ白なら 60KB 前後）。

ターゲットの App Icon の設定は `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`
（`notti.xcodeproj/project.pbxproj`）のままでよい。アセットカタログの `AppIcon`
（iOS 17〜25 用の 1024 PNG）と `AppIcon.icon` が両方あっても actool は警告なく処理し、
`.icon` を優先する（レガシーサイズも `.icon` から生成される。2026-10-19 にシミュレータの
ホーム画面で確認）。`AppIcon.appiconset` は消さない。

## 作り方（書き出し手順）

座標・色の正本は `make_app_icon.py`（スクリプト内の定数）。SVG はその出力なので、
SVG を手で直さずスクリプトを編集して組み立て直す:

```bash
# app-icon.svg とレイヤー素材（icon-layers/）を組み立て直す
python3 design/app-icon/scripts/make_app_icon.py

# レイヤー素材を .icon へコピーし直す
mkdir -p notti/AppIcon.icon/Assets
cp design/app-icon/icon-layers/foreground.svg design/app-icon/icon-layers/background.svg notti/AppIcon.icon/Assets/

# SVG からプレビューの PNG を書き出す
design/app-icon/scripts/export_png.sh

# SVG・PNG・.icon のレイヤーが乖離していないことを確かめる（何も出なければ一致）
git diff --exit-code -- design/app-icon notti/AppIcon.icon
```

`export_png.sh` は macOS の QuickLook（`qlmanage`）で SVG を描き直す。
`qlmanage` は出力先のディレクトリが無いと何も書かずに終わるので、スクリプト側で先に作っている。
