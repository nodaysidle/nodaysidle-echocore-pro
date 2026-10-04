//
//  ContentView.swift
//  EchoCorePro
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var backend: BackendManager
    @SceneStorage("selectedTab") private var selectedTabRaw = WorkspaceTab.tts.rawValue
    @Namespace private var sidebarNamespace

    private var selectedTab: WorkspaceTab {
        get { WorkspaceTab(rawValue: selectedTabRaw) ?? .tts }
        nonmutating set { selectedTabRaw = newValue.rawValue }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            ZStack {
                AppBackdrop()

                switch selectedTab {
                case .tts:
                    TTSView()
                case .stt:
                    STTView()
                case .status:
                    StatusView()
                }
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(ECTheme.cyan)
                        .frame(width: 34, height: 34)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("EchoCore Pro")
                            .font(.headline)
                        Text("Local speech")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Circle()
                        .fill(backend.isRunning ? ECTheme.mint : ECTheme.amber)
                        .frame(width: 8, height: 8)
                    Text(backend.statusMessage)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)

            List(selection: Binding(get: { selectedTab }, set: { selectedTab = $0 })) {
                Section("Tools") {
                    ForEach(WorkspaceTab.allCases) { tab in
                        HStack(spacing: 10) {
                            Image(systemName: tab.systemImage)
                                .foregroundStyle(selectedTab == tab ? ECTheme.cyan : .secondary)
                                .frame(width: 18)
                            Text(tab.rawValue)
                            Spacer()
                        }
                        .padding(.vertical, 5)
                        .background {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(ECTheme.cyan.opacity(0.10))
                                    .matchedGeometryEffect(id: "selection", in: sidebarNamespace)
                            }
                        }
                        .tag(tab)
                    }
                }
            }
            .listStyle(.sidebar)

            VStack(alignment: .leading, spacing: 8) {
                MetricPill(
                    title: "Primary TTS",
                    value: backend.health.voxtralLoaded ? "Voxtral loaded" : "Voxtral ready",
                    color: ECTheme.cyan
                )
                MetricPill(
                    title: "STT",
                    value: backend.health.sttReady ? "Whisper bundled" : "Checking",
                    color: .blue
                )
            }
            .padding(14)
        }
        .navigationSplitViewColumnWidth(min: 230, ideal: 250, max: 290)
    }
}
