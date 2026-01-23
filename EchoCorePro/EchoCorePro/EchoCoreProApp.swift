//
//  EchoCoreProApp.swift
//  EchoCorePro
//
//  A high-performance local voice server for macOS
//

import SwiftData
import SwiftUI

/// Main entry point for EchoCore Pro application
@main
struct EchoCoreProApp: App {
    /// App coordinator managing lifecycle and dependencies
    @StateObject private var coordinator = AppCoordinator()

    /// SwiftData model container for persistence
    let modelContainer: ModelContainer

    init() {
        // Initialize SwiftData model container with all required schemas
        do {
            let schema = Schema([
                LocalModelEntity.self,
                DownloadJobEntity.self,
                UserSettingsEntity.self,
                ProcessingHistoryEntity.self,
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }

        // Initialize logging system
        OSLogManager.shared.log("EchoCorePro app initializing", category: .lifecycle, level: .info)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
                .environment(\.serviceRegistry, coordinator.serviceRegistry)
                .environment(\.viewModelRegistry, coordinator.viewModelRegistry)
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 900, height: 650)

        // Menu bar controls
        MenuBarExtra("EchoCore Pro", systemImage: "waveform") {
            MenuBarView()
                .environmentObject(coordinator)
        }
        .menuBarExtraStyle(.window)

        // Settings window
        Settings {
            SettingsView()
                .environmentObject(coordinator)
        }
    }
}

/// Main content view - Simplified: Voice Cloning + History only
struct ContentView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var selectedTab: SidebarTab = .voiceCloning

    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView(selectedTab: $selectedTab)
        } detail: {
            // Main content area based on selected tab
            switch selectedTab {
            case .voiceCloning:
                VoiceCloningView()
            case .history:
                HistoryView()
            }
        }
        .frame(minWidth: 900, minHeight: 650)
        .background(.ultraThinMaterial)
    }
}

/// Sidebar navigation tabs - Simplified
enum SidebarTab: String, CaseIterable, Identifiable {
    case voiceCloning = "Voice Cloning"
    case history = "History"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .voiceCloning: return "person.wave.2.fill"
        case .history: return "clock"
        }
    }
}

/// Sidebar navigation view
struct SidebarView: View {
    @Binding var selectedTab: SidebarTab

    var body: some View {
        List(SidebarTab.allCases, selection: $selectedTab) { tab in
            Label(tab.rawValue, systemImage: tab.icon)
                .tag(tab)
        }
        .listStyle(.sidebar)
        .navigationTitle("EchoCore Pro")
    }
}

/// Menu bar view for quick access
struct MenuBarView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EchoCore Pro")
                .font(.headline)
            Divider()
            Button("Start Recording") {
                // TODO: Implement recording
            }
            Button("Stop Recording") {
                // TODO: Implement stop recording
            }
            Divider()
            Button("Open Main Window") {
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding()
        .frame(width: 200)
    }
}

/// Settings view - simplified
struct SettingsView: View {
    var body: some View {
        Form {
            Text("EchoCore Pro Settings")
                .font(.headline)

            Divider()

            Text("Qwen3-TTS Voice Cloning")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("• 10 Languages: EN, IT, DE, FR, ES, PT, RU, ZH, JA, KO")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("• Voice cloning from 3+ seconds of audio")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(width: 400, height: 200)
        .padding()
    }
}
