//
//  LinkURL.swift
//  notti
//

import Foundation

/// 通知に紐づけて開く URL（Universal Link `https://...` かカスタム URL スキーム `xxxx://`）の解釈
///
/// 入力は前後の空白を取り除いて保存し、空なら紐づけなしにする。インストール済みのアプリかどうかは確かめない
/// （`canOpenURL` は使わない）ので、開けるかどうかは開いたときに分かる
nonisolated enum LinkURL {
    /// 保存できない理由
    nonisolated enum Problem: Error, Equatable, Sendable {
        /// URL として読めないか、スキーム（`https://` など）が無い
        case unreadable
        /// 受け付けないスキーム（`javascript:`・`file:`・`data:`）
        case unsupportedScheme
    }

    /// 受け付けないスキーム。のっちの外のアプリを開くためのものではなく、開くと危ないか意味が無いため
    static let unsupportedSchemes: Set<String> = ["javascript", "file", "data"]

    /// ホスト（`example.com` など）が要るスキーム。カスタム URL スキームは `xxxx://` だけでも開けるので要らない
    private static let schemesRequiringHost: Set<String> = ["https", "http"]

    /// 保存する形。前後の空白を取り除き、空なら nil（紐づけなし）
    static func normalized(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    /// 入力を解釈する
    ///
    /// - Returns: 紐づけなし（空）なら `.success(nil)`、開ける形なら `.success(URL)`、保存できなければ `.failure`
    static func parse(_ text: String?) -> Result<URL?, Problem> {
        guard let text = normalized(text) else {
            return .success(nil)
        }
        guard let url = URL(string: text), let scheme = url.scheme?.lowercased(), !scheme.isEmpty else {
            return .failure(.unreadable)
        }
        if unsupportedSchemes.contains(scheme) {
            return .failure(.unsupportedScheme)
        }
        if schemesRequiringHost.contains(scheme) && (url.host() ?? "").isEmpty {
            return .failure(.unreadable)
        }
        return .success(url)
    }

    /// 保存できない理由。紐づけなし（空）か開ける形なら nil
    static func problem(of text: String?) -> Problem? {
        switch parse(text) {
        case .success:
            return nil
        case .failure(let problem):
            return problem
        }
    }

    /// 開く URL。紐づけなし（空）か保存できない形なら nil
    static func url(from text: String?) -> URL? {
        switch parse(text) {
        case .success(let url):
            return url
        case .failure:
            return nil
        }
    }
}
