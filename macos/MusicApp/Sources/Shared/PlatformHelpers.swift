import SwiftUI

#if os(iOS)
import UIKit
public typealias PlatformImage = UIImage
#else
import AppKit
public typealias PlatformImage = NSImage
#endif

nonisolated(unsafe) private let imageCache = NSCache<NSString, PlatformImage>()

func loadImage(contentsOfFile path: String) -> PlatformImage? {
    let key = path as NSString
    if let cached = imageCache.object(forKey: key) {
        return cached
    }
    #if os(iOS)
    guard let image = UIImage(contentsOfFile: path) else { return nil }
    #else
    guard let image = NSImage(contentsOfFile: path) else { return nil }
    #endif
    imageCache.setObject(image, forKey: key)
    return image
}

extension Image {
    init(platformImage: PlatformImage) {
        #if os(iOS)
        self.init(uiImage: platformImage)
        #else
        self.init(nsImage: platformImage)
        #endif
    }
}
