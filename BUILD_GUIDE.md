# PhotoFind — From Repo to Running App on Your iPhone

This guide takes the PhotoFind-iOS repository from GitHub to an app icon on your
iPhone's home screen. The repo already contains the full SwiftUI source and an
Xcode project (`PhotoFind.xcodeproj`), so the remaining steps are building,
signing, and installing.

## What PhotoFind does

Based on the repository's commit history, the app:

- Indexes your photo library on-device with a background media indexer
- Extracts text from images (OCR) so photos are searchable by their content
- Integrates with Core Spotlight, so your photos are findable from iOS system
  search
- Supports iOS limited photo library access

## Path A — You have access to a Mac (fastest, free)

1. **Install Xcode** from the Mac App Store (free, roughly 12 GB).
2. **Clone the repo**:

   ```bash
   git clone https://github.com/emmanuelorta/PhotoFind-iOS.git
   cd PhotoFind-iOS
   ```

3. **Open the project**: double-click `PhotoFind.xcodeproj` (or run `open
   PhotoFind.xcodeproj`).
4. **Add your Apple ID to Xcode**: Xcode → Settings → Accounts → `+` → sign in
   with your personal Apple ID. This creates a free "Personal Team".
5. **Configure signing**: select the `PhotoFind` target → **Signing &
   Capabilities** → check *Automatically manage signing* → select your
   Personal Team under *Team*.
6. **Set a unique bundle identifier** (e.g. `com.emmanuelorta.photofind`) if
   signing complains about the default.
7. **Plug your iPhone into the Mac** (unlock it, tap *Trust* if prompted). In
   Xcode's toolbar, select your iPhone as the run destination.
8. **Press ⌘R** to build and run. First build may take a few minutes.
9. **Trust the developer on the iPhone**: the first launch will be blocked —
   go to Settings → General → VPN & Device Management → tap your Apple ID →
   *Trust*. Launch the app again.
10. **Grant photo access** when prompted. Choose *Full Access* for complete
    indexing, or *Limited Access* to pick specific albums/photos.

### Free-account limitations

- Apps signed with a free Personal Team expire after **7 days** — re-run from
  Xcode to refresh.
- A free Apple ID can only have **3 apps** installed at once per device.
- No TestFlight or App Store distribution.

## Path B — No Mac

iOS builds require Xcode, which only runs on macOS. Your options:

1. **Borrow or rent a Mac** (MacinCloud and similar services rent Macs by the
   hour) and follow Path A.
2. **GitHub Actions CI** (now included in this repo): every push to `main`
   triggers a build on GitHub's macOS runners. This verifies the project
   compiles and uploads the compiled app as an artifact. It does **not** sign
   the app — installing on a device still requires a Mac + Apple ID.
3. **TestFlight distribution** (requires a Mac *and* the $99/yr Apple
   Developer Program): archive the app and upload to App Store Connect, then
   invite testers via public link.

## CI details

`.github/workflows/build.yml` builds the app against the iOS Simulator with
signing disabled and uploads `PhotoFind.app` as a downloadable artifact.

- **Public repo**: Actions usage is free.
- **Private repo**: macOS runner minutes bill at 10× the standard rate — each
  build uses roughly 10–15 billed minutes. Keep an eye on the Actions usage
   page, or use `workflow_dispatch` to build only on demand.

If the build fails, open the failed run in the **Actions** tab — the log shows
the exact file and line number of each compiler error.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Signing error in Xcode | Set a Team, make the bundle ID unique (e.g. `com.emmanuelorta.photofind`) |
| "Untrusted developer" on iPhone | Settings → General → VPN & Device Management → Trust your profile |
| App icon disappears after a week | Free provisioning expired — re-run from Xcode, or join the Developer Program |
| Empty photo grid in the app | Check Settings → Privacy & Security → Photos → PhotoFind |
| Build fails in CI | Read the Actions log; compiler errors list file + line |

## Verify the build before touching Xcode

Push any change (or manually trigger the workflow from the repo's **Actions**
tab → *Build PhotoFind (iOS)* → *Run workflow*). A green check means the
project compiles cleanly; a red X means the log contains the exact errors to
fix before you spend time in Xcode.
