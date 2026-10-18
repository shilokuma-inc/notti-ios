#!/bin/bash
# アイコン候補の SVG から、プレビュー用の PNG を書き出す。
#
#   design/app-icon/scripts/export_png.sh
#
# SVG（`candidates/NN.svg`）が正本で、PNG はプレビュー用。macOS の QuickLook
# （qlmanage）で描き直す。qlmanage は出力先のディレクトリが無いと何も書かずに
# 終わるので、先に作る。出力名は `<元の名前>.svg.png` になるため、`.svg` を
# 落として `<名前>.png` に直す。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "${OUT}"' EXIT

# 1 案ごとのプレビューはアイコンと同じ 1024 角、一覧は全体が入る大きさにする
CANDIDATE_SIZE=1024
OVERVIEW_SIZE=1608

export_svg() {
  local source="$1"
  local destination="$2"
  local size="$3"
  local work
  work="$(mktemp -d "${OUT}/work.XXXXXX")"

  qlmanage -t -s "${size}" -o "${work}" "${source}" >/dev/null 2>&1

  local produced="${work}/$(basename "${source}").png"
  if [[ ! -f "${produced}" ]]; then
    echo "${source} を PNG に書き出せませんでした" >&2
    exit 1
  fi
  mv "${produced}" "${destination}"
}

for source in "${ROOT}"/candidates/*.svg; do
  export_svg "${source}" "${source%.svg}.png" "${CANDIDATE_SIZE}"
done
export_svg "${ROOT}/overview.svg" "${ROOT}/overview.png" "${OVERVIEW_SIZE}"

echo "プレビューの PNG を書き出しました"
