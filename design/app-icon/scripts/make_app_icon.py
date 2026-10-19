#!/usr/bin/env python3
"""採用案（ベル＋未読バッジ）の元データ（SVG）を組み立てる。

    python3 design/app-icon/scripts/make_app_icon.py

次の 3 つを書き出す:

- `design/app-icon/app-icon.svg`               採用案の正本（アプリの 1024 PNG 用）
- `design/app-icon/icon-layers/background.svg` Icon Composer の背景レイヤー
- `design/app-icon/icon-layers/foreground.svg` Icon Composer の前景レイヤー

プレビューの PNG は `design/app-icon/scripts/export_png.sh` で作る。
`.icon`（Icon Composer）の作り方は `design/app-icon/README.md` を参照。

候補 20 案のうち案 16「ベル（塗り）＋未読バッジ・白背景」を採用した
（PR #162 の ask への回答）。画像生成 AI は使わず、幾何学的な図形だけで
組んでいる（モノトーン）。
"""

from __future__ import annotations

from pathlib import Path

SIZE = 1024

INK = "#101010"
BG_WHITE = "#FFFFFF"

# ベルの輪郭（1024 の座標系。上端の丸と下端の打鈴を含めて x 236〜788 / y 186〜830）
BELL_PATH = (
    "M512 246 C388 246 302 336 298 470 L290 612 C286 652 266 672 240 698 "
    "C230 708 236 724 250 724 L774 724 C788 724 794 708 784 698 "
    "C758 672 738 652 734 612 L726 470 C722 336 636 246 512 246 Z"
)

# 未読バッジ（右上）。白いリングを挟んでベルから分離する
BADGE_CENTER = (770, 272)
BADGE_RADIUS = 74
BADGE_RING = 92


def bell(fill: str) -> str:
    """ベル（塗り）を返す。上端の丸・胴・下端の打鈴の 3 つで組む。"""
    return (
        f'<circle cx="512" cy="222" r="36" fill="{fill}"/>'
        f'<path d="{BELL_PATH}" fill="{fill}"/>'
        f'<circle cx="512" cy="784" r="46" fill="{fill}"/>'
    )


def badge(fill: str, ring: str) -> str:
    """未読バッジ（リング＋丸）を返す。"""
    cx, cy = BADGE_CENTER
    return (
        f'<circle cx="{cx}" cy="{cy}" r="{BADGE_RING}" fill="{ring}"/>'
        f'<circle cx="{cx}" cy="{cy}" r="{BADGE_RADIUS}" fill="{fill}"/>'
    )


def motif() -> str:
    """モチーフ（ベル＋未読バッジ）を返す。背景は含まない。"""
    return f"{bell(fill=INK)}{badge(fill=INK, ring=BG_WHITE)}"


def svg(body: str, background: str | None) -> str:
    """`body` を載せた SVG を返す。`background` が None なら背景を描かない。"""
    lines = []
    if background:
        lines.append(f'  <rect width="{SIZE}" height="{SIZE}" fill="{background}"/>')
    if body:
        lines.append(f"  {body}")
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" '
        f'viewBox="0 0 {SIZE} {SIZE}">\n' + "\n".join(lines) + "\n</svg>\n"
    )


def outputs() -> dict[str, str]:
    """書き出すファイル（`design/app-icon/` からの相対パス）と中身を返す。"""
    return {
        "app-icon.svg": svg(motif(), BG_WHITE),
        "icon-layers/background.svg": svg("", BG_WHITE),
        "icon-layers/foreground.svg": svg(motif(), None),
    }


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    for relative, content in outputs().items():
        destination = root / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(content, encoding="utf-8")
        print(f"{destination} を書き出しました")


if __name__ == "__main__":
    main()
