import SwiftUI
import Photos
import AVKit

struct AssetDetailView: View {
    let item: IndexedMediaItem
    @EnvironmentObject var library: PhotoLibraryManager
    @State private var image: UIImage?
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if item.mediaType == .video, let player {
                VideoPlayer(player: player)
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
            }
        }
        .navigationTitle(item.filename ?? "Media")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadContent()
        }
    }

    private func loadContent() async {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [item.localIdentifier], options: nil).firstObject else { return }
        if item.mediaType == .video {
            let manager = PHImageManager.default()
            let opts = PHVideoRequestOptions()
            opts.isNetworkAccessAllowed = true
            let avAsset: AVAsset? = await withCheckedContinuation { continuation in
                manager.requestAVAsset(forVideo: asset, options: opts) { avAsset, _, _ in
                    continuation.resume(returning: avAsset)
                }
            }
            if let urlAsset = avAsset as? AVURLAsset {
                player = AVPlayer(url: urlAsset.url)
            } else if let avAsset {
                let playerItem = AVPlayerItem(asset: avAsset)
                player = AVPlayer(playerItem: playerItem)
            }
        } else {
            image = await library.requestThumbnail(for: item.localIdentifier, targetSize: PHImageManagerMaximumSize)
        }
    }
}
