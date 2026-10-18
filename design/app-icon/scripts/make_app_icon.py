#!/usr/bin/env python3
"""採用案（ベル＋未読バッジ）の元データ（SVG）を組み立てる。

    python3 design/app-icon/scripts/make_app_icon.py

`design/app-icon/app-icon.svg`（元データ・正本）を書き出す。プレビューの PNG は
`design/app-icon/scripts/export_png.sh` で作る。

候補 20 案のうち案 16「ベル（塗り）＋未読バッジ・白背景」を採用した
（Discussion #160 の ask への回答）。画像生成 AI は使わず、幾何学的な図形だけで
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


def app_icon_svg() -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" '
        f'viewBox="0 0 {SIZE} {SIZE}">\n'
        f'  <rect width="{SIZE}" height="{SIZE}" fill="{BG_WHITE}"/>\n'
        f"  {bell(fill=INK)}{badge(fill=INK, ring=BG_WHITE)}\n"
        "</svg>\n"
    )


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    destination = root / "app-icon.svg"
    destination.write_text(app_icon_svg(), encoding="utf-8")
    print(f"{destination} を書き出しました")


if __name__ == "__main__":
    main()
