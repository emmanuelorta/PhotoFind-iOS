import Foundation
import Photos
import CoreLocation

struct IndexedMediaItem: Identifiable, Codable, Hashable {
    let id: String
    let localIdentifier: String
    let mediaType: MediaKind
    let creationDate: Date?
    let latitude: Double?
    let longitude: Double?
    let duration: Double?
    let pixelWidth: Int
    let pixelHeight: Int
    let terms: [String]
    let filename: String?
    let subtitle: String?
    let isFavorite: Bool
    let mediaSubtypes: [String]

    var location: CLLocation? {
        guard let latitude, let longitude else { return nil }
        return CLLocation(latitude: latitude, longitude: longitude)
    }
}

enum MediaKind: String, Codable, CaseIterable {
    case photo
    case video
}

struct SearchSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [IndexedMediaItem]
}

extension PHAuthorizationStatus {
    var isAuthorizedLike: Bool {
        self == .authorized || self == .limited
    }
}

extension Notification.Name {
    static let photoLibraryDidChangeExternally = Notification.Name("photoLibraryDidChangeExternally")
    static let presentLimitedLibraryPicker = Notification.Name("presentLimitedLibraryPicker")
}
