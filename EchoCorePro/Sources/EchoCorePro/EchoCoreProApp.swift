//
//  EchoCoreProApp.swift
//  EchoCorePro
//

import SwiftUI

@main
struct EchoCoreProApp: App {
    @StateObject private var backend = BackendManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(backend)
                .frame(minWidth: 1080, minHeight: 720)
                .task {
                    await backend.start()
                }
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Speech") {
                Button("Refresh Backend") {
                    Task { await backend.refreshHealth() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(backend)
        }
    }
}
