//
//  MetalRacingGameApp.swift
//  MetalRacingGame
//
//  Main app entry point
//

import SwiftUI

@main
struct MetalRacingGameApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

