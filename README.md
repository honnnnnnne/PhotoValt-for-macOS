# PhotoValt-for-macOS
A photo-viewing app that offers an experience similar to the native Photos app, with added features. Created using Gemini 4.
# PhotoVault for macOS

**The familiar look and feel of macOS Photos.app — supercharged with browser-style multi-tabs, spatial trackpad video scrubbing, and 120fps performance for 100,000+ photo libraries.**

PhotoVault is a native macOS photo and video browser built with **Swift 6**, **SwiftUI**, **AppKit**, [**PhotoKit**](https://www.google.com/search?q=https%3A%2F%2Fdeveloper.apple.com%2Fdocumentation%2Fphotos "ヌル"), [**MapKit**](https://www.google.com/search?q=https%3A%2F%2Fdeveloper.apple.com%2Fdocumentation%2Fmapkit "ヌル"), [**AVFoundation**](https://www.google.com/search?q=https%3A%2F%2Fdeveloper.apple.com%2Fdocumentation%2Favfoundation "ヌル"), and **SQLite3**. It connects directly to your existing macOS System Photo Library (`Photos Library.photoslibrary`) in **100% Read-Only, Non-Destructive Mode**—preserving all your existing Albums, Folders, Smart Albums, People, Favorites, Keywords, and Captions with zero re-importing or file duplication, while eliminating the everyday UI frustrations of Apple's stock `Photos.app`.

## Why PhotoVault? (Native Photos.app vs. PhotoVault)

PhotoVault intentionally mirrors the dark visual aesthetic and muscle memory of macOS `Photos.app` so you feel at home immediately, while upgrading every bottleneck in navigation, video playback, and large-library browsing:

| Feature / Workflow | Apple macOS `Photos.app` | **PhotoVault for macOS** | 
| ----- | ----- | ----- | 
| **Multitasking & Navigation** | Single-view window; switching from an album to People or Map loses your current context | **Chrome-Style Multi-Tab Bar (`⌘T` / `⌘W`)**: Open any Album, Folder, Person, Smart Album, or Map in parallel tabs with independent filters and zoom levels | 
| **Scroll Position Memory** | Sidebar or grid scroll position can reset when jumping between detail views and collections | **100% Persistent Scroll Memory**: Opens albums at the bottom (most recent items) by default and keeps the sidebar & grid mounted underneath the detail viewer so scroll offsets never reset | 
| **Trackpad Video Scrubbing vs. Photo Swiping** | Two-finger swipes and pinches often conflict or trigger unintended actions | **Spatial Trackpad Gesture Separation**: Two-finger swipe **over the HUD controller** scrubs frame-by-frame ([Apple QA1820](https://www.google.com/search?q=https%3A%2F%2Fdeveloper.apple.com%2Flibrary%2Farchive%2Fqa%2Fqa1820%2F_index.html) zero-tolerance chase seek); two-finger swipe **on the canvas** flips to the previous/next photo with live adjacent previews | 
| **Video Player Controls** | Fixed bottom controller with limited speed controls | **Freely Draggable Floating HUD + Speed Controls**: Drag the video HUD anywhere on screen so it never blocks subtitles, with `-5s` rewind, `+10s` skip, and `1.5x / 2x / 4x / 8x` fast-forward buttons | 
| **Zooming & Panning Stability** | Limited zoom range; gesture coordinate feedback can feel sluggish | **Zero-Flyaway 1.0x–8.0x Zoom (`StationaryDetailCanvasGestureView`)**: Unscaled AppKit gesture router prevents coordinate feedback flyaway during rapid pinch-to-zoom and pan | 
| **100,000+ Asset Library Performance** | Large `LazyVGrid` views can stall layout passes when scrolling tens of thousands of items | **3-Column Year Overview + 2,000-Item Page Slicing**: Consolidates sparse decades (`1970–79`), slices large views into 2,000-item pages (`1`, `2`, `3`...), and renders via row-chunked `LazyVStack` | 
| **Smart Albums & Native Metadata** | Locked inside Apple's private frameworks | **Native `Photos.sqlite` + Protobuf (`PLQuery`) Decoder**: Evaluates macOS `Photos.app` Smart Albums (`ZUSERQUERYDATA`), custom key photos (`ZCUSTOMKEYASSET`), and key faces (`ZPERSON.ZKEYFACE`) out of the box | 
| **Data Safety** | Edits mutate the system library directly | **100% Read-Only & Non-Destructive**: Opens `Photos.sqlite` with \`SQLITE_OPEN_READONLY | 

## Key Features & UX Enhancements

### 1. Familiar macOS Photos UX with Zero Migration

* **Instant System Library Integration**: Reads `~/Pictures/Photos Library.photoslibrary` (or any external `.photoslibrary` selected via `⌘O`) without copying a single photo.

* **Complete Hierarchy Fidelity**: Preserves your exact folder/album hierarchy, album sort order, custom album key photos (`ZCUSTOMKEYASSET` / `ZKEYASSET`), and People key faces (`ZPERSON.ZKEYFACE`).

* **Native Smart Album Protobuf Decoder**: Built-in binary wire-format decoder (`ApplePhotosSmartAlbumProtobufDecoder`) parses `ZGENERICALBUM.ZUSERQUERYDATA` (`PLQuery` / `PLSingleQuery`) to evaluate complex multi-condition Smart Albums (Caption, Title, Keyword, Person, Camera/Lens, Favorites, Media Type, and Date ranges).

### 2. Upgraded Browsing, Tabs & Scroll Ergonomics

* **Dynamic Chrome-Style Multi-Tab Bar**: Tabs automatically resize to fit the window width. Right-click any sidebar item or folder card to **Open in New Tab**.

* **3-Column Library Year Overview**: Clicking **Library** presents a 3-column year card overview showing each year's key photo and total count (automatically grouping decades with fewer than 50 photos into ranges like `1970–79`). Double-clicking a year opens its photos in 2,000-item pages.

* **Bottom-Anchored Default Scroll & Persistent State**: Just like native `Photos.app`, opening an album or library page starts scrolled to the bottom (newest photos first). Opening a photo into the full-window detail player and pressing `ESC` or `Back` restores your exact scroll pixel offset in both the photo grid and the left sidebar.

* **Rubber-Band Marquee Selection & Inline GIF Playback**: Drag from grid whitespace to multi-select items with a rubber-band selection box; animated GIFs play inline automatically when visible.

### 3. Spatial Trackpad Gestures & Pro Video Player

* **Cursor-Aware Trackpad Routing**:

  * **Cursor over Video HUD + 2-Finger Horizontal Swipe**: Smooth, frame-accurate variable-speed video scrubbing powered by [Apple Technical Q&A QA1820](https://www.google.com/search?q=https%3A%2F%2Fdeveloper.apple.com%2Flibrary%2Farchive%2Fqa%2Fqa1820%2F_index.html) (`toleranceBefore: .zero, toleranceAfter: .zero`).

  * **Cursor over Canvas + 2-Finger Pinch / Pan**: Smooth `1.0x–8.0x` zoom and panning captured on a stationary AppKit surface so transformed views never cause coordinate flyaway.

  * **Cursor over Canvas + 2-Finger Horizontal Swipe**: 1:1 interactive finger-tracking swipe between adjacent photos and videos.

* **Auto-Hiding Top Bar Synchronized with macOS Traffic Lights**: In detail view, the top toolbar, tab bar, and macOS window close/minimize/zoom buttons hide for distraction-free viewing and slide down together only when the cursor approaches the top edge of the active monitor (`NSToolbarFullScreenWindow` aware).

### 4. Draggable Info Inspector (`⌘I`), Keyword Manager (`⌘K`) & Batch Tools

* **Compact Floating Info Panel (`⌘I`)**: Freely draggable inspector displaying editable Title, Original Filename (`IMG_XXXX.JPG`), Creation Date (with quick `Adjust...` button), Camera/Lens model, a 5-column EXIF bar (`ISO | mm | ev | f | s`), native `ZASSETDESCRIPTION` captions, keyword capsules, circular People avatars, and a 2D location mini-map.

* **Keyword Manager (`⌘K`) & Batch Date/Time Adjust**: Toggle keywords across multiple selected photos with a single click, or shift timestamps across a batch of photos while preserving their relative time intervals.

* **External Editor Launcher**: Right-click any photo and choose **Edit With** to open the asset directly in compatible installed macOS apps (Photoshop, Pixelmator Pro, Capture One, Preview, etc.).

## Architecture Overview

```
+-----------------------------------------------------------------------------------+
|                        SwiftUI + AppKit Presentation Layer                        |
|  - PhotoVaultCompleteRootView (Persistent ZStack: Sidebar + Main Pane + Detail)   |
|  - ChromeStyleTabBarView / UnifiedTopActionToolbar (2,000-item Page Jumpers)      |
|  - StationaryDetailCanvasGestureView (Unscaled AppKit NSEvent Gesture Router)     |
|  - SmoothVideoSeekController (Apple QA1820 Zero-Tolerance Chase Seek Engine)      |
|  - PhotoClusterMapView (AppKit MKMapView + CoreAnimation Bubble Pin Clustering)   |
+-----------------------------------------+-----------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
|                     @MainActor @Observable Workspace ViewModel                    |
|  - Multi-tab state management (BrowserTabState) & WorkspacePersistenceSnapshot    |
|  - O(1) cached page slicing (max 2,000 items/page) & 3-column Year overview       |
|  - Non-destructive local overlay (Favorites, Custom Albums, Tags, Date Shifts)    |
+--------------------+-----------------------------------------+--------------------+
                     |                                         |
                     v                                         v
+----------------------------------------+ +----------------------------------------+
|      PhotoKit (PHCachingImageManager)  | |   Photos.sqlite Read-Only Engine       |
|  - Fast derivative thumbnail decoding  | |  - SQLITE_OPEN_READONLY | NOMUTEX      |
|  - Bucket-quantized target sizes       | |  - ZASSET / ZADDITIONALASSETATTRIBUTES |
|  - Strictly local grid browsing        | |  - ZDETECTEDFACE x ZPERSON (ZKEYFACE)  |
|    (isNetworkAccessAllowed = false)    | |  - ZGENERICALBUM + PLQuery Protobuf    |
+----------------------------------------+ +----------------------------------------+

```

## Getting Started (Build & Run in Xcode)

Currently, the entire application is distributed as a self-contained single-file Swift source (`PhotoVaultCompleteApp_EN.swift` for English UI, `PhotoVaultCompleteApp.swift` for Japanese UI) with **zero external dependencies** so anyone can build and test it in Xcode in under 2 minutes.

### Requirements

* **macOS 14.0 Sonoma** or later (macOS 15 Sequoia & Apple Silicon M1–M4 recommended)

* **Xcode 15.0** or later (Swift 5.10 / Swift 6 strict concurrency compatible)

### Step-by-Step Build Instructions

1. **Create a New macOS App Project in Xcode**:

   * Open Xcode and select **File > New > Project... (`⇧⌘N`)**.

   * Choose **macOS > App**, then click **Next**.

   * Set **Product Name** to `PhotoVaultMac`, **Interface** to `SwiftUI`, **Language** to `Swift`, and **Storage** to `None`.

2. **Replace Template Files with PhotoVault Source**:

   * Delete the auto-generated `ContentView.swift`.

   * Open `PhotoVaultMacApp.swift`, replace its entire contents with `PhotoVaultCompleteApp_EN.swift` (or `PhotoVaultCompleteApp.swift`), and save (`⌘S`).

3. **Add Photo Library Permission in `Info` Tab**:

   * Select the project root in the Xcode Project Navigator -> **TARGETS > PhotoVaultMac > Info**.

   * Add the key `Privacy - Photo Library Usage Description` (`NSPhotoLibraryUsageDescription`) with a string value such as `"PhotoVault uses Photo Library access to browse photos, videos, maps, and metadata at high speed."`

4. **Configure App Sandbox for `Photos.sqlite` Read Access**:

   * Go to **TARGETS > PhotoVaultMac > Signing & Capabilities**.

   * Click the trash/remove icon (`×`) on **App Sandbox** so the app can directly open `~/Pictures/Photos Library.photoslibrary/database/Photos.sqlite` in read-only mode.

   * *(Optional)* If you keep App Sandbox enabled, set **File Access > Pictures Folder** to `Read Only` and select your `Photos Library.photoslibrary` once via **File > Open Photo Library... (`⌘O`)**.

5. **Build & Run (`⌘R`)**:

   * Select **My Mac** as the run destination and press **`⌘R`**. Grant Photo Library access when prompted.

## Customizing UI Sizing & Layout

Every UI dimension—including grid column counts, thumbnail spacing, sidebar width, row height, top toolbar height, people portrait aspect ratio, info panel width, and font sizes—is annotated inline.
Search for **`UI SIZING:`** in `PhotoVaultCompleteApp_EN.swift` (or **`★【UIサイズ調整`** in `PhotoVaultCompleteApp.swift`) using `⌘F` in Xcode to jump directly to all 11 categories of layout constants.

## Contributing & Roadmap (Good First Issues)

Contributions, bug reports, and pull requests are warmly welcome! Here are high-impact areas where community contributors can jump right in:

1. **Modularize Single-File Source into Folders (`Good First Issue`)**:

   * Split the `// MARK: - 1` through `// MARK: - 19` sections into dedicated folders (`Models/`, `SQLite/`, `Services/`, `ViewModels/`, `Views/`) while keeping a clean Xcode project structure.

2. **Expand `PLQuery` Smart Album Protobuf Operators**:

   * Add support for additional undocumented `PLSingleQuery` comparators (e.g., aperture/ISO numeric ranges, burst photo flags, raw/ProRAW filters).

3. **On-Device Standalone Vision/CoreML Face Clustering for External Folders**:

   * Integrate `VNDetectFaceRectanglesRequest` + `VNGenerateImageFeaturePrintRequest` / `CoreML` embeddings for raw Finder folders outside `Photos.sqlite`.

4. **Localization (`Localizable.xcstrings`)**:

   * Unify `PhotoVaultCompleteApp_EN.swift` and `PhotoVaultCompleteApp.swift` into a single codebase backed by an Xcode String Catalog (`Localizable.xcstrings`).

## Safety, Privacy & Disclaimer

* **100% Read-Only Database Access**: PhotoVault opens `Photos.sqlite` exclusively with `SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX` and never executes `PHPhotoLibrary.shared().performChanges` or mutating SQL statements. Your original photo library is never altered.

* **No Network Telemetry**: All database queries, thumbnail decoding, and reverse geocoding run locally on your Mac. Grid browsing strictly sets `isNetworkAccessAllowed = false` to prevent background iCloud download storms.

* **Disclaimer**: This project is an independent open-source project and is not affiliated with, authorized by, or endorsed by Apple Inc. Provided "AS IS" without warranty of any kind.

## 🇯🇵 日本語ガイド (Japanese Overview)

**PhotoVault for macOS** は、macOS純正「写真」アプリ（`Photos.app`）の直感的なデザイン・操作感をそのまま継承しつつ、純正アプリの弱点だった「タブ移動のしづらさ」「動画シークと写真スワイプの誤爆」「数万枚規模でのスクロールのカクつき」「コントローラーの位置固定」をすべて解消したネイティブ写真・動画ブラウザです。

### 純正「写真」アプリからの主な進化ポイント

* **完全非破壊・読み取り専用（Read-Only）で即時移行**: `~/Pictures/Photos Library.photoslibrary` を直接読み取り専用で開くため、写真の再インポートや容量の二重消費なしで、本家で作ったアルバム・フォルダ・スマートアルバム・ピープル・キー写真・キャプションがそのまま表示されます。

* **Chrome風マルチタブバー（`⌘T` / `⌘W`）**: ライブラリ、お気に入り、ピープル、地図、個別アルバムを別々のタブで同時に開き、画面状態を保ったまま瞬時に行き来できます。

* **スクロール位置の完全記憶 & 下端（最新写真）からのデフォルト表示**: アルバムやライブラリを開いた際は純正と同じく一番下（最新の写真）がデフォルトで表示され、写真を拡大表示して戻った際もサイドバーとグリッドのスクロール位置が1ミリもずれずに復帰します。

* **QuickTime / VLC 級の空間分離トラックパッド動画シーク**:

  * **動画コントローラー上にカーソルがある時**: 2本指水平スワイプで1フレーム単位〜高速可変シーク（[Apple QA1820](https://www.google.com/search?q=https%3A%2F%2Fdeveloper.apple.com%2Flibrary%2Farchive%2Fqa%2Fqa1820%2F_index.html) 準拠のゼロトレランスシーク）。

  * **写真・動画キャンバス上にカーソルがある時**: 2本指ピンチで吹っ飛びゼロの無段階拡大（`1.0x〜8.0x`）、2本指水平スワイプで前後の写真・動画へ滑らかにページ送り。

* **自由にドラッグ移動できる動画コントローラー & 倍速ボタン復活**: 字幕や被写体に重ならないようコントローラーを画面内のどこへでもドラッグ移動でき、`-5秒` 巻き戻し、`+10秒` スキップ、`1.5x / 2x / 4x / 8x` 早送りボタンを搭載しています。

* **UIサイズの簡単カスタマイズ**: ソースコード内で `★【UIサイズ調整`（英語版は `UI SIZING:`）と検索（`⌘F`）すると、グリッド間隔、サイドバー幅、ピープル写真の縦横比、文字サイズなどの数値行へ直接ジャンプして自分好みに調整できます。
