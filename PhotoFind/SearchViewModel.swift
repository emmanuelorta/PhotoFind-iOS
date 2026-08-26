import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [IndexedMediaItem] = []

    func refreshResults(query: String, index: [IndexedMediaItem]) async {
        self.query = query
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        let words = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        results = index
            .map { item in
                let hay = Set(item.terms)
                let score = words.reduce(into: 0) { partial, word in
                    if hay.contains(word) { partial += 4 }
                    partial += hay.filter { $0.contains(word) || word.contains($0) }.count
                    if item.mediaType.rawValue == word { partial += 2 }
                    if item.filename?.lowercased().contains(word) == true { partial += 2 }
                }
                return (item, score)
            }
            .filter { $0.1 > 0 }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 { return (lhs.0.creationDate ?? .distantPast) > (rhs.0.creationDate ?? .distantPast) }
                return lhs.1 > rhs.1
            }
            .map { $0.0 }
    }
}
