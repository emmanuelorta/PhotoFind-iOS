# PhotoFind iOS

A native iOS app that lets you search your Photos library (photos AND videos) by typing what you're looking for — powered by PhotoKit, Vision, and Core Spotlight.

This version incorporates every fix from the build audit performed on the earlier scaffold:

- Fixed the fatal `actor` + `ObservableObject` conflict — `MediaIndexer` is now a proper `@MainActor final class`.
- Removed the invalid `async` computed properties (`awaitableIsIndexing`/`awaitableProgress`) that could never compile inside a synchronous SwiftUI `body`.
- Replaced the racy unstructured-`Task`-per-asset indexing loop with `TaskGroup`-based, concurrency-capped batches (6 assets in flight at a time) — no more shared-array data race.
- Indexing is now **incremental**: already-indexed `localIdentifier`s are tracked and skipped on every subsequent launch, instead of reprocessing the whole library every time.
- Added OCR via `VNRecognizeTextRequest` alongside `VNClassifyImageRequest`, so text/captions inside photos and video frames are now actually searchable.
- Replaced the private, undocumented `asset.value(forKey: "filename")` KVC call with the supported `PHAssetResource.assetResources(for:).first?.originalFilename`.
- Added `PHPhotoLibraryChangeObserver` so newly taken photos/videos get indexed without a full relaunch.
- Added `.limited` photo-library-access handling with `PHPhotoLibrary.shared().presentLimitedLibraryPicker`.
- Reverse geocoding is now cached by a rounded coordinate grid cell instead of firing one network request per photo.
- Added an `NSCache`-backed thumbnail cache so scrolling the results grid doesn't re-request the same image repeatedly.
- Added a real `AssetDetailView` for viewing full-resolution photos and playing videos (`AVPlayer`).
- Added `PrivacyInfo.xcprivacy` for App Store submission requirements.

## The one honest limitation

iOS does not allow any third-party app to replace or take over the system Photos app — Apple does not expose that level of system integration. What this app does, which is the closest Apple-sanctioned equivalent to "integrating into Photos":

- **Core Spotlight integration** (`SpotlightIndexer.swift`) — every indexed photo/video is pushed into the system Spotlight index, so swiping down from your Home Screen and typing a search term surfaces matches from your library system-wide.
- Shares the exact same photo library as the Photos app via PhotoKit.
- Reacts live to new photos/videos via `PHPhotoLibraryChangeObserver`.

## What still requires a manual step

This repo contains all Swift source files, `Info.plist`, and `PrivacyInfo.xcprivacy`, but not a binary `.xcodeproj`/`project.pbxproj`. To build:

1. Open Xcode → File → New → Project → iOS → App.
2. Name it `PhotoFind`, interface: SwiftUI, language: Swift, minimum target: iOS 17+.
3. Delete the auto-generated `ContentView.swift` and `PhotoFindApp.swift`.
4. Drag every `.swift` file from this repo's `PhotoFind/` folder into the project navigator (check "Copy items if needed").
5. Replace the project's `Info.plist` with the one in this repo.
6. Add `PrivacyInfo.xcprivacy` to the project target.
7. Sign with your Apple ID team, then build to a real iPhone (test on-device, not Simulator).

## Info.plist keys required

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>PhotoFind needs access to your photo library to search photos and videos.</string>
<key>PHPhotoLibraryPreventAutomaticLimitedAccessAlert</key>
<true/>
```

## Search coverage

Matches on: media type, favorite/hidden status, screenshot/live-photo/portrait/panorama/HDR/slow-mo/timelapse subtypes, creation date, reverse-geocoded place name, original filename, Vision scene/object classification labels, and OCR'd text in images or sampled video frames.

## Known remaining limits

- Vision's `VNClassifyImageRequest` uses a general label set and will not recognize specific named people or pets — Apple's own People & Pets model is not public API.
- Search quality is bounded by what Vision/OCR actually detect in the pixels.
- Very large libraries (50k+ assets) take time to fully index on first run; later launches only process new items.