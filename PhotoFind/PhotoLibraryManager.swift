import Foundation
import Photos
import UIKit

@MainActor
final class PhotoLibraryManager: NSObject, ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var allAssets: PHFetchResult<PHAsset>?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handlePresentLimitedPicker), name: .presentLimitedLibraryPicker, object: nil)
    }

    func bootstrap() async {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if authorizationStatus == .notDetermined {
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            authorizationStatus = status
        }
        guard authorizationStatus.isAuthorizedLike else { return }
        fetchAssets()
    }

    func fetchAssets() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        allAssets = PHAsset.fetchAssets(with: options)
    }

    func requestThumbnail(for localIdentifier: String, targetSize: CGSize) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject else { return nil }
        let manager = PHImageManager.default()
        return await withCheckedContinuation { continuation in
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .opportunistic
            opts.resizeMode = .fast
            opts.isSynchronous = false
            opts.isNetworkAccessAllowed = true
            manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: opts) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    @objc private func handlePresentLimitedPicker() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: root)
    }
}
