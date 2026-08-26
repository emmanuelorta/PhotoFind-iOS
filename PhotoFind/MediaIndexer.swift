import Foundation
import Photos
import Vision
import AVFoundation
import UIKit
import CoreLocation

@MainActor
final class MediaIndexer: NSObject, ObservableObject {
    @Published private(set) var items: [IndexedMediaItem] = []
    @Published private(set) var isIndexing = false
    @Published private(set) var progress: Double = 0

    private var indexedIdentifiers: Set<String> = []
    private let geocodeCache = GeocodeCache()
    private let maxConcurrentIndexingTasks = 6

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("media-index.json")
    }()

    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func loadPersistedIndex() async {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([IndexedMediaItem].self, from: data) else { return }
        items = decoded
        indexedIdentifiers = Set(decoded.map { $0.localIdentifier })
    }

    func indexIfNeeded(using library: PhotoLibraryManager) async {
        guard let assets = library.allAssets else { return }
        var toIndex: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            if !self.indexedIdentifiers.contains(asset.localIdentifier) {
                toIndex.append(asset)
            }
        }
        guard !toIndex.isEmpty else { return }

        isIndexing = true
        progress = 0
        var newItems: [IndexedMediaItem] = []
        var completed = 0
        let total = toIndex.count
        let cache = geocodeCache

        var chunkStart = 0
        while chunkStart < toIndex.count {
            let chunkEnd = min(chunkStart + maxConcurrentIndexingTasks, toIndex.count)
            let chunk = Array(toIndex[chunkStart..<chunkEnd])
            let results = await withTaskGroup(of: IndexedMediaItem?.self, returning: [IndexedMediaItem].self) { group in
                for asset in chunk {
                    group.addTask {
                        await MediaIndexer.buildItem(for: asset, geocodeCache: cache)
                    }
                }
                var collected: [IndexedMediaItem] = []
                for await result in group {
                    if let result { collected.append(result) }
                }
                return collected
            }
            newItems.append(contentsOf: results)
            completed += chunk.count
            progress = Double(completed) / Double(total)
            chunkStart = chunkEnd
        }

        items = (items + newItems).sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        indexedIdentifiers.formUnion(newItems.map { $0.localIdentifier })
        isIndexing = false

        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: fileURL)
        }

        SpotlightIndexer.shared.index(items: newItems)
    }

    nonisolated private static func buildItem(for asset: PHAsset, geocodeCache: GeocodeCache) async -> IndexedMediaItem? {
        var terms = Set<String>()
        var subtypeTerms: [String] = []

        if asset.mediaType == .image { terms.insert("photo") }
        if asset.mediaType == .video { terms.insert("video") }
        if asset.isFavorite { terms.insert("favorite") }
        if asset.isHidden { terms.insert("hidden") }

        let subtypeMap: [(PHAssetMediaSubtype, String)] = [
            (.photoPanorama, "panorama"),
            (.photoHDR, "hdr"),
            (.photoScreenshot, "screenshot"),
            (.photoLive, "live photo"),
            (.photoDepthEffect, "portrait"),
            (.videoStreamed, "streamed video"),
            (.videoHighFrameRate, "slow motion"),
            (.videoTimelapse, "timelapse")
        ]
        for (subtype, label) in subtypeMap where asset.mediaSubtypes.contains(subtype) {
            terms.insert(label)
            subtypeTerms.append(label)
        }

        if let date = asset.creationDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            terms.insert(formatter.string(from: date).lowercased())
            formatter.dateFormat = "yyyy"
            terms.insert(formatter.string(from: date).lowercased())
            formatter.dateFormat = "MMMM"
            terms.insert(formatter.string(from: date).lowercased())
        }

        if let location = asset.location, let placeName = await geocodeCache.placeName(for: location) {
            placeName.split(separator: " ").forEach { terms.insert($0.lowercased()) }
            terms.insert(placeName.lowercased())
        }

        let filename = PHAssetResource.assetResources(for: asset).first?.originalFilename
        if let filename {
            filename.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).forEach { terms.insert(String($0)) }
        }

        if asset.mediaType == .image {
            let visionTerms = await MediaIndexer.imageTerms(for: asset)
            visionTerms.forEach { terms.insert($0) }
        } else if asset.mediaType == .video {
            let visionTerms = await MediaIndexer.videoTerms(for: asset)
            visionTerms.forEach { terms.insert($0) }
        }

        return IndexedMediaItem(
            id: asset.localIdentifier,
            localIdentifier: asset.localIdentifier,
            mediaType: asset.mediaType == .video ? .video : .photo,
            creationDate: asset.creationDate,
            latitude: asset.location?.coordinate.latitude,
            longitude: asset.location?.coordinate.longitude,
            duration: asset.mediaType == .video ? asset.duration : nil,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            terms: Array(terms).sorted(),
            filename: filename,
            subtitle: nil,
            isFavorite: asset.isFavorite,
            mediaSubtypes: subtypeTerms
        )
    }

    nonisolated private static func imageTerms(for asset: PHAsset) async -> [String] {
        let manager = PHImageManager.default()
        let targetSize = CGSize(width: 512, height: 512)
        let image: UIImage? = await withCheckedContinuation { continuation in
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .highQualityFormat
            opts.resizeMode = .fast
            opts.isSynchronous = false
            opts.isNetworkAccessAllowed = true
            manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: opts) { image, _ in
                continuation.resume(returning: image)
            }
        }
        guard let cgImage = image?.cgImage else { return [] }
        async let classification = classify(cgImage: cgImage)
        async let text = recognizeText(cgImage: cgImage)
        return await classification + text
    }

    nonisolated private static func videoTerms(for asset: PHAsset) async -> [String] {
        let manager = PHImageManager.default()
        let avAsset: AVAsset? = await withCheckedContinuation { continuation in
            let opts = PHVideoRequestOptions()
            opts.isNetworkAccessAllowed = true
            manager.requestAVAsset(forVideo: asset, options: opts) { avAsset, _, _ in
                continuation.resume(returning: avAsset)
            }
        }
        guard let avAsset else { return [] }
        let generator = AVAssetImageGenerator(asset: avAsset)
        generator.appliesPreferredTrackTransform = true
        let durationSeconds = max(CMTimeGetSeconds(avAsset.duration), 0.1)
        let sampleCount = min(max(Int(durationSeconds / 4), 2), 6)
        let step = durationSeconds / Double(sampleCount)
        var terms = Set<String>()
        for i in 0..<sampleCount {
            let time = CMTime(seconds: Double(i) * step, preferredTimescale: 600)
            if let cg = try? generator.copyCGImage(at: time, actualTime: nil) {
                async let classification = classify(cgImage: cg)
                async let text = recognizeText(cgImage: cg)
                let frameTerms = await classification + text
                frameTerms.forEach { terms.insert($0) }
            }
        }
        return Array(terms)
    }

    nonisolated private static func classify(cgImage: CGImage) async -> [String] {
        await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, _ in
                let observations = (request.results as? [VNClassificationObservation]) ?? []
                let labels = observations.prefix(8).filter { $0.confidence > 0.18 }.flatMap {
                    $0.identifier.lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                }
                continuation.resume(returning: Array(Set(labels)))
            }
            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
        }
    }

    nonisolated private static func recognizeText(cgImage: CGImage) async -> [String] {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let strings = observations.compactMap { $0.topCandidates(1).first?.string.lowercased() }
                continuation.resume(returning: strings)
            }
            request.recognitionLevel = .fast
            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
        }
    }
}

extension MediaIndexer: PHPhotoLibraryChangeObserver {
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            NotificationCenter.default.post(name: .photoLibraryDidChangeExternally, object: nil)
        }
    }
}

actor GeocodeCache {
    private var cache: [String: String] = [:]
    private let geocoder = CLGeocoder()

    func placeName(for location: CLLocation) async -> String? {
        let key = gridKey(for: location.coordinate)
        if let cached = cache[key] { return cached.isEmpty ? nil : cached }
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
            cache[key] = ""
            return nil
        }
        let name = [placemark.locality, placemark.administrativeArea, placemark.country].compactMap { $0 }.joined(separator: " ")
        cache[key] = name
        return name.isEmpty ? nil : name
    }

    private func gridKey(for coordinate: CLLocationCoordinate2D) -> String {
        let lat = (coordinate.latitude * 20).rounded() / 20
        let lon = (coordinate.longitude * 20).rounded() / 20
        return "\(lat),\(lon)"
    }
}
