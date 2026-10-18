#!/usr/bin/env python3
"""アプリアイコンの候補（モノトーン・通知モチーフ）の SVG を生成する。

    python3 design/app-icon/scripts/make_candidates.py

`design/app-icon/candidates/NN.svg`（元データ）と、全案を並べた
`design/app-icon/overview.svg` を書き出す。プレビューの PNG は
`design/app-icon/scripts/export_png.sh` で作る（SVG が正本）。

画像生成 AI は使わず、幾何学的な図形だけで組んでいる（モノトーン）。
"""

from __future__ import annotations

from pathlib import Path

SIZE = 1024

INK = "#101010"
INK_SOFT = "#2E2E2E"
GRAY_DARK = "#4A4A4A"
GRAY = "#7A7A7A"
GRAY_LIGHT = "#C9C9C9"
BG_WHITE = "#FFFFFF"
BG_LIGHT = "#F2F2F2"
BG_DARK = "#121212"
BG_DARK_SOFT = "#1E1E1E"

# ベルの輪郭（1024 の座標系。x 236〜788 / y 176〜830 に収まる）
BELL_PATH = (
    "M512 246 C388 246 302 336 298 470 L290 612 C286 652 266 672 240 698 "
    "C230 708 236 724 250 724 L774 724 C788 724 794 708 784 698 "
    "C758 672 738 652 734 612 L726 470 C722 336 636 246 512 246 Z"
)

# 吹き出しの輪郭（1024 の座標系。尻尾は左下に伸ばす）
BUBBLE_PATH = (
    "M300 260 H724 C780 260 824 304 824 360 V600 C824 656 780 700 724 700 "
    "H482 L330 806 L372 700 H300 C244 700 200 656 200 600 V360 "
    "C200 304 244 260 300 260 Z"
)

# ベルの中心（他の図形の中に収めるときの基準）
BELL_CENTER = (512, 511)


def place(cx: float, cy: float, scale: float) -> str:
    """ベルの中心が (cx, cy) に来るように拡大縮小して置く transform を返す。"""
    bx, by = BELL_CENTER
    return f"translate({cx} {cy}) scale({scale}) translate({-bx} {-by})"


def bell(fill: str | None = None, stroke: str | None = None, width: int = 40,
         transform: str | None = None) -> str:
    """ベル（塗り・線画・両方）を返す。"""
    elements = []
    if fill:
        elements += [
            f'<circle cx="512" cy="222" r="36" fill="{fill}"/>',
            f'<path d="{BELL_PATH}" fill="{fill}"/>',
            f'<circle cx="512" cy="784" r="46" fill="{fill}"/>',
        ]
    if stroke:
        elements += [
            f'<path d="M480 244 A 32 32 0 0 1 544 244" fill="none" stroke="{stroke}" '
            f'stroke-width="{width}" stroke-linecap="round"/>',
            f'<path d="{BELL_PATH}" fill="none" stroke="{stroke}" stroke-width="{width}" '
            f'stroke-linejoin="round"/>',
            f'<circle cx="512" cy="786" r="44" fill="none" stroke="{stroke}" stroke-width="{width}"/>',
        ]
    body = "".join(elements)
    return f'<g transform="{transform}">{body}</g>' if transform else body


def bubble(fill: str | None = None, stroke: str | None = None, width: int = 40) -> str:
    """吹き出しを返す。"""
    if fill:
        return f'<path d="{BUBBLE_PATH}" fill="{fill}"/>'
    return (
        f'<path d="{BUBBLE_PATH}" fill="none" stroke="{stroke}" stroke-width="{width}" '
        'stroke-linejoin="round"/>'
    )


def dots(color: str, radius: int = 46) -> str:
    """吹き出しの中の 3 点リーダー。"""
    return "".join(
        f'<circle cx="{x}" cy="480" r="{radius}" fill="{color}"/>' for x in (372, 512, 652)
    )


def gradient(id_: str, top: str, bottom: str) -> str:
    return (
        f'<defs><linearGradient id="{id_}" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/>'
        "</linearGradient></defs>"
    )


def ripple() -> str:
    """ベルから左右に広がる波紋（通知が鳴っている様子）。"""
    return (
        f'<path d="M196 372 C 148 466 148 558 196 652" fill="none" stroke="{GRAY}" '
        'stroke-width="40" stroke-linecap="round"/>'
        f'<path d="M828 372 C 876 466 876 558 828 652" fill="none" stroke="{GRAY}" '
        'stroke-width="40" stroke-linecap="round"/>'
    )


CANDIDATES = [
    dict(
        title="ベル（塗り）・白背景",
        bg=BG_WHITE,
        elements=[bell(fill=INK)],
    ),
    dict(
        title="ベル（塗り）・淡グレー背景",
        bg=BG_LIGHT,
        elements=[bell(fill=INK)],
    ),
    dict(
        title="ベル（塗り）・黒背景（反転）",
        bg=BG_DARK,
        elements=[bell(fill=BG_WHITE)],
    ),
    dict(
        title="ベル（グラデーション塗り）・白背景",
        bg=BG_WHITE,
        elements=[gradient("g4", "#8F8F8F", INK), bell(fill="url(#g4)")],
    ),
    dict(
        title="ベル（濃グレー塗り＋黒い輪郭線）・淡グレー背景",
        bg=BG_LIGHT,
        elements=[bell(fill=GRAY_DARK), bell(stroke=INK, width=30)],
    ),
    dict(
        title="ベル（極太の線画）・白背景",
        bg=BG_WHITE,
        elements=[bell(stroke=INK, width=56)],
    ),
    dict(
        title="ベル（細い線画）・白背景",
        bg=BG_WHITE,
        elements=[bell(stroke=INK, width=26)],
    ),
    dict(
        title="ベル（中太の線画）・淡グレー背景",
        bg=BG_LIGHT,
        elements=[bell(stroke=INK, width=40)],
    ),
    dict(
        title="ベル（線画）・黒背景",
        bg=BG_DARK_SOFT,
        elements=[bell(stroke=BG_WHITE, width=44)],
    ),
    dict(
        title="ベル（線画＋淡いオフセット線で立体感）・白背景",
        bg=BG_WHITE,
        elements=[bell(stroke=GRAY_LIGHT, width=34, transform="translate(-30 -30)"),
                  bell(stroke=INK, width=34)],
    ),
    dict(
        title="吹き出し（塗り）＋白い 3 点・白背景",
        bg=BG_WHITE,
        elements=[bubble(fill=INK), dots(BG_WHITE)],
    ),
    dict(
        title="吹き出し（線画）＋黒い 3 点・白背景",
        bg=BG_WHITE,
        elements=[bubble(stroke=INK, width=40), dots(INK)],
    ),
    dict(
        title="吹き出し（塗り）＋黒い 3 点・黒背景",
        bg=BG_DARK,
        elements=[bubble(fill=BG_WHITE), dots(INK)],
    ),
    dict(
        title="吹き出し（線画）の中にベル（塗り）・淡グレー背景",
        bg=BG_LIGHT,
        elements=[bubble(stroke=INK, width=36), bell(fill=INK, transform=place(512, 470, 0.55))],
    ),
    dict(
        title="吹き出し（塗り）の中に白いベル・白背景",
        bg=BG_WHITE,
        elements=[bubble(fill=INK), bell(fill=BG_WHITE, transform=place(512, 470, 0.55))],
    ),
    dict(
        title="ベル（塗り）＋未読バッジ・白背景",
        bg=BG_WHITE,
        elements=[bell(fill=INK),
                  f'<circle cx="770" cy="272" r="92" fill="{BG_WHITE}"/>',
                  f'<circle cx="770" cy="272" r="74" fill="{INK}"/>'],
    ),
    dict(
        title="ベル（塗り）＋波紋・淡グレー背景",
        bg=BG_LIGHT,
        elements=[ripple(), bell(fill=INK)],
    ),
    dict(
        title="ベル（塗り）＋淡いハロー（光）・黒背景",
        bg=BG_DARK,
        elements=[f'<circle cx="512" cy="512" r="404" fill="#262626"/>', bell(fill=BG_WHITE)],
    ),
    dict(
        title="角丸四角のパネルの中にベル・淡グレー背景",
        bg=BG_LIGHT,
        elements=[f'<rect x="220" y="220" width="584" height="584" rx="132" fill="{INK}"/>',
                  bell(fill=BG_WHITE, transform=place(512, 512, 0.6))],
    ),
    dict(
        title="円枠の中にベル（塗り）・白背景",
        bg=BG_WHITE,
        elements=[f'<circle cx="512" cy="512" r="330" fill="none" stroke="{INK}" stroke-width="40"/>',
                  bell(fill=INK, transform=place(512, 512, 0.55))],
    ),
]


def render_svg(body: str, background: str) -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" '
        f'viewBox="0 0 {SIZE} {SIZE}">\n'
        f'  <rect width="{SIZE}" height="{SIZE}" fill="{background}"/>\n'
        f"  {body}\n"
        "</svg>\n"
    )


def candidate_svg(candidate: dict) -> str:
    return render_svg("".join(candidate["elements"]), candidate["bg"])


def overview_svg(columns: int = 4, cell: int = 256, gap: int = 24, label: int = 44) -> str:
    """全案を並べた一覧（案の番号つき）。"""
    scale = cell / SIZE
    rows = (len(CANDIDATES) + columns - 1) // columns
    width = columns * cell + (columns + 1) * gap
    height = rows * (cell + label) + (rows + 1) * gap
    # qlmanage は正方形のサムネイルを作るため、余白が付かないよう正方形にする
    side = max(width, height)
    offset_x = (side - width) / 2
    offset_y = (side - height) / 2
    parts = [f'<rect width="{side}" height="{side}" fill="{BG_WHITE}"/>']
    for index, candidate in enumerate(CANDIDATES):
        column = index % columns
        row = index // columns
        x = gap + column * (cell + gap)
        y = gap + row * (cell + label + gap)
        parts.append(
            f'<g transform="translate({x + offset_x} {y + offset_y}) scale({scale})">'
            f'<rect width="{SIZE}" height="{SIZE}" fill="{candidate["bg"]}"/>'
            f'{"".join(candidate["elements"])}</g>'
        )
        parts.append(
            f'<rect x="{x + offset_x}" y="{y + offset_y}" width="{cell}" height="{cell}" '
            f'fill="none" stroke="{GRAY_LIGHT}" stroke-width="2"/>'
        )
        parts.append(
            f'<text x="{x + offset_x + cell / 2}" y="{y + offset_y + cell + 34}" '
            f'text-anchor="middle" font-family="Helvetica, Arial, sans-serif" '
            f'font-size="34" fill="{INK}">{index + 1:02d}</text>'
        )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{side}" height="{side}" '
        f'viewBox="0 0 {side} {side}">\n  ' + "\n  ".join(parts) + "\n</svg>\n"
    )


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    candidates_dir = root / "candidates"
    candidates_dir.mkdir(parents=True, exist_ok=True)
    for index, candidate in enumerate(CANDIDATES, start=1):
        (candidates_dir / f"{index:02d}.svg").write_text(candidate_svg(candidate), encoding="utf-8")
    (root / "overview.svg").write_text(overview_svg(), encoding="utf-8")
    print(f"{len(CANDIDATES)} 案を {candidates_dir} に書き出しました")


if __name__ == "__main__":
    main()
