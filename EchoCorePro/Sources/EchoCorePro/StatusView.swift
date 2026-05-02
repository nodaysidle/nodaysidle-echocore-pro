//
//  StatusView.swift
//  EchoCorePro
//

import SwiftUI

struct StatusView: View {
    @EnvironmentObject private var backend: BackendManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Runtime Status")
                            .font(.largeTitle.weight(.semibold))
                        Text("Backend lifecycle, bundled assets, and recent activity.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task { await backend.refreshHealth() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    StatusCard(title: "Backend", value: backend.health.ready && backend.health.modelsReady == false ? "Running, assets incomplete" : backend.statusMessage, icon: "server.rack", color: backend.health.ready ? ECTheme.mint : ECTheme.amber)
                    StatusCard(title: "Voxtral", value: backend.health.voxtralLoaded ? "Loaded in memory" : "Bundled, lazy loaded", icon: "cpu.fill", color: ECTheme.cyan)
                    StatusCard(title: "Slovenian", value: "Piper artur medium", icon: "globe.europe.africa.fill", color: ECTheme.rose)
                    StatusCard(title: "STT", value: backend.health.sttReady ? "Whisper small q4 bundled" : "Model check pending", icon: "waveform.and.mic", color: .blue)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Models Root")
                        .font(.headline)
                    Text(backend.health.modelsRoot.isEmpty ? "Unknown" : backend.health.modelsRoot)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .glassPanel()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent Activity")
                        .font(.headline)

                    if backend.activity.isEmpty {
                        Text("No activity yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(backend.activity) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "smallcircle.filled.circle")
                                    .foregroundStyle(ECTheme.cyan)
                                    .padding(.top, 3)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.callout.weight(.medium))
                                    Text(item.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                }
                                Spacer()
                                Text(item.date, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Divider()
                        }
                    }
                }
                .glassPanel()
            }
            .padding(24)
        }
    }
}

private struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(value)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 98, alignment: .topLeading)
        .glassPanel()
    }
}

struct SettingsView: View {
    @EnvironmentObject private var backend: BackendManager

    var body: some View {
        Form {
            Section("Backend") {
                LabeledContent("Status", value: backend.statusMessage)
                LabeledContent("Address", value: "127.0.0.1:8765")
                LabeledContent("Models", value: backend.health.modelsRoot.isEmpty ? "Bundled" : backend.health.modelsRoot)
            }

            Section("Defaults") {
                LabeledContent("Primary TTS", value: "mlx-community/Voxtral-4B-TTS-2603-mlx-4bit")
                LabeledContent("Slovenian fallback", value: "Piper sl_SI-artur-medium")
                LabeledContent("STT", value: "mlx-community/whisper-small-mlx-q4")
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 320)
        .padding()
    }
}
