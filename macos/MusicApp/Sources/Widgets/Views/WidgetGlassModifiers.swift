import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct WidgetGlass: ViewModifier {
    var cornerRadius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
    }
}

extension View {
    func widgetGlass(cornerRadius: CGFloat = 8) -> some View {
        modifier(WidgetGlass(cornerRadius: cornerRadius))
    }
}

struct WidgetCoverArt: View {
    let path: String?
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let path, let image = Self.loadCoverImage(path) {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.06)
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.3))
                        .foregroundStyle(.gray.opacity(0.5))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size > 40 ? 6 : 4))
    }

    // Per-process cover cache. Without this, every widget body re-render
    // synchronously re-reads and re-decodes the image on the main thread,
    // which trips WidgetKit's "took too long to render" logs. Bounded so a
    // library with thousands of covers can't retain all decoded images.
    @MainActor private static var coverCache: [String: Image] = [:]
    @MainActor private static var coverCacheOrder: [String] = []
    private static let coverCacheLimit = 32

    @MainActor
    static func loadCoverImage(_ path: String) -> Image? {
        if let cached = coverCache[path] { return cached }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        #if os(iOS)
        guard let uiImage = UIImage(data: data) else { return nil }
        let image = Image(uiImage: uiImage)
        #elseif os(macOS)
        guard let nsImage = NSImage(data: data) else { return nil }
        let image = Image(nsImage: nsImage)
        #else
        return nil
        #endif
        coverCache[path] = image
        coverCacheOrder.append(path)
        if coverCacheOrder.count > coverCacheLimit {
            let evict = coverCacheOrder.removeFirst()
            coverCache.removeValue(forKey: evict)
        }
        return image
    }
}

struct WidgetProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 3)

                Capsule()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: max(0, geo.size.width * progress), height: 3)
            }
        }
        .frame(height: 3)
    }
}
