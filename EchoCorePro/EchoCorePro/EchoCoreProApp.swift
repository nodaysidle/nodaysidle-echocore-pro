//
//  EchoCoreProApp.swift
//  EchoCorePro
//
//  A high-performance local voice server for macOS
//  Voice Cloning (Qwen3-TTS) + Natural TTS (Kokoro)
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
        .defaultSize(width: 1100, height: 720)

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

/// Main content view - Voice Cloning + Fast TTS
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
            case .fastTTS:
                KokoroTTSView()
            }
        }
        .frame(minWidth: 1000, minHeight: 720)
        .background(DS.BG.primary)
    }
}

/// Sidebar navigation tabs
enum SidebarTab: String, CaseIterable, Identifiable {
    case voiceCloning = "Voice Clone"
    case fastTTS = "Fast TTS"

    var id: String { rawValue }
}

/// Sidebar navigation view with custom icons
struct SidebarView: View {
    @Binding var selectedTab: SidebarTab

    private let brandPurple = DS.Fuchsia.primary
    private let brandViolet = DS.Fuchsia.secondary
    private let brandCyan   = DS.Cyan.secondary

    var body: some View {
        List(selection: $selectedTab) {
            Section {
                // Voice Clone (Qwen3-TTS)
                sidebarItem(
                    tab: .voiceCloning,
                    title: "Voice Clone",
                    subtitle: "Qwen3-TTS",
                    icon: { VoiceCloneIcon(color: selectedTab == .voiceCloning ? brandViolet : .gray) }
                )

                // Natural TTS (Kokoro)
                sidebarItem(
                    tab: .fastTTS,
                    title: "Natural TTS",
                    subtitle: "Kokoro",
                    icon: { KokoroIcon(color: selectedTab == .fastTTS ? brandCyan : .gray) }
                )
            } header: {
                Text("Speech")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("EchoCore Pro")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Text("by nodaysidle")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(minWidth: 220)
    }

    @ViewBuilder
    private func sidebarItem<Icon: View>(
        tab: SidebarTab,
        title: String,
        subtitle: String,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        HStack(spacing: 10) {
            icon()
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .tag(tab)
        .padding(.vertical, 4)
    }
}

/// Menu bar view for quick access
struct MenuBarView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    private let brandPurple = DS.Fuchsia.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(brandPurple)
                Text("EchoCore Pro")
                    .font(.headline)
            }

            Text("by nodaysidle")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Divider()

            Text("Voice Clone: Qwen3-TTS")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Natural TTS: Kokoro")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button {
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open Main Window", systemImage: "macwindow")
            }

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
        }
        .padding()
        .frame(width: 200)
    }
}

/// Settings view
struct SettingsView: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    VoiceCloneIcon()
                        .frame(width: 32, height: 32)
                    VStack(alignment: .leading) {
                        Text("Voice Clone - Qwen3-TTS")
                            .font(.headline)
                        Text("Clone any voice from 6+ seconds of audio")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("10 Languages:")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("EN, ZH, JA, KO, FR, DE, ES, IT, PT, RU")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } header: {
                Text("Voice Cloning")
            }

            Section {
                HStack {
                    KokoroIcon()
                        .frame(width: 32, height: 32)
                    VStack(alignment: .leading) {
                        Text("Natural TTS - Kokoro")
                            .font(.headline)
                        Text("High-quality natural voices")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("3 Languages:")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("EN (US/UK), IT")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } header: {
                Text("Natural TTS")
            }

            Section {
                Text("Both models support unlimited text length")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Features")
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 400)
        .padding()
    }
}
