//
//  HistoryView.swift
//  EchoCorePro
//
//  View for displaying processing history
//

import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProcessingHistoryEntity.timestamp, order: .reverse)
    private var historyItems: [ProcessingHistoryEntity]

    @State private var selectedType: ProcessingType?
    @State private var showingClearAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with filter
            headerBar

            // Content
            if filteredItems.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .background(
            LinearGradient(
                colors: [Color(white: 0.05), Color(white: 0.08), Color(white: 0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            HistoryService.shared.setContext(modelContext)
        }
        .alert("Clear History", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                HistoryService.shared.clearAllHistory()
            }
        } message: {
            Text("Are you sure you want to clear all processing history? This cannot be undone.")
        }
    }

    private var filteredItems: [ProcessingHistoryEntity] {
        guard let type = selectedType else { return historyItems }
        return historyItems.filter { $0.processingType == type }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Processing History", systemImage: "clock")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                if !historyItems.isEmpty {
                    Button {
                        showingClearAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear all history")
                }
            }

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChipView(
                        title: "All",
                        count: historyItems.count,
                        isSelected: selectedType == nil
                    ) {
                        selectedType = nil
                    }

                    ForEach(ProcessingType.allCases, id: \.self) { type in
                        let count = historyItems.filter { $0.processingType == type }.count
                        FilterChipView(
                            title: type.rawValue,
                            icon: type.icon,
                            count: count,
                            isSelected: selectedType == type
                        ) {
                            selectedType = type
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No History Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your transcriptions and voice synthesis\noperations will appear here")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - History List

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredItems) { item in
                    HistoryItemCard(item: item) {
                        HistoryService.shared.deleteEntry(item)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - History Item Card

struct HistoryItemCard: View {
    let item: ProcessingHistoryEntity
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Type icon
            Image(systemName: item.processingType.icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.processingType.rawValue)
                        .font(.headline)

                    Spacer()

                    Text(item.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Model name
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .font(.caption2)
                    Text(item.modelName)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                // Text preview
                if let text = item.textContent, !text.isEmpty {
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }

                // Stats
                HStack(spacing: 16) {
                    Label(item.inputLengthFormatted, systemImage: "arrow.down.circle")
                    Label(item.processingTimeFormatted, systemImage: "timer")

                    if let confidence = item.confidence {
                        Label(
                            String(format: "%.0f%%", confidence * 100),
                            systemImage: "chart.bar.fill"
                        )
                    }

                    if item.realTimeFactor > 0 {
                        Label(
                            String(format: "%.2fx RT", item.realTimeFactor),
                            systemImage: "speedometer"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            // Delete button on hover
            if isHovered {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var iconColor: Color {
        switch item.processingType {
        case .speechToText:
            return .blue
        case .textToSpeech:
            return .purple
        case .audioPostProcessing:
            return .orange
        }
    }
}

// MARK: - Filter Chip View

struct FilterChipView: View {
    let title: String
    var icon: String?
    var count: Int = 0
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? .white.opacity(0.2) : .secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? .clear : .secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HistoryView()
        .frame(width: 700, height: 500)
}
