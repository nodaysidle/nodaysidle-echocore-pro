//
//  DesignSystem.swift
//  EchoCorePro
//

import SwiftUI

enum ECTheme {
    static let cyan = Color(red: 0.18, green: 0.78, blue: 0.86)
    static let mint = Color(red: 0.38, green: 0.84, blue: 0.58)
    static let rose = Color(red: 0.92, green: 0.36, blue: 0.56)
    static let amber = Color(red: 0.98, green: 0.69, blue: 0.26)
    static let ink = Color(red: 0.08, green: 0.10, blue: 0.13)
}

struct AppBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .underPageBackgroundColor).opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [ECTheme.cyan.opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 520
            )

            RadialGradient(
                colors: [ECTheme.rose.opacity(0.15), .clear],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }
}

struct GlassPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            }
    }
}

extension View {
    func glassPanel() -> some View {
        modifier(GlassPanel())
    }
}

struct MetricPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.weight(.medium))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
