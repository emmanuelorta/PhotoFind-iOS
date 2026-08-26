import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

final class SpotlightIndexer {
    static let shared = SpotlightIndexer()
    private let domainIdentifier = "com.photofind.media"

    func index(items: [IndexedMediaItem]) {
        guard !items.isEmpty else { return }
        let searchableItems = items.map { item -> CSSearchableItem in
            let attributes = CSSearchableItemAttributeSet(contentType: item.mediaType == .video ? UTType.movie : UTType.image)
            attributes.title = item.filename ?? (item.mediaType == .video ? "Video" : "Photo")
            attributes.contentDescription = item.terms.joined(separator: ", ")
            attributes.keywords = item.terms
            if let date = item.creationDate {
                attributes.contentCreationDate = date
            }
            return CSSearchableItem(uniqueIdentifier: item.localIdentifier, domainIdentifier: domainIdentifier, attributeSet: attributes)
        }
        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
            if let error {
                print("Spotlight indexing error: \(error)")
            }
        }
    }

    func removeAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier], completionHandler: nil)
    }
}
