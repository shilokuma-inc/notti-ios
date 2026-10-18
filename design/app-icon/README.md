# アプリアイコン（`epic/app-icon`）

アプリアイコンのデザインデータ。**SVG が正本**で、PNG はプレビュー用。

- モチーフは「通知」を表すベルと吹き出し。モノトーン（グレースケール）でまとめる
- アイコンに文字（「notti」など）は入れない（Apple のガイドライン）
- 1024 の PNG は不透明（透過なし）にする。透過を落とすには `Tools/remove_alpha.swift` を使う

```
design/app-icon/
├── README.md                  このファイル
├── overview.svg / overview.png  全 20 案の一覧（番号つき）
├── candidates/NN.svg          候補の元データ（正本）
├── candidates/NN.png          候補のプレビュー（1024×1024）
└── scripts/
    ├── make_candidates.py     候補の SVG を組み立てる
    └── export_png.sh          SVG からプレビューの PNG を書き出す
```

画像生成 AI は使っていない（`Discussion #160` の Q4）。幾何学的な図形だけで組んであり、
`scripts/make_candidates.py` の座標と色を変えると全案を作り直せる。

## 候補の一覧

| 案 | ファイル | デザイン |
| --- | --- | --- |
| 01 | `candidates/01.svg` | ベル（塗り）・白背景 |
| 02 | `candidates/02.svg` | ベル（塗り）・淡グレー背景 |
| 03 | `candidates/03.svg` | ベル（塗り）・黒背景（反転） |
| 04 | `candidates/04.svg` | ベル（グラデーション塗り）・白背景 |
| 05 | `candidates/05.svg` | ベル（濃グレー塗り＋黒い輪郭線）・淡グレー背景 |
| 06 | `candidates/06.svg` | ベル（極太の線画）・白背景 |
| 07 | `candidates/07.svg` | ベル（細い線画）・白背景 |
| 08 | `candidates/08.svg` | ベル（中太の線画）・淡グレー背景 |
| 09 | `candidates/09.svg` | ベル（線画）・黒背景 |
| 10 | `candidates/10.svg` | ベル（線画＋淡いオフセット線で立体感）・白背景 |
| 11 | `candidates/11.svg` | 吹き出し（塗り）＋白い 3 点・白背景 |
| 12 | `candidates/12.svg` | 吹き出し（線画）＋黒い 3 点・白背景 |
| 13 | `candidates/13.svg` | 吹き出し（塗り）＋黒い 3 点・黒背景 |
| 14 | `candidates/14.svg` | 吹き出し（線画）の中にベル（塗り）・淡グレー背景 |
| 15 | `candidates/15.svg` | 吹き出し（塗り）の中に白いベル・白背景 |
| 16 | `candidates/16.svg` | ベル（塗り）＋未読バッジ・白背景 |
| 17 | `candidates/17.svg` | ベル（塗り）＋波紋・淡グレー背景 |
| 18 | `candidates/18.svg` | ベル（塗り）＋淡いハロー（光）・黒背景 |
| 19 | `candidates/19.svg` | 角丸四角のパネルの中にベル・淡グレー背景 |
| 20 | `candidates/20.svg` | 円枠の中にベル（塗り）・白背景 |

## 使っている色

すべて無彩色。モノトーンの階調は次の値で統一している。

| 用途 | 値 |
| --- | --- |
| 図形（インク） | `#101010` |
| 図形（濃いグレー） | `#4A4A4A` |
| 図形（グレー） | `#7A7A7A` |
| 図形（淡いグレー・オフセット線） | `#C9C9C9` |
| 背景（白） | `#FFFFFF` |
| 背景（淡グレー） | `#F2F2F2` |
| 背景（黒） | `#121212` |
| 背景（黒・少し明るい） | `#1E1E1E` |

## 作り方（書き出し手順）

```bash
# 候補の SVG を組み立て直す（座標や色を変えたとき）
python3 design/app-icon/scripts/make_candidates.py

# SVG からプレビューの PNG を書き出す
design/app-icon/scripts/export_png.sh
```

`export_png.sh` は macOS の QuickLook（`qlmanage`）で SVG を描き直す。
`qlmanage` は出力先のディレクトリが無いと何も書かずに終わるので、スクリプト側で先に作っている。

## 採用案の決め方

`epic/app-icon` の PR の ask コメント（`回答: 案 N`）で選ぶ。採用が決まったら、
採用されなかったものを片付け、採用案の元データ・プレビュー・書き出し手順だけを残す。
