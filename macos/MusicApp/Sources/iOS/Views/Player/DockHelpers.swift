import SwiftUI
import AVKit

// MARK: - Queue Sheet View

struct QueueSheetView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            let player = appState.player
            if player.queue.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 32))
                        .foregroundStyle(.gray.opacity(0.4))
                    Text(Lang.emptyQueue)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            } else {
                List {
                    ForEach(Array(player.queue.enumerated()), id: \.element.id) { index, track in
                        HStack(spacing: 10) {
                            // Now playing indicator
                            ZStack {
                                if index == player.queueIndex && player.state == .playing {
                                    NowPlayingBars()
                                        .frame(width: 14, height: 12)
                                } else if index == player.queueIndex {
                                    Image(systemName: "speaker.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white)
                                } else {
                                    Text("\(index + 1)")
                                        .font(.caption2)
                                        .foregroundStyle(.gray.opacity(0.5))
                                }
                            }
                            .frame(width: 24)

                            CoverArtView(path: track.coverArtPath, size: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.system(size: 13, weight: index == player.queueIndex ? .semibold : .regular))
                                    .foregroundStyle(index == player.queueIndex ? .white : .white.opacity(0.8))
                                    .lineLimit(1)

                                Text(track.artist)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.gray)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(track.duration.formattedDuration)
                                .font(.caption2)
                                .foregroundStyle(.gray.opacity(0.4))
                                .fontDesign(.monospaced)
                        }
                        .listRowBackground(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            player.setQueue(player.queue, startIndex: index)
                        }
                    }
                    .onDelete { offsets in
                        var queue = player.queue
                        var idx = player.queueIndex
                        let deletingCurrent = offsets.contains(idx)
                        for offset in offsets.sorted().reversed() {
                            queue.remove(at: offset)
                            if offset < idx {
                                idx -= 1
                            } else if offset == idx {
                                idx = min(idx, max(0, queue.count - 1))
                            }
                        }
                        player.queue = queue
                        if queue.isEmpty {
                            player.stop()
                        } else {
                            player.queueIndex = max(0, min(idx, queue.count - 1))
                            if deletingCurrent, player.queueIndex < queue.count {
                                let newTrack = queue[player.queueIndex]
                                player.setQueue(queue, startIndex: player.queueIndex)
                            }
                        }
                    }
                    .onMove { from, to in
                        var queue = player.queue
                        var idx = player.queueIndex
                        queue.move(fromOffsets: from, toOffset: to)
                        // Update current index after move
                        for fromIndex in from {
                            if fromIndex == idx {
                                idx = to > fromIndex ? to - 1 : to
                            } else if fromIndex < idx && to > idx {
                                idx -= 1
                            } else if fromIndex > idx && to <= idx {
                                idx += 1
                            }
                        }
                        player.queue = queue
                        player.queueIndex = idx
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.black)
                .environment(\.editMode, .constant(.active))
            }
        }
        .navigationTitle(Lang.queue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.black.opacity(0.95))
    }
}

// MARK: - Haptic Feedback

enum Haptic {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - Volume Slider

struct VolumeSlider: View {
    @Binding var value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)

                Capsule()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: max(0, geo.size.width * value), height: 4)

                Circle()
                    .fill(.white)
                    .frame(width: 10, height: 10)
                    .offset(x: max(0, geo.size.width * value - 5))
            }
            .frame(height: 10)
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let ratio = max(0, min(1, drag.location.x / geo.size.width))
                        value = ratio
                    }
            )
        }
        .frame(height: 20)
    }
}

// MARK: - AirPlay Button

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = UIColor.white.withAlphaComponent(0.35)
        picker.activeTintColor = .white
        picker.prioritizesVideoDevices = false
        return picker
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

// MARK: - LRC Parser

struct LRCLine: Identifiable {
    let id = UUID()
    let time: Double
    let text: String
}

struct LRCParser {
    static func parse(_ content: String) -> [LRCLine] {
        var lines: [LRCLine] = []
        for rawLine in content.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            var timestamps: [Double] = []
            var text = trimmed

            while text.hasPrefix("[") {
                guard let closeBracket = text.firstIndex(of: "]") else { break }
                let tag = String(text[text.index(after: text.startIndex)..<closeBracket])
                text = String(text[text.index(after: closeBracket)...])
                if let time = parseTimestamp(tag) {
                    timestamps.append(time)
                }
            }

            let lyricText = text.trimmingCharacters(in: .whitespaces)
            for time in timestamps {
                lines.append(LRCLine(time: time, text: lyricText))
            }
        }
        return lines.sorted { $0.time < $1.time }
    }

    private static func parseTimestamp(_ tag: String) -> Double? {
        let parts = tag.split(separator: ":")
        guard parts.count == 2, let minutes = Double(parts[0]) else { return nil }
        let secParts = parts[1].split(separator: ".")
        guard !secParts.isEmpty, let seconds = Double(secParts[0]) else { return nil }
        var fraction: Double = 0
        if secParts.count > 1, let f = Double("0.\(secParts[1])") {
            fraction = f
        }
        return minutes * 60.0 + seconds + fraction
    }
}

// MARK: - Marquee Text

struct MarqueeText: View {
    let text: String
    let font: Font
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var animating = false

    private var needsScroll: Bool { textWidth > containerWidth && containerWidth > 0 }
    private let pauseDuration: Double = 3.0
    private let scrollSpeed: Double = 30.0

    var body: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize(horizontal: needsScroll, vertical: false)
            .offset(x: needsScroll ? offset : 0)
            .frame(maxWidth: .infinity, alignment: needsScroll ? .leading : .center)
            .clipped()
            .background(
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .hidden()
                    .background(GeometryReader { textGeo in
                        Color.clear
                            .onAppear { textWidth = textGeo.size.width }
                            .onChange(of: text) { _, _ in
                                textWidth = textGeo.size.width
                            }
                    })
            )
            .background(GeometryReader { geo in
                Color.clear
                    .onAppear {
                        containerWidth = geo.size.width
                        startScrollIfNeeded()
                    }
                    .onChange(of: geo.size.width) { _, w in containerWidth = w }
            })
            .onChange(of: text) { _, _ in
                offset = 0
                animating = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    startScrollIfNeeded()
                }
            }
    }

    private func startScrollIfNeeded() {
        guard needsScroll, !animating else { return }
        animating = true
        scrollCycle()
    }

    private func scrollCycle() {
        guard animating, needsScroll else {
            animating = false
            return
        }
        let distance = textWidth - containerWidth + 20
        let duration = distance / scrollSpeed

        DispatchQueue.main.asyncAfter(deadline: .now() + pauseDuration) {
            guard animating else { return }
            withAnimation(.linear(duration: duration)) {
                offset = -distance
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + pauseDuration) {
                guard animating else { return }
                withAnimation(.linear(duration: duration)) {
                    offset = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    scrollCycle()
                }
            }
        }
    }
}
