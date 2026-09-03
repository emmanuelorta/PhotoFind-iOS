# TestFlight Setup — PhotoFind

This repo can build, sign, and upload PhotoFind to TestFlight entirely from
GitHub Actions. Until the secrets below are configured, the *TestFlight Upload*
workflow simply skips — the *Build PhotoFind (iOS)* compile check keeps working
with zero configuration.

## Prerequisites

1. **Apple Developer Program membership** ($99/yr).
2. **An app record in App Store Connect** whose bundle ID exactly matches the
   one in the Xcode project. Open `PhotoFind.xcodeproj` in Xcode → target
   *PhotoFind* → *General* → *Bundle Identifier* to see it (change it to
   something unique like `com.emmanuelorta.photofind` first if needed), then
   create the app with that ID at appstoreconnect.apple.com.
3. **One session on a Mac** (borrowed or rented is fine) to export your signing
   certificate. After that, every release is CI-only.

## One-time secret setup

### 1. Export your distribution certificate (on the Mac)

Open **Keychain Access**, right-click your *Apple Distribution* certificate →
*Export* → save as `.p12` with a password you choose. If you have no
certificate yet, Xcode → Settings → Accounts → your team → *Manage
Certificates* → `+` → *Apple Distribution* creates one.

### 2. Create an App Store Connect API key

At App Store Connect: *Users and Access* → *Integrations* → *App Store Connect
API* → `+`. Choose the **App Manager** role (or higher). Download the
`AuthKey_XXXXXXXXXX.p8` file — it **cannot be re-downloaded**. Note the
**Key ID** and **Issuer ID** shown next to it.

### 3. Base64-encode the files (on the Mac)

```bash
base64 -i Certificates.p12 | pbcopy
# paste into BUILD_CERTIFICATE_BASE64

base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
# paste into ASC_KEY_BASE64
```

### 4. Add the GitHub secrets

Repo → *Settings* → *Secrets and variables* → *Actions* → *New repository
secret*:

| Secret name | Contents |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | Base64 of your `.p12` distribution certificate |
| `P12_PASSWORD` | Password you set when exporting the `.p12` |
| `KEYCHAIN_PASSWORD` | Any password for the temporary CI keychain (e.g. a random string) |
| `ASC_KEY_ID` | Key ID of the App Store Connect API key |
| `ASC_ISSUER_ID` | Issuer ID of the App Store Connect API key |
| `ASC_KEY_BASE64` | Base64 of the `AuthKey_...p8` file |
| `ASC_TEAM_ID` | Your 10-character Apple Team ID (found in Developer portal → Membership) |

## Releasing a build

The workflow runs when you push a version tag, or manually:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Or: repo → *Actions* → *TestFlight Upload* → *Run workflow*.

The upload takes ~5–10 minutes, then the build appears in App Store Connect →
TestFlight and needs another 10–30 minutes of processing before testers can
install it. Build numbers are set automatically from the GitHub run number, so
every upload is unique.

Add internal testers (up to 100 per app) in App Store Connect, or enable a
public TestFlight link to share with anyone.

## Cost

- Public repo: Actions minutes are free.
- Private repo: macOS runners bill at 10×. A TestFlight run uses roughly 15–25
  billed minutes; tag-triggered releases keep this occasional.

## Troubleshooting

| Error | Cause and fix |
| --- | --- |
| No signing certificate "Apple Distribution" found | Certificate import failed — check the `security find-identity` output in the *Import signing certificate* step |
| exportArchive: "requires a provisioning profile" | The bundle ID in the project doesn't match the app record in App Store Connect, or the API key lacks the App Manager role |
| altool: Invalid API key | Base64 of the `.p8` got line breaks/spaces when pasted — re-copy with `base64 -i file.p8 \| pbcopy` |
| No profiles for bundle ID | App record not created in App Store Connect yet, or bundle ID mismatch |

## Advanced: no Mac at all

Creating the distribution certificate normally needs macOS, but it can be done
without one: the App Store Connect API accepts a certificate-signing request,
and a CSR + private key can be generated with OpenSSL anywhere, then combined
into a `.p12`. If you have no Mac access, ask and this can be scripted.
