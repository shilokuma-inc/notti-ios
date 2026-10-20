//
//  LinkCandidate.swift
//  notti
//

import Foundation

/// 「アプリを開く」の URL の候補。会社が公式に公開している URL（Universal Link・カスタム URL スキーム）だけを載せる
///
/// 候補を足すときは、公式のヘルプ・開発者向けの資料など、その会社のドメインのページで「この URL でアプリが開く」と
/// 案内されていることを確かめ、`source` に出典のページを、ドキュメントコメントに出典と確かめた日を書く。
/// ブログ・まとめサイト・Q&A サイトなど公式でない情報や、推測で分かった URL は載せない。
/// 保存するのは URL だけで、候補の名前は保存しない（URL が候補と一致するときに `matching(_:)` で引く）
nonisolated struct LinkCandidate: Identifiable, Sendable, Equatable {
    /// 候補を区別する ID。画面の識別子にも使うので、一度決めたら変えない
    let id: String
    /// 画面に出すアプリ名
    let name: String
    /// 開く URL。`LinkURL.problem(of:)` が nil になる形で書く
    let url: String
    /// URL を公開している公式のページ（`https://`）
    let source: String

    /// 候補の一覧。画面ではこの順に並べる
    static let all: [LinkCandidate] = [
        line
    ]

    /// LINE のウォレットタブ（日本ではミニアプリタブ）。LINE ポイントや残高を見る画面
    ///
    /// 出典: LINE Developers「LINE URLスキームでLINEの機能を使う」の「その他の画面を開く」
    /// （<https://developers.line.biz/ja/docs/messaging-api/using-line-url-scheme/>、2026-10-21 に確認）。
    /// `https://line.me/R/` で始まる URL を開くと LINE が起動すると案内されている。`line://` は非推奨とされているので使わない
    static let line = LinkCandidate(
        id: "line-wallet",
        name: "LINE",
        url: "https://line.me/R/nv/wallet",
        source: "https://developers.line.biz/ja/docs/messaging-api/using-line-url-scheme/"
    )

    /// URL が一致する候補。前後の空白を除いて比べる。紐づけなし（空）か、どの候補とも一致しなければ nil
    static func matching(_ linkURL: String?, in candidates: [LinkCandidate] = all) -> LinkCandidate? {
        guard let normalized = LinkURL.normalized(linkURL) else {
            return nil
        }
        return candidates.first { $0.url == normalized }
    }
}
