# PhotoFind for iOS

[![Build PhotoFind (iOS)](https://github.com/emmanuelorta/PhotoFind-iOS/actions/workflows/build.yml/badge.svg)](https://github.com/emmanuelorta/PhotoFind-iOS/actions/workflows/build.yml)

Search your Photos library by what is *in* the pictures — the text on a sign, a label, a receipt, a whiteboard — not just by date or album. Native SwiftUI, on-device, no account, no upload.

## What it does

- **Indexes on-device** with PhotoKit: photos and videos, incrementally, so a second launch only processes what is new.
- **Reads the text** in images and sampled video frames with Vision OCR, and labels scenes and objects with Vision classification.
- **Pushes every indexed item into Core Spotlight**, so a swipe-down search on the Home Screen finds your photos system-wide.
- **Matches on** media type, favorite/hidden state, screenshot / Live Photo / portrait / panorama / slow-mo / timelapse subtypes, creation date, reverse-geocoded place, original filename, Vision labels, and OCR text.
- **Respects limited library access** (`.limited`) and reacts live to new photos via `PHPhotoLibraryChangeObserver`.

## Build

The repo contains the full source and `PhotoFind.xcodeproj`. Xcode 15+, iOS 17+, a real device (Vision and Spotlight behave differently in the Simulator). Every push to `main` is compiled on GitHub's macOS runners by `.github/workflows/build.yml`; the badge above is that workflow's last result.

```bash
git clone https://github.com/emmanuelorta/PhotoFind-iOS.git
open PhotoFind-iOS/PhotoFind.xcodeproj
```

Set your signing team, build to your iPhone. Step-by-step, including the no-Mac route, is in [BUILD_GUIDE.md](BUILD_GUIDE.md); TestFlight distribution in [TESTFLIGHT_SETUP.md](TESTFLIGHT_SETUP.md).

Required `Info.plist` keys:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>PhotoFind needs access to your photo library to search photos and videos.</string>
<key>PHPhotoLibraryPreventAutomaticLimitedAccessAlert</key>
<true/>
```

## The honest limits

- iOS does not let a third-party app replace the Photos app. Core Spotlight is the closest Apple-sanctioned integration, and that is what this uses.
- `VNClassifyImageRequest` uses a general label set; it will not recognise specific people or pets (Apple's People & Pets model is not public API).
- Search quality is bounded by what Vision and OCR actually detect in the pixels.
- Libraries of 50k+ assets take time on the first index; later launches process only new items.

## Why it exists

The Photos app searches metadata and Apple's own scene labels. It does not search the words inside your photos. This does, entirely on the device, with the system search as the front door.

## Engineering notes

`MediaIndexer` is a `@MainActor final class`; indexing runs as concurrency-capped `TaskGroup` batches (6 assets in flight); thumbnails are cached in `NSCache`; reverse geocoding is cached per rounded coordinate cell; filenames come from `PHAssetResource.originalFilename`, not private KVC. `PrivacyInfo.xcprivacy` is included for App Store submission.

## Licence

MIT. Built by [Emmanuel Orta](https://emmanuelorta.com/).
