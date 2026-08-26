import SwiftUI

final class ThumbnailCache {
    static let shared = NSCache<NSString, UIImage>()
}

struct ThumbnailView: View {
    @EnvironmentObject var library: PhotoLibraryManager
    let identifier: String
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(.gray.opacity(0.18))
                    .overlay(ProgressView().controlSize(.small))
            }
        }
        .task {
            if let cached = ThumbnailCache.shared.object(forKey: identifier as NSString) {
                image = cached
                return
            }
            if let loaded = await library.requestThumbnail(for: identifier, targetSize: CGSize(width: 240, height: 240)) {
                ThumbnailCache.shared.setObject(loaded, forKey: identifier as NSString)
                image = loaded
            }
        }
        .clipped()
    }
}
