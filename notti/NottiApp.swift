//
//  NottiApp.swift
//  notti
//
//  Created by 村石 拓海 on 2024/05/12.
//

import SwiftData
import SwiftUI

@main
struct NottiApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try NottiModelContainer.make()
        } catch {
            fatalError("ModelContainer を作成できません: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
