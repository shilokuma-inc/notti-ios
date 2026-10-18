# アプリアイコン（`epic/app-icon`）

アプリアイコンのデザインデータ。**SVG が正本**で、PNG はプレビュー用。

- 採用案: ベル（塗り）＋未読バッジ・白背景（候補 20 案のうちの案 16。Discussion #160 の ask への回答で採用）
- モチーフは「通知」を表すベル。モノトーン（無彩色）でまとめる
- アイコンに文字（「notti」など）は入れない（Apple のガイドライン）
- 1024 の PNG は不透明（透過なし）にする。プレビューの `app-icon.png` は alpha チャンネルを持つ（全画素 255 で見た目は不透明）ため、App Store に出す 1024 PNG は `Tools/remove_alpha.swift` を通す

```
design/app-icon/
├── README.md                 このファイル
├── app-icon.svg              採用案の元データ（正本）
├── app-icon.png              採用案のプレビュー（1024×1024）
└── scripts/
    ├── make_app_icon.py      `app-icon.svg` を組み立てる
    └── export_png.sh         SVG からプレビューの PNG を書き出す
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

## 作り方（書き出し手順）

```bash
# app-icon.svg を組み立て直す（座標や色を変えたとき）
python3 design/app-icon/scripts/make_app_icon.py

# SVG からプレビューの PNG を書き出す
design/app-icon/scripts/export_png.sh

# SVG と PNG が乖離していないことを確かめる（何も出なければ一致）
design/app-icon/scripts/export_png.sh && git diff --exit-code -- design/app-icon
```

`export_png.sh` は macOS の QuickLook（`qlmanage`）で SVG を描き直す。
`qlmanage` は出力先のディレクトリが無いと何も書かずに終わるので、スクリプト側で先に作っている。
**SVG（`app-icon.svg`）を変えたら `export_png.sh` を必ず流す**（PNG は正本ではないため、片方だけを直すと乖離する）。
