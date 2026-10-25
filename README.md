# FIXXE — Currency Converter

Real-time multi-currency converter for **Android**, **iOS** and as an installable **PWA** (web app).
Mid-market rates, 300+ currencies incl. crypto, 40 languages.
Built entirely with CLI tools — no Android Studio required.

**Get FIXXE:** [Google Play](https://play.google.com/store/apps/details?id=com.karpinity.fixxe) ·
[App Store](https://apps.apple.com/app/id6815242016) (iPhone, iPad, Apple-silicon Mac) ·
[APK from GitHub releases](https://github.com/fixxe-app/fixxe/releases/latest) for Android without
Google Play · [web app](https://telebimmer.com/fixxe/) that installs to the home screen.

**Open source.** The complete source code — Android, iOS and the web app — is published here under
the [GPL-3.0](LICENSE) licence. See [About the app](https://telebimmer.com/fixxe/about/) for a
description in 40 languages.

### About the APK

The app uses **Play App Signing**, so the key that signs what users install from Google Play lives at
Google. Anything built and signed locally carries a different signature and therefore cannot be
installed over a Play copy, nor updated from Play afterwards.

Google's own universal APK (Play Console → App bundle explorer → Downloads, or
`androidpublisher.generatedapks`) carries the right certificate, but it is **not** a general-purpose
APK: it keeps split-APK metadata, and without the Play Store Android refuses to start it.

What works off-store is a plain **release APK** built here and signed with the upload key. Every
release publishes it on the [GitHub releases page](https://github.com/fixxe-app/fixxe/releases)
(`FIXXE-1.N.apk`) and at `telebimmer.com/fixxe/FIXXE.apk`:

```bash
# the upload keystore and its password live outside the repo — see .release.local.example
./gradlew assembleRelease \
  -Pandroid.injected.signing.store.file="$FIXXE_UPLOAD_KEYSTORE" \
  -Pandroid.injected.signing.store.password="$FIXXE_KEYSTORE_PASSWORD" \
  -Pandroid.injected.signing.key.alias=upload \
  -Pandroid.injected.signing.key.password="$FIXXE_KEYSTORE_PASSWORD"
# → app/build/outputs/apk/release/app-release.apk, attach to the GitHub release
```

It has no split metadata and no Google Play Services dependency, so it installs and runs on devices
with no Google at all — tested on an AOSP Android 16 image with neither `com.google.android.gms`
nor `com.android.vending` present. It cannot be installed over a Play copy, though: different
signature, so the Play version has to be uninstalled first.

### Update notice, and why only off-store

`release.sh` builds this APK itself (`assembleStandalone`) and attaches it to the GitHub release.

The `standalone` build type exists for exactly one difference: it checks GitHub for a newer release
and shows a banner — "FIXXE 1.52 is available / Download" — that opens the release page in a
browser. The app never downloads or installs anything itself, so it needs no
`REQUEST_INSTALL_PACKAGES` (Google grants that only to apps whose core purpose is installing
packages) and never modifies itself.

None of this ships to Play. An app distributed through Play may not update itself by any means
other than Play's own mechanism — Device and Network Abuse policy — so the check lives in
`src/updatecheck/`, while `src/release/` and `src/debug/` get a no-op `UpdateNotice` from
`src/noupdate/`. Verified by grepping the built artifacts: the GitHub API URL appears once in the
standalone APK and zero times in the `.aab` that goes to Play.

A build type rather than a product flavor on purpose: flavors would rename the Gradle task to
`bundlePlayRelease`, and `play-ops` invokes `:app:bundleRelease` by name — publishing would break.

Google's developer-verification rules also apply to apps installed outside Play, but they roll out
by region: Brazil, Indonesia, Singapore and Thailand from September 2026, the rest through 2027.
Verification is tied to the developer's identity, which the Play account already carries.

For "install without a store" the PWA remains the simplest channel — nothing to sign, nothing to
verify, works on any platform.

## Supported platforms and devices

| | Minimum OS | Devices |
|---|---|---|
| **Android** | **7.0 Nougat** (API 24) | phones and tablets |
| **iOS / iPadOS** | **15.0** | iPhone 6s and newer, iPad Air 2 / mini 4 / iPad (5th gen) and newer, all iPad Pro, iPod touch (7th gen) |
| **Web (PWA)** | — | any browser with service workers and `AbortController`: Chrome 66+, Safari 12.1+, Firefox 57+, Edge 79+ |

Details worth knowing:

- **Android** targets API 36 and is built against SDK 36. One binary covers phones and tablets;
  Play lists it for both. No Google Play Services dependency — the app runs on devices without them.
- **iOS** ships as a universal binary (`TARGETED_DEVICE_FAMILY = 1,2`). iPhone is portrait-only;
  iPad supports all four orientations. iOS 15 is a deliberate floor — it covers every iPhone
  released from 2015 onwards, at the cost of some newer SwiftUI APIs (see
  [iOS 15 caveats](#ios-15-caveats)).
- **Mac with Apple silicon** can install the iOS build through the "Designed for iPad" category.
  It is not verified for macOS: we never tested it there, and the App Store says so on the listing.
  Switching that off is a checkbox in App Store Connect → Pricing and Availability.
- **PWA** needs no install and no store. It is the only channel on devices older than the floors
  above, and the fallback for anyone who cannot use Play or the App Store.

### iOS 15 caveats

Things that behave differently on the oldest supported release, and how they are handled:

- `ToolbarItemGroup(placement: .keyboard)` renders nothing unless the view sits inside a
  `NavigationView`. Our list is a `ScrollView` + `LazyVStack` (a `List` swallows the drag-and-drop
  used for reordering), so the keyboard toolbar never appeared and the number pad could not be
  dismissed. The dismiss button lives in the app's own header instead — works on every version.
- Verify such changes on a real iOS 15 device: current Xcode ships no iOS 15 simulator runtime,
  so the simulator cannot prove the behaviour.

## Features

- **Live mid-market rates** with a 3-source fallback chain (see [Rate sources](#rate-sources))
- **335 currencies** in the add dialog — the union of all three sources (fiat, crypto, metals);
  picking one that the active source lacks offers a one-tap switch to a source that has it
- **Real-time conversion** — type in any field, all others update instantly
- **Dynamic base** — the rate line is computed relative to the currency you're editing, not a fixed one
- **Smart rounding** — chosen precision (0/1/2/4) is a minimum; if it would distort a value by >2%,
  that row automatically shows more decimals (e.g. small/strong currencies never collapse to `1`)
- **Source-aware currency picker** — search across all sources or filter by one; colored dots show
  which sources have each currency; find a coin even on a source that lacks it and get a one-tap
  prompt to switch source and add it
- **Forced source** selection in Settings (Auto / ExchangeRate-API / F.A. / Frankfurter), others stay as fallback
- **40 languages** with automatic device-language detection (RTL for Arabic/Hebrew/Persian)
- **Drag to reorder**, delete-with-confirmation, CLEAR, searchable add dialog
- **Persistent** currencies, order, precision, source and language across restarts
- **Works offline** — the last rates are cached on-device, so conversion keeps working with no
  network; if the cache is older than 24 h the header says so instead of passing stale numbers
  off as current
- **No ads, no accounts, no tracking** — the only permission is internet access
- **Android:** settings backed up via Google Backup
- **PWA:** installable, app shell cached, settings stay in the browser

## Rate sources

Multi-source fallback chain (all normalized to EUR base), tried in order; the current source is
shown in the header:

1. **ExchangeRate-API** (`open.er-api.com`) — primary. Open Access tier **requires attribution**:
   the "Rates By Exchange Rate API" link back to [exchangerate-api.com](https://www.exchangerate-api.com)
   shown in the footer.
2. **F.A.** — Fawaz Ahmed currency-api (jsDelivr + `currency-api.pages.dev` mirror). CC0 public
   domain, no attribution. 300+ currencies incl. crypto/metals.
3. **Frankfurter** (`api.frankfurter.dev`) — MIT-licensed API, data from the European Central Bank (ECB).

All are free, no API key, CORS-enabled. Rates update roughly once a day; the difference from other
reference services is usually under 0.5% — these are mid-market reference rates, not real-time quotes.

## Repository layout

```
app/                         # Android app (Kotlin)
  src/main/java/com/example/currencyconverter/
    MainActivity.kt          # UI: RecyclerView, ItemTouchHelper, dialogs, language/source pickers
    UpdateChecker.kt         # In-app auto-update via GitHub Releases API
    data/CurrencyRepository.kt  # OkHttp multi-source fetch + per-source currency lists
    ui/CurrencyViewModel.kt  # AndroidViewModel: state, rates, persistence, source availability
    ui/CurrencyAdapter.kt    # Row binding, smart rounding, drag, double-tap select-all
  src/main/res/values*/      # strings.xml in 40 languages (default = English)
ios/                         # iOS app (SwiftUI, project generated by XcodeGen)
  project.yml                # target settings: deployment target, device family, Info.plist keys
  FIXXE/Views/               # ContentView, CurrencyRowView, AddCurrencyView, RowDropDelegate
  FIXXE/ViewModels/          # ConverterViewModel: state, rates, offline cache
  FIXXE/Services/            # RatesService: the same 3-source chain as Android
  FIXXE/Resources/           # currency-data.json — generated from CurrencyViewModel.kt
  FIXXEUITests/              # XCUITests: keyboard dismissal, reordering, orientations
  tools/shoot-screenshots.sh # store screenshots for iPhone + iPad in the simulator
  tools/render-flags.swift   # flag PNGs side-loaded into DEBUG builds (see below)
  appstore/screenshots/      # what gets uploaded, by display type
web/                         # PWA (vanilla JS/CSS, no build step)
  index.html  app.js  styles.css  sw.js  manifest.webmanifest
  i18n.js                    # auto-generated from Android strings.xml (40 languages)
  currency-data.js           # auto-generated from CurrencyViewModel.kt (symbols/names/flags)
  icons/
tools/gen-data.py            # Kotlin -> web/currency-data.js + ios/.../currency-data.json
tools/gen-i18n.py            # strings.xml -> web/i18n.js
release.sh                   # single release command: Android + PWA in sync, auto-deploy
```

**Single source of truth:** currency symbols, names, flags and the default list live in
`CurrencyViewModel.kt`. After editing them run `python3 tools/gen-data.py` so the PWA and iOS
copies stay identical — never edit the generated files by hand.

**Android stack:** Kotlin, ViewBinding, AndroidViewModel + StateFlow, OkHttp 4 + Gson,
RecyclerView + DiffUtil + ItemTouchHelper, Material Components, SharedPreferences,
per-app locales via `AppCompatDelegate.setApplicationLocales`.

**iOS stack:** SwiftUI targeting iOS 15, `@FocusState` for the active field, `ScrollView` +
`LazyVStack` with `.onDrag`/`.onDrop` for reordering, `UserDefaults` for persistence, XcodeGen for
the project file, XCUITest for UI tests. No third-party dependencies.

**Request timeouts** are 8 s per URL on all three platforms. Worst case — every source down — is
four attempts, and the UI never blocks: cached rates are on screen from the first frame.

## Exchange rate logic

Rates are fetched relative to EUR (the pivot). Any pair is a cross-rate `rate[target] / rate[source]`
computed from a single snapshot — no extra requests when switching the active currency:

```
amountInEUR = userInput / rate[activeCurrency]
result[X]   = amountInEUR × rate[X]
```

The pivot is an implementation detail; the displayed rate line uses the active currency as base.

## Building the Android app

Requirements: macOS, JDK 17 (`brew install openjdk@17`), Android SDK command-line tools in
`~/android-sdk/cmdline-tools/latest/`, `platforms;android-34` + `build-tools;34.0.0`.

```bash
export JAVA_HOME=$(brew --prefix openjdk@17)
export ANDROID_HOME=$HOME/android-sdk
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$JAVA_HOME/bin:$PATH
./gradlew assembleDebug
# APK → app/build/outputs/apk/debug/app-debug.apk
```

## Building the iOS app

Requirements: macOS with Xcode, `xcodegen` (`brew install xcodegen`). The `.xcodeproj` is
generated, so after changing `project.yml` or adding files run `xcodegen generate` in `ios/`.

```bash
cd ios && xcodegen generate
xcodebuild -project FIXXE.xcodeproj -scheme FIXXE \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project FIXXE.xcodeproj -scheme FIXXEUITests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test   # UI tests
```

Note on the deployment target: current Xcode ships no iOS 15 simulator runtime, so anything that
could behave differently there has to be checked on a real iOS 15 device — see
[iOS 15 caveats](#ios-15-caveats).

## Releasing (always use the script)

`release.sh` is the **single source of truth** — it derives everything from one number `N` so the
Android `versionCode`, `versionName`, the git tag, the release body, the PWA `APP_VERSION` and the
service-worker cache all stay in sync:

```bash
./release.sh            # auto-increment
./release.sh 28         # release version 28 explicitly
./release.sh 28 "note"  # with a custom release note
```

It builds the app, bumps the PWA version + SW cache, commits & pushes, tags GitHub release `vN`
(no APK attached), and **auto-deploys the PWA** to the VM (best-effort). It also refuses to run if
it finds Cyrillic in the store copy — everything a store shows must be English.

Shipping to the stores is separate.

**Google Play** (one command builds, signs, uploads and assigns):

```bash
play-ops ship --track production --yes --notes-file store-release-notes.txt
play-ops graphics upload --yes      # only when screenshots changed
```

Release notes come from `store-release-notes.txt` on purpose: `play-ops` otherwise defaults to the
last commit subject, and our commits are in Russian.

**App Store** — build first, wait for Apple to finish processing it, then fill the version:

```bash
cd ios
testflight-ops ship --upload-only --yes --notes-file ../store-release-notes.txt   # build + upload
appstore-ops version create        # create 1.N, attach the latest build
appstore-ops metadata push         # description, keywords, what's new, categories
appstore-ops screenshots upload    # from ios/appstore/screenshots/<locale>/<display type>/
appstore-ops submit --yes          # send for review
```

Caveats learned the hard way:

- `screenshots upload` **adds** to a set, it does not replace. A set caps at 10, so delete the old
  assets first (the API ones, via `appScreenshots`), or the next upload fails.
- Screenshots and the description can only be changed **with a new version** — Apple does not let
  you edit them on a published one. Only the promotional text is editable any time.
- Each new build needs an export-compliance answer. `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption:
  NO` in `project.yml` supplies it; without it the version cannot be submitted and the API only
  says "this resource cannot be reviewed".

## Store screenshots

```bash
ios/tools/shoot-screenshots.sh                 # iPhone 6.9" + iPad 13", into store-assets/
```

The script boots the simulators, forces the status bar to 9:41 and the system language to English
(otherwise the iPad bar shows a localized date), launches the app with a fixed currency list and
rate source, and captures four frames each. The list is passed via `-screen-currencies` so the
frames are full rather than three-quarters empty, and includes the currencies worth showing off.

The simulator's emoji font has no flag glyphs, so `render-flags.swift` renders real PNGs and they
are side-loaded into the DEBUG bundle for the shoot only — release builds never contain them.

## PWA hosting

The web app is a static site: any web server will do. The address published in the stores is
`telebimmer.com/fixxe/`, updated by hand. `release.sh` can also redeploy a mirror over SSH
(`tar → scp → extract → systemctl reload nginx`) when `FIXXE_MIRROR_SSH` is set in
`.release.local`. Assets carry `Cache-Control: no-cache` so updates propagate immediately;
installed PWAs refresh on the next open via the SW cache bump.

## Infrastructure settings

Everything that belongs to one particular publisher — the upload keystore and its password, the
PWA mirror, the App Store Connect and Google Play credentials — is read from `.release.local`
(not in git). Copy `.release.local.example` and fill in your own values; without the file the
scripts still run and simply skip those steps.

## License

FIXXE is free software: you can redistribute it and/or modify it under the terms of the
**GNU General Public License v3.0 or later** — see [LICENSE](LICENSE). Any derivative work must be
published under the same licence, with its source.

Copyright © 2026 Karpinity (Davidovski GmbH).

**The FIXXE name and logo are not covered by the licence.** Forks and derivatives must use their own
name and icon; they must not present themselves as FIXXE or as published by Karpinity.

Displayed rates are mid-market reference rates. "Rates By Exchange Rate API" attribution is
required by ExchangeRate-API's Open Access tier and shown in-app.

### Contributing

Bug reports, translation fixes and pull requests are welcome. By submitting a change you agree
that it is licensed under GPL-3.0-or-later and that it may also be distributed as part of FIXXE
through the Apple App Store and Google Play, whose terms differ from the GPL.
