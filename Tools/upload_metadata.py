#!/usr/bin/env python3
"""App Store の説明文・キーワード・プロモーションテキスト・URL を App Store Connect に反映する。

`AppStore/metadata/<言語>.json` と `AppStore/metadata/shared.json` を読み、
対象バージョンの言語ごとに書き込む。

    python3 Tools/upload_metadata.py            # 反映する
    python3 Tools/upload_metadata.py --dry-run  # 現在値との差分だけ出す
    python3 Tools/upload_metadata.py --check    # App Store Connect につながず、手元のファイルだけ検査する
    python3 Tools/upload_metadata.py --export   # App Store Connect の現在値を AppStore/metadata/*.json に書き出す

認証は App Store Connect API Key（.p8）。次の環境変数でも渡せる。

    APP_STORE_CONNECT_KEY_ID / APP_STORE_CONNECT_ISSUER_ID / APP_STORE_CONNECT_PRIVATE_KEY_PATH

触るのは **編集できる状態のバージョンだけ**。審査中や配信済みのバージョンは対象にしない。
JSON に書いていない項目（例: 省略した promotionalText）は App Store Connect 側の値をそのまま残す。

`--export` は逆向きで、App Store Connect の現在値を JSON に書き出す。公開中の文言を正として
リポジトリに取り込むとき（初回）や、App Store Connect 側で直接編集した内容を取り込むときに使う。
現在値が無い言語・項目は書かず、その旨を出力する（勝手に説明文を作らない）。

PyJWT が要る（--check では不要）: `python3 -m pip install pyjwt cryptography`
"""

from __future__ import annotations

import argparse
import difflib
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from app_store_config import ROOT, Language, bundle_id, languages, parse_list

METADATA_DIR = ROOT / "AppStore" / "metadata"

#: 言語によらない値をまとめたファイル
SHARED_FILE = "shared.json"

#: App Store Connect 側の上限。超えると反映時に弾かれるので、手元で先に落とす。
LIMITS = {
    "description": 4000,
    "keywords": 100,
    "promotionalText": 170,
}


def load_shared(directory: Path) -> tuple[dict[str, str], list[str]]:
    path = directory / SHARED_FILE
    if not path.is_file():
        return {}, [f"{path} がありません"]
    raw = json.loads(path.read_text(encoding="utf-8"))
    problems = []
    attributes = {}
    # supportUrl は審査で実際に開かれるので必須。marketingUrl は任意
    for key, required in (("supportUrl", True), ("marketingUrl", False)):
        value = raw.get(key)
        if isinstance(value, str) and value.strip():
            if not value.startswith("https://"):
                problems.append(f"{path}: {key} は https:// で始まる URL にしてください")
            attributes[key] = value
        elif required:
            problems.append(f"{path}: {key} がありません")
    return attributes, problems


def load(directory: Path, target: Language, shared: dict[str, str]) -> tuple[dict[str, str] | None, list[str]]:
    """1 言語ぶんの書き込む値を読む。問題があれば値の代わりに理由を返す。"""
    path = directory / f"{target.language}.json"
    if not path.is_file():
        return None, [f"{path} がありません"]
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        return None, [f"{path} が JSON として読めません: {error}"]

    problems: list[str] = []
    attributes: dict[str, str] = {}

    description = raw.get("description")
    if isinstance(description, str) and description.strip():
        attributes["description"] = description
    else:
        problems.append(f"{path}: description がありません")

    keywords = raw.get("keywords")
    if isinstance(keywords, list) and keywords:
        # App Store Connect にはカンマ区切りの 1 本の文字列として渡す。
        # 区切りのあとに空白を入れると、そのぶん 100 字の枠を食うので詰めて繋ぐ。
        attributes["keywords"] = ",".join(str(keyword).strip() for keyword in keywords)
    else:
        problems.append(f"{path}: keywords がありません（配列で書く）")

    promotional_text = raw.get("promotionalText")
    if promotional_text is not None:
        if isinstance(promotional_text, str) and promotional_text.strip():
            attributes["promotionalText"] = promotional_text
        else:
            problems.append(f"{path}: promotionalText が空です（使わないなら項目ごと消す）")

    for field, limit in LIMITS.items():
        value = attributes.get(field, "")
        if len(value) > limit:
            problems.append(f"{path}: {field} が {len(value)} 字あります（上限 {limit} 字）")

    if problems:
        return None, problems
    return {**attributes, **shared}, []


def describe_changes(current: dict, new: dict[str, str]) -> list[str]:
    """現在値から変わる項目を、人が読める形で返す。長い文章は行単位の差分にする。"""
    lines: list[str] = []
    for field, value in new.items():
        before = current.get(field) or ""
        if before == value:
            continue
        if "\n" in before or "\n" in value:
            lines.append(f"    {field}:")
            diff = difflib.unified_diff(before.splitlines(), value.splitlines(), lineterm="", n=1)
            lines.extend(f"      {line}" for line in list(diff)[2:])
        else:
            lines.append(f"    {field}: {before or '（空）'} → {value}")
    return lines


def _load_comment(path: Path) -> list[str] | None:
    """既存ファイルの `_comment`（運用メモ）は、現在値で上書きしても残す。"""
    if not path.is_file():
        return None
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    comment = raw.get("_comment")
    return comment if isinstance(comment, list) else None


def _write_json(path: Path, body: dict) -> None:
    comment = _load_comment(path)
    payload = {"_comment": comment, **body} if comment else body
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def export(directory: Path, targets: list[Language], available: dict[str, dict], version_string: str) -> int:
    """App Store Connect の現在値を `<言語>.json` と `shared.json` に書き出す。

    書き出した言語の数を返す。現在値が無い言語・項目は書かずに報告だけする。
    """
    directory.mkdir(parents=True, exist_ok=True)
    written = 0
    missing: list[str] = []
    shared_values: dict[str, dict[str, str]] = {}

    for target in targets:
        label = f"{target.language} → {target.store_locale}"
        localization = available.get(target.store_locale)
        if localization is None:
            missing.append(f"{label}: {version_string} にこの言語がありません")
            continue
        attributes = localization["attributes"]

        body: dict[str, object] = {}
        description = attributes.get("description") or ""
        keywords = attributes.get("keywords") or ""
        promotional_text = attributes.get("promotionalText") or ""
        if description.strip():
            body["description"] = description
        else:
            missing.append(f"{label}: description が空です")
        if keywords.strip():
            body["keywords"] = [keyword.strip() for keyword in keywords.split(",") if keyword.strip()]
        else:
            missing.append(f"{label}: keywords が空です")
        if promotional_text.strip():
            body["promotionalText"] = promotional_text

        for key in ("supportUrl", "marketingUrl"):
            value = attributes.get(key) or ""
            if value.strip():
                shared_values.setdefault(key, {})[target.language] = value

        path = directory / f"{target.language}.json"
        _write_json(path, body)
        written += 1
        counts = " / ".join(
            f"{field} {len(value if isinstance(value, str) else ','.join(value))} 字"
            for field, value in body.items()
        )
        print(f"  {label}: {path} に書き出し（{counts or '値なし'}）")

    # URL は言語によらない前提なので shared.json に 1 つだけ持つ。言語で違っていたら最初の言語の値を採り、報告する
    shared: dict[str, str] = {}
    for key, values in shared_values.items():
        distinct = sorted(set(values.values()))
        if len(distinct) > 1:
            details = ", ".join(f"{language}: {value}" for language, value in values.items())
            missing.append(f"shared.json: {key} が言語で違います（{details}）。先頭の言語の値を書きました")
        shared[key] = next(iter(values.values()))
    if "supportUrl" not in shared:
        missing.append("shared.json: supportUrl がどの言語にもありません（必須なので手で埋めてください）")
    if shared:
        shared_path = directory / SHARED_FILE
        _write_json(shared_path, shared)
        print(f"  共通: {shared_path} に書き出し（{', '.join(shared)}）")

    if missing:
        print("現在値が無い項目（JSON には書いていません）:")
        for line in missing:
            print(f"  - {line}")
    return written


def make_client(args: argparse.Namespace, dry_run: bool):
    """認証情報がそろっているか確かめてから App Store Connect のクライアントを作る。"""
    missing_key = [
        name for name, value in
        [("--key-id", args.key_id), ("--issuer-id", args.issuer_id), ("--private-key", args.private_key)]
        if not value
    ]
    if missing_key:
        raise SystemExit(f"認証情報が足りません: {', '.join(missing_key)}")

    from app_store_connect import AppStoreConnect

    return AppStoreConnect(args.key_id, args.issuer_id, Path(args.private_key).read_text(), dry_run=dry_run)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--metadata-dir", type=Path, default=METADATA_DIR, help="<ここ>/<言語>.json を読む")
    parser.add_argument("--languages", help="対象の言語（カンマ区切り）。省略すると全言語")
    parser.add_argument("--bundle-id", help="省略すると project.pbxproj から読む")
    parser.add_argument("--app-version", help="反映先のバージョン。省略すると編集できるバージョンを自動で選ぶ")
    parser.add_argument("--key-id", default=os.environ.get("APP_STORE_CONNECT_KEY_ID"))
    parser.add_argument("--issuer-id", default=os.environ.get("APP_STORE_CONNECT_ISSUER_ID"))
    parser.add_argument(
        "--private-key",
        type=Path,
        default=os.environ.get("APP_STORE_CONNECT_PRIVATE_KEY_PATH"),
        help="App Store Connect API Key の .p8",
    )
    parser.add_argument(
        "--missing-locales",
        choices=("fail", "skip", "create"),
        default="fail",
        help="App Store Connect にその言語が無いときの扱い。"
             "fail: 止める（既定） / skip: 飛ばす / create: その言語を追加してから反映する",
    )
    parser.add_argument("--check", action="store_true",
                        help="App Store Connect につながず、手元のファイルの欠損と文字数だけ見る")
    parser.add_argument("--dry-run", action="store_true", help="何も書き換えず、現在値との差分だけ出す")
    parser.add_argument("--export", action="store_true",
                        help="App Store Connect の現在値を --metadata-dir の JSON に書き出す（App Store Connect には書き込まない）")
    args = parser.parse_args()

    if args.check and args.export:
        raise SystemExit("--check と --export は同時に指定できません")

    targets = languages(parse_list(args.languages))

    if args.export:
        # 取り込みが目的なので、手元の JSON が無くても・壊れていても止めない
        client = make_client(args, dry_run=True)
        app = client.find_app(args.bundle_id or bundle_id())
        version = client.find_version(app["id"], args.app_version)
        version_string = version["attributes"]["versionString"]
        print(f"取り込み元: {app['attributes']['name']} {version_string} "
              f"({version['attributes']['appStoreState']})")
        written = export(args.metadata_dir, targets, client.localization_entries(version["id"]), version_string)
        print(f"書き出し: {written} 言語")
        return 0

    shared, problems = load_shared(args.metadata_dir)
    entries: list[tuple[Language, dict[str, str]]] = []
    for target in targets:
        attributes, issues = load(args.metadata_dir, target, shared)
        problems.extend(issues)
        if attributes:
            entries.append((target, attributes))
    if problems:
        raise SystemExit("\n".join(problems))

    if args.check:
        for target, attributes in entries:
            counts = " / ".join(
                f"{field} {len(attributes[field])} 字" for field in LIMITS if field in attributes
            )
            print(f"  {target.language}: {counts}")
        print(f"問題なし: {len(entries)} 言語")
        return 0

    client = make_client(args, dry_run=args.dry_run)

    app = client.find_app(args.bundle_id or bundle_id())
    version = client.find_version(app["id"], args.app_version)
    version_string = version["attributes"]["versionString"]
    print(f"対象: {app['attributes']['name']} {version_string} "
          f"({version['attributes']['appStoreState']})")
    if args.dry_run:
        print("--dry-run: App Store Connect には何も書き込みません")

    available = client.localization_entries(version["id"])

    # スクリーンショットのときと同じく、書き込む前に全言語ぶんの前提を確かめる
    plan: list[tuple[Language, dict[str, str], dict | None]] = []
    skipped: list[str] = []
    missing_locales: list[str] = []
    for target, attributes in entries:
        localization = available.get(target.store_locale)
        if localization is None:
            if args.missing_locales == "create":
                plan.append((target, attributes, None))
            elif args.missing_locales == "skip":
                print(f"  飛ばす — {target.language}: {target.store_locale} が {version_string} にありません")
                skipped.append(target.language)
            else:
                missing_locales.append(f"{target.language} → {target.store_locale}")
            continue
        plan.append((target, attributes, localization))

    if missing_locales:
        raise SystemExit(
            f"App Store Connect の {version_string} に無い言語: {', '.join(missing_locales)}\n"
            "App Store Connect でこれらの言語を追加してから実行するか、"
            "--missing-locales create（追加してから反映）か "
            "--missing-locales skip（飛ばす）を付けてください。"
        )

    for target, attributes, localization in plan:
        label = f"{target.language} → {target.store_locale}"
        if localization is None:
            client.create_localization(version["id"], target.store_locale, attributes)
            print(f"  {label}: {'言語を追加して書き込む予定' if args.dry_run else '言語を追加して書き込み'}")
            for line in describe_changes({}, attributes):
                print(line)
            continue

        changes = describe_changes(localization["attributes"], attributes)
        if not changes:
            print(f"  {label}: 変更なし")
            continue
        print(f"  {label}: {'書き込む予定' if args.dry_run else '書き込み'}")
        for line in changes:
            print(line)
        if not args.dry_run:
            client.patch(
                f"/v1/appStoreVersionLocalizations/{localization['id']}",
                {
                    "data": {
                        "type": "appStoreVersionLocalizations",
                        "id": localization["id"],
                        "attributes": attributes,
                    }
                },
            )

    print(f"完了: {len(plan)} 言語")
    if skipped:
        print(f"飛ばした言語: {', '.join(skipped)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
