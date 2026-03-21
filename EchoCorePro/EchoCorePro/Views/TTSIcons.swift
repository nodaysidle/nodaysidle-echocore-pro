//
//  TTSIcons.swift
//  EchoCorePro
//
//  Custom SVG-style icons for Voice Cloning and TTS
//  Also contains the EchoCore Pro design system tokens and shared components

import SwiftUI

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Design System

enum DS {
    enum BG {
        static let primary   = Color(hex: "09090b")
        static let secondary = Color(hex: "18181b")
        static let tertiary  = Color(hex: "27272a")
    }
    enum Surface {
        static let dark  = Color(hex: "0c0c0f")
        static let mid   = Color(hex: "141417")
        static let light = Color(hex: "1c1c21")
    }
    enum Fuchsia {
        static let primary   = Color(hex: "c026d3")
        static let secondary = Color(hex: "e879f9")
        static let glow      = Color(hex: "f0abfc")
        static let darkBG    = Color(hex: "1a0a1e")
        static var gradient: LinearGradient {
            LinearGradient(colors: [primary, secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    enum Cyan {
        static let primary   = Color(hex: "0891b2")
        static let secondary = Color(hex: "22d3ee")
        static let glow      = Color(hex: "67e8f9")
        static let darkBG    = Color(hex: "0a1a1e")
        static var gradient: LinearGradient {
            LinearGradient(colors: [primary, secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    enum Semantic {
        static let success = Color(hex: "10b981")
        static let warning = Color(hex: "f59e0b")
        static let error   = Color(hex: "ef4444")
    }
    enum Text {
        static let primary   = Color(hex: "fafafa")
        static let secondary = Color(hex: "a1a1aa")
        static let tertiary  = Color(hex: "71717a")
        static let disabled  = Color(hex: "52525b")
    }
    enum Border {
        static let subtle   = Color(hex: "27272a")
        static let standard = Color(hex: "3f3f46")
        static let strong   = Color(hex: "52525b")
    }
}

// MARK: - Studio Card Style

struct StudioCard: ViewModifier {
    var cornerRadius: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(DS.Surface.mid)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(DS.Border.subtle, lineWidth: 0.5)
                    )
            )
    }
}

extension View {
    func studioCard(_ cornerRadius: CGFloat = 14) -> some View {
        modifier(StudioCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Grid Pattern

struct GridPatternShape: Shape {
    var spacing: CGFloat = 40
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x: CGFloat = 0
        while x <= rect.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: rect.height)); x += spacing }
        var y: CGFloat = 0
        while y <= rect.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: rect.width, y: y)); y += spacing }
        return path
    }
}

// MARK: - Studio Background

struct StudioBackground: View {
    var accentColor: Color = DS.Fuchsia.primary
    var glowOffsetX: CGFloat = -150
    var glowOffsetY: CGFloat = -80
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [DS.BG.primary, DS.BG.secondary, DS.BG.primary],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            GridPatternShape()
                .stroke(Color.white.opacity(0.015), lineWidth: 0.5)
            Ellipse()
                .fill(accentColor.opacity(0.07))
                .frame(width: 500, height: 500)
                .blur(radius: 100)
                .offset(x: glowOffsetX, y: glowOffsetY)
        }
        .ignoresSafeArea()
    }
}

// MARK: - VU Meter

struct VUMeterView: View {
    var level: Int  // 0=offline, 1-2=starting, 3-5=healthy
    private let heights: [CGFloat] = [5, 7, 10, 8, 6]
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i < level ? barColor : DS.Border.subtle)
                    .frame(width: 3.5, height: heights[i])
                    .animation(.easeInOut(duration: 0.3), value: level)
            }
        }
    }
    private var barColor: Color {
        if level >= 4 { return DS.Semantic.success }
        if level >= 2 { return DS.Semantic.warning }
        return DS.Semantic.error
    }
}

// MARK: - Glow Button

struct GlowButton: View {
    var label: String
    var icon: String
    var accentColor: Color
    var accentSecondary: Color
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var action: () -> Void
    @State private var glowOpacity: Double = 0.4
    var body: some View {
        Button(action: action) {
            ZStack {
                if !isDisabled {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(accentColor)
                        .blur(radius: 14)
                        .opacity(glowOpacity)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                glowOpacity = 0.7
                            }
                        }
                }
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        isDisabled
                            ? AnyShapeStyle(DS.Surface.light)
                            : AnyShapeStyle(LinearGradient(colors: [accentColor, accentSecondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(isDisabled ? 0.05 : 0.22), .clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: icon).font(.body.weight(.medium))
                    }
                    Text(isLoading ? "Generating..." : label).fontWeight(.semibold)
                }
                .foregroundStyle(isDisabled ? DS.Text.tertiary : .white)
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            .shadow(color: isDisabled ? .clear : accentColor.opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }
}

// MARK: - Voice Clone Icon (DNA/Person hybrid for cloning)

struct VoiceCloneIcon: View {
    var color: Color = .blue

    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height

            // Person silhouette (head)
            let headCenter = CGPoint(x: width * 0.35, y: height * 0.25)
            let headRadius = width * 0.15

            var headPath = Path()
            headPath.addEllipse(in: CGRect(
                x: headCenter.x - headRadius,
                y: headCenter.y - headRadius,
                width: headRadius * 2,
                height: headRadius * 2
            ))
            context.fill(headPath, with: .color(color))

            // Person silhouette (body)
            var bodyPath = Path()
            bodyPath.move(to: CGPoint(x: width * 0.2, y: height * 0.45))
            bodyPath.addQuadCurve(
                to: CGPoint(x: width * 0.5, y: height * 0.45),
                control: CGPoint(x: width * 0.35, y: height * 0.35)
            )
            bodyPath.addLine(to: CGPoint(x: width * 0.45, y: height * 0.75))
            bodyPath.addLine(to: CGPoint(x: width * 0.25, y: height * 0.75))
            bodyPath.closeSubpath()
            context.fill(bodyPath, with: .color(color))

            // DNA helix strands (representing cloning)
            let helixColor = color.opacity(0.8)

            // Left strand
            var strand1 = Path()
            strand1.move(to: CGPoint(x: width * 0.55, y: height * 0.15))
            strand1.addCurve(
                to: CGPoint(x: width * 0.7, y: height * 0.4),
                control1: CGPoint(x: width * 0.85, y: height * 0.2),
                control2: CGPoint(x: width * 0.5, y: height * 0.35)
            )
            strand1.addCurve(
                to: CGPoint(x: width * 0.55, y: height * 0.65),
                control1: CGPoint(x: width * 0.9, y: height * 0.45),
                control2: CGPoint(x: width * 0.45, y: height * 0.6)
            )
            strand1.addCurve(
                to: CGPoint(x: width * 0.7, y: height * 0.9),
                control1: CGPoint(x: width * 0.85, y: height * 0.7),
                control2: CGPoint(x: width * 0.55, y: height * 0.85)
            )
            context.stroke(strand1, with: .color(helixColor), lineWidth: 2.5)

            // Right strand
            var strand2 = Path()
            strand2.move(to: CGPoint(x: width * 0.7, y: height * 0.15))
            strand2.addCurve(
                to: CGPoint(x: width * 0.55, y: height * 0.4),
                control1: CGPoint(x: width * 0.4, y: height * 0.2),
                control2: CGPoint(x: width * 0.75, y: height * 0.35)
            )
            strand2.addCurve(
                to: CGPoint(x: width * 0.7, y: height * 0.65),
                control1: CGPoint(x: width * 0.35, y: height * 0.45),
                control2: CGPoint(x: width * 0.8, y: height * 0.6)
            )
            strand2.addCurve(
                to: CGPoint(x: width * 0.55, y: height * 0.9),
                control1: CGPoint(x: width * 0.4, y: height * 0.7),
                control2: CGPoint(x: width * 0.7, y: height * 0.85)
            )
            context.stroke(strand2, with: .color(helixColor), lineWidth: 2.5)

            // Connecting bars
            for i in 0..<4 {
                let y = height * (0.22 + Double(i) * 0.19)
                var bar = Path()
                bar.move(to: CGPoint(x: width * 0.55, y: y))
                bar.addLine(to: CGPoint(x: width * 0.7, y: y))
                context.stroke(bar, with: .color(helixColor.opacity(0.6)), lineWidth: 1.5)
            }

            // Sound waves from person
            for i in 1...3 {
                let arcRadius = width * 0.08 * Double(i)
                var arc = Path()
                arc.addArc(
                    center: CGPoint(x: width * 0.5, y: height * 0.4),
                    radius: arcRadius,
                    startAngle: .degrees(-60),
                    endAngle: .degrees(60),
                    clockwise: false
                )
                context.stroke(arc, with: .color(color.opacity(0.3)), lineWidth: 1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - TTS Icon (Speaker with waveform)

struct TTSIcon: View {
    var color: Color = .purple

    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height

            // Speaker cone
            var cone = Path()
            cone.move(to: CGPoint(x: width * 0.15, y: height * 0.35))
            cone.addLine(to: CGPoint(x: width * 0.15, y: height * 0.65))
            cone.addLine(to: CGPoint(x: width * 0.28, y: height * 0.65))
            cone.addLine(to: CGPoint(x: width * 0.45, y: height * 0.8))
            cone.addLine(to: CGPoint(x: width * 0.45, y: height * 0.2))
            cone.addLine(to: CGPoint(x: width * 0.28, y: height * 0.35))
            cone.closeSubpath()
            context.fill(cone, with: .color(color))

            // Sound waves
            let waveColors: [Color] = [
                color.opacity(0.8),
                color.opacity(0.6),
                color.opacity(0.4)
            ]

            for i in 0..<3 {
                let radius = width * (0.12 + Double(i) * 0.1)
                var wave = Path()
                wave.addArc(
                    center: CGPoint(x: width * 0.45, y: height * 0.5),
                    radius: radius,
                    startAngle: .degrees(-50),
                    endAngle: .degrees(50),
                    clockwise: false
                )
                context.stroke(wave, with: .color(waveColors[i]), lineWidth: 2.5)
            }

            // Text "A" indicator
            var textPath = Path()
            textPath.move(to: CGPoint(x: width * 0.75, y: height * 0.75))
            textPath.addLine(to: CGPoint(x: width * 0.85, y: height * 0.35))
            textPath.addLine(to: CGPoint(x: width * 0.95, y: height * 0.75))
            context.stroke(textPath, with: .color(color), lineWidth: 2)

            // Crossbar of A
            var crossbar = Path()
            crossbar.move(to: CGPoint(x: width * 0.78, y: height * 0.6))
            crossbar.addLine(to: CGPoint(x: width * 0.92, y: height * 0.6))
            context.stroke(crossbar, with: .color(color), lineWidth: 1.5)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Previews

#Preview("Voice Clone Icon") {
    VStack(spacing: 20) {
        VoiceCloneIcon()
            .frame(width: 48, height: 48)

        VoiceCloneIcon(color: .cyan)
            .frame(width: 64, height: 64)

        VoiceCloneIcon(color: .green)
            .frame(width: 32, height: 32)
    }
    .padding()
    .background(Color(white: 0.1))
}

#Preview("TTS Icon") {
    VStack(spacing: 20) {
        TTSIcon()
            .frame(width: 48, height: 48)

        TTSIcon(color: .pink)
            .frame(width: 64, height: 64)

        TTSIcon(color: .orange)
            .frame(width: 32, height: 32)
    }
    .padding()
    .background(Color(white: 0.1))
}

// MARK: - Kokoro TTS Icon (Waveform heart - kokoro means heart in Japanese)

struct KokoroIcon: View {
    var color: Color = .cyan

    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height

            // Heart shape (kokoro = heart)
            var heart = Path()
            let center = CGPoint(x: width * 0.5, y: height * 0.55)
            heart.move(to: CGPoint(x: center.x, y: height * 0.85))
            // Left curve
            heart.addCurve(
                to: CGPoint(x: width * 0.1, y: height * 0.35),
                control1: CGPoint(x: width * 0.15, y: height * 0.75),
                control2: CGPoint(x: width * 0.05, y: height * 0.55)
            )
            heart.addCurve(
                to: CGPoint(x: center.x, y: height * 0.3),
                control1: CGPoint(x: width * 0.15, y: height * 0.15),
                control2: CGPoint(x: width * 0.35, y: height * 0.2)
            )
            // Right curve
            heart.addCurve(
                to: CGPoint(x: width * 0.9, y: height * 0.35),
                control1: CGPoint(x: width * 0.65, y: height * 0.2),
                control2: CGPoint(x: width * 0.85, y: height * 0.15)
            )
            heart.addCurve(
                to: CGPoint(x: center.x, y: height * 0.85),
                control1: CGPoint(x: width * 0.95, y: height * 0.55),
                control2: CGPoint(x: width * 0.85, y: height * 0.75)
            )
            context.fill(heart, with: .color(color.opacity(0.15)))
            context.stroke(heart, with: .color(color), lineWidth: 2)

            // Sound waveform through the heart
            let waveColor = color
            var wave = Path()
            let waveY = height * 0.48
            let points: [(CGFloat, CGFloat)] = [
                (0.2, 0), (0.28, -0.12), (0.33, 0.08),
                (0.38, -0.2), (0.43, 0.22), (0.48, -0.15),
                (0.53, 0.18), (0.58, -0.22), (0.63, 0.12),
                (0.68, -0.08), (0.73, 0.1), (0.8, 0),
            ]
            wave.move(to: CGPoint(x: width * points[0].0, y: waveY))
            for point in points.dropFirst() {
                wave.addLine(to: CGPoint(x: width * point.0, y: waveY + height * point.1))
            }
            context.stroke(wave, with: .color(waveColor), lineWidth: 2.5)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview("All Icons") {
    HStack(spacing: 20) {
        VStack {
            VoiceCloneIcon(color: .purple)
                .frame(width: 48, height: 48)
            Text("Qwen3-TTS")
                .font(.caption)
        }
        VStack {
            KokoroIcon(color: .cyan)
                .frame(width: 48, height: 48)
            Text("Kokoro")
                .font(.caption)
        }
    }
    .padding()
    .background(Color(white: 0.1))
}
