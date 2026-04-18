import SwiftUI
import UIKit

struct GlassPill: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
    }
}

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
    }
}

extension View {
    func glassPill() -> some View {
        modifier(GlassPill())
    }

    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

struct FilterButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.white.opacity(0.15) : Color.clear)
                .foregroundStyle(isSelected ? .white : .gray)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct SortMenuButton: View {
    let options: [(key: String, label: String)]
    let selected: String
    let onChange: (String) -> Void

    @State private var expanded = false

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.25)) {
                expanded.toggle()
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 12))
                .foregroundStyle(.gray)
                .rotationEffect(.degrees(expanded ? 90 : 0))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if expanded {
                HStack(spacing: 4) {
                    ForEach(options, id: \.key) { option in
                        FilterButton(label: option.label, isSelected: selected == option.key) {
                            onChange(option.key)
                            withAnimation(.spring(duration: 0.25)) {
                                expanded = false
                            }
                        }
                    }
                }
                .fixedSize()
                .offset(x: -32)
                .transition(.opacity)
            }
        }
        .zIndex(10)
    }
}

struct CoverArtView: View {
    let path: String?
    var size: CGFloat? = 48

    var body: some View {
        Group {
            if let path, let image = loadImage(contentsOfFile: path) {
                if let size {
                    Image(platformImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipped()
                        .transition(.opacity.animation(.easeIn(duration: 0.2)))
                } else {
                    Color.clear.overlay(
                        Image(platformImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    )
                    .clipped()
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
                }
            } else {
                ZStack {
                    Color(white: 0.12)
                    Image(systemName: "music.note")
                        .font(.system(size: (size ?? 48) * 0.3))
                        .foregroundStyle(.gray.opacity(0.5))
                }
                .if(size != nil) { view in
                    view.frame(width: size!, height: size!)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: (size ?? 80) > 60 ? 8 : 6))
    }
}

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct FormatBadge: View {
    let format: String

    private var label: String {
        switch format.uppercased() {
        case "FLAC": return "FLAC"
        case "ALAC": return "ALAC"
        case "WAV", "WAVE": return "WAV"
        case "AIFF", "AIF": return "AIFF"
        case "DSD", "DSF", "DFF": return "DSD"
        case "MP3": return "MP3"
        case "AAC", "M4A": return "AAC"
        case "OGG", "VORBIS": return "OGG"
        case "OPUS": return "OPUS"
        case "WMA": return "WMA"
        default: return format.uppercased()
        }
    }

    private var color: Color {
        switch label {
        case "FLAC": return .cyan
        case "ALAC": return .green
        case "WAV", "AIFF": return .teal
        case "DSD": return .purple
        case "MP3": return .orange
        case "AAC": return .yellow
        case "OGG", "OPUS": return .mint
        default: return .gray
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 7, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1.5)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

struct FormatBadgesView: View {
    let formats: Set<String>

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(sortedFormats), id: \.self) { fmt in
                FormatBadge(format: fmt)
            }
        }
    }

    private var sortedFormats: [String] {
        let order = ["DSD", "DSF", "DFF", "FLAC", "ALAC", "WAV", "WAVE", "AIFF", "AIF", "OPUS", "OGG", "AAC", "M4A", "MP3", "WMA"]
        return formats.sorted { a, b in
            let ia = order.firstIndex(of: a.uppercased()) ?? order.count
            let ib = order.firstIndex(of: b.uppercased()) ?? order.count
            return ia < ib
        }
    }
}

struct NowPlayingBars: View {
    var isPlaying: Bool = true
    @State private var animate = false
    private let heights: [CGFloat] = [10, 6, 8]
    private let durations: [Double] = [0.4, 0.5, 0.35]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 3)
                    .frame(height: animate ? heights[i] : CGFloat(3 + i * 2))
                    .animation(
                        animate
                            ? .easeInOut(duration: durations[i])
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15)
                            : .easeOut(duration: 0.2),
                        value: animate
                    )
            }
        }
        .onAppear { animate = isPlaying }
        .onChange(of: isPlaying) { _, playing in animate = playing }
    }
}

extension Double {
    var formattedDuration: String {
        let m = Int(self) / 60
        let s = Int(self) % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}

// MARK: - Progress Bar (always-visible seek circle for touch)

struct ProgressBarView: View {
    let progress: Double
    let onSeek: (Double) -> Void
    @State private var dragRatio: Double?

    private var displayProgress: Double {
        dragRatio ?? progress
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)

                Capsule()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: max(0, geo.size.width * displayProgress), height: 4)

                Circle()
                    .fill(.white)
                    .frame(width: 14, height: 14)
                    .offset(x: max(0, geo.size.width * displayProgress - 7))
            }
            .frame(height: 14)
            .contentShape(Rectangle())
            .onTapGesture { location in
                let ratio = max(0, min(1, location.x / geo.size.width))
                onSeek(ratio)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragRatio = max(0, min(1, value.location.x / geo.size.width))
                    }
                    .onEnded { value in
                        let ratio = max(0, min(1, value.location.x / geo.size.width))
                        dragRatio = nil
                        onSeek(ratio)
                    }
            )
        }
        .frame(height: 14)
    }
}

// MARK: - Letter Sidebar (touch drag with haptic feedback)

struct LetterSidebar: View {
    let letters: [String]
    let onSelect: (String) -> Void
    @State private var activeLetter: String?

    private var isCompact: Bool {
        letters.allSatisfy { $0.count <= 2 }
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                    Text(letter)
                        .font(.system(size: isCompact ? 10 : 8, weight: activeLetter == letter ? .bold : .medium))
                        .foregroundStyle(activeLetter == letter ? .white : .gray.opacity(0.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let letterHeight = geo.size.height / CGFloat(letters.count)
                        let index = Int(value.location.y / letterHeight)
                        if index >= 0, index < letters.count {
                            let letter = letters[index]
                            if letter != activeLetter {
                                activeLetter = letter
                                onSelect(letter)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                    }
                    .onEnded { _ in activeLetter = nil }
            )
        }
        .frame(width: isCompact ? 20 : 32)
        .padding(.vertical, 8)
    }
}
