import SwiftUI

@main
struct PhotoFindApp: App {
    @StateObject private var library = PhotoLibraryManager()
    @StateObject private var indexer = MediaIndexer()
    @StateObject private var searchModel = SearchViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .environmentObject(indexer)
                .environmentObject(searchModel)
                .task {
                    await library.bootstrap()
                    if library.authorizationStatus.isAuthorizedLike {
                        await indexer.loadPersistedIndex()
                        await indexer.indexIfNeeded(using: library)
                        await searchModel.refreshResults(query: searchModel.query, index: indexer.items)
                    }
                }
        }
    }
}
