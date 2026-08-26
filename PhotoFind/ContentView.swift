import SwiftUI
import PhotosUI

struct ContentView: View {
    @EnvironmentObject var library: PhotoLibraryManager
    @EnvironmentObject var indexer: MediaIndexer
    @EnvironmentObject var searchModel: SearchViewModel

    private let suggestions = ["dog", "beach sunset", "family", "video concert", "screenshot", "reptile", "mountains", "portrait"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        NavigationStack {
            Group {
                if !library.authorizationStatus.isAuthorizedLike {
                    accessView
                } else {
                    mainView
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchModel.query, prompt: "Photos, videos, places, text")
            .onSubmit(of: .search) {
                Task { await searchModel.refreshResults(query: searchModel.query, index: indexer.items) }
            }
            .onChange(of: searchModel.query) { _, newValue in
                Task { await searchModel.refreshResults(query: newValue, index: indexer.items) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .photoLibraryDidChangeExternally)) { _ in
                Task {
                    library.fetchAssets()
                    await indexer.indexIfNeeded(using: library)
                    await searchModel.refreshResults(query: searchModel.query, index: indexer.items)
                }
            }
        }
    }

    @ViewBuilder
    private var accessView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 54))
            Text("Allow Photo Library Access")
                .font(.title2.bold())
            Text("PhotoFind needs access to search your photos and videos.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Grant Access") {
                Task { await library.bootstrap() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }

    @ViewBuilder
    private var mainView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if library.authorizationStatus == .limited {
                    limitedAccessBanner
                }

                if indexer.isIndexing {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Indexing library")
                            .font(.headline)
                        ProgressView(value: indexer.progress)
                        Text("Analyzing new photos and videos so text search works. Already-indexed items are skipped on future launches.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                if searchModel.query.isEmpty {
                    suggestionSection
                }

                if !searchModel.results.isEmpty {
                    Text("\(searchModel.results.count) results")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(searchModel.results) { item in
                            NavigationLink(value: item) {
                                ZStack(alignment: .bottomLeading) {
                                    ThumbnailView(identifier: item.localIdentifier)
                                        .aspectRatio(1, contentMode: .fill)
                                    HStack(spacing: 4) {
                                        if item.mediaType == .video {
                                            Image(systemName: "video.fill")
                                        }
                                        if item.isFavorite {
                                            Image(systemName: "heart.fill")
                                        }
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(.black.opacity(0.35), in: Capsule())
                                    .padding(6)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .navigationDestination(for: IndexedMediaItem.self) { item in
                        AssetDetailView(item: item)
                    }
                } else if !searchModel.query.isEmpty {
                    ContentUnavailableView.search(text: searchModel.query)
                        .padding(.top, 40)
                }
            }
            .padding(.bottom, 20)
        }
    }

    private var limitedAccessBanner: some View {
        Button {
            NotificationCenter.default.post(name: .presentLimitedLibraryPicker, object: nil)
        } label: {
            HStack {
                Image(systemName: "photo.stack")
                VStack(alignment: .leading) {
                    Text("Limited photo access").font(.subheadline.bold())
                    Text("Tap to select more photos to search").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    private var suggestionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested Searches")
                .font(.headline)
                .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion.capitalized) {
                            searchModel.query = suggestion
                            Task { await searchModel.refreshResults(query: suggestion, index: indexer.items) }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
