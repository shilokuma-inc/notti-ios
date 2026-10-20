//
//  LinkOpenFailureAlert.swift
//  notti
//

import SwiftUI

/// 紐づけたアプリを開けなかったときの知らせ（`LinkOpener.isShowingFailure`）を出す
///
/// アラートは付けた画面の上にしか出ないので、一覧と、一覧から開くシート（追加・編集・おやすみ時間）のそれぞれに付ける。
/// シートを開いたまま通知の「アプリを開く」から戻っても、開いている画面の上で知らせるため
struct LinkOpenFailureAlert: ViewModifier {
    @Environment(LinkOpener.self) private var linkOpener

    func body(content: Content) -> some View {
        @Bindable var linkOpener = linkOpener
        content
            .alert("アプリを開けませんでした", isPresented: $linkOpener.isShowingFailure) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("紐づけた URL を確かめてください。開くアプリが入っていないと開けません")
            }
    }
}

extension View {
    /// 紐づけたアプリを開けなかったときの知らせを、この画面の上に出す
    func linkOpenFailureAlert() -> some View {
        modifier(LinkOpenFailureAlert())
    }
}
