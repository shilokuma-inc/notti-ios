//
//  LinkURLSection.swift
//  notti
//

import SwiftUI

/// 追加・編集画面の「アプリを開く」の節。通知に紐づけて開くアプリの URL を入れる。通知の種類によらず出す
struct LinkURLSection: View {
    /// 紐づけて開くアプリの URL の入力。空の入力は nil（紐づけなし）にする
    @Binding var linkURL: String?
    /// 「候補から選ぶ」に並べる候補。空なら「候補から選ぶ」を出さない
    var candidates: [LinkCandidate] = LinkCandidate.all

    var body: some View {
        Section {
            TextField("例: https://example.com", text: text)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("linkURLField")
                .accessibilityLabel("開くアプリの URL")
            if !candidates.isEmpty {
                candidateMenu
            }
        } header: {
            Text("アプリを開く")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let candidate = LinkCandidate.matching(linkURL, in: candidates) {
                    Label("\(candidate.name) を開きます", systemImage: "arrow.up.forward.app")
                }
                Text(
                    "通知を長押ししたときの「アプリを開く」と、一覧のボタンから開けます。完了するまで繰り返す通知では、\(AppDisplayName.current)に戻ったときに済んだかを聞きます。URL を消すと紐づけを外します"
                )
                // 保存できない理由は文言・時刻と繰り返し・URL の順で 1 つだけ決まる。時刻の理由が先に出ていても見えるよう、ここでは URL の理由を直接出す
                switch LinkURL.problem(of: linkURL) {
                case .unreadable:
                    Label("URL を読めません。https:// などから始まる URL を入れてください", systemImage: "exclamationmark.circle")
                        .foregroundStyle(.orange)
                case .unsupportedScheme:
                    Label("この種類の URL は開けません", systemImage: "exclamationmark.circle")
                        .foregroundStyle(.orange)
                case nil:
                    EmptyView()
                }
            }
        }
    }

    /// 公式に公開されている URL の候補から選ぶメニュー。選ぶと URL 欄をその候補の URL に置き換える
    private var candidateMenu: some View {
        Menu {
            ForEach(candidates) { candidate in
                Button(candidate.name) {
                    linkURL = candidate.url
                }
                .accessibilityIdentifier("linkCandidate-\(candidate.id)")
            }
        } label: {
            Label("候補から選ぶ", systemImage: "list.bullet")
        }
        .accessibilityIdentifier("linkCandidateMenu")
        .accessibilityLabel("開くアプリを候補から選ぶ")
    }

    /// 入力欄の値。`linkURL` の nil は空の文字列にする
    private var text: Binding<String> {
        Binding(
            get: { linkURL ?? "" },
            set: { linkURL = $0.isEmpty ? nil : $0 }
        )
    }
}

#Preview {
    Form {
        LinkURLSection(linkURL: .constant("example.com"))
    }
}

#Preview("候補と一致") {
    Form {
        LinkURLSection(linkURL: .constant(LinkCandidate.line.url))
    }
}
