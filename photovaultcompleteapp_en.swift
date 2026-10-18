//
//  PhotoVaultCompleteApp.swift
//  PhotoVaultMac — Complete Integrated Build v13
//
//  Platform: macOS 14.0+ (Apple Silicon Optimized)
//  Language: Swift 5.10 / Swift 6 (Strict Concurrency & Default MainActor Isolation Ready)
//  Frameworks: SwiftUI, AppKit, Photos, MapKit, AVFoundation, CoreImage, ImageIO, UniformTypeIdentifiers, CoreLocation, SQLite3, Observation
//
//  IMPORTANT NON-DESTRUCTIVE POLICY:
//  This application NEVER mutates or writes to the user's original Photos Library (`Photos Library.photoslibrary`).
//  `PHPhotoLibrary.shared().performChanges` is NEVER called, and `Photos.sqlite` is accessed strictly Read-Only.
//  People detection and photo deletion are delegated to the native macOS Photos.app; this app is dedicated to fast, comfortable browsing.
//
//  ============================================================================
//  ★ [UI SIZING GUIDE] Search for "UI SIZING:" in Xcode (⌘F) to jump directly to
//  every customizable UI dimension, padding, font size, and aspect ratio:
//    1. ★ [UI SIZING: Grid Defaults]        ... Default column count, thumbnail spacing, and square crop default
//    2. ★ [UI SIZING: Page Capacity]        ... Maximum assets displayed per page (default: 2,000 items)
//    3. ★ [UI SIZING: Sidebar]              ... Initial width, drag resize min/max, font size, and row padding
//    4. ★ [UI SIZING: Top Toolbar & Tabs]   ... Action toolbar height, tab bar height, page button & search bar widths
//    5. ★ [UI SIZING: Library Year Grid]    ... 3-column year overview card count, spacing, margins, and font sizes
//    6. ★ [UI SIZING: Folder Album Cards]   ... Folder album card width, aspect ratio, corner radius, and font sizes
//    7. ★ [UI SIZING: People Grid & Header] ... Portrait crop ratio, margins, card spacing, and name font sizes
//    8. ★ [UI SIZING: Photo Grid & Cells]   ... Grid horizontal margins, cell corner radius, selection border, and heart icon size
//    9. ★ [UI SIZING: Info Inspector Panel] ... Floating Info (i) panel width, font sizes, circular face avatar size, and mini-map height
//   10. ★ [UI SIZING: Detail View & HUD]    ... Floating video controller width/offset and face name tag pill font size
//   11. ★ [UI SIZING: Map Annotation Pins]  ... Map thumbnail bubble pin dimensions and badge font size
//  ============================================================================
//

import SwiftUI
import AppKit
import Photos
import MapKit
import AVFoundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import CoreLocation
import SQLite3
import Observation

// MARK: - 0. App Lifecycle Delegate (Red Close Button Quits App + Dark-Adapted Custom Icon)

@MainActor
final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let customIcon = CustomAppIconAsset.makeDarkAdaptedAppIcon() {
            NSApplication.shared.applicationIconImage = customIcon
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

enum CustomAppIconAsset {
    @MainActor
    static func makeDarkAdaptedAppIcon() -> NSImage? {
        let size = NSSize(width: 512, height: 512)
        let img = NSImage(size: size)
        img.lockFocus()
        defer { img.unlockFocus() }

        guard let ctx = NSGraphicsContext.current?.cgContext else { return nil }
        let rect = CGRect(origin: .zero, size: size)

        let bgPath = CGPath(roundedRect: rect.insetBy(dx: 20, dy: 20), cornerWidth: 108, cornerHeight: 108, transform: nil)
        ctx.saveGState()
        ctx.addPath(bgPath)
        ctx.clip()
        let colors = [
            NSColor(calibratedRed: 0.14, green: 0.14, blue: 0.16, alpha: 1.0).cgColor,
            NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.09, alpha: 1.0).cgColor
        ] as CFArray
        if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) {
            ctx.drawLinearGradient(grad, start: CGPoint(x: 256, y: 492), end: CGPoint(x: 256, y: 20), options: [])
        }
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(bgPath)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.14).cgColor)
        ctx.setLineWidth(4.0)
        ctx.strokePath()
        ctx.restoreGState()

        let petalColors: [NSColor] = [
            NSColor(calibratedRed: 1.00, green: 0.27, blue: 0.23, alpha: 0.88),
            NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.04, alpha: 0.88),
            NSColor(calibratedRed: 1.00, green: 0.84, blue: 0.04, alpha: 0.88),
            NSColor(calibratedRed: 0.19, green: 0.82, blue: 0.35, alpha: 0.88),
            NSColor(calibratedRed: 0.39, green: 0.82, blue: 1.00, alpha: 0.88),
            NSColor(calibratedRed: 0.04, green: 0.52, blue: 1.00, alpha: 0.88),
            NSColor(calibratedRed: 0.75, green: 0.35, blue: 0.95, alpha: 0.88),
            NSColor(calibratedRed: 1.00, green: 0.22, blue: 0.37, alpha: 0.88)
        ]

        ctx.saveGState()
        ctx.translateBy(x: 256, y: 256)
        ctx.setBlendMode(.screen)
        for i in 0..<8 {
            ctx.saveGState()
            let angle = CGFloat(i) * (.pi / 4.0)
            ctx.rotate(by: angle)
            let petalRect = CGRect(x: -44, y: 18, width: 88, height: 142)
            let petalPath = CGPath(roundedRect: petalRect, cornerWidth: 44, cornerHeight: 44, transform: nil)
            ctx.addPath(petalPath)
            ctx.setFillColor(petalColors[i].cgColor)
            ctx.fillPath()
            ctx.restoreGState()
        }
        ctx.restoreGState()

        return img
    }
}

// MARK: - 1. Domain Models (nonisolated & Sendable for Swift 6 Strict Concurrency)

/// Detected face & person metadata (extracted from Photos.sqlite ZDETECTEDFACE × ZPERSON, including native ZPERSON.ZKEYFACE support)
nonisolated struct DetectedFaceInfo: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var personUUID: String?
    var displayName: String
    var fullName: String?
    var centerX: Double
    var centerY: Double
    var size: Double
    var qualityScore: Double
    var isFavoritePerson: Bool
    var isKeyFaceInSQLite: Bool

    init(
        id: String = UUID().uuidString,
        personUUID: String? = nil,
        displayName: String,
        fullName: String? = nil,
        centerX: Double = 0.5,
        centerY: Double = 0.5,
        size: Double = 0.14,
        qualityScore: Double = 0.5,
        isFavoritePerson: Bool = false,
        isKeyFaceInSQLite: Bool = false
    ) {
        self.id = id
        self.personUUID = personUUID
        self.displayName = displayName
        self.fullName = fullName
        self.centerX = centerX
        self.centerY = centerY
        self.size = size
        self.qualityScore = qualityScore
        self.isFavoritePerson = isFavoritePerson
        self.isKeyFaceInSQLite = isKeyFaceInSQLite
    }

    enum CodingKeys: String, CodingKey {
        case id, personUUID, displayName, fullName, centerX, centerY, size, qualityScore, isFavoritePerson, isKeyFaceInSQLite
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        personUUID = try c.decodeIfPresent(String.self, forKey: .personUUID)
        displayName = try c.decode(String.self, forKey: .displayName)
        fullName = try c.decodeIfPresent(String.self, forKey: .fullName)
        centerX = try c.decode(Double.self, forKey: .centerX)
        centerY = try c.decode(Double.self, forKey: .centerY)
        size = try c.decode(Double.self, forKey: .size)
        qualityScore = try c.decodeIfPresent(Double.self, forKey: .qualityScore) ?? size
        isFavoritePerson = try c.decodeIfPresent(Bool.self, forKey: .isFavoritePerson) ?? false
        isKeyFaceInSQLite = try c.decodeIfPresent(Bool.self, forKey: .isKeyFaceInSQLite) ?? false
    }

    var isUnnamed: Bool {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.hasPrefix("Untitled") || trimmed == "Unnamed" || trimmed.hasPrefix("名称未設定")
    }

    /// Normalized face bounding box converted to SwiftUI top-left origin (0.0...1.0)
    var normalizedSwiftUIRect: CGRect {
        let clampedSize = max(0.04, min(size, 1.0))
        let originX = max(0.0, min(centerX - clampedSize / 2.0, 1.0 - clampedSize))
        let flippedCenterY = 1.0 - centerY
        let originY = max(0.0, min(flippedCenterY - clampedSize / 2.0, 1.0 - clampedSize))
        return CGRect(x: originX, y: originY, width: clampedSize, height: clampedSize)
    }

    /// Square normalized crop rect for circular face avatars in the Info panel (scaled to fit the full head comfortably)
    var avatarCropNormalizedRect: CGRect {
        let paddedSize = max(0.16, min(size * 2.25, 1.0))
        let originX = max(0.0, min(centerX - paddedSize / 2.0, 1.0 - paddedSize))
        let flippedCenterY = 1.0 - centerY
        let originY = max(0.0, min(flippedCenterY - paddedSize * 0.48, 1.0 - paddedSize))
        return CGRect(x: originX, y: originY, width: paddedSize, height: paddedSize)
    }

    /// Vertical portrait normalized crop rect for People grid & header cards (framing full head and upper shoulders)
    var portraitAvatarCropNormalizedRect: CGRect {
        let cropW = max(0.22, min(size * 2.55, 1.0))
        let cropH = max(0.30, min(cropW * 1.38, 1.0))
        let originX = max(0.0, min(centerX - cropW / 2.0, 1.0 - cropW))
        let flippedCenterY = 1.0 - centerY
        // Center vertically so the crown of the head and shoulders fit naturally without clipping
        let originY = max(0.0, min(flippedCenterY - cropH * 0.46, 1.0 - cropH))
        return CGRect(x: originX, y: originY, width: cropW, height: cropH)
    }
}

/// Extended EXIF, video codec, frame rate, and file size metadata
nonisolated struct ExifSummary: Hashable, Codable, Sendable {
    var cameraMake: String?
    var cameraModel: String?
    var lensModel: String?
    var iso: Int?
    var aperture: Double?
    var shutterSpeed: Double?
    var focalLength: Double?
    var exposureBias: Double?
    var fps: Double?
    var codecName: String?
    var originalFileSize: Int64?

    init(
        cameraMake: String? = nil,
        cameraModel: String? = nil,
        lensModel: String? = nil,
        iso: Int? = nil,
        aperture: Double? = nil,
        shutterSpeed: Double? = nil,
        focalLength: Double? = nil,
        exposureBias: Double? = nil,
        fps: Double? = nil,
        codecName: String? = nil,
        originalFileSize: Int64? = nil
    ) {
        self.cameraMake = cameraMake
        self.cameraModel = cameraModel
        self.lensModel = lensModel
        self.iso = iso
        self.aperture = aperture
        self.shutterSpeed = shutterSpeed
        self.focalLength = focalLength
        self.exposureBias = exposureBias
        self.fps = fps
        self.codecName = codecName
        self.originalFileSize = originalFileSize
    }

    var formattedSummary: String {
        var parts: [String] = []
        if let model = cameraModel, !model.isEmpty { parts.append(model) }
        if let fl = focalLength, fl > 0 { parts.append(String(format: "%.0fmm", fl)) }
        if let f = aperture, f > 0 { parts.append(String(format: "ƒ/%.1f", f)) }
        if let ss = shutterSpeed, ss > 0 {
            if ss < 1.0 {
                parts.append("1/\(max(1, Int(round(1.0 / ss))))s")
            } else {
                parts.append(String(format: "%.1fs", ss))
            }
        }
        if let iso = iso, iso > 0 { parts.append("ISO \(iso)") }
        if let codec = codecName, !codec.isEmpty { parts.append(codec) }
        if let fps = fps, fps > 0 { parts.append(String(format: "%.0f fps", fps)) }
        return parts.isEmpty ? "No Camera Info" : parts.joined(separator: " · ")
    }

    var formattedFileSize: String {
        guard let bytes = originalFileSize, bytes > 0 else { return "—" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    var isoText: String {
        if let iso, iso > 0 { return "ISO \(iso)" }
        return "ISO —"
    }

    var focalLengthText: String {
        if let fl = focalLength, fl > 0 { return String(format: "%.0f mm", fl) }
        return "— mm"
    }

    var evText: String {
        if let ev = exposureBias { return String(format: "%.0f ev", ev) }
        return "0 ev"
    }

    var apertureText: String {
        if let f = aperture, f > 0 {
            if f.truncatingRemainder(dividingBy: 1.0) == 0 {
                return String(format: "ƒ%.0f", f)
            }
            return String(format: "ƒ%.1f", f)
        }
        return "ƒ—"
    }

    var shutterSpeedText: String {
        guard let ss = shutterSpeed, ss > 0 else { return "— s" }
        if ss < 1.0 {
            return "1/\(max(1, Int(round(1.0 / ss)))) s"
        }
        return String(format: "%.1f s", ss)
    }
}

/// Single asset metadata record extracted from Photos.sqlite (including native ZASSETDESCRIPTION captions)
nonisolated struct SQLiteAssetRecord: Hashable, Sendable {
    let pk: Int64
    let uuid: String
    let internalFilename: String
    let originalFilename: String
    let uniformTypeIdentifier: String?
    let title: String?
    let caption: String?
    let directory: String?
    let latitude: Double?
    let longitude: Double?
    let isLocallyAvailable: Bool
    let isHiddenInSQLite: Bool
    let isTrashedInSQLite: Bool
    let isFavoriteInSQLite: Bool
    let isEditedInSQLite: Bool
    let playbackStyleInSQLite: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let duration: Double
    let creationDate: Date?
    let isVideoInSQLite: Bool
    let faces: [DetectedFaceInfo]
    let keywords: [String]
    let exif: ExifSummary

    var isGIFInSQLite: Bool {
        if playbackStyleInSQLite == 2 { return true }
        let lowerOrig = originalFilename.lowercased()
        let lowerInt = internalFilename.lowercased()
        let lowerUTI = (uniformTypeIdentifier ?? "").lowercased()
        return lowerOrig.hasSuffix(".gif") || lowerInt.hasSuffix(".gif") || lowerUTI.contains("gif")
    }
}

/// Unified photo/video asset model combining PhotoKit PHAsset + Photos.sqlite metadata
nonisolated struct PhotoAssetItem: Identifiable, Hashable, Sendable {
    let id: String                  // PHAsset.localIdentifier ("UUID/L0/001")
    let uuid: String                // 36-character UUID
    var creationDate: Date?
    let modificationDate: Date?
    let mediaTypeRaw: Int           // PHAssetMediaType.rawValue
    let mediaSubtypesRaw: UInt      // PHAssetMediaSubtype.rawValue
    let sourceTypeRaw: UInt
    let playbackStyleRaw: Int       // PHAsset.PlaybackStyle.rawValue (2 == .imageAnimated)
    let pixelWidth: Int
    let pixelHeight: Int
    let duration: TimeInterval
    var isFavorite: Bool
    var isHidden: Bool
    var isTrashed: Bool
    var isEdited: Bool

    let originalFilename: String
    let internalFilename: String
    var uniformTypeIdentifier: String?
    var title: String?
    var caption: String?
    var latitude: Double?
    var longitude: Double?
    var locationName: String?
    let isLocallyAvailable: Bool
    var faces: [DetectedFaceInfo]
    var keywords: [String]
    var exif: ExifSummary

    var mediaType: PHAssetMediaType {
        PHAssetMediaType(rawValue: mediaTypeRaw) ?? .unknown
    }

    var mediaSubtypes: PHAssetMediaSubtype {
        PHAssetMediaSubtype(rawValue: mediaSubtypesRaw)
    }

    var hasLocation: Bool {
        guard let lat = latitude, let lon = longitude,
              lat.isFinite, lon.isFinite,
              abs(lat) <= 85.0, abs(lon) <= 180.0,
              !(abs(lat) < 0.0001 && abs(lon) < 0.0001) else {
            return false
        }
        return CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: lat, longitude: lon))
    }

    var isVideo: Bool {
        mediaType == .video
    }

    var isGIF: Bool {
        if playbackStyleRaw == 2 { return true }
        let lowerOrig = originalFilename.lowercased()
        let lowerInt = internalFilename.lowercased()
        let lowerUTI = (uniformTypeIdentifier ?? "").lowercased()
        return lowerOrig.hasSuffix(".gif") || lowerInt.hasSuffix(".gif") || lowerUTI.contains("gif")
    }

    var isLivePhoto: Bool {
        mediaSubtypes.contains(.photoLive) || playbackStyleRaw == 3
    }

    var isScreenshot: Bool {
        mediaSubtypes.contains(.photoScreenshot)
    }

    var isPortrait: Bool {
        mediaSubtypes.contains(.photoDepthEffect)
    }

    var isPanorama: Bool {
        mediaSubtypes.contains(.photoPanorama)
    }

    var aspectRatio: CGFloat {
        guard pixelHeight > 0 else { return 1.0 }
        return CGFloat(pixelWidth) / CGFloat(pixelHeight)
    }

    var formatBadgeTitle: String {
        if isGIF { return "GIF" }
        if let codec = exif.codecName, !codec.isEmpty {
            let up = codec.uppercased()
            if up == "JPG" { return "JPEG" }
            return up
        }
        let ext = (originalFilename as NSString).pathExtension.lowercased()
        let intExt = (internalFilename as NSString).pathExtension.lowercased()
        let effectiveExt = ext.isEmpty ? intExt : ext
        switch effectiveExt {
        case "jpg", "jpeg", "jpe": return "JPEG"
        case "png": return "PNG"
        case "heic", "heif": return "HEIC"
        case "gif": return "GIF"
        case "webp": return "WEBP"
        case "dng", "cr2", "cr3", "nef", "arw", "orf", "raf", "rw2": return "RAW"
        case "tiff", "tif": return "TIFF"
        case "mov", "qt": return "MOV"
        case "mp4", "m4v": return "MP4"
        default:
            break
        }
        if let uti = uniformTypeIdentifier?.lowercased() {
            if uti.contains("gif") { return "GIF" }
            if uti.contains("jpeg") || uti.contains("jpg") { return "JPEG" }
            if uti.contains("png") { return "PNG" }
            if uti.contains("heic") || uti.contains("heif") { return "HEIC" }
            if uti.contains("webp") { return "WEBP" }
            if uti.contains("raw") || uti.contains("dng") { return "RAW" }
            if uti.contains("quicktime") || uti.contains("mov") { return "MOV" }
            if uti.contains("mpeg-4") || uti.contains("mp4") { return "MP4" }
        }
        return isVideo ? "H.264" : "JPEG"
    }
}

/// Library curation granularity (Years / Months / All Photos)
nonisolated enum LibraryTimeGranularity: String, CaseIterable, Identifiable, Codable, Sendable {
    case years = "Years"
    case months = "Months"
    case allPhotos = "All Photos"

    var id: String { rawValue }
}

/// Sort order for the People overview grid
nonisolated enum PeopleSortOrder: String, CaseIterable, Identifiable, Codable, Sendable {
    case countDesc = "By Item Count"
    case nameAsc = "By Name"
    case latestDateDesc = "By Most Recent Photo"

    var id: String { rawValue }
}

/// Content filter menu at the top-right of the photo grid (Filter: All Items)
nonisolated enum GridContentFilter: String, CaseIterable, Identifiable, Codable, Sendable {
    case allItems = "All Items"
    case favorites = "Favorites"
    case edited = "Edited"
    case photos = "Photos"
    case videos = "Videos"
    case screenshots = "Screenshots"

    var id: String { rawValue }

    var systemIcon: String {
        switch self {
        case .allItems: return "square.grid.3x3"
        case .favorites: return "heart.fill"
        case .edited: return "slider.horizontal.3"
        case .photos: return "photo"
        case .videos: return "video"
        case .screenshots: return "camera.viewfinder"
        }
    }

    func matches(_ item: PhotoAssetItem) -> Bool {
        switch self {
        case .allItems: return true
        case .favorites: return item.isFavorite
        case .edited: return item.isEdited
        case .photos: return !item.isVideo
        case .videos: return item.isVideo
        case .screenshots: return item.isScreenshot
        }
    }
}

/// Customizable photo grid layout configuration
nonisolated struct GridCustomizationConfig: Equatable, Codable, Sendable {
    var columnCountDouble: Double = 5.0 // ★ [UI SIZING: Grid Defaults] Default column count (smaller = larger thumbnails, larger = smaller thumbnails)
    var spacing: CGFloat = 18.0         // ★ [UI SIZING: Grid Defaults] Horizontal & vertical spacing between photo thumbnails (pt)
    var cropToSquare: Bool = false      // ★ [UI SIZING: Grid Defaults] Set true for square thumbnails by default, false for original aspect ratio
    var showExifOverlay: Bool = false
    var showFaceBoundingBoxes: Bool = false
    var showOriginalFilename: Bool = false
    var timeGranularity: LibraryTimeGranularity = .allPhotos

    var columnCount: Int {
        get { max(2, min(10, Int(columnCountDouble.rounded()))) } // ★ [UI SIZING: Grid Defaults] Allowed column count range (min: 3, max: 10)
        set { columnCountDouble = Double(max(3, min(10, newValue))) }
    }

    init(
        columnCountDouble: Double = 5.0,
        spacing: CGFloat = 14.0,
        cropToSquare: Bool = false,
        showExifOverlay: Bool = false,
        showFaceBoundingBoxes: Bool = false,
        showOriginalFilename: Bool = false,
        timeGranularity: LibraryTimeGranularity = .allPhotos
    ) {
        self.columnCountDouble = columnCountDouble
        self.spacing = spacing
        self.cropToSquare = cropToSquare
        self.showExifOverlay = showExifOverlay
        self.showFaceBoundingBoxes = showFaceBoundingBoxes
        self.showOriginalFilename = showOriginalFilename
        self.timeGranularity = timeGranularity
    }

    var bucketedTargetSize: CGSize {
        let step: CGFloat
        switch columnCount {
        case 1...2: step = 760
        case 3...4: step = 480
        case 5...7: step = 300
        default:    step = 200
        }
        return CGSize(width: step, height: step)
    }
}

/// Map view display mode
nonisolated enum MapDisplayStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case standard = "Map"
    case satellite = "Satellite"
    case grid = "Grid"

    var id: String { rawValue }
}

/// In-app Smart Album rule definition (with caption filtering support)
nonisolated struct SmartAlbumDefinition: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var name: String
    var captionContains: String
    var keywordContains: String
    var cameraContains: String
    var personContains: String
    var onlyFavorites: Bool
    var onlyVideos: Bool
    var onlyPhotos: Bool
    var onlyWithLocation: Bool
    var filenameContains: String

    init(
        id: UUID = UUID(),
        name: String,
        captionContains: String = "",
        keywordContains: String = "",
        cameraContains: String = "",
        personContains: String = "",
        onlyFavorites: Bool = false,
        onlyVideos: Bool = false,
        onlyPhotos: Bool = false,
        onlyWithLocation: Bool = false,
        filenameContains: String = ""
    ) {
        self.id = id
        self.name = name
        self.captionContains = captionContains
        self.keywordContains = keywordContains
        self.cameraContains = cameraContains
        self.personContains = personContains
        self.onlyFavorites = onlyFavorites
        self.onlyVideos = onlyVideos
        self.onlyPhotos = onlyPhotos
        self.onlyWithLocation = onlyWithLocation
        self.filenameContains = filenameContains
    }

    enum CodingKeys: String, CodingKey {
        case id, name, captionContains, keywordContains, cameraContains, personContains
        case onlyFavorites, onlyVideos, onlyPhotos, onlyWithLocation, filenameContains
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        captionContains = try c.decodeIfPresent(String.self, forKey: .captionContains) ?? ""
        keywordContains = try c.decodeIfPresent(String.self, forKey: .keywordContains) ?? ""
        cameraContains = try c.decodeIfPresent(String.self, forKey: .cameraContains) ?? ""
        personContains = try c.decodeIfPresent(String.self, forKey: .personContains) ?? ""
        onlyFavorites = try c.decodeIfPresent(Bool.self, forKey: .onlyFavorites) ?? false
        onlyVideos = try c.decodeIfPresent(Bool.self, forKey: .onlyVideos) ?? false
        onlyPhotos = try c.decodeIfPresent(Bool.self, forKey: .onlyPhotos) ?? false
        onlyWithLocation = try c.decodeIfPresent(Bool.self, forKey: .onlyWithLocation) ?? false
        filenameContains = try c.decodeIfPresent(String.self, forKey: .filenameContains) ?? ""
    }

    func matches(_ item: PhotoAssetItem) -> Bool {
        if item.isTrashed || item.isHidden { return false }
        if onlyFavorites && !item.isFavorite { return false }
        if onlyVideos && !item.isVideo { return false }
        if onlyPhotos && item.isVideo { return false }
        if onlyWithLocation && !item.hasLocation { return false }

        let cap = captionContains.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cap.isEmpty {
            let matched = item.caption?.localizedCaseInsensitiveContains(cap) ?? false
            if !matched { return false }
        }

        let kw = keywordContains.trimmingCharacters(in: .whitespacesAndNewlines)
        if !kw.isEmpty {
            let matched = item.keywords.contains { $0.localizedCaseInsensitiveContains(kw) }
            if !matched { return false }
        }

        let cam = cameraContains.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cam.isEmpty {
            let modelMatch = item.exif.cameraModel?.localizedCaseInsensitiveContains(cam) ?? false
            let makeMatch = item.exif.cameraMake?.localizedCaseInsensitiveContains(cam) ?? false
            let lensMatch = item.exif.lensModel?.localizedCaseInsensitiveContains(cam) ?? false
            if !(modelMatch || makeMatch || lensMatch) { return false }
        }

        let per = personContains.trimmingCharacters(in: .whitespacesAndNewlines)
        if !per.isEmpty {
            let matched = item.faces.contains { $0.displayName.localizedCaseInsensitiveContains(per) }
            if !matched { return false }
        }

        let fn = filenameContains.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fn.isEmpty {
            let origMatch = item.originalFilename.localizedCaseInsensitiveContains(fn)
            let titleMatch = item.title?.localizedCaseInsensitiveContains(fn) ?? false
            if !(origMatch || titleMatch) { return false }
        }

        return true
    }
}

/// In-app custom album and folder models
nonisolated struct CustomAlbumDefinition: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var name: String
    var parentFolderID: UUID?
    var parentSystemFolderIdentifier: String?
    var assetIDs: [String]
    var keyAssetID: String?

    init(
        id: UUID = UUID(),
        name: String,
        parentFolderID: UUID? = nil,
        parentSystemFolderIdentifier: String? = nil,
        assetIDs: [String] = [],
        keyAssetID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.parentFolderID = parentFolderID
        self.parentSystemFolderIdentifier = parentSystemFolderIdentifier
        self.assetIDs = assetIDs
        self.keyAssetID = keyAssetID
    }
}

nonisolated struct CustomFolderDefinition: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var name: String
    var parentFolderID: UUID?

    init(id: UUID = UUID(), name: String, parentFolderID: UUID? = nil) {
        self.id = id
        self.name = name
        self.parentFolderID = parentFolderID
    }
}

/// Smart Album query rules decoded from Photos.sqlite ZGENERICALBUM.ZUSERQUERYDATA (Apple PLQuery Protobuf)
nonisolated struct SingleSmartQueryRule: Hashable, Sendable {
    let key: Int
    let comparator: Int
    let stringValue: String?
    let intValue: Int64?
}

nonisolated struct SmartAlbumQueryCriteria: Hashable, Sendable {
    let isAnyConjunction: Bool      // true == OR (Match Any), false == AND (Match All)
    let rules: [SingleSmartQueryRule]
    let extractedStrings: [String]

    func matches(_ item: PhotoAssetItem, albumAssetIDsByNameOrUUID: [String: Set<String>]) -> Bool {
        if item.isTrashed || item.isHidden { return false }

        if !rules.isEmpty {
            var evaluatedAnyRule = false
            var results: [Bool] = []

            for rule in rules {
                if let res = evaluateSingleRule(rule, item: item, albumAssetIDsByNameOrUUID: albumAssetIDsByNameOrUUID) {
                    evaluatedAnyRule = true
                    results.append(res)
                }
            }

            if evaluatedAnyRule && !results.isEmpty {
                if isAnyConjunction {
                    if results.contains(true) { return true }
                } else {
                    if results.allSatisfy({ $0 }) { return true }
                }
            }
        }

        if !extractedStrings.isEmpty {
            let matchFn: (String) -> Bool = { token in
                let t = token.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return false }
                // Match against asset caption (ZASSETDESCRIPTION.ZLONGDESCRIPTION)
                if let cap = item.caption, cap.localizedCaseInsensitiveContains(t) {
                    return true
                }
                if item.faces.contains(where: { $0.displayName.localizedCaseInsensitiveContains(t) || ($0.personUUID?.caseInsensitiveCompare(t) == .orderedSame) }) {
                    return true
                }
                if item.keywords.contains(where: { $0.localizedCaseInsensitiveContains(t) }) {
                    return true
                }
                if item.originalFilename.localizedCaseInsensitiveContains(t) || item.internalFilename.localizedCaseInsensitiveContains(t) {
                    return true
                }
                if let title = item.title, title.localizedCaseInsensitiveContains(t) {
                    return true
                }
                if let cam = item.exif.cameraModel, cam.localizedCaseInsensitiveContains(t) {
                    return true
                }
                if let make = item.exif.cameraMake, make.localizedCaseInsensitiveContains(t) {
                    return true
                }
                if let lens = item.exif.lensModel, lens.localizedCaseInsensitiveContains(t) {
                    return true
                }
                if let albumIDs = albumAssetIDsByNameOrUUID[t.lowercased()], albumIDs.contains(item.id) || albumIDs.contains(item.uuid) {
                    return true
                }
                return false
            }

            if isAnyConjunction {
                return extractedStrings.contains(where: matchFn)
            } else {
                return extractedStrings.allSatisfy(matchFn)
            }
        }

        return false
    }

    private func compareText(_ targetText: String?, query: String, comparator: Int) -> Bool {
        let content = targetText ?? ""
        switch comparator {
        case 30: // is set / is not empty
            return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 31: // is not set / is empty
            return content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1: // is / equals
            return content.localizedCaseInsensitiveCompare(query) == .orderedSame
                || content.localizedCaseInsensitiveContains(query)
        case 2: // is not
            return !content.localizedCaseInsensitiveContains(query)
        case 20, 50: // contains
            return content.localizedCaseInsensitiveContains(query)
        case 21: // does not contain
            return !content.localizedCaseInsensitiveContains(query)
        case 22: // starts with
            return content.lowercased().hasPrefix(query.lowercased())
        case 23: // ends with
            return content.lowercased().hasSuffix(query.lowercased())
        default:
            return content.localizedCaseInsensitiveContains(query)
        }
    }

    private func evaluateSingleRule(
        _ rule: SingleSmartQueryRule,
        item: PhotoAssetItem,
        albumAssetIDsByNameOrUUID: [String: Set<String>]
    ) -> Bool? {
        let isNegated = (rule.comparator == 2 || rule.comparator == 21 || rule.comparator == 31 || rule.comparator == 41)
        let str = rule.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        switch rule.key {
        case 1: // Title
            if rule.comparator == 30 || rule.comparator == 31 || !str.isEmpty {
                return compareText(item.title, query: str, comparator: rule.comparator)
            }
            return nil
        case 2: // Caption / Description (ZASSETDESCRIPTION.ZLONGDESCRIPTION)
            if rule.comparator == 30 || rule.comparator == 31 || !str.isEmpty {
                return compareText(item.caption, query: str, comparator: rule.comparator)
            }
            return nil
        case 3, 4: // Any Text (Caption, Title, Keyword, Person, Filename, Camera)
            guard !str.isEmpty else { return nil }
            let matched = (item.caption?.localizedCaseInsensitiveContains(str) ?? false)
                || (item.title?.localizedCaseInsensitiveContains(str) ?? false)
                || item.originalFilename.localizedCaseInsensitiveContains(str)
                || item.faces.contains(where: { $0.displayName.localizedCaseInsensitiveContains(str) })
                || item.keywords.contains(where: { $0.localizedCaseInsensitiveContains(str) })
                || (item.exif.cameraModel?.localizedCaseInsensitiveContains(str) ?? false)
            return isNegated ? !matched : matched
        case 5, 500: // Filename
            guard !str.isEmpty else { return nil }
            let matched = compareText(item.originalFilename, query: str, comparator: rule.comparator)
                || compareText(item.internalFilename, query: str, comparator: rule.comparator)
            return matched
        case 100: // Favorite
            let flag = (rule.intValue ?? 1) != 0
            let matched = (item.isFavorite == flag)
            return rule.comparator == 31 ? !item.isFavorite : (isNegated ? !matched : matched)
        case 101: // Hidden
            let flag = (rule.intValue ?? 1) != 0
            return item.isHidden == flag
        case 102: // Edited
            let matched = item.isEdited
            return (rule.comparator == 31 || rule.comparator == 2) ? !matched : matched
        case 105: // Selfie
            let matched = !item.faces.isEmpty
            return isNegated ? !matched : matched
        case 106: // Panorama
            let matched = item.isPanorama
            return isNegated ? !matched : matched
        case 107: // Video
            let matched = item.isVideo
            return isNegated ? !matched : matched
        case 110: // Screenshot
            let matched = item.isScreenshot
            return isNegated ? !matched : matched
        case 111: // Portrait
            let matched = item.isPortrait
            return isNegated ? !matched : matched
        case 112: // Live Photo
            let matched = item.isLivePhoto
            return isNegated ? !matched : matched
        case 114: // Animated / GIF
            let matched = item.isGIF
            return isNegated ? !matched : matched
        case 200: // Album
            guard !str.isEmpty else { return nil }
            let matched = albumAssetIDsByNameOrUUID[str.lowercased()]?.contains(item.id) ?? false
            return isNegated ? !matched : matched
        case 300: // Keyword
            if str.isEmpty {
                let hasAny = !item.keywords.isEmpty
                return isNegated ? !hasAny : hasAny
            }
            let matched = item.keywords.contains { $0.localizedCaseInsensitiveContains(str) }
            return isNegated ? !matched : matched
        case 301: // Person / Pet
            if str.isEmpty {
                let hasAny = !item.faces.filter({ !$0.isUnnamed }).isEmpty
                return isNegated ? !hasAny : hasAny
            }
            let matched = item.faces.contains {
                $0.displayName.localizedCaseInsensitiveContains(str)
                    || ($0.fullName?.localizedCaseInsensitiveContains(str) ?? false)
                    || ($0.personUUID?.caseInsensitiveCompare(str) == .orderedSame)
            }
            return isNegated ? !matched : matched
        case 400: // Camera Model / Make
            guard !str.isEmpty else { return nil }
            let matched = (item.exif.cameraModel?.localizedCaseInsensitiveContains(str) ?? false)
                || (item.exif.cameraMake?.localizedCaseInsensitiveContains(str) ?? false)
            return isNegated ? !matched : matched
        case 401: // Lens
            guard !str.isEmpty else { return nil }
            let matched = item.exif.lensModel?.localizedCaseInsensitiveContains(str) ?? false
            return isNegated ? !matched : matched
        case 600: // GPS / Location
            let matched = item.hasLocation
            return isNegated ? !matched : matched
        default:
            if !str.isEmpty {
                let matched = (item.caption?.localizedCaseInsensitiveContains(str) ?? false)
                    || (item.title?.localizedCaseInsensitiveContains(str) ?? false)
                    || item.faces.contains(where: { $0.displayName.localizedCaseInsensitiveContains(str) || ($0.personUUID?.caseInsensitiveCompare(str) == .orderedSame) })
                    || item.keywords.contains(where: { $0.localizedCaseInsensitiveContains(str) })
                    || item.originalFilename.localizedCaseInsensitiveContains(str)
                    || (item.exif.cameraModel?.localizedCaseInsensitiveContains(str) ?? false)
                    || (item.exif.lensModel?.localizedCaseInsensitiveContains(str) ?? false)
                return isNegated ? !matched : matched
            }
            return nil
        }
    }
}

/// Album, folder, and Smart Album hierarchy node combining PhotoKit & Photos.sqlite
nonisolated struct AlbumTreeNode: Identifiable, Hashable, Sendable {
    let id: String
    let uuid: String
    let title: String
    let isFolder: Bool
    let isSmartAlbum: Bool
    let assetLocalIdentifiers: [String]
    let smartQueryCriteria: SmartAlbumQueryCriteria?
    let children: [AlbumTreeNode]
    var customKeyAssetID: String?

    init(
        id: String,
        uuid: String = "",
        title: String,
        isFolder: Bool,
        isSmartAlbum: Bool = false,
        assetLocalIdentifiers: [String],
        smartQueryCriteria: SmartAlbumQueryCriteria? = nil,
        children: [AlbumTreeNode],
        customKeyAssetID: String? = nil
    ) {
        self.id = id
        self.uuid = uuid.isEmpty ? id : uuid
        self.title = title
        self.isFolder = isFolder
        self.isSmartAlbum = isSmartAlbum
        self.assetLocalIdentifiers = assetLocalIdentifiers
        self.smartQueryCriteria = smartQueryCriteria
        self.children = children
        self.customKeyAssetID = customKeyAssetID
    }

    var allDescendantAssetIDs: [String] {
        var set = Set(assetLocalIdentifiers)
        for child in children {
            set.formUnion(child.allDescendantAssetIDs)
        }
        return Array(set)
    }
}

/// Navigation scope for sidebar items and browser tabs
nonisolated enum TabFilterScope: Hashable, Codable, Sendable {
    case library
    case favorites
    case peopleOverview
    case map
    case recentlyDeleted
    case hidden
    case recentlyViewed
    case duplicates
    case imports
    case videos
    case selfies
    case livePhotos
    case portrait
    case panoramas
    case screenshots
    case animated
    case person(name: String)
    case systemAlbum(id: String, title: String)
    case systemFolder(id: String, title: String)
    case customAlbum(id: UUID, title: String)
    case customFolder(id: UUID, title: String)
    case smartAlbum(id: UUID, title: String)
    case keyword(tag: String)

    var displayTitle: String {
        switch self {
        case .library: return "Library"
        case .favorites: return "Favorites"
        case .peopleOverview: return "People"
        case .map: return "Map"
        case .recentlyDeleted: return "Recently Deleted"
        case .hidden: return "Hidden"
        case .recentlyViewed: return "Recently Viewed"
        case .duplicates: return "Duplicates"
        case .imports: return "Imports"
        case .videos: return "Videos"
        case .selfies: return "Selfies"
        case .livePhotos: return "Live Photos"
        case .portrait: return "Portrait"
        case .panoramas: return "Panoramas"
        case .screenshots: return "Screenshots"
        case .animated: return "Animated"
        case .person(let name): return name
        case .systemAlbum(_, let title): return title
        case .systemFolder(_, let title): return title
        case .customAlbum(_, let title): return title
        case .customFolder(_, let title): return title
        case .smartAlbum(_, let title): return title
        case .keyword(let tag): return "#\(tag)"
        }
    }

    var systemIcon: String {
        switch self {
        case .library: return "photo.on.rectangle"
        case .favorites: return "heart"
        case .peopleOverview: return "person.crop.circle"
        case .map: return "map"
        case .recentlyDeleted: return "trash"
        case .hidden: return "eye.slash"
        case .recentlyViewed: return "eye"
        case .duplicates: return "square.on.square"
        case .imports: return "square.and.arrow.down"
        case .videos: return "video"
        case .selfies: return "camera.aperture"
        case .livePhotos: return "livephoto"
        case .portrait: return "cube"
        case .panoramas: return "pano"
        case .screenshots: return "camera.viewfinder"
        case .animated: return "square.stack.3d.forward.dottedline"
        case .person: return "person.crop.circle"
        case .systemAlbum: return "rectangle.stack"
        case .systemFolder: return "folder"
        case .customAlbum: return "rectangle.stack"
        case .customFolder: return "folder"
        case .smartAlbum: return "gearshape"
        case .keyword: return "tag"
        }
    }

    var isFolderScope: Bool {
        switch self {
        case .systemFolder, .customFolder: return true
        default: return false
        }
    }
}

/// Independent state model for a single browser tab
nonisolated struct BrowserTabState: Identifiable, Equatable, Codable, Sendable {
    var id: UUID
    var filterScope: TabFilterScope
    var contentFilter: GridContentFilter
    var mapStyle: MapDisplayStyle
    var mapZoomLevel: Double
    var searchQuery: String
    var gridConfig: GridCustomizationConfig
    var selectedAssetID: String?
    var selectedAssetIDs: Set<String>
    var selectedFolderAlbumID: String?
    var selectedLibraryBucketID: String?
    var currentPageIndex: Int
    var activeDetailAssetID: String?
    var showInspectorPanel: Bool
    var navigationHistory: [TabFilterScope]

    init(
        id: UUID = UUID(),
        filterScope: TabFilterScope = .library,
        contentFilter: GridContentFilter = .allItems,
        mapStyle: MapDisplayStyle = .standard,
        mapZoomLevel: Double = 5.0,
        searchQuery: String = "",
        gridConfig: GridCustomizationConfig = GridCustomizationConfig(),
        selectedAssetID: String? = nil,
        selectedAssetIDs: Set<String> = [],
        selectedFolderAlbumID: String? = nil,
        selectedLibraryBucketID: String? = nil,
        currentPageIndex: Int = 0,
        activeDetailAssetID: String? = nil,
        showInspectorPanel: Bool = false,
        navigationHistory: [TabFilterScope] = []
    ) {
        self.id = id
        self.filterScope = filterScope
        self.contentFilter = contentFilter
        self.mapStyle = mapStyle
        self.mapZoomLevel = mapZoomLevel
        self.searchQuery = searchQuery
        self.gridConfig = gridConfig
        self.selectedAssetID = selectedAssetID
        self.selectedAssetIDs = selectedAssetIDs
        self.selectedFolderAlbumID = selectedFolderAlbumID
        self.selectedLibraryBucketID = selectedLibraryBucketID
        self.currentPageIndex = currentPageIndex
        self.activeDetailAssetID = activeDetailAssetID
        self.showInspectorPanel = showInspectorPanel
        self.navigationHistory = navigationHistory
    }

    enum CodingKeys: String, CodingKey {
        case id, filterScope, contentFilter, mapStyle, mapZoomLevel, searchQuery
        case gridConfig, selectedAssetID, selectedAssetIDs, selectedFolderAlbumID
        case selectedLibraryBucketID, currentPageIndex
        case activeDetailAssetID, showInspectorPanel, navigationHistory
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        filterScope = try c.decodeIfPresent(TabFilterScope.self, forKey: .filterScope) ?? .library
        contentFilter = try c.decodeIfPresent(GridContentFilter.self, forKey: .contentFilter) ?? .allItems
        mapStyle = try c.decodeIfPresent(MapDisplayStyle.self, forKey: .mapStyle) ?? .standard
        mapZoomLevel = try c.decodeIfPresent(Double.self, forKey: .mapZoomLevel) ?? 5.0
        searchQuery = try c.decodeIfPresent(String.self, forKey: .searchQuery) ?? ""
        gridConfig = try c.decodeIfPresent(GridCustomizationConfig.self, forKey: .gridConfig) ?? GridCustomizationConfig()
        selectedAssetID = try c.decodeIfPresent(String.self, forKey: .selectedAssetID)
        selectedAssetIDs = try c.decodeIfPresent(Set<String>.self, forKey: .selectedAssetIDs) ?? []
        selectedFolderAlbumID = try c.decodeIfPresent(String.self, forKey: .selectedFolderAlbumID)
        selectedLibraryBucketID = try c.decodeIfPresent(String.self, forKey: .selectedLibraryBucketID)
        currentPageIndex = try c.decodeIfPresent(Int.self, forKey: .currentPageIndex) ?? 0
        activeDetailAssetID = try c.decodeIfPresent(String.self, forKey: .activeDetailAssetID)
        showInspectorPanel = try c.decodeIfPresent(Bool.self, forKey: .showInspectorPanel) ?? false
        navigationHistory = try c.decodeIfPresent([TabFilterScope].self, forKey: .navigationHistory) ?? []
    }

    var isShowingLibraryYearOverview: Bool {
        filterScope == .library
            && selectedLibraryBucketID == nil
            && searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var tabTitle: String {
        let base: String
        if filterScope == .library, let bucket = selectedLibraryBucketID {
            base = "Library · \(bucket)"
        } else {
            base = filterScope.displayTitle
        }
        if !searchQuery.isEmpty {
            return "\(base) · \(searchQuery)"
        }
        return base
    }
}

/// Persistent workspace state snapshot saved on exit and restored on launch
nonisolated struct PersistedWorkspaceSnapshot: Codable, Sendable {
    var tabs: [BrowserTabState]
    var activeTabID: UUID
    var expandedSidebarSections: Set<String>
    var expandedFolderIDs: Set<String>
    var smartAlbums: [SmartAlbumDefinition]
    var customAlbums: [CustomAlbumDefinition]
    var customFolders: [CustomFolderDefinition]
    var allRegisteredTags: [String]
    var assetTagsByID: [String: [String]]
    var favoriteOverridesByID: [String: Bool]
    var hiddenOverridesByID: [String: Bool]
    var deletedOverridesByID: [String: Bool]
    var customTitlesByID: [String: String]
    var customCaptionsByID: [String: String]
    var customCreationDatesByID: [String: Date]
    var personKeyPhotoByPersonName: [String: String]
    var albumKeyPhotoByAlbumID: [String: String]
    var renamedPeopleMap: [String: String]
    var manualFacesByAssetID: [String: [DetectedFaceInfo]]
    var favoritePeopleByName: [String: Bool]?
    var customLibraryPath: String?
    var sidebarWidth: Double?
    var peopleSortOrder: PeopleSortOrder?
    var showPersonNameTagsInDetail: Bool?
}

// MARK: - 2. PLQueryProtobufParser & Photos.sqlite Direct Read-Only Reader (Captions + Album/People Key Thumbnails)

/// Decoder for Apple Photos.sqlite ZGENERICALBUM.ZUSERQUERYDATA (PLQuery / PLSingleQuery Protobuf)
nonisolated enum PLQueryProtobufParser {
    static func parse(data: Data) -> SmartAlbumQueryCriteria? {
        guard !data.isEmpty else { return nil }
        var rules: [SingleSmartQueryRule] = []
        var conjunction: Int = 1 // 1 == AND (Match All), 0 == OR (Match Any)
        parsePLQueryMessage(bytes: [UInt8](data), conjunctionOut: &conjunction, rulesOut: &rules)

        let extractedStrings = extractAllSearchableStrings(from: data)
        if rules.isEmpty && extractedStrings.isEmpty {
            return nil
        }
        return SmartAlbumQueryCriteria(
            isAnyConjunction: (conjunction == 0),
            rules: rules,
            extractedStrings: extractedStrings
        )
    }

    private static func parsePLQueryMessage(
        bytes: [UInt8],
        conjunctionOut: inout Int,
        rulesOut: inout [SingleSmartQueryRule]
    ) {
        var idx = 0
        while idx < bytes.count {
            guard let tag = readVarint(bytes, index: &idx) else { break }
            let fieldNumber = Int(tag >> 3)
            let wireType = Int(tag & 0x07)

            switch wireType {
            case 0:
                guard let val = readVarint(bytes, index: &idx) else { return }
                if fieldNumber == 1 {
                    conjunctionOut = Int(val)
                }
            case 1:
                idx += 8
            case 2:
                guard let length = readVarint(bytes, index: &idx),
                      length >= 0,
                      idx + Int(length) <= bytes.count else { return }
                let subBytes = Array(bytes[idx..<(idx + Int(length))])
                idx += Int(length)

                if fieldNumber == 2 || fieldNumber == 3 {
                    parsePLQueryMessage(bytes: subBytes, conjunctionOut: &conjunctionOut, rulesOut: &rulesOut)
                } else if fieldNumber == 4 {
                    if let single = parsePLSingleQuery(bytes: subBytes) {
                        rulesOut.append(single)
                    }
                }
            case 5:
                idx += 4
            default:
                return
            }
        }
    }

    private static func parsePLSingleQuery(bytes: [UInt8]) -> SingleSmartQueryRule? {
        var idx = 0
        var key: Int?
        var comparator: Int = 1
        var firstRawBytes: [UInt8]?

        while idx < bytes.count {
            guard let tag = readVarint(bytes, index: &idx) else { break }
            let fieldNum = Int(tag >> 3)
            let wireType = Int(tag & 0x07)

            switch wireType {
            case 0:
                guard let val = readVarint(bytes, index: &idx) else { return nil }
                if fieldNum == 1 { key = Int(val) }
                else if fieldNum == 5 { comparator = Int(val) }
            case 1:
                idx += 8
            case 2:
                guard let len = readVarint(bytes, index: &idx),
                      len >= 0,
                      idx + Int(len) <= bytes.count else { return nil }
                let slice = Array(bytes[idx..<(idx + Int(len))])
                idx += Int(len)
                if fieldNum == 3 {
                    firstRawBytes = slice
                }
            case 5:
                idx += 4
            default:
                return nil
            }
        }

        guard let resolvedKey = key else { return nil }
        var strVal: String? = nil
        var intVal: Int64? = nil

        if let raw = firstRawBytes, !raw.isEmpty {
            if let utf8 = String(bytes: raw, encoding: .utf8) {
                let cleaned = utf8.trimmingCharacters(in: .controlCharacters.union(.whitespacesAndNewlines))
                if !cleaned.isEmpty && isLikelyReadableText(cleaned) {
                    strVal = cleaned
                }
            }
            if raw.count <= 8 {
                var v: Int64 = 0
                for (i, b) in raw.enumerated() {
                    v |= (Int64(b) << (i * 8))
                }
                intVal = v
            }
        }

        return SingleSmartQueryRule(
            key: resolvedKey,
            comparator: comparator,
            stringValue: strVal,
            intValue: intVal
        )
    }

    private static func readVarint(_ bytes: [UInt8], index: inout Int) -> UInt64? {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while index < bytes.count {
            let b = bytes[index]
            index += 1
            result |= UInt64(b & 0x7F) << shift
            if (b & 0x80) == 0 {
                return result
            }
            shift += 7
            if shift >= 64 { return nil }
        }
        return nil
    }

    private static func extractAllSearchableStrings(from data: Data) -> [String] {
        let bytes = [UInt8](data)
        var results: [String] = []
        var idx = 0
        while idx < bytes.count {
            if bytes[idx] == 0x1A || bytes[idx] == 0x22 {
                var tempIdx = idx + 1
                if let len = readVarint(bytes, index: &tempIdx),
                   len >= 1, len <= 200,
                   tempIdx + Int(len) <= bytes.count {
                    let sub = Array(bytes[tempIdx..<(tempIdx + Int(len))])
                    if let s = String(bytes: sub, encoding: .utf8) {
                        let trimmed = s.trimmingCharacters(in: .controlCharacters.union(.whitespacesAndNewlines))
                        if trimmed.count >= 1, isLikelyReadableText(trimmed),
                           !trimmed.hasPrefix("bplist"),
                           !trimmed.hasPrefix("NSKeyed") {
                            if !results.contains(trimmed) {
                                results.append(trimmed)
                            }
                            idx = tempIdx + Int(len)
                            continue
                        }
                    }
                }
            }
            idx += 1
        }
        return results
    }

    private static func isLikelyReadableText(_ s: String) -> Bool {
        for scalar in s.unicodeScalars {
            if CharacterSet.controlCharacters.contains(scalar) {
                return false
            }
        }
        return true
    }
}

nonisolated enum PhotosSQLiteError: LocalizedError, Sendable {
    case databaseNotFound(String)
    case openFailed(String)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .databaseNotFound(let p): return "Photos.sqlite not found: \(p)"
        case .openFailed(let m): return "Failed to open Photos.sqlite: \(m)"
        case .queryFailed(let m): return "SQL query failed: \(m)"
        }
    }
}

nonisolated final class PhotosSQLiteReader: Sendable {
    private static let appleEpochOffset: TimeInterval = 978_307_200.0

    init() {}

    static var defaultLibraryPackageURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures", isDirectory: true)
            .appendingPathComponent("Photos Library.photoslibrary", isDirectory: true)
    }

    static var defaultDatabaseURL: URL {
        defaultLibraryPackageURL
            .appendingPathComponent("database", isDirectory: true)
            .appendingPathComponent("Photos.sqlite", isDirectory: false)
    }

    struct SQLiteLibraryPayload: Sendable {
        let recordsByUUID: [String: SQLiteAssetRecord]
        let albumHierarchy: [AlbumTreeNode]
    }

    func loadAllMetadataAndAlbums(from databaseURL: URL) throws -> SQLiteLibraryPayload {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            throw PhotosSQLiteError.databaseNotFound(databaseURL.path)
        }

        var db: OpaquePointer?
        var tempCopyDir: URL?
        defer {
            if let db { sqlite3_close(db) }
            if let tempCopyDir {
                try? FileManager.default.removeItem(at: tempCopyDir)
            }
        }

        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("PhotoVaultReadOnlyDB_\(UUID().uuidString)", isDirectory: true)
        var targetOpenPath = databaseURL.path

        if (try? fm.createDirectory(at: tempDir, withIntermediateDirectories: true)) != nil {
            let dstSQLite = tempDir.appendingPathComponent("Photos.sqlite")
            if (try? fm.copyItem(at: databaseURL, to: dstSQLite)) != nil {
                tempCopyDir = tempDir
                targetOpenPath = dstSQLite.path
                for suffix in ["-wal", "-shm"] {
                    let srcSidecar = URL(fileURLWithPath: databaseURL.path + suffix)
                    let dstSidecar = URL(fileURLWithPath: dstSQLite.path + suffix)
                    if fm.fileExists(atPath: srcSidecar.path) {
                        try? fm.copyItem(at: srcSidecar, to: dstSidecar)
                    }
                }
            }
        }

        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        let rc = sqlite3_open_v2(targetOpenPath, &db, flags, nil)
        guard rc == SQLITE_OK, let database = db else {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown"
            throw PhotosSQLiteError.openFailed(msg)
        }

        let assetTable = Self.tableExists("ZASSET", in: database) ? "ZASSET" : "ZGENERICASSET"
        let faceAssetFK = Self.columnExists("ZASSETFORFACE", inTable: "ZDETECTEDFACE", db: database)
            ? "ZASSETFORFACE" : "ZASSET"
        let facePersonFK = Self.columnExists("ZPERSONFORFACE", inTable: "ZDETECTEDFACE", db: database)
            ? "ZPERSONFORFACE" : "ZPERSON"

        let facesByAssetPK = fetchDetectedFacesByAssetPK(
            in: database,
            faceAssetFK: faceAssetFK,
            facePersonFK: facePersonFK
        )

        let keywordsByAttrPK = fetchKeywordsByAttributesPK(in: database)
        let captionsByAttrPK = fetchCaptionsByAttributesPK(in: database)

        let hasUTICol = Self.columnExists("ZUNIFORMTYPEIDENTIFIER", inTable: assetTable, db: database)
        let utiSelectExpr = hasUTICol ? "a.ZUNIFORMTYPEIDENTIFIER" : "NULL"
        let hasWidthCol = Self.columnExists("ZWIDTH", inTable: assetTable, db: database)
        let widthExpr = hasWidthCol ? "COALESCE(a.ZWIDTH, 0)" : "0"
        let heightExpr = hasWidthCol ? "COALESCE(a.ZHEIGHT, 0)" : "0"
        let hasDurationCol = Self.columnExists("ZDURATION", inTable: assetTable, db: database)
        let durationExpr = hasDurationCol ? "COALESCE(a.ZDURATION, 0.0)" : "0.0"
        let hasDateCol = Self.columnExists("ZDATECREATED", inTable: assetTable, db: database)
        let dateExpr = hasDateCol ? "a.ZDATECREATED" : "NULL"
        let hasFavCol = Self.columnExists("ZFAVORITE", inTable: assetTable, db: database)
        let favExpr = hasFavCol ? "COALESCE(a.ZFAVORITE, 0)" : "0"
        let hasKindCol = Self.columnExists("ZKIND", inTable: assetTable, db: database)
        let kindExpr = hasKindCol ? "COALESCE(a.ZKIND, 0)" : "0"
        let hasAdjustCol = Self.columnExists("ZHASADJUSTMENTS", inTable: assetTable, db: database)
        let adjustExpr = hasAdjustCol ? "COALESCE(a.ZHASADJUSTMENTS, 0)" : "0"
        let hasPlaybackStyleCol = Self.columnExists("ZPLAYBACKSTYLE", inTable: assetTable, db: database)
        let playbackStyleExpr = hasPlaybackStyleCol ? "COALESCE(a.ZPLAYBACKSTYLE, 0)" : "0"
        let hasAccessDescCol = Self.columnExists("ZACCESSIBILITYDESCRIPTION", inTable: "ZADDITIONALASSETATTRIBUTES", db: database)
        let accessDescExpr = hasAccessDescCol ? "attr.ZACCESSIBILITYDESCRIPTION" : "NULL"

        let sql = """
        SELECT
            a.Z_PK,
            a.ZUUID,
            COALESCE(a.ZFILENAME, ''),
            COALESCE(attr.ZORIGINALFILENAME, a.ZFILENAME, ''),
            attr.ZTITLE,
            a.ZDIRECTORY,
            CASE WHEN a.ZLATITUDE <= -180.0 THEN NULL ELSE a.ZLATITUDE END,
            CASE WHEN a.ZLONGITUDE <= -180.0 THEN NULL ELSE a.ZLONGITUDE END,
            COALESCE(a.ZCLOUDLOCALSTATE, 1),
            ext.ZCAMERAMAKE,
            ext.ZCAMERAMODEL,
            ext.ZLENSMODEL,
            ext.ZISO,
            ext.ZAPERTURE,
            ext.ZSHUTTERSPEED,
            ext.ZFOCALLENGTH,
            ext.ZFPS,
            ext.ZCODEC,
            attr.ZORIGINALFILESIZE,
            COALESCE(a.ZHIDDEN, 0),
            COALESCE(a.ZTRASHEDSTATE, 0),
            attr.Z_PK,
            \(utiSelectExpr),
            \(widthExpr),
            \(heightExpr),
            \(durationExpr),
            \(dateExpr),
            \(favExpr),
            \(kindExpr),
            \(adjustExpr),
            \(playbackStyleExpr),
            \(accessDescExpr)
        FROM \(assetTable) a
        LEFT JOIN ZADDITIONALASSETATTRIBUTES attr ON attr.ZASSET = a.Z_PK
        LEFT JOIN ZEXTENDEDATTRIBUTES ext ON ext.ZASSET = a.Z_PK
        WHERE a.ZUUID IS NOT NULL;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PhotosSQLiteError.queryFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(stmt) }

        var records: [String: SQLiteAssetRecord] = [:]
        var uuidByAssetPK: [Int64: String] = [:]
        records.reserveCapacity(32_768)
        uuidByAssetPK.reserveCapacity(32_768)

        while sqlite3_step(stmt) == SQLITE_ROW {
            let pk = sqlite3_column_int64(stmt, 0)
            guard let uuidC = sqlite3_column_text(stmt, 1) else { continue }
            let uuid = String(cString: uuidC)
            uuidByAssetPK[pk] = uuid

            let internalName = Self.stringCol(stmt, 2) ?? ""
            let originalName = Self.stringCol(stmt, 3) ?? internalName
            let exif = ExifSummary(
                cameraMake: Self.stringCol(stmt, 9),
                cameraModel: Self.stringCol(stmt, 10),
                lensModel: Self.stringCol(stmt, 11),
                iso: Self.intCol(stmt, 12),
                aperture: Self.doubleCol(stmt, 13),
                shutterSpeed: Self.doubleCol(stmt, 14),
                focalLength: Self.doubleCol(stmt, 15),
                exposureBias: nil,
                fps: Self.doubleCol(stmt, 16),
                codecName: Self.stringCol(stmt, 17),
                originalFileSize: Self.int64Col(stmt, 18)
            )
            let isHidden = sqlite3_column_int(stmt, 19) != 0
            let isTrashed = sqlite3_column_int(stmt, 20) != 0
            let attrPK = sqlite3_column_int64(stmt, 21)
            let uti = Self.stringCol(stmt, 22)
            let width = max(0, Int(sqlite3_column_int(stmt, 23)))
            let height = max(0, Int(sqlite3_column_int(stmt, 24)))
            let duration = Self.doubleCol(stmt, 25) ?? 0.0
            let rawAppleTimestamp = Self.doubleCol(stmt, 26)
            let creationDate = rawAppleTimestamp.map { Date(timeIntervalSince1970: $0 + Self.appleEpochOffset) }
            let isFav = sqlite3_column_int(stmt, 27) != 0
            let kind = Int(sqlite3_column_int(stmt, 28))
            let isEdited = sqlite3_column_int(stmt, 29) != 0
            let playbackStyle = Int(sqlite3_column_int(stmt, 30))
            let fallbackAccessCaption = Self.stringCol(stmt, 31)
            let resolvedCaption = captionsByAttrPK[attrPK] ?? fallbackAccessCaption

            records[uuid] = SQLiteAssetRecord(
                pk: pk,
                uuid: uuid,
                internalFilename: internalName,
                originalFilename: originalName.isEmpty ? internalName : originalName,
                uniformTypeIdentifier: uti,
                title: Self.stringCol(stmt, 4),
                caption: resolvedCaption,
                directory: Self.stringCol(stmt, 5),
                latitude: Self.doubleCol(stmt, 6),
                longitude: Self.doubleCol(stmt, 7),
                isLocallyAvailable: sqlite3_column_int(stmt, 8) != 0,
                isHiddenInSQLite: isHidden,
                isTrashedInSQLite: isTrashed,
                isFavoriteInSQLite: isFav,
                isEditedInSQLite: isEdited,
                playbackStyleInSQLite: playbackStyle,
                pixelWidth: width,
                pixelHeight: height,
                duration: duration,
                creationDate: creationDate,
                isVideoInSQLite: (kind == 1) || duration > 0.0,
                faces: facesByAssetPK[pk] ?? [],
                keywords: keywordsByAttrPK[attrPK] ?? [],
                exif: exif
            )
        }

        let albums = fetchAlbumHierarchyFromSQLite(in: database, uuidByAssetPK: uuidByAssetPK)
        return SQLiteLibraryPayload(recordsByUUID: records, albumHierarchy: albums)
    }

    /// Batch-extract native captions (ZLONGDESCRIPTION) from the ZASSETDESCRIPTION table in Photos.sqlite
    private func fetchCaptionsByAttributesPK(in db: OpaquePointer) -> [Int64: String] {
        guard Self.tableExists("ZASSETDESCRIPTION", in: db),
              Self.columnExists("ZLONGDESCRIPTION", inTable: "ZASSETDESCRIPTION", db: db) else {
            return [:]
        }

        var result: [Int64: String] = [:]

        // Pattern A: ZASSETDESCRIPTION.ZASSETATTRIBUTES -> ZADDITIONALASSETATTRIBUTES.Z_PK
        if Self.columnExists("ZASSETATTRIBUTES", inTable: "ZASSETDESCRIPTION", db: db) {
            let sql = """
            SELECT ZASSETATTRIBUTES, ZLONGDESCRIPTION
            FROM ZASSETDESCRIPTION
            WHERE ZASSETATTRIBUTES IS NOT NULL
              AND ZLONGDESCRIPTION IS NOT NULL
              AND ZLONGDESCRIPTION != '';
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let attrPK = sqlite3_column_int64(stmt, 0)
                    if let text = Self.stringCol(stmt, 1)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                        result[attrPK] = text
                    }
                }
            }
            sqlite3_finalize(stmt)
        }

        // Pattern B: ZADDITIONALASSETATTRIBUTES.ZASSETDESCRIPTION -> ZASSETDESCRIPTION.Z_PK
        if result.isEmpty && Self.columnExists("ZASSETDESCRIPTION", inTable: "ZADDITIONALASSETATTRIBUTES", db: db) {
            let sql = """
            SELECT attr.Z_PK, d.ZLONGDESCRIPTION
            FROM ZADDITIONALASSETATTRIBUTES attr
            INNER JOIN ZASSETDESCRIPTION d ON d.Z_PK = attr.ZASSETDESCRIPTION
            WHERE d.ZLONGDESCRIPTION IS NOT NULL
              AND d.ZLONGDESCRIPTION != '';
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let attrPK = sqlite3_column_int64(stmt, 0)
                    if let text = Self.stringCol(stmt, 1)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                        result[attrPK] = text
                    }
                }
            }
            sqlite3_finalize(stmt)
        }

        return result
    }

    /// Extract exact album sort order and custom key assets (ZCUSTOMKEYASSET / ZKEYASSET) from ZGENERICALBUM
    private func fetchAlbumHierarchyFromSQLite(
        in db: OpaquePointer,
        uuidByAssetPK: [Int64: String]
    ) -> [AlbumTreeNode] {
        guard Self.tableExists("ZGENERICALBUM", in: db) else { return [] }

        var albumAssetsByAlbumPK: [Int64: [String]] = [:]
        var joinTableNames: [String] = []
        var jStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'Z_%ASSETS';", -1, &jStmt, nil) == SQLITE_OK {
            while sqlite3_step(jStmt) == SQLITE_ROW {
                if let name = Self.stringCol(jStmt, 0) {
                    joinTableNames.append(name)
                }
            }
        }
        sqlite3_finalize(jStmt)

        for jTable in joinTableNames {
            var albumCol: String?
            var assetCol: String?
            var fokCol: String?
            var cStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "PRAGMA table_info(\(jTable));", -1, &cStmt, nil) == SQLITE_OK {
                while sqlite3_step(cStmt) == SQLITE_ROW {
                    if let col = Self.stringCol(cStmt, 1) {
                        let up = col.uppercased()
                        if up.contains("ALBUMS") { albumCol = col }
                        else if up.contains("FOK_") && up.contains("ASSETS") { fokCol = col }
                        else if up.contains("ASSETS") { assetCol = col }
                    }
                }
            }
            sqlite3_finalize(cStmt)
            guard let alCol = albumCol, let asCol = assetCol else { continue }
            let orderClause = fokCol != nil ? "ORDER BY \(alCol) ASC, \(fokCol!) ASC" : "ORDER BY \(alCol) ASC"
            let q = "SELECT \(alCol), \(asCol) FROM \(jTable) \(orderClause);"
            var aStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, q, -1, &aStmt, nil) == SQLITE_OK {
                while sqlite3_step(aStmt) == SQLITE_ROW {
                    let albPK = sqlite3_column_int64(aStmt, 0)
                    let astPK = sqlite3_column_int64(aStmt, 1)
                    if let uuid = uuidByAssetPK[astPK] {
                        albumAssetsByAlbumPK[albPK, default: []].append("\(uuid)/L0/001")
                    }
                }
            }
            sqlite3_finalize(aStmt)
        }

        let hasParentCol = Self.columnExists("ZPARENTFOLDER", inTable: "ZGENERICALBUM", db: db)
        guard hasParentCol else { return [] }
        let hasFokParent = Self.columnExists("Z_FOK_PARENTFOLDER", inTable: "ZGENERICALBUM", db: db)
        let hasTrashed = Self.columnExists("ZTRASHEDSTATE", inTable: "ZGENERICALBUM", db: db)
        let hasQueryData = Self.columnExists("ZUSERQUERYDATA", inTable: "ZGENERICALBUM", db: db)
        let hasCustomKeyAsset = Self.columnExists("ZCUSTOMKEYASSET", inTable: "ZGENERICALBUM", db: db)
        let hasKeyAsset = Self.columnExists("ZKEYASSET", inTable: "ZGENERICALBUM", db: db)

        let fokExpr = hasFokParent ? "COALESCE(Z_FOK_PARENTFOLDER, 0)" : "Z_PK"
        let trashWhere = hasTrashed ? "AND COALESCE(ZTRASHEDSTATE, 0) = 0" : ""
        let queryDataExpr = hasQueryData ? "ZUSERQUERYDATA" : "NULL"
        let keyAssetExpr: String
        if hasCustomKeyAsset && hasKeyAsset {
            keyAssetExpr = "COALESCE(ZCUSTOMKEYASSET, ZKEYASSET)"
        } else if hasCustomKeyAsset {
            keyAssetExpr = "ZCUSTOMKEYASSET"
        } else if hasKeyAsset {
            keyAssetExpr = "ZKEYASSET"
        } else {
            keyAssetExpr = "NULL"
        }

        let sql = """
        SELECT
            Z_PK,
            COALESCE(ZUUID, CAST(Z_PK AS TEXT)),
            COALESCE(ZTITLE, ''),
            COALESCE(ZKIND, 0),
            ZPARENTFOLDER,
            \(fokExpr),
            \(queryDataExpr),
            \(keyAssetExpr)
        FROM ZGENERICALBUM
        WHERE ZTITLE IS NOT NULL
          AND ZTITLE != ''
          \(trashWhere)
        ORDER BY \(fokExpr) ASC, Z_PK ASC;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        struct RawAlbumRow {
            let pk: Int64
            let uuid: String
            let title: String
            let kind: Int
            let parentPK: Int64?
            let orderKey: Int64
            let queryCriteria: SmartAlbumQueryCriteria?
            let keyAssetLocalID: String?
        }

        var rowsByPK: [Int64: RawAlbumRow] = [:]
        var childrenByParentPK: [Int64: [RawAlbumRow]] = [:]
        var rootFolderPKs: Set<Int64> = []

        let systemInternalTitles: Set<String> = [
            "Root Folder", "TopLevelAlbums", "ProjectRootFolder",
            "All Photos", "ibrary", "Trash", "Recently Deleted", "Hidden"
        ]

        while sqlite3_step(stmt) == SQLITE_ROW {
            let pk = sqlite3_column_int64(stmt, 0)
            let uuid = Self.stringCol(stmt, 1) ?? "\(pk)"
            let title = (Self.stringCol(stmt, 2) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let kind = Int(sqlite3_column_int(stmt, 3))
            let parentPK = Self.int64Col(stmt, 4)
            let fok = sqlite3_column_int64(stmt, 5)

            var criteria: SmartAlbumQueryCriteria? = nil
            if sqlite3_column_type(stmt, 6) == SQLITE_BLOB,
               let blobPtr = sqlite3_column_blob(stmt, 6) {
                let blobLen = Int(sqlite3_column_bytes(stmt, 6))
                if blobLen > 0 {
                    let data = Data(bytes: blobPtr, count: blobLen)
                    criteria = PLQueryProtobufParser.parse(data: data)
                }
            }

            let keyAssetPK = Self.int64Col(stmt, 7)
            let resolvedKeyAssetID = keyAssetPK.flatMap { uuidByAssetPK[$0] }.map { "\($0)/L0/001" }

            if kind == 3999 || title == "Root Folder" || title == "TopLevelAlbums" {
                rootFolderPKs.insert(pk)
                continue
            }
            guard !title.isEmpty, !systemInternalTitles.contains(title), !title.hasPrefix("Progress-") else { continue }
            guard kind == 2 || kind == 1507 || kind == 4000 || kind == 1508 else { continue }

            let row = RawAlbumRow(
                pk: pk,
                uuid: uuid,
                title: title,
                kind: kind,
                parentPK: parentPK,
                orderKey: fok,
                queryCriteria: criteria,
                keyAssetLocalID: resolvedKeyAssetID
            )
            rowsByPK[pk] = row
            if let p = parentPK {
                childrenByParentPK[p, default: []].append(row)
            }
        }

        func buildTree(for row: RawAlbumRow, visited: Set<Int64>) -> AlbumTreeNode? {
            guard !visited.contains(row.pk) else { return nil }
            var nextVisited = visited
            nextVisited.insert(row.pk)

            let isFolder = (row.kind == 4000)
            let isSmart = (row.kind == 1507 || row.kind == 1508 || row.queryCriteria != nil)
            let childRows = (childrenByParentPK[row.pk] ?? []).sorted {
                if $0.orderKey != $1.orderKey { return $0.orderKey < $1.orderKey }
                return $0.pk < $1.pk
            }
            let childNodes = childRows.compactMap { buildTree(for: $0, visited: nextVisited) }
            let assetIDs = albumAssetsByAlbumPK[row.pk] ?? []

            return AlbumTreeNode(
                id: "\(row.uuid)/L0/040",
                uuid: row.uuid,
                title: row.title,
                isFolder: isFolder,
                isSmartAlbum: isSmart,
                assetLocalIdentifiers: assetIDs,
                smartQueryCriteria: row.queryCriteria,
                children: childNodes,
                customKeyAssetID: row.keyAssetLocalID ?? assetIDs.first
            )
        }

        var topRows: [RawAlbumRow] = []
        for row in rowsByPK.values {
            if let p = row.parentPK {
                if rootFolderPKs.contains(p) || rowsByPK[p] == nil {
                    topRows.append(row)
                }
            } else {
                topRows.append(row)
            }
        }

        topRows.sort {
            if $0.orderKey != $1.orderKey { return $0.orderKey < $1.orderKey }
            return $0.pk < $1.pk
        }

        return topRows.compactMap { buildTree(for: $0, visited: []) }
    }

    /// Extract people and native key faces (ZPERSON.ZKEYFACE == df.Z_PK) from ZDETECTEDFACE × ZPERSON
    private func fetchDetectedFacesByAssetPK(
        in db: OpaquePointer,
        faceAssetFK: String,
        facePersonFK: String
    ) -> [Int64: [DetectedFaceInfo]] {
        guard Self.tableExists("ZDETECTEDFACE", in: db) else { return [:] }
        let hasPersonTable = Self.tableExists("ZPERSON", in: db)
        let hasPersonTypeCol = hasPersonTable && Self.columnExists("ZTYPE", inTable: "ZPERSON", db: db)
        let personTypeExpr = hasPersonTypeCol ? "COALESCE(p.ZTYPE, 0)" : "0"
        let hasPersonKeyFaceCol = hasPersonTable && Self.columnExists("ZKEYFACE", inTable: "ZPERSON", db: db)
        let personKeyFaceExpr = hasPersonKeyFaceCol ? "p.ZKEYFACE" : "NULL"
        let hasFaceIsKeyCol = Self.columnExists("ZISKEYFACE", inTable: "ZDETECTEDFACE", db: db)
        let faceIsKeyExpr = hasFaceIsKeyCol ? "COALESCE(df.ZISKEYFACE, 0)" : "0"

        let sql: String
        if hasPersonTable {
            sql = """
            SELECT
                df.\(faceAssetFK),
                COALESCE(df.ZUUID, CAST(df.Z_PK AS TEXT)),
                p.ZPERSONUUID,
                COALESCE(NULLIF(p.ZDISPLAYNAME, ''), NULLIF(p.ZFULLNAME, '')),
                p.ZFULLNAME,
                df.ZCENTERX,
                df.ZCENTERY,
                COALESCE(df.ZSIZE, 0.14),
                df.\(facePersonFK),
                \(personTypeExpr),
                df.Z_PK,
                \(personKeyFaceExpr),
                \(faceIsKeyExpr)
            FROM ZDETECTEDFACE df
            LEFT JOIN ZPERSON p ON p.Z_PK = df.\(facePersonFK)
            WHERE COALESCE(df.ZHIDDEN, 0) = 0
              AND COALESCE(df.ZISINTRASH, 0) = 0
              AND df.\(faceAssetFK) IS NOT NULL;
            """
        } else {
            sql = """
            SELECT
                df.\(faceAssetFK),
                COALESCE(df.ZUUID, CAST(df.Z_PK AS TEXT)),
                NULL,
                NULL,
                NULL,
                df.ZCENTERX,
                df.ZCENTERY,
                COALESCE(df.ZSIZE, 0.14),
                NULL,
                0,
                df.Z_PK,
                NULL,
                0
            FROM ZDETECTEDFACE df
            WHERE COALESCE(df.ZHIDDEN, 0) = 0
              AND COALESCE(df.ZISINTRASH, 0) = 0
              AND df.\(faceAssetFK) IS NOT NULL;
            """
        }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(stmt) }

        var map: [Int64: [DetectedFaceInfo]] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let assetPK = sqlite3_column_int64(stmt, 0)
            let faceID = Self.stringCol(stmt, 1) ?? UUID().uuidString
            let personUUID = Self.stringCol(stmt, 2)
            let rawName = Self.stringCol(stmt, 3)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fullName = Self.stringCol(stmt, 4)
            let cx = Self.doubleCol(stmt, 5) ?? 0.5
            let cy = Self.doubleCol(stmt, 6) ?? 0.5
            let sz = Self.doubleCol(stmt, 7) ?? 0.14
            let personPK = Self.int64Col(stmt, 8)
            let personType = Int(sqlite3_column_int(stmt, 9))
            let dfPK = sqlite3_column_int64(stmt, 10)
            let personKeyFacePK = Self.int64Col(stmt, 11)
            let dfIsKeyFlag = sqlite3_column_int(stmt, 12) != 0

            guard cx > 0.0 && cx < 1.0 && cy > 0.0 && cy < 1.0 else { continue }

            let finalDisplayName: String
            if let rawName, !rawName.isEmpty {
                finalDisplayName = rawName
            } else if let personPK, personPK > 0 {
                finalDisplayName = "Untitled #\(personPK)"
            } else {
                finalDisplayName = "Untitled"
            }

            let isKeyFace = (personKeyFacePK != nil && personKeyFacePK == dfPK) || dfIsKeyFlag

            let info = DetectedFaceInfo(
                id: faceID,
                personUUID: personUUID ?? (personPK.map { "PERSON_PK_\($0)" }),
                displayName: finalDisplayName,
                fullName: fullName,
                centerX: cx,
                centerY: cy,
                size: sz,
                qualityScore: sz,
                isFavoritePerson: (personType == 1),
                isKeyFaceInSQLite: isKeyFace
            )
            map[assetPK, default: []].append(info)
        }
        return map
    }

    private func fetchKeywordsByAttributesPK(in db: OpaquePointer) -> [Int64: [String]] {
        guard Self.tableExists("ZKEYWORD", in: db) else { return [:] }
        var joinTableName: String?
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'Z_%KEYWORDS';", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                joinTableName = Self.stringCol(stmt, 0)
            }
        }
        sqlite3_finalize(stmt)
        guard let joinTable = joinTableName else { return [:] }

        var attrCol: String?
        var kwCol: String?
        if sqlite3_prepare_v2(db, "PRAGMA table_info(\(joinTable));", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let col = Self.stringCol(stmt, 1) {
                    if col.uppercased().contains("ASSETATTRIBUTES") { attrCol = col }
                    if col.uppercased().contains("KEYWORDS") { kwCol = col }
                }
            }
        }
        sqlite3_finalize(stmt)
        guard let aCol = attrCol, let kCol = kwCol else { return [:] }

        let sql = """
        SELECT j.\(aCol), k.ZTITLE
        FROM \(joinTable) j
        INNER JOIN ZKEYWORD k ON k.Z_PK = j.\(kCol)
        WHERE k.ZTITLE IS NOT NULL;
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(stmt) }

        var result: [Int64: [String]] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let pk = sqlite3_column_int64(stmt, 0)
            if let title = Self.stringCol(stmt, 1), !title.isEmpty {
                result[pk, default: []].append(title)
            }
        }
        return result
    }

    private static func tableExists(_ name: String, in db: OpaquePointer) -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1;", -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    private static func columnExists(_ col: String, inTable table: String, db: OpaquePointer) -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(\(table));", -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let name = stringCol(stmt, 1), name.caseInsensitiveCompare(col) == .orderedSame {
                return true
            }
        }
        return false
    }

    private static func stringCol(_ s: OpaquePointer?, _ i: Int32) -> String? {
        guard sqlite3_column_type(s, i) != SQLITE_NULL, let c = sqlite3_column_text(s, i) else { return nil }
        return String(cString: c)
    }
    private static func doubleCol(_ s: OpaquePointer?, _ i: Int32) -> Double? {
        sqlite3_column_type(s, i) == SQLITE_NULL ? nil : sqlite3_column_double(s, i)
    }
    private static func intCol(_ s: OpaquePointer?, _ i: Int32) -> Int? {
        sqlite3_column_type(s, i) == SQLITE_NULL ? nil : Int(sqlite3_column_int(s, i))
    }
    private static func int64Col(_ s: OpaquePointer?, _ i: Int32) -> Int64? {
        sqlite3_column_type(s, i) == SQLITE_NULL ? nil : sqlite3_column_int64(s, i)
    }
}

// MARK: - 3. Hybrid Repository, External .photoslibrary Resolver & Thumbnail / Avatar / GIF Cache Service

@MainActor
final class HybridPhotoRepository {
    private var sqliteCache: [String: SQLiteAssetRecord] = [:]
    private var phAssetByID: [String: PHAsset] = [:]
    private var localMediaFileURLByID: [String: URL] = [:]
    private(set) var currentLibraryPackageURL: URL = PhotosSQLiteReader.defaultLibraryPackageURL

    init() {}

    func requestAuthorization() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .notDetermined {
            return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        return current
    }

    func loadLibrary(sqliteURL: URL? = nil) async -> (
        items: [PhotoAssetItem],
        albumTree: [AlbumTreeNode],
        allKeywords: [String]
    ) {
        let targetDatabaseURL = sqliteURL ?? PhotosSQLiteReader.defaultDatabaseURL
        let packageRoot = Self.resolveLibraryPackageRoot(from: targetDatabaseURL)
        self.currentLibraryPackageURL = packageRoot

        let sqliteLoadResult: Result<PhotosSQLiteReader.SQLiteLibraryPayload, Error> = await Task.detached(priority: .userInitiated) {
            do {
                let reader = PhotosSQLiteReader()
                let payload = try reader.loadAllMetadataAndAlbums(from: targetDatabaseURL)
                return .success(payload)
            } catch {
                return .failure(error)
            }
        }.value

        var sqliteAlbumTree: [AlbumTreeNode] = []
        if case .success(let payload) = sqliteLoadResult {
            sqliteCache = payload.recordsByUUID
            sqliteAlbumTree = payload.albumHierarchy
        } else {
            sqliteCache = [:]
        }

        let isDefaultSystemLibrary = (packageRoot.standardizedFileURL == PhotosSQLiteReader.defaultLibraryPackageURL.standardizedFileURL)

        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        opts.includeHiddenAssets = true

        let fetchResult = PHAsset.fetchAssets(with: opts)
        var phByUUID: [String: PHAsset] = [:]
        phByUUID.reserveCapacity(fetchResult.count)
        for idx in 0..<fetchResult.count {
            let asset = fetchResult.object(at: idx)
            let uuid = Self.extractUUID(from: asset.localIdentifier)
            phByUUID[uuid] = asset
        }

        var items: [PhotoAssetItem] = []
        var assetMap: [String: PHAsset] = [:]
        var resolvedFileURLs: [String: URL] = [:]
        var keywordSet: Set<String> = []
        let localSQLiteCache = sqliteCache

        if isDefaultSystemLibrary && !phByUUID.isEmpty {
            items.reserveCapacity(fetchResult.count)
            for idx in 0..<fetchResult.count {
                let asset = fetchResult.object(at: idx)
                let localID = asset.localIdentifier
                assetMap[localID] = asset
                let uuid = Self.extractUUID(from: localID)
                let rec = localSQLiteCache[uuid]

                if let rec, let localURL = Self.resolveLocalMediaFileURL(for: rec, in: packageRoot) {
                    resolvedFileURLs[localID] = localURL
                }

                let fallbackName = (asset.value(forKey: "filename") as? String) ?? "\(uuid).JPG"
                let fallbackUTI = asset.value(forKey: "uniformTypeIdentifier") as? String
                let origName = rec?.originalFilename ?? fallbackName
                let intName = rec?.internalFilename ?? fallbackName
                let kws = rec?.keywords ?? []
                for kw in kws { keywordSet.insert(kw) }

                let effectivePlaybackStyle = max(asset.playbackStyle.rawValue, rec?.playbackStyleInSQLite ?? 0)
                let effectiveUTI: String?
                if effectivePlaybackStyle == 2 || origName.lowercased().hasSuffix(".gif") || intName.lowercased().hasSuffix(".gif") {
                    effectiveUTI = "com.compuserve.gif"
                } else {
                    effectiveUTI = rec?.uniformTypeIdentifier ?? fallbackUTI
                }

                let item = PhotoAssetItem(
                    id: localID,
                    uuid: uuid,
                    creationDate: asset.creationDate ?? rec?.creationDate,
                    modificationDate: asset.modificationDate,
                    mediaTypeRaw: asset.mediaType.rawValue,
                    mediaSubtypesRaw: asset.mediaSubtypes.rawValue,
                    sourceTypeRaw: asset.sourceType.rawValue,
                    playbackStyleRaw: effectivePlaybackStyle,
                    pixelWidth: asset.pixelWidth > 0 ? asset.pixelWidth : (rec?.pixelWidth ?? 0),
                    pixelHeight: asset.pixelHeight > 0 ? asset.pixelHeight : (rec?.pixelHeight ?? 0),
                    duration: asset.duration > 0 ? asset.duration : (rec?.duration ?? 0),
                    isFavorite: asset.isFavorite || (rec?.isFavoriteInSQLite ?? false),
                    isHidden: asset.isHidden || (rec?.isHiddenInSQLite ?? false),
                    isTrashed: rec?.isTrashedInSQLite ?? false,
                    isEdited: rec?.isEditedInSQLite ?? false,
                    originalFilename: origName,
                    internalFilename: intName,
                    uniformTypeIdentifier: effectiveUTI,
                    title: rec?.title,
                    caption: rec?.caption,
                    latitude: rec?.latitude ?? asset.location?.coordinate.latitude,
                    longitude: rec?.longitude ?? asset.location?.coordinate.longitude,
                    locationName: nil,
                    isLocallyAvailable: rec?.isLocallyAvailable ?? true,
                    faces: rec?.faces ?? [],
                    keywords: kws,
                    exif: rec?.exif ?? ExifSummary()
                )
                items.append(item)
            }
        } else {
            let sortedRecords = localSQLiteCache.values.sorted {
                ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
            }
            items.reserveCapacity(sortedRecords.count)

            for rec in sortedRecords {
                let matchedPHAsset = phByUUID[rec.uuid]
                let localID = matchedPHAsset?.localIdentifier ?? "\(rec.uuid)/L0/001"
                if let matchedPHAsset {
                    assetMap[localID] = matchedPHAsset
                }
                if let localURL = Self.resolveLocalMediaFileURL(for: rec, in: packageRoot) {
                    resolvedFileURLs[localID] = localURL
                }
                for kw in rec.keywords { keywordSet.insert(kw) }

                let mediaType: PHAssetMediaType = rec.isVideoInSQLite ? .video : .image
                let effectivePlaybackStyle = max(matchedPHAsset?.playbackStyle.rawValue ?? 0, rec.playbackStyleInSQLite)
                let effectiveUTI: String?
                if rec.isGIFInSQLite || effectivePlaybackStyle == 2 {
                    effectiveUTI = "com.compuserve.gif"
                } else {
                    effectiveUTI = rec.uniformTypeIdentifier
                }

                let item = PhotoAssetItem(
                    id: localID,
                    uuid: rec.uuid,
                    creationDate: rec.creationDate ?? matchedPHAsset?.creationDate,
                    modificationDate: matchedPHAsset?.modificationDate,
                    mediaTypeRaw: matchedPHAsset?.mediaType.rawValue ?? mediaType.rawValue,
                    mediaSubtypesRaw: matchedPHAsset?.mediaSubtypes.rawValue ?? 0,
                    sourceTypeRaw: matchedPHAsset?.sourceType.rawValue ?? 0,
                    playbackStyleRaw: effectivePlaybackStyle,
                    pixelWidth: rec.pixelWidth > 0 ? rec.pixelWidth : (matchedPHAsset?.pixelWidth ?? 1600),
                    pixelHeight: rec.pixelHeight > 0 ? rec.pixelHeight : (matchedPHAsset?.pixelHeight ?? 1200),
                    duration: rec.duration > 0 ? rec.duration : (matchedPHAsset?.duration ?? 0),
                    isFavorite: rec.isFavoriteInSQLite || (matchedPHAsset?.isFavorite ?? false),
                    isHidden: rec.isHiddenInSQLite || (matchedPHAsset?.isHidden ?? false),
                    isTrashed: rec.isTrashedInSQLite,
                    isEdited: rec.isEditedInSQLite,
                    originalFilename: rec.originalFilename,
                    internalFilename: rec.internalFilename,
                    uniformTypeIdentifier: effectiveUTI,
                    title: rec.title,
                    caption: rec.caption,
                    latitude: rec.latitude,
                    longitude: rec.longitude,
                    locationName: nil,
                    isLocallyAvailable: rec.isLocallyAvailable,
                    faces: rec.faces,
                    keywords: rec.keywords,
                    exif: rec.exif
                )
                items.append(item)
            }
        }

        self.phAssetByID = assetMap
        self.localMediaFileURLByID = resolvedFileURLs

        let phAlbumTree = fetchSystemAlbumHierarchy()
        let finalAlbumTree = mergeSQLiteAndPhotoKitAlbumTrees(sqliteTree: sqliteAlbumTree, photoKitTree: phAlbumTree)
        return (items, finalAlbumTree, keywordSet.sorted())
    }

    private static func resolveLibraryPackageRoot(from dbOrPackageURL: URL) -> URL {
        var current = dbOrPackageURL
        for _ in 0..<5 {
            if current.pathExtension.lowercased() == "photoslibrary" {
                return current
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }
        return dbOrPackageURL.deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func resolveLocalMediaFileURL(for rec: SQLiteAssetRecord, in packageRoot: URL) -> URL? {
        let fm = FileManager.default
        if let dir = rec.directory, !dir.isEmpty, !rec.internalFilename.isEmpty {
            let origCandidate = packageRoot
                .appendingPathComponent("originals", isDirectory: true)
                .appendingPathComponent(dir, isDirectory: true)
                .appendingPathComponent(rec.internalFilename, isDirectory: false)
            if fm.fileExists(atPath: origCandidate.path) { return origCandidate }

            let mastersCandidate = packageRoot
                .appendingPathComponent("Masters", isDirectory: true)
                .appendingPathComponent(dir, isDirectory: true)
                .appendingPathComponent(rec.internalFilename, isDirectory: false)
            if fm.fileExists(atPath: mastersCandidate.path) { return mastersCandidate }
        }
        if let firstChar = rec.uuid.first {
            let prefix = String(firstChar)
            let origDir = packageRoot
                .appendingPathComponent("originals", isDirectory: true)
                .appendingPathComponent(prefix, isDirectory: true)

            if !rec.internalFilename.isEmpty {
                let origSub = origDir.appendingPathComponent(rec.internalFilename, isDirectory: false)
                if fm.fileExists(atPath: origSub.path) { return origSub }
            }
            let gifCandidate = origDir.appendingPathComponent("\(rec.uuid).gif", isDirectory: false)
            if fm.fileExists(atPath: gifCandidate.path) { return gifCandidate }
            let gifUpperCandidate = origDir.appendingPathComponent("\(rec.uuid).GIF", isDirectory: false)
            if fm.fileExists(atPath: gifUpperCandidate.path) { return gifUpperCandidate }

            if let origFiles = try? fm.contentsOfDirectory(at: origDir, includingPropertiesForKeys: nil),
               let matchedOrig = origFiles.first(where: { $0.lastPathComponent.hasPrefix(rec.uuid) }) {
                return matchedOrig
            }

            guard !rec.isGIFInSQLite else { return nil }

            let derivDir = packageRoot
                .appendingPathComponent("resources/derivatives", isDirectory: true)
                .appendingPathComponent(prefix, isDirectory: true)
            if let files = try? fm.contentsOfDirectory(at: derivDir, includingPropertiesForKeys: nil),
               let matched = files.first(where: { $0.lastPathComponent.hasPrefix(rec.uuid) }) {
                return matched
            }
        }
        return nil
    }

    private func fetchSystemAlbumHierarchy() -> [AlbumTreeNode] {
        let topList = PHCollectionList.fetchTopLevelUserCollections(with: nil)
        return buildNodes(from: topList)
    }

    private func buildNodes(from fetchResult: PHFetchResult<PHCollection>) -> [AlbumTreeNode] {
        var nodes: [AlbumTreeNode] = []
        for i in 0..<fetchResult.count {
            let col = fetchResult.object(at: i)
            let title = col.localizedTitle ?? "Untitled"
            let uuid = Self.extractUUID(from: col.localIdentifier)
            if let folder = col as? PHCollectionList {
                let childFetch = PHCollection.fetchCollections(in: folder, options: nil)
                let children = buildNodes(from: childFetch)
                nodes.append(
                    AlbumTreeNode(
                        id: folder.localIdentifier,
                        uuid: uuid,
                        title: title,
                        isFolder: true,
                        isSmartAlbum: false,
                        assetLocalIdentifiers: [],
                        smartQueryCriteria: nil,
                        children: children,
                        customKeyAssetID: nil
                    )
                )
            } else if let album = col as? PHAssetCollection {
                let assetsFetch = PHAsset.fetchAssets(in: album, options: nil)
                var ids: [String] = []
                ids.reserveCapacity(assetsFetch.count)
                for j in 0..<assetsFetch.count {
                    ids.append(assetsFetch.object(at: j).localIdentifier)
                }
                let isSmart = (album.assetCollectionType == .smartAlbum)
                nodes.append(
                    AlbumTreeNode(
                        id: album.localIdentifier,
                        uuid: uuid,
                        title: title,
                        isFolder: false,
                        isSmartAlbum: isSmart,
                        assetLocalIdentifiers: ids,
                        smartQueryCriteria: nil,
                        children: [],
                        customKeyAssetID: ids.first
                    )
                )
            }
        }
        return nodes
    }

    /// Merge SQLite album ordering, Smart Album rules, and custom key photos (ZCUSTOMKEYASSET / ZKEYASSET) with PhotoKit
    private func mergeSQLiteAndPhotoKitAlbumTrees(
        sqliteTree: [AlbumTreeNode],
        photoKitTree: [AlbumTreeNode]
    ) -> [AlbumTreeNode] {
        guard !sqliteTree.isEmpty else { return photoKitTree }

        var phNodeByUUID: [String: AlbumTreeNode] = [:]
        var phNodeByTitle: [String: AlbumTreeNode] = [:]
        func indexPHNodes(_ list: [AlbumTreeNode]) {
            for n in list {
                phNodeByUUID[n.uuid] = n
                if phNodeByTitle[n.title] == nil {
                    phNodeByTitle[n.title] = n
                }
                indexPHNodes(n.children)
            }
        }
        indexPHNodes(photoKitTree)

        func mergeNode(_ sqNode: AlbumTreeNode) -> AlbumTreeNode {
            let matchedPH = phNodeByUUID[sqNode.uuid] ?? phNodeByTitle[sqNode.title]
            let combinedIDs: [String]
            if !sqNode.assetLocalIdentifiers.isEmpty {
                combinedIDs = sqNode.assetLocalIdentifiers
            } else if let phIDs = matchedPH?.assetLocalIdentifiers, !phIDs.isEmpty {
                combinedIDs = phIDs
            } else {
                combinedIDs = []
            }
            let mergedChildren = sqNode.children.map { mergeNode($0) }
            // Prioritize ZCUSTOMKEYASSET / ZKEYASSET from SQLite when resolving album cover key photo
            let preferredKeyAssetID = sqNode.customKeyAssetID ?? combinedIDs.first ?? matchedPH?.customKeyAssetID
            return AlbumTreeNode(
                id: matchedPH?.id ?? sqNode.id,
                uuid: sqNode.uuid,
                title: sqNode.title,
                isFolder: sqNode.isFolder,
                isSmartAlbum: sqNode.isSmartAlbum || (matchedPH?.isSmartAlbum ?? false),
                assetLocalIdentifiers: combinedIDs,
                smartQueryCriteria: sqNode.smartQueryCriteria,
                children: mergedChildren,
                customKeyAssetID: preferredKeyAssetID
            )
        }

        return sqliteTree.map { mergeNode($0) }
    }

    func phAsset(for localIdentifier: String) -> PHAsset? {
        phAssetByID[localIdentifier]
    }

    func localMediaURL(for localIdentifier: String) -> URL? {
        localMediaFileURLByID[localIdentifier]
    }

    nonisolated static func extractUUID(from localIdentifier: String) -> String {
        if let idx = localIdentifier.firstIndex(of: "/") {
            return String(localIdentifier[..<idx])
        }
        return localIdentifier
    }
}

@MainActor
final class ThumbnailCacheController {
    let imageManager = PHCachingImageManager()
    private var avatarCache: [String: NSImage] = [:]
    private var highResCache: [String: NSImage] = [:]
    private var gifDataCache: [String: Data] = [:]
    private var fileURLCache: [String: URL] = [:]

    init() {
        imageManager.allowsCachingHighQualityImages = false
    }

    func clearAllCaches() {
        avatarCache.removeAll()
        highResCache.removeAll()
        gifDataCache.removeAll()
        fileURLCache.removeAll()
        imageManager.stopCachingImagesForAllAssets()
    }

    func cachedHighResImage(for assetID: String) -> NSImage? {
        highResCache[assetID]
    }

    func storeHighResImage(_ image: NSImage, for assetID: String) {
        if highResCache.count > 48 {
            highResCache.removeAll(keepingCapacity: true)
        }
        highResCache[assetID] = image
    }

    func requestThumbnail(
        for asset: PHAsset?,
        fallbackFileURL: URL? = nil,
        targetSize: CGSize,
        cropToSquare: Bool,
        completion: @escaping @MainActor (NSImage?, Bool) -> Void
    ) -> PHImageRequestID {
        if let asset {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = false
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast

            return imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: cropToSquare ? .aspectFill : .aspectFit,
                options: options
            ) { image, info in
                let inCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                Task { @MainActor in
                    completion(image, inCloud)
                }
            }
        } else if let fallbackFileURL {
            let maxDim = max(120, Int(max(targetSize.width, targetSize.height)))
            Task.detached(priority: .userInitiated) {
                let thumb = Self.decodeThumbnailFromFile(url: fallbackFileURL, maxPixelSize: maxDim)
                await MainActor.run {
                    completion(thumb, false)
                }
            }
            return PHInvalidImageRequestID
        } else {
            completion(nil, false)
            return PHInvalidImageRequestID
        }
    }

    func requestHighResolutionImage(
        for asset: PHAsset?,
        fallbackFileURL: URL? = nil,
        assetID: String? = nil,
        completion: @escaping @MainActor (NSImage?) -> Void
    ) -> PHImageRequestID {
        let localID = asset?.localIdentifier ?? assetID ?? fallbackFileURL?.path ?? ""
        if !localID.isEmpty, let cached = highResCache[localID] {
            completion(cached)
        }

        if let asset {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast

            return imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 2560, height: 2560),
                contentMode: .aspectFit,
                options: options
            ) { [weak self] image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                Task { @MainActor [weak self] in
                    guard let self, let image else { return }
                    if !isDegraded || self.highResCache[localID] == nil {
                        self.storeHighResImage(image, for: localID)
                    }
                    completion(image)
                }
            }
        } else if let fallbackFileURL {
            Task.detached(priority: .userInitiated) {
                let img = Self.decodeThumbnailFromFile(url: fallbackFileURL, maxPixelSize: 2560) ?? NSImage(contentsOf: fallbackFileURL)
                await MainActor.run { [weak self] in
                    if let self, let img, !localID.isEmpty {
                        self.storeHighResImage(img, for: localID)
                    }
                    completion(img)
                }
            }
            return PHInvalidImageRequestID
        } else {
            completion(nil)
            return PHInvalidImageRequestID
        }
    }

    func requestFaceAvatar(
        for asset: PHAsset?,
        fallbackFileURL: URL? = nil,
        face: DetectedFaceInfo?,
        portraitRectangular: Bool = false,
        completion: @escaping @MainActor (NSImage?) -> Void
    ) {
        let baseID = asset?.localIdentifier ?? fallbackFileURL?.path ?? "unknown"
        let shapeKey = portraitRectangular ? "portrait_v14" : "square_v14"
        let cacheKey = "\(baseID)_\(face?.id ?? "full")_\(shapeKey)"
        if let cached = avatarCache[cacheKey] {
            completion(cached)
            return
        }

        let cropAndComplete: @MainActor (NSImage?) -> Void = { [weak self] image in
            guard let self, let image else {
                completion(nil)
                return
            }
            let finalImage: NSImage
            if let cgImg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let imgW = CGFloat(cgImg.width)
                let imgH = CGFloat(cgImg.height)
                let targetAspect: CGFloat = portraitRectangular ? 0.5 : 1.0 // ★ [UI SIZING: People Grid & Header] Face portrait crop aspect ratio (width / height; e.g. 0.5 or 0.74 = vertical portrait, 1.0 = square)
                if let face {
                    let facePxX = CGFloat(face.centerX) * imgW
                    let facePxY = CGFloat(1.0 - face.centerY) * imgH
                    let baseDim = max(imgW, imgH) * CGFloat(max(0.11, min(face.size, 0.55)))
                    var cropH = portraitRectangular ? (baseDim * 2.9) : (baseDim * 2.25) // ★ [UI SIZING: People Grid & Header] Padding multiplier around the detected face box (increase for a wider crop)
                    var cropW = cropH * targetAspect
                    if cropW > imgW {
                        cropW = imgW
                        cropH = cropW / targetAspect
                    }
                    if cropH > imgH {
                        cropH = imgH
                        cropW = cropH * targetAspect
                    }
                    let shiftY = portraitRectangular ? (cropH * 0.05) : 0.0
                    let minX = max(0.0, min(facePxX - cropW / 2.0, imgW - cropW))
                    let minY = max(0.0, min(facePxY - cropH / 2.0 + shiftY, imgH - cropH))
                    let cropRect = CGRect(x: minX, y: minY, width: cropW, height: cropH).integral
                    if cropRect.width > 8, cropRect.height > 8, let cropped = cgImg.cropping(to: cropRect) {
                        finalImage = NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
                    } else {
                        finalImage = image
                    }
                } else {
                    var cropH = imgH
                    var cropW = cropH * targetAspect
                    if cropW > imgW {
                        cropW = imgW
                        cropH = cropW / targetAspect
                    }
                    let minX = max(0.0, (imgW - cropW) / 2.0)
                    let minY = max(0.0, (imgH - cropH) / 2.0)
                    let cropRect = CGRect(x: minX, y: minY, width: cropW, height: cropH).integral
                    if cropRect.width > 8, cropRect.height > 8, let cropped = cgImg.cropping(to: cropRect) {
                        finalImage = NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
                    } else {
                        finalImage = image
                    }
                }
            } else {
                finalImage = image
            }
            self.avatarCache[cacheKey] = finalImage
            completion(finalImage)
        }

        if let asset {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact

            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 840, height: 840),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                Task { @MainActor in
                    cropAndComplete(image)
                }
            }
        } else if let fallbackFileURL {
            Task.detached(priority: .userInitiated) {
                let img = Self.decodeThumbnailFromFile(url: fallbackFileURL, maxPixelSize: 840)
                await MainActor.run {
                    cropAndComplete(img)
                }
            }
        } else {
            completion(nil)
        }
    }

    func requestRawImageData(
        for asset: PHAsset?,
        fallbackFileURL: URL? = nil,
        completion: @escaping @MainActor (Data?, String?) -> Void
    ) -> PHImageRequestID {
        let cacheKey = asset?.localIdentifier ?? fallbackFileURL?.path ?? ""
        if !cacheKey.isEmpty, let cachedData = gifDataCache[cacheKey] {
            completion(cachedData, "com.compuserve.gif")
            return PHInvalidImageRequestID
        }

        if let fallbackFileURL,
           fallbackFileURL.pathExtension.lowercased() == "gif",
           FileManager.default.fileExists(atPath: fallbackFileURL.path) {
            Task.detached(priority: .userInitiated) {
                if let data = try? Data(contentsOf: fallbackFileURL), !data.isEmpty {
                    await MainActor.run { [weak self] in
                        if !cacheKey.isEmpty {
                            self?.storeGIFData(data, for: cacheKey)
                        }
                        completion(data, "com.compuserve.gif")
                    }
                    return
                }
            }
            return PHInvalidImageRequestID
        }

        if let asset {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.version = .original
            options.deliveryMode = .highQualityFormat

            return imageManager.requestImageDataAndOrientation(for: asset, options: options) { [weak self] data, uti, _, _ in
                if let data, Self.isMultiFrameGIFData(data) {
                    Task { @MainActor [weak self] in
                        if !cacheKey.isEmpty {
                            self?.storeGIFData(data, for: cacheKey)
                        }
                        completion(data, uti)
                    }
                    return
                }

                let resources = PHAssetResource.assetResources(for: asset)
                if let gifRes = resources.first(where: {
                    $0.uniformTypeIdentifier.lowercased().contains("gif")
                        || $0.originalFilename.lowercased().hasSuffix(".gif")
                        || $0.type == .photo
                }) {
                    let resOpts = PHAssetResourceRequestOptions()
                    resOpts.isNetworkAccessAllowed = true
                    nonisolated(unsafe) var buffer = Data()
                    PHAssetResourceManager.default().requestData(for: gifRes, options: resOpts) { chunk in
                        buffer.append(chunk)
                    } completionHandler: { error in
                        let finalBuffer = buffer
                        Task { @MainActor [weak self] in
                            if error == nil, !finalBuffer.isEmpty {
                                if !cacheKey.isEmpty, Self.isMultiFrameGIFData(finalBuffer) {
                                    self?.storeGIFData(finalBuffer, for: cacheKey)
                                }
                                completion(finalBuffer, gifRes.uniformTypeIdentifier)
                            } else if let fallbackFileURL, let diskData = try? Data(contentsOf: fallbackFileURL) {
                                completion(diskData, uti)
                            } else {
                                completion(data, uti)
                            }
                        }
                    }
                } else {
                    Task { @MainActor in
                        completion(data, uti)
                    }
                }
            }
        } else if let fallbackFileURL {
            Task.detached(priority: .userInitiated) {
                let data = try? Data(contentsOf: fallbackFileURL)
                let ext = fallbackFileURL.pathExtension
                await MainActor.run { [weak self] in
                    if let data, !cacheKey.isEmpty, Self.isMultiFrameGIFData(data) {
                        self?.storeGIFData(data, for: cacheKey)
                    }
                    completion(data, ext)
                }
            }
            return PHInvalidImageRequestID
        } else {
            completion(nil, nil)
            return PHInvalidImageRequestID
        }
    }

    private func storeGIFData(_ data: Data, for key: String) {
        if gifDataCache.count > 64 {
            gifDataCache.removeAll(keepingCapacity: true)
        }
        gifDataCache[key] = data
    }

    nonisolated private static func isMultiFrameGIFData(_ data: Data) -> Bool {
        guard data.count > 6 else { return false }
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        return CGImageSourceGetCount(src) > 1
    }

    func resolveExternalOpenFileURL(for asset: PHAsset?, fallbackFileURL: URL? = nil, originalFilename: String) async -> URL? {
        if let fallbackFileURL, FileManager.default.fileExists(atPath: fallbackFileURL.path) {
            return fallbackFileURL
        }
        guard let asset else { return nil }
        if let cached = fileURLCache[asset.localIdentifier], FileManager.default.fileExists(atPath: cached.path) {
            return cached
        }

        let resources = PHAssetResource.assetResources(for: asset)
        guard let targetRes = resources.first(where: { $0.type == .photo || $0.type == .video || $0.type == .fullSizePhoto || $0.type == .fullSizeVideo }) ?? resources.first else {
            return nil
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PhotoVaultExternalPreview", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let safeName = originalFilename.replacingOccurrences(of: "/", with: "_")
        let destURL = tempDir.appendingPathComponent("\(UUID().uuidString.prefix(8))_\(safeName)")
        try? FileManager.default.removeItem(at: destURL)

        let reqOptions = PHAssetResourceRequestOptions()
        reqOptions.isNetworkAccessAllowed = true

        return await withCheckedContinuation { continuation in
            PHAssetResourceManager.default().writeData(for: targetRes, toFile: destURL, options: reqOptions) { error in
                Task { @MainActor in
                    if error == nil {
                        self.fileURLCache[asset.localIdentifier] = destURL
                        continuation.resume(returning: destURL)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }

    func cancelRequest(_ id: PHImageRequestID) {
        if id != PHInvalidImageRequestID {
            imageManager.cancelImageRequest(id)
        }
    }

    nonisolated private static func decodeThumbnailFromFile(url: URL, maxPixelSize: Int) -> NSImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return NSImage(cgImage: cgImg, size: NSSize(width: cgImg.width, height: cgImg.height))
    }
}

// MARK: - 4. Native Animated GIF View (CGAnimateImageDataWithBlock + Layer-Backed Zero-Overhead Rendering)

struct AnimatedGIFSurfaceView: NSViewRepresentable {
    let asset: PHAsset?
    var fallbackFileURL: URL? = nil
    let assetID: String
    let thumbnailCache: ThumbnailCacheController
    var contentScaling: NSImageScaling = .scaleProportionallyUpOrDown

    func makeNSView(context: Context) -> GIFContainerNSView {
        let view = GIFContainerNSView()
        view.updateGravity(for: contentScaling)
        view.startLoadingGIF(assetID: assetID, asset: asset, fallbackFileURL: fallbackFileURL, cache: thumbnailCache)
        return view
    }

    func updateNSView(_ nsView: GIFContainerNSView, context: Context) {
        nsView.updateGravity(for: contentScaling)
        if nsView.currentAssetID != assetID {
            nsView.startLoadingGIF(assetID: assetID, asset: asset, fallbackFileURL: fallbackFileURL, cache: thumbnailCache)
        } else {
            nsView.resumeAnimationIfNeeded()
        }
    }

    final class GIFContainerNSView: NSView {
        private let gifLayer = CALayer()
        var currentAssetID: String?
        private var animationToken = UUID()
        private var loadedGIFData: Data?
        private var isRunningAnimation: Bool = false
        private var dataRequestID: PHImageRequestID?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.masksToBounds = true
            gifLayer.contentsGravity = .resizeAspect
            gifLayer.masksToBounds = true
            layer?.addSublayer(gifLayer)
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            gifLayer.frame = bounds
            CATransaction.commit()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil {
                resumeAnimationIfNeeded()
            } else {
                animationToken = UUID()
                isRunningAnimation = false
            }
        }

        func updateGravity(for scaling: NSImageScaling) {
            let targetGravity: CALayerContentsGravity = (scaling == .scaleAxesIndependently) ? .resizeAspectFill : .resizeAspect
            if gifLayer.contentsGravity != targetGravity {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                gifLayer.contentsGravity = targetGravity
                CATransaction.commit()
            }
        }

        func startLoadingGIF(assetID: String, asset: PHAsset?, fallbackFileURL: URL?, cache: ThumbnailCacheController) {
            stopAnimation(cache: cache)
            currentAssetID = assetID
            let expectedID = assetID

            dataRequestID = cache.requestRawImageData(for: asset, fallbackFileURL: fallbackFileURL) { [weak self] data, _ in
                guard let self, self.currentAssetID == expectedID, let data, !data.isEmpty else { return }
                self.loadedGIFData = data
                if let src = CGImageSourceCreateWithData(data as CFData, nil),
                   let firstCG = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    self.gifLayer.contents = firstCG
                    CATransaction.commit()
                }
                self.startCoreGraphicsGIFLoop(with: data, expectedID: expectedID)
            }
        }

        func resumeAnimationIfNeeded() {
            guard !isRunningAnimation, let data = loadedGIFData, let expectedID = currentAssetID else { return }
            startCoreGraphicsGIFLoop(with: data, expectedID: expectedID)
        }

        private func startCoreGraphicsGIFLoop(with data: Data, expectedID: String) {
            let token = UUID()
            self.animationToken = token
            self.isRunningAnimation = true

            let status = CGAnimateImageDataWithBlock(data as CFData, nil) { [weak self] _, cgImage, stop in
                guard let self,
                      self.animationToken == token,
                      self.currentAssetID == expectedID else {
                    stop.pointee = true
                    return
                }
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.gifLayer.contents = cgImage
                CATransaction.commit()
            }
            if status != noErr {
                self.isRunningAnimation = false
            }
        }

        func stopAnimation(cache: ThumbnailCacheController) {
            animationToken = UUID()
            isRunningAnimation = false
            loadedGIFData = nil
            if let reqID = dataRequestID {
                cache.cancelRequest(reqID)
                dataRequestID = nil
            }
            currentAssetID = nil
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            gifLayer.contents = nil
            CATransaction.commit()
        }

        deinit {
            animationToken = UUID()
        }
    }
}

// MARK: - 5. QuickTime / VLC Style Smooth Video Seek Engine (Apple QA1820 Zero-Tolerance Chase Seek)

@MainActor
@Observable
final class SmoothVideoSeekController {
    let player = AVPlayer()
    var isPlaying: Bool = false
    var currentTimeSeconds: Double = 0.0
    var durationSeconds: Double = 1.0
    var playbackRate: Float = 1.0
    var volume: Float = 0.85
    var isMuted: Bool = false
    var nominalFPS: Double = 30.0

    private var isSeekInProgress: Bool = false
    private var chaseTime: CMTime = .zero
    private var timeObserverToken: Any?
    private var videoRequestID: PHImageRequestID?
    private var activeLoadTask: Task<Void, Never>?

    init() {
        player.volume = volume
        setupPeriodicTimeObserver()
    }

    private func setupPeriodicTimeObserver() {
        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let secs = time.seconds
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !self.isSeekInProgress {
                    self.currentTimeSeconds = max(0, secs.isFinite ? secs : 0)
                }
            }
        }
    }

    func loadVideo(
        for phAsset: PHAsset?,
        fallbackFileURL: URL? = nil,
        fallbackDuration: TimeInterval,
        fallbackFPS: Double?
    ) {
        stopAndCleanup()
        self.durationSeconds = max(0.1, fallbackDuration)
        self.nominalFPS = fallbackFPS ?? 30.0

        if let phAsset {
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat

            videoRequestID = PHImageManager.default().requestPlayerItem(forVideo: phAsset, options: options) { [weak self] item, _ in
                guard let item else { return }
                let avAsset = item.asset
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let freshItem = AVPlayerItem(asset: avAsset)
                    self.activatePlayerItem(freshItem)
                }
            }
        } else if let fallbackFileURL {
            let item = AVPlayerItem(url: fallbackFileURL)
            activatePlayerItem(item)
        }
    }

    private func activatePlayerItem(_ item: AVPlayerItem) {
        item.audioTimePitchAlgorithm = .spectral
        player.replaceCurrentItem(with: item)
        player.play()
        isPlaying = true
        playbackRate = 1.0

        activeLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            if let loadedDuration = try? await item.asset.load(.duration) {
                let d = loadedDuration.seconds
                if d.isFinite && d > 0 {
                    self.durationSeconds = d
                }
            }
        }
    }

    func stopAndCleanup() {
        activeLoadTask?.cancel()
        activeLoadTask = nil
        player.pause()
        isPlaying = false
        playbackRate = 1.0
        isSeekInProgress = false
        chaseTime = .zero
        if let reqID = videoRequestID {
            PHImageManager.default().cancelImageRequest(reqID)
            videoRequestID = nil
        }
    }

    func togglePlayPause() {
        if isPlaying {
            player.pause()
            isPlaying = false
            playbackRate = 1.0
        } else {
            player.rate = playbackRate
            isPlaying = true
        }
    }

    func cycleFastForward() {
        let speeds: [Float] = [1.0, 1.5, 2.0, 4.0, 8.0]
        let currentIndex = speeds.firstIndex(of: playbackRate) ?? 0
        let nextIndex = (currentIndex + 1) % speeds.count
        playbackRate = speeds[nextIndex]
        player.rate = playbackRate
        isPlaying = true
    }

    func stepBackward(seconds: Double = 5.0) {
        scrubByDeltaSeconds(-seconds)
    }

    func stepForward(seconds: Double = 10.0) {
        scrubByDeltaSeconds(seconds)
    }

    /// Two-finger trackpad horizontal swipe over the HUD controller for variable frame-accurate scrubbing
    func handleControllerTrackpadSwipe(deltaX: CGFloat) {
        let frameDuration = 1.0 / max(24.0, nominalFPS)
        let absDelta = abs(Double(deltaX))
        // Invert delta sign for natural trackpad scrubbing direction
        let sign = Double(deltaX >= 0 ? -1.0 : 1.0)

        let deltaSeconds: Double
        if absDelta < 1.8 {
            deltaSeconds = sign * frameDuration * (absDelta / 1.1)
        } else {
            let scale = max(0.06, min(durationSeconds * 0.0025, 1.2))
            deltaSeconds = sign * pow(absDelta, 1.30) * scale
        }

        scrubByDeltaSeconds(deltaSeconds)
    }

    func scrubByDeltaSeconds(_ deltaSeconds: Double) {
        let target = max(0.0, min(currentTimeSeconds + deltaSeconds, durationSeconds))
        scrub(toSeconds: target)
    }

    func scrub(toSeconds targetSeconds: Double) {
        let clamped = max(0.0, min(targetSeconds, durationSeconds))
        currentTimeSeconds = clamped
        let targetCMTime = CMTime(seconds: clamped, preferredTimescale: 600)
        chaseTime = targetCMTime

        if !isSeekInProgress {
            trySeekToChaseTime()
        }
    }

    private func trySeekToChaseTime() {
        guard let currentItem = player.currentItem else { return }
        if currentItem.status == .readyToPlay {
            actuallySeekToTime()
        } else {
            currentItem.seek(to: chaseTime, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: nil)
        }
    }

    private func actuallySeekToTime() {
        isSeekInProgress = true
        let seekTimeInProgress = chaseTime

        player.seek(
            to: seekTimeInProgress,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if CMTimeCompare(seekTimeInProgress, self.chaseTime) == 0 {
                    self.isSeekInProgress = false
                } else {
                    self.actuallySeekToTime()
                }
            }
        }
    }
}

// MARK: - 6. AppKit AVPlayerLayer View + Stationary Spatial Trackpad Gesture Router (Zero-Flyaway 1:1 Swipe & Pinch)

/// Stationary gesture surface unscaled by zoom/pan transforms (prevents positive-feedback coordinate flyaway)
private struct StationaryDetailCanvasGestureView: NSViewRepresentable {
    var isHoveringController: Bool
    var currentZoomScale: CGFloat
    var onControllerSwipeDeltaX: (CGFloat) -> Void
    var onCanvasSwipeDragChanged: (CGFloat) -> Void
    var onCanvasSwipeDragEnded: (CGFloat) -> Void
    var onMagnifyAtLocation: (CGFloat, CGPoint) -> Void
    var onPanDelta: (CGFloat, CGFloat) -> Void
    var onPinchInClose: () -> Void
    var onDoubleClickAtLocation: (CGPoint) -> Void

    func makeNSView(context: Context) -> StationaryGestureNSView {
        let v = StationaryGestureNSView()
        v.isHoveringController = isHoveringController
        v.currentZoomScale = currentZoomScale
        v.onControllerSwipeDeltaX = onControllerSwipeDeltaX
        v.onCanvasSwipeDragChanged = onCanvasSwipeDragChanged
        v.onCanvasSwipeDragEnded = onCanvasSwipeDragEnded
        v.onMagnifyAtLocation = onMagnifyAtLocation
        v.onPanDelta = onPanDelta
        v.onPinchInClose = onPinchInClose
        v.onDoubleClickAtLocation = onDoubleClickAtLocation
        return v
    }

    func updateNSView(_ nsView: StationaryGestureNSView, context: Context) {
        nsView.isHoveringController = isHoveringController
        nsView.currentZoomScale = currentZoomScale
        nsView.onControllerSwipeDeltaX = onControllerSwipeDeltaX
        nsView.onCanvasSwipeDragChanged = onCanvasSwipeDragChanged
        nsView.onCanvasSwipeDragEnded = onCanvasSwipeDragEnded
        nsView.onMagnifyAtLocation = onMagnifyAtLocation
        nsView.onPanDelta = onPanDelta
        nsView.onPinchInClose = onPinchInClose
        nsView.onDoubleClickAtLocation = onDoubleClickAtLocation
    }

    final class StationaryGestureNSView: NSView {
        var isHoveringController: Bool = false
        var currentZoomScale: CGFloat = 1.0
        var onControllerSwipeDeltaX: ((CGFloat) -> Void)?
        var onCanvasSwipeDragChanged: ((CGFloat) -> Void)?
        var onCanvasSwipeDragEnded: ((CGFloat) -> Void)?
        var onMagnifyAtLocation: ((CGFloat, CGPoint) -> Void)?
        var onPanDelta: ((CGFloat, CGFloat) -> Void)?
        var onPinchInClose: (() -> Void)?
        var onDoubleClickAtLocation: ((CGPoint) -> Void)?

        private var accumDragX: CGFloat = 0.0
        private var isTrackingHorizontalSwipe: Bool = false
        private var accumPinch: CGFloat = 0.0
        private var lastMouseDragLoc: NSPoint?

        override var isFlipped: Bool { true }
        override var acceptsFirstResponder: Bool { true }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        override func mouseDown(with event: NSEvent) {
            let loc = convert(event.locationInWindow, from: nil)
            if event.clickCount == 2 {
                onDoubleClickAtLocation?(loc)
            } else {
                lastMouseDragLoc = loc
            }
        }

        override func mouseDragged(with event: NSEvent) {
            let cur = convert(event.locationInWindow, from: nil)
            if currentZoomScale > 1.01, let last = lastMouseDragLoc {
                onPanDelta?(cur.x - last.x, cur.y - last.y)
                lastMouseDragLoc = cur
            }
        }

        override func mouseUp(with event: NSEvent) {
            lastMouseDragLoc = nil
        }

        override func scrollWheel(with event: NSEvent) {
            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY

            if isHoveringController {
                guard abs(dx) > abs(dy) * 0.75 else { return }
                let effectiveDelta = event.isDirectionInvertedFromDevice ? -dx : dx
                onControllerSwipeDeltaX?(effectiveDelta)
                return
            }

            if currentZoomScale > 1.01 {
                if event.momentumPhase == [] {
                    let stepX = event.hasPreciseScrollingDeltas ? dx : dx * 6.0
                    let stepY = event.hasPreciseScrollingDeltas ? dy : dy * 6.0
                    onPanDelta?(stepX, stepY)
                }
                return
            }

            // Ignore post-release momentum events and track direct finger contact 1:1
            guard event.momentumPhase == [] else { return }

            if event.phase == .began {
                accumDragX = 0.0
                isTrackingHorizontalSwipe = false
            } else if event.phase == .changed {
                if !isTrackingHorizontalSwipe {
                    if abs(dx) > abs(dy) * 1.05 && abs(dx) > 0.4 {
                        isTrackingHorizontalSwipe = true
                    } else {
                        return
                    }
                }
                let factor: CGFloat = event.hasPreciseScrollingDeltas ? 1.15 : 8.0
                accumDragX += dx * factor
                onCanvasSwipeDragChanged?(accumDragX)
            } else if event.phase == .ended || event.phase == .cancelled {
                if isTrackingHorizontalSwipe {
                    let finalX = accumDragX
                    accumDragX = 0.0
                    isTrackingHorizontalSwipe = false
                    onCanvasSwipeDragEnded?(finalX)
                } else {
                    accumDragX = 0.0
                }
            } else if event.phase == [] && !event.hasPreciseScrollingDeltas {
                guard abs(dx) > abs(dy) * 1.1, abs(dx) > 1.0 else { return }
                onCanvasSwipeDragEnded?(dx > 0 ? 180.0 : -180.0)
            }
        }

        override func magnify(with event: NSEvent) {
            let loc = convert(event.locationInWindow, from: nil)
            if event.phase == .began {
                accumPinch = 0.0
            }
            accumPinch += event.magnification
            if currentZoomScale <= 1.05 && accumPinch < -0.32 {
                accumPinch = 0.0
                onPinchInClose?()
            } else {
                onMagnifyAtLocation?(event.magnification, loc)
            }
        }
    }
}

private struct VideoPlayerLayerSurfaceView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerLayerNSView {
        let v = PlayerLayerNSView()
        v.playerLayer.player = player
        return v
    }

    func updateNSView(_ nsView: PlayerLayerNSView, context: Context) {
        if nsView.playerLayer.player !== player {
            nsView.playerLayer.player = player
        }
    }

    final class PlayerLayerNSView: NSView {
        let playerLayer = AVPlayerLayer()

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.backgroundColor = NSColor.black.cgColor
            playerLayer.videoGravity = .resizeAspect
            layer?.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = bounds
            CATransaction.commit()
        }
    }
}

// MARK: - 7. Detail Media Viewer (Auto-Hiding Video HUD + Reversed Seek + Clamped Zoom Pan + No Bottom Filmstrip)

struct DetailMediaPlayerView: View {
    let item: PhotoAssetItem
    let prevItem: PhotoAssetItem?
    let nextItem: PhotoAssetItem?
    @Bindable var viewModel: PhotoWorkspaceViewModel
    @Binding var showInspector: Bool
    var onCloseDetail: () -> Void
    var onNavigateRelative: (Int) -> Void

    @State private var seekController = SmoothVideoSeekController()
    @State private var currentImage: NSImage?
    @State private var prevImage: NSImage?
    @State private var nextImage: NSImage?
    @State private var isHoveringHUD: Bool = false
    @State private var showVideoControllerHUD: Bool = true
    @State private var videoHUDIdleTask: Task<Void, Never>?
    @State private var videoMouseMonitorToken: Any?

    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var swipeDragOffset: CGFloat = 0.0
    @State private var isAnimatingPageSnap: Bool = false

    @State private var controllerOffset: CGSize = .zero
    @State private var controllerDragStartOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let pageWidth = max(1.0, geo.size.width)

            ZStack {
                Color.black.ignoresSafeArea()

                // 1. Visual media layer (adjacent previous/next photo previews + active media)
                ZStack {
                    if let prevImage, zoomScale <= 1.01, swipeDragOffset > 0.5 {
                        Image(nsImage: prevImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .offset(x: -pageWidth + swipeDragOffset)
                    }

                    if let nextImage, zoomScale <= 1.01, swipeDragOffset < -0.5 {
                        Image(nsImage: nextImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .offset(x: pageWidth + swipeDragOffset)
                    }

                    Group {
                        if item.isVideo {
                            VideoPlayerLayerSurfaceView(player: seekController.player)
                                .frame(width: geo.size.width, height: geo.size.height)
                        } else if item.isGIF {
                            AnimatedGIFSurfaceView(
                                asset: viewModel.repository.phAsset(for: item.id),
                                fallbackFileURL: viewModel.repository.localMediaURL(for: item.id),
                                assetID: item.id,
                                thumbnailCache: viewModel.thumbnailCache,
                                contentScaling: .scaleProportionallyUpOrDown
                            )
                            .frame(width: geo.size.width, height: geo.size.height)
                        } else if let currentImage {
                            Image(nsImage: currentImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geo.size.width, height: geo.size.height)
                        } else {
                            ProgressView()
                                .controlSize(.regular)
                                .frame(width: geo.size.width, height: geo.size.height)
                        }
                    }
                    .scaleEffect(zoomScale)
                    .offset(x: swipeDragOffset + panOffset.width, y: panOffset.height)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .allowsHitTesting(false)

                // 2. Stationary coordinate space trackpad & mouse gesture router (zero coordinate flyaway)
                StationaryDetailCanvasGestureView(
                    isHoveringController: isHoveringHUD && showVideoControllerHUD,
                    currentZoomScale: zoomScale,
                    onControllerSwipeDeltaX: { deltaX in
                        revealVideoHUDAndResetTimer()
                        seekController.handleControllerTrackpadSwipe(deltaX: deltaX)
                    },
                    onCanvasSwipeDragChanged: { dragX in
                        handleInteractiveDragChanged(dragX, pageWidth: pageWidth)
                    },
                    onCanvasSwipeDragEnded: { finalX in
                        completeInteractiveSwipe(finalX: finalX, pageWidth: pageWidth)
                    },
                    onMagnifyAtLocation: { magDelta, cursorLoc in
                        applyZoomAtLocation(magDelta: magDelta, location: cursorLoc, viewportSize: geo.size)
                    },
                    onPanDelta: { dx, dy in
                        applyClampedPan(dx: dx, dy: dy, viewportSize: geo.size)
                    },
                    onPinchInClose: {
                        if zoomScale <= 1.08 {
                            onCloseDetail()
                        } else {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                                zoomScale = 1.0
                                panOffset = .zero
                            }
                        }
                    },
                    onDoubleClickAtLocation: { _ in
                        onCloseDetail()
                    }
                )
                .frame(width: geo.size.width, height: geo.size.height)

                // 3. Face name tag pills (shown only when enabled and for named people)
                if viewModel.showPersonNameTagsInDetail && abs(swipeDragOffset) < 4 {
                    ForEach(item.faces.filter { !$0.isUnnamed }) { face in
                        let rect = face.normalizedSwiftUIRect
                        let tagX = (rect.midX - 0.5) * geo.size.width * zoomScale + geo.size.width / 2.0 + panOffset.width
                        let tagY = min(geo.size.height - 60, ((rect.maxY + 0.02) - 0.5) * geo.size.height * zoomScale + geo.size.height / 2.0 + panOffset.height)

                        Text(face.displayName)
                            .font(.system(size: 12, weight: .medium)) // ★ [UI SIZING: Detail View & HUD] Font size of face name tag pills in detail view (pt)
                            .foregroundStyle(.black.opacity(0.88))
                            .padding(.horizontal, 8)                  // ★ [UI SIZING: Detail View & HUD] Horizontal padding of face name tag pills
                            .padding(.vertical, 3)                    // ★ [UI SIZING: Detail View & HUD] Vertical padding of face name tag pills
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.92))
                                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                            )
                            .position(x: tagX, y: tagY)
                            .onTapGesture {
                                if let idx = viewModel.activeTabIndex {
                                    viewModel.navigateToScope(inTab: idx, scope: .person(name: face.displayName))
                                }
                            }
                    }
                }

                // 4. Draggable floating Info inspector panel
                if showInspector {
                    DraggableInspectorOverlayView(
                        item: item,
                        viewModel: viewModel,
                        onClose: { showInspector = false }
                    )
                }

                // 5. Draggable floating video playback HUD (shown only for video assets)
                if item.isVideo {
                    DraggableFloatingVideoHUD(
                        seekController: seekController,
                        isHoveringHUD: $isHoveringHUD,
                        onUserActivity: {
                            revealVideoHUDAndResetTimer()
                        }
                    )
                    .frame(width: 540) // ★ [UI SIZING: Detail View & HUD] Width of the floating video playback controller HUD (pt)
                    .position(
                        x: geo.size.width / 2.0 + controllerOffset.width,
                        y: geo.size.height - 96.0 + controllerOffset.height // ★ [UI SIZING: Detail View & HUD] Initial bottom offset of the floating video controller HUD (pt)
                    )
                    .opacity(showVideoControllerHUD ? 1.0 : 0.0)
                    .allowsHitTesting(showVideoControllerHUD)
                    .animation(.easeInOut(duration: 0.20), value: showVideoControllerHUD)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                revealVideoHUDAndResetTimer()
                                controllerOffset = CGSize(
                                    width: controllerDragStartOffset.width + value.translation.width,
                                    height: controllerDragStartOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                controllerDragStartOffset = controllerOffset
                                revealVideoHUDAndResetTimer()
                            }
                    )
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    revealVideoHUDAndResetTimer()
                case .ended:
                    videoHUDIdleTask?.cancel()
                    isHoveringHUD = false
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showVideoControllerHUD = false
                    }
                }
            }
        }
        .task(id: item.id) {
            zoomScale = 1.0
            panOffset = .zero
            swipeDragOffset = 0.0
            isAnimatingPageSnap = false
            prepareMediaAndPreloadNeighbors()
            if item.isVideo {
                installVideoMouseActivityMonitor()
                revealVideoHUDAndResetTimer()
            } else {
                removeVideoMouseActivityMonitor()
            }
            await viewModel.enrichAssetMetadata(for: item.id)
        }
        .onDisappear {
            videoHUDIdleTask?.cancel()
            removeVideoMouseActivityMonitor()
            seekController.stopAndCleanup()
        }
    }

    private func calculateFittedMediaSize(in viewportSize: CGSize) -> CGSize {
        let vw = max(1.0, viewportSize.width)
        let vh = max(1.0, viewportSize.height)
        let aspect = max(0.15, min(6.0, item.aspectRatio))
        let viewAspect = vw / vh
        if aspect > viewAspect {
            return CGSize(width: vw, height: vw / aspect)
        } else {
            return CGSize(width: vh * aspect, height: vh)
        }
    }

    private func clampedPanOffset(_ proposed: CGSize, scale: CGFloat, viewportSize: CGSize) -> CGSize {
        guard scale > 1.005 else { return .zero }
        let fitted = calculateFittedMediaSize(in: viewportSize)
        let scaledW = fitted.width * scale
        let scaledH = fitted.height * scale
        let maxX = max(0.0, (scaledW - viewportSize.width) / 2.0)
        let maxY = max(0.0, (scaledH - viewportSize.height) / 2.0)
        return CGSize(
            width: max(-maxX, min(maxX, proposed.width)),
            height: max(-maxY, min(maxY, proposed.height))
        )
    }

    private func applyZoomAtLocation(magDelta: CGFloat, location: CGPoint, viewportSize: CGSize) {
        let oldScale = zoomScale
        let newScale = max(1.0, min(6.0, oldScale * (1.0 + magDelta * 1.45)))
        guard abs(newScale - oldScale) > 0.0005 else { return }

        if newScale <= 1.01 {
            zoomScale = 1.0
            panOffset = .zero
            return
        }

        let center = CGPoint(x: viewportSize.width / 2.0, y: viewportSize.height / 2.0)
        let relX = location.x - center.x - panOffset.width
        let relY = location.y - center.y - panOffset.height
        let ratio = newScale / max(0.1, oldScale)
        let rawPan = CGSize(
            width: panOffset.width - relX * (ratio - 1.0),
            height: panOffset.height - relY * (ratio - 1.0)
        )
        zoomScale = newScale
        panOffset = clampedPanOffset(rawPan, scale: newScale, viewportSize: viewportSize)
    }

    private func applyClampedPan(dx: CGFloat, dy: CGFloat, viewportSize: CGSize) {
        guard zoomScale > 1.01 else { return }
        let rawPan = CGSize(width: panOffset.width + dx, height: panOffset.height + dy)
        panOffset = clampedPanOffset(rawPan, scale: zoomScale, viewportSize: viewportSize)
    }

    private func revealVideoHUDAndResetTimer() {
        guard item.isVideo else { return }
        if !showVideoControllerHUD {
            withAnimation(.easeInOut(duration: 0.16)) {
                showVideoControllerHUD = true
            }
        }
        videoHUDIdleTask?.cancel()
        videoHUDIdleTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                showVideoControllerHUD = false
            }
        }
    }

    private func installVideoMouseActivityMonitor() {
        guard videoMouseMonitorToken == nil else { return }
        videoMouseMonitorToken = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .mouseEntered, .mouseExited]) { event in
            guard item.isVideo else { return event }
            if let win = event.window ?? NSApplication.shared.keyWindow {
                let mouseScreen = NSEvent.mouseLocation
                if !win.frame.insetBy(dx: 2, dy: 2).contains(mouseScreen) {
                    videoHUDIdleTask?.cancel()
                    isHoveringHUD = false
                    if showVideoControllerHUD {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            showVideoControllerHUD = false
                        }
                    }
                    return event
                }
            }
            revealVideoHUDAndResetTimer()
            return event
        }
    }

    private func removeVideoMouseActivityMonitor() {
        if let token = videoMouseMonitorToken {
            NSEvent.removeMonitor(token)
            videoMouseMonitorToken = nil
        }
    }

    private func handleInteractiveDragChanged(_ rawDrag: CGFloat, pageWidth: CGFloat) {
        guard zoomScale <= 1.02, !isAnimatingPageSnap else { return }
        swipeDragOffset = clampedDragOffset(rawDrag, width: pageWidth)
    }

    private func clampedDragOffset(_ rawDrag: CGFloat, width: CGFloat) -> CGFloat {
        if rawDrag > 0 && prevItem == nil {
            return rawDrag * 0.18
        }
        if rawDrag < 0 && nextItem == nil {
            return rawDrag * 0.18
        }
        return max(-width, min(width, rawDrag))
    }

    private func completeInteractiveSwipe(finalX: CGFloat, pageWidth: CGFloat) {
        guard !isAnimatingPageSnap else { return }
        let threshold: CGFloat = max(36.0, pageWidth * 0.055)

        if finalX <= -threshold, nextItem != nil {
            isAnimatingPageSnap = true
            withAnimation(.interpolatingSpring(stiffness: 340, damping: 34)) {
                swipeDragOffset = -pageWidth
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    if let nextImg = nextImage {
                        prevImage = currentImage
                        currentImage = nextImg
                    }
                    swipeDragOffset = 0.0
                    isAnimatingPageSnap = false
                }
                onNavigateRelative(1)
            }
        } else if finalX >= threshold, prevItem != nil {
            isAnimatingPageSnap = true
            withAnimation(.interpolatingSpring(stiffness: 340, damping: 34)) {
                swipeDragOffset = pageWidth
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    if let prevImg = prevImage {
                        nextImage = currentImage
                        currentImage = prevImg
                    }
                    swipeDragOffset = 0.0
                    isAnimatingPageSnap = false
                }
                onNavigateRelative(-1)
            }
        } else {
            isAnimatingPageSnap = true
            withAnimation(.interpolatingSpring(stiffness: 380, damping: 36)) {
                swipeDragOffset = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                swipeDragOffset = 0.0
                isAnimatingPageSnap = false
            }
        }
    }

    private func prepareMediaAndPreloadNeighbors() {
        let curPH = viewModel.repository.phAsset(for: item.id)
        let curURL = viewModel.repository.localMediaURL(for: item.id)

        if let cached = viewModel.thumbnailCache.cachedHighResImage(for: item.id) {
            self.currentImage = cached
        }
        if item.isVideo {
            seekController.loadVideo(
                for: curPH,
                fallbackFileURL: curURL,
                fallbackDuration: item.duration,
                fallbackFPS: item.exif.fps
            )
        } else if !item.isGIF {
            _ = viewModel.thumbnailCache.requestHighResolutionImage(
                for: curPH,
                fallbackFileURL: curURL,
                assetID: item.id
            ) { img in
                if let img { self.currentImage = img }
            }
        }

        if let prev = prevItem {
            if let cachedPrev = viewModel.thumbnailCache.cachedHighResImage(for: prev.id) {
                self.prevImage = cachedPrev
            } else {
                _ = viewModel.thumbnailCache.requestHighResolutionImage(
                    for: viewModel.repository.phAsset(for: prev.id),
                    fallbackFileURL: viewModel.repository.localMediaURL(for: prev.id),
                    assetID: prev.id
                ) { img in
                    if let img { self.prevImage = img }
                }
            }
        } else {
            self.prevImage = nil
        }

        if let next = nextItem {
            if let cachedNext = viewModel.thumbnailCache.cachedHighResImage(for: next.id) {
                self.nextImage = cachedNext
            } else {
                _ = viewModel.thumbnailCache.requestHighResolutionImage(
                    for: viewModel.repository.phAsset(for: next.id),
                    fallbackFileURL: viewModel.repository.localMediaURL(for: next.id),
                    assetID: next.id
                ) { img in
                    if let img { self.nextImage = img }
                }
            }
        } else {
            self.nextImage = nil
        }
    }
}

private struct DraggableFloatingVideoHUD: View {
    @Bindable var seekController: SmoothVideoSeekController
    @Binding var isHoveringHUD: Bool
    var onUserActivity: () -> Void
    @State private var scrollMonitorToken: Any?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .help("Drag to move video controller")

                Button {
                    onUserActivity()
                    seekController.isMuted.toggle()
                    seekController.player.isMuted = seekController.isMuted
                } label: {
                    Image(systemName: seekController.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    onUserActivity()
                    seekController.stepBackward(seconds: 5.0)
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .buttonStyle(.plain)

                Button {
                    onUserActivity()
                    seekController.togglePlayPause()
                } label: {
                    Image(systemName: seekController.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)

                Button {
                    onUserActivity()
                    seekController.cycleFastForward()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13))
                        if seekController.playbackRate > 1.05 {
                            Text(String(format: "%.1fx", seekController.playbackRate))
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.accentColor, in: Capsule())
                        }
                    }
                    .foregroundStyle(.white.opacity(0.95))
                }
                .buttonStyle(.plain)

                Button {
                    onUserActivity()
                    seekController.stepForward(seconds: 10.0)
                } label: {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .buttonStyle(.plain)

                Spacer()

                Image(systemName: "pip.enter")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
            }

            HStack(spacing: 10) {
                Text(Self.formatTime(seekController.currentTimeSeconds))
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 48, alignment: .leading)

                Slider(
                    value: Binding(
                        get: { seekController.currentTimeSeconds },
                        set: {
                            onUserActivity()
                            seekController.scrub(toSeconds: $0)
                        }
                    ),
                    in: 0...max(0.1, seekController.durationSeconds)
                )
                .controlSize(.small)
                .tint(.white)

                let remaining = max(0, seekController.durationSeconds - seekController.currentTimeSeconds)
                Text("-" + Self.formatTime(remaining))
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 54, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.14, opacity: 0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isHoveringHUD ? Color.white.opacity(0.45) : Color.white.opacity(0.14),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.55), radius: 12, y: 4)
        )
        .onContinuousHover { phase in
            switch phase {
            case .active:
                isHoveringHUD = true
                onUserActivity()
            case .ended:
                isHoveringHUD = false
            }
        }
        .onAppear {
            installHUDScrollMonitorIfNeeded()
        }
        .onDisappear {
            removeHUDScrollMonitor()
        }
    }

    private func installHUDScrollMonitorIfNeeded() {
        guard scrollMonitorToken == nil else { return }
        scrollMonitorToken = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { event in
            guard isHoveringHUD else { return event }
            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY
            guard abs(dx) > abs(dy) * 0.75, abs(dx) > 0.05 else { return event }
            let effectiveDelta = event.isDirectionInvertedFromDevice ? -dx : dx
            onUserActivity()
            seekController.handleControllerTrackpadSwipe(deltaX: effectiveDelta)
            return nil
        }
    }

    private func removeHUDScrollMonitor() {
        if let token = scrollMonitorToken {
            NSEvent.removeMonitor(token)
            scrollMonitorToken = nil
        }
    }

    private static func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let total = Int(round(seconds))
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        }
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - 8. Draggable Floating Info Inspector Panel (Unified Key Face Avatars, Native Captions, 5-Column EXIF Bar & Mini-Map)

struct DraggableInspectorOverlayView: View {
    let item: PhotoAssetItem
    @Bindable var viewModel: PhotoWorkspaceViewModel
    var onClose: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var dragStartOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let panelWidth: CGFloat = 272.0 // ★ [UI SIZING: Info Inspector Panel] Width of the floating Info (i) inspector panel (pt)
            let defaultX = max(panelWidth / 2.0 + 16.0, geo.size.width - panelWidth / 2.0 - 38.0) // ★ [UI SIZING: Info Inspector Panel] Initial right margin of the floating Info (i) panel (pt)
            let defaultY = max(210.0, min(geo.size.height - 210.0, geo.size.height * 0.48))

            FloatingInspectorPanelView(
                item: item,
                viewModel: viewModel,
                onClose: onClose
            )
            .frame(width: panelWidth)
            .position(
                x: max(panelWidth / 2.0 + 8.0, min(geo.size.width - panelWidth / 2.0 - 8.0, defaultX + dragOffset.width)),
                y: max(150.0, min(geo.size.height - 150.0, defaultY + dragOffset.height))
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        viewModel.isDraggingInspector = true
                        dragOffset = CGSize(
                            width: dragStartOffset.width + value.translation.width,
                            height: dragStartOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        dragStartOffset = dragOffset
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            viewModel.isDraggingInspector = false
                        }
                    }
            )
        }
    }
}

struct FloatingInspectorPanelView: View {
    let item: PhotoAssetItem
    @Bindable var viewModel: PhotoWorkspaceViewModel
    var onClose: () -> Void

    @State private var editingTitle: String = ""
    @State private var editingCaption: String = ""

    private static let inspectorDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d, yyyy  HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { // ★ [UI SIZING: Info Inspector Panel] Vertical spacing between sections inside the Info panel (pt)
            // 1. Panel header (Close button, Info title, Favorite heart toggle)
            HStack {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13)) // ★ [UI SIZING: Info Inspector Panel] Close (x) button icon size (pt)
                        .foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.plain)

                Spacer()
                Text("Info")
                    .font(.system(size: 12.5, weight: .semibold)) // ★ [UI SIZING: Info Inspector Panel] Header title ("Info") font size (pt)
                    .foregroundStyle(.white.opacity(0.80))
                Spacer()

                Button {
                    viewModel.toggleFavorite(for: item.id)
                } label: {
                    Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 11))
                        .foregroundStyle(item.isFavorite ? .white : .secondary)
                }
                .buttonStyle(.plain)
            }

            // 2. Title, original filename, and creation timestamp
            VStack(alignment: .leading, spacing: 3) {
                TextField("Add a Title", text: $editingTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .onSubmit {
                        viewModel.updateCustomTitle(editingTitle, for: item.id)
                    }

                Text(item.originalFilename)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let date = item.creationDate {
                        Text(Self.inspectorDateFormatter.string(from: date))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Adjust...") {
                        viewModel.presentDateTimeEditSheet(for: [item.id])
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                }
            }

            Divider().overlay(Color.white.opacity(0.14))

            // 3. Camera, lens, resolution, codec/format badge, and 5-column EXIF bar
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.exif.cameraModel ?? "No Camera Info")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                        Text(item.exif.lensModel ?? "No Lens Info")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(item.formatBadgeTitle)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.88))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
                }

                HStack {
                    Text("\(item.pixelWidth) × \(item.pixelHeight)")
                    Spacer()
                    Text(item.exif.formattedFileSize)
                    if item.isVideo {
                        Spacer()
                        Text(String(format: "%.0f fps", item.exif.fps ?? 30))
                    }
                }
                .font(.system(size: 9.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.82))

                Divider().overlay(Color.white.opacity(0.12))

                // 5-column EXIF bar (ISO | mm | ev | f | s)
                HStack(spacing: 0) {
                    Text(item.exif.isoText)
                        .frame(maxWidth: .infinity)
                    Divider().frame(height: 11).overlay(Color.white.opacity(0.15))
                    Text(item.exif.focalLengthText)
                        .frame(maxWidth: .infinity)
                    Divider().frame(height: 11).overlay(Color.white.opacity(0.15))
                    Text(item.exif.evText)
                        .frame(maxWidth: .infinity)
                    Divider().frame(height: 11).overlay(Color.white.opacity(0.15))
                    Text(item.exif.apertureText)
                        .frame(maxWidth: .infinity)
                    Divider().frame(height: 11).overlay(Color.white.opacity(0.15))
                    Text(item.exif.shutterSpeedText)
                        .frame(maxWidth: .infinity)
                }
                .font(.system(size: 9, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
            .padding(7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )

            // 4. Caption field (displays native Photos.sqlite ZASSETDESCRIPTION.ZLONGDESCRIPTION captions and supports non-destructive editing)
            TextField("Add a Caption", text: $editingCaption, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 10.5))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1...4)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                .onSubmit {
                    viewModel.updateCustomCaption(editingCaption, for: item.id)
                }

            // 5. Keyword tag capsules (displays assigned tags cleanly)
            if !item.keywords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(item.keywords, id: \.self) { kw in
                            Text(kw)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.92))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(Color.white.opacity(0.14), in: Capsule())
                                .onTapGesture {
                                    if let idx = viewModel.activeTabIndex {
                                        viewModel.navigateToScope(inTab: idx, scope: .keyword(tag: kw))
                                    }
                                }
                        }
                    }
                }
            }

            // 6. Circular people avatars (unified with each person's key face thumbnail)
            let namedFaces = item.faces.filter { !$0.isUnnamed }
            if !namedFaces.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(namedFaces) { face in
                            FaceCircleAvatarButton(
                                item: item,
                                face: face,
                                viewModel: viewModel
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            // 7. 2D location pin mini-map
            if item.hasLocation, let lat = item.latitude, let lon = item.longitude {
                InspectorFlatPinMapView(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    locationTitle: item.locationName
                )
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.15, green: 0.15, blue: 0.16, opacity: 0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.55), radius: 12, y: 4)
        )
        .onAppear {
            editingTitle = item.title ?? ""
            editingCaption = item.caption ?? ""
        }
        .onChange(of: item.id) { _, _ in
            editingTitle = item.title ?? ""
            editingCaption = item.caption ?? ""
        }
        .onChange(of: item.caption) { _, newCap in
            editingCaption = newCap ?? ""
        }
    }
}

private struct InspectorFlatPinMapView: View {
    let coordinate: CLLocationCoordinate2D
    let locationTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            InspectorMKMapRepresentable(coordinate: coordinate)
                .frame(height: 124) // ★ [UI SIZING: Info Inspector Panel] Height of the location mini-map at the bottom of the Info panel (pt)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                )

            Text(locationTitle ?? String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude))
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct InspectorMKMapRepresentable: NSViewRepresentable {
    let coordinate: CLLocationCoordinate2D

    func makeNSView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.isPitchEnabled = false
        map.isRotateEnabled = false
        map.showsCompass = false
        map.showsZoomControls = false
        map.appearance = NSAppearance(named: .darkAqua)
        return map
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)
        let pin = MKPointAnnotation()
        pin.coordinate = coordinate
        mapView.addAnnotation(pin)
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
        )
        mapView.setRegion(region, animated: false)
    }
}

/// Circular person avatar in the Info panel (uses the person's key face thumbnail)
private struct FaceCircleAvatarButton: View {
    let item: PhotoAssetItem
    let face: DetectedFaceInfo
    @Bindable var viewModel: PhotoWorkspaceViewModel

    @State private var avatarImg: NSImage?

    private var personEntry: PhotoWorkspaceViewModel.PersonSummaryEntry? {
        viewModel.peopleEntries.first(where: { $0.name == face.displayName })
    }

    var body: some View {
        let targetAssetID = personEntry?.keyAssetID ?? item.id
        let targetFace = personEntry?.keyFace ?? face

        ZStack {
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 48, height: 48) // ★ [UI SIZING: Info Inspector Panel] Diameter of circular person avatars inside the Info panel (pt)

            if let avatarImg {
                Image(nsImage: avatarImg)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48) // ★ [UI SIZING: Info Inspector Panel] Avatar image diameter (keep identical to the Circle frame above)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
        }
        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
        .contentShape(Circle())
        .help(face.displayName)
        .onTapGesture {
            if let idx = viewModel.activeTabIndex {
                viewModel.navigateToScope(inTab: idx, scope: .person(name: face.displayName))
            }
        }
        .task(id: "\(face.displayName)_\(targetAssetID)_\(targetFace.id)") {
            let ph = viewModel.repository.phAsset(for: targetAssetID)
            let url = viewModel.repository.localMediaURL(for: targetAssetID)
            viewModel.thumbnailCache.requestFaceAvatar(
                for: ph,
                fallbackFileURL: url,
                face: targetFace,
                portraitRectangular: false
            ) { img in
                self.avatarImg = img
            }
        }
    }
}

// MARK: - 9. MapKit View with Crash-Proof Viewport Spatial Grid Clustering

final class PhotoClusterNodeAnnotation: NSObject, MKAnnotation {
    let clusterKey: String
    let representativeItem: PhotoAssetItem
    let memberItems: [PhotoAssetItem]
    let coordinate: CLLocationCoordinate2D

    init(clusterKey: String, representativeItem: PhotoAssetItem, memberItems: [PhotoAssetItem], coordinate: CLLocationCoordinate2D) {
        self.clusterKey = clusterKey
        self.representativeItem = representativeItem
        self.memberItems = memberItems
        self.coordinate = coordinate
        super.init()
    }
}

final class PhotoBubbleAnnotationView: MKAnnotationView {
    static let reuseID = "PhotoBubbleAnnotationView"

    private let cardShapeLayer = CAShapeLayer()
    private let thumbnailImageView = NSImageView()
    private let countBadgeContainer = NSView()
    private let countLabel = NSTextField(labelWithString: "")
    private var currentRequestID: PHImageRequestID?
    private weak var activeImageManager: PHCachingImageManager?
    private var currentLoadedAssetID: String?

    private let cardSize = CGSize(width: 62.0, height: 62.0) // ★ [UI SIZING: Map Annotation Pins] Width & height of photo thumbnail bubble pins on the map (pt)
    private let tailHeight: CGFloat = 7.0                    // ★ [UI SIZING: Map Annotation Pins] Height of the bottom pointer triangle on map pins (pt)
    private let borderInset: CGFloat = 3.0                   // ★ [UI SIZING: Map Annotation Pins] White border thickness of map thumbnail pins (pt)

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupLayers()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupLayers()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        if let reqID = currentRequestID, reqID != PHInvalidImageRequestID {
            activeImageManager?.cancelImageRequest(reqID)
            currentRequestID = nil
        }
        currentLoadedAssetID = nil
        thumbnailImageView.image = nil
        countBadgeContainer.isHidden = true
    }

    private func setupLayers() {
        let totalHeight = cardSize.height + tailHeight
        frame = CGRect(x: 0, y: 0, width: cardSize.width, height: totalHeight)
        centerOffset = CGPoint(x: 0, y: -totalHeight / 2.0)
        wantsLayer = true
        layer?.masksToBounds = false

        cardShapeLayer.fillColor = NSColor.white.cgColor
        cardShapeLayer.strokeColor = NSColor.black.withAlphaComponent(0.22).cgColor
        cardShapeLayer.lineWidth = 1.0
        cardShapeLayer.shadowColor = NSColor.black.cgColor
        cardShapeLayer.shadowOpacity = 0.42
        cardShapeLayer.shadowOffset = CGSize(width: 0, height: -2)
        cardShapeLayer.shadowRadius = 5.0

        let path = CGMutablePath()
        let cardRect = CGRect(x: 0, y: tailHeight, width: cardSize.width, height: cardSize.height)
        path.addRoundedRect(in: cardRect, cornerWidth: 10.0, cornerHeight: 10.0)
        let midX = cardSize.width / 2.0
        path.move(to: CGPoint(x: midX - 6.0, y: tailHeight))
        path.addLine(to: CGPoint(x: midX, y: 0))
        path.addLine(to: CGPoint(x: midX + 6.0, y: tailHeight))
        path.closeSubpath()
        cardShapeLayer.path = path
        layer?.addSublayer(cardShapeLayer)

        thumbnailImageView.frame = CGRect(
            x: borderInset,
            y: tailHeight + borderInset,
            width: cardSize.width - borderInset * 2,
            height: cardSize.height - borderInset * 2
        )
        thumbnailImageView.wantsLayer = true
        thumbnailImageView.layer?.cornerRadius = 8.0
        thumbnailImageView.layer?.masksToBounds = true
        thumbnailImageView.layer?.backgroundColor = NSColor.darkGray.cgColor
        thumbnailImageView.imageScaling = .scaleAxesIndependently
        addSubview(thumbnailImageView)

        countBadgeContainer.wantsLayer = true
        countBadgeContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.78).cgColor
        countBadgeContainer.layer?.cornerRadius = 4.5
        countBadgeContainer.layer?.masksToBounds = true
        countBadgeContainer.isHidden = true

        countLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .bold)
        countLabel.textColor = .white
        countLabel.alignment = .center
        countBadgeContainer.addSubview(countLabel)
        addSubview(countBadgeContainer)
    }

    func configure(with cluster: PhotoClusterNodeAnnotation, repository: HybridPhotoRepository, imageManager: PHCachingImageManager) {
        self.activeImageManager = imageManager
        let count = cluster.memberItems.count
        if count > 1 {
            countBadgeContainer.isHidden = false
            countLabel.stringValue = "\(count)"
            countLabel.sizeToFit()
            let badgeW = max(20.0, countLabel.frame.width + 9.0)
            let badgeH: CGFloat = 16.0
            countBadgeContainer.frame = CGRect(x: borderInset + 4.0, y: tailHeight + borderInset + 4.0, width: badgeW, height: badgeH)
            countLabel.frame = CGRect(x: (badgeW - countLabel.frame.width) / 2.0, y: (badgeH - countLabel.frame.height) / 2.0 - 0.5, width: countLabel.frame.width, height: countLabel.frame.height)
        } else {
            countBadgeContainer.isHidden = true
        }

        let targetID = cluster.representativeItem.id
        guard currentLoadedAssetID != targetID else { return }
        currentLoadedAssetID = targetID

        if let phAsset = repository.phAsset(for: targetID) {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = false
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast

            currentRequestID = imageManager.requestImage(
                for: phAsset,
                targetSize: CGSize(width: 140, height: 140),
                contentMode: .aspectFill,
                options: options
            ) { [weak self] image, _ in
                guard let image else { return }
                Task { @MainActor [weak self] in
                    guard let self, self.currentLoadedAssetID == targetID else { return }
                    self.thumbnailImageView.image = image
                }
            }
        } else if let localURL = repository.localMediaURL(for: targetID) {
            Task.detached(priority: .userInitiated) {
                guard let src = CGImageSourceCreateWithURL(localURL as CFURL, nil) else { return }
                let opts: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 140
                ]
                guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return }
                let nsImg = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                await MainActor.run { [weak self] in
                    guard let self, self.currentLoadedAssetID == targetID else { return }
                    self.thumbnailImageView.image = nsImg
                }
            }
        }
    }
}

struct PhotoClusterMapView: NSViewRepresentable {
    let items: [PhotoAssetItem]
    let mapStyle: MapDisplayStyle
    let zoomLevel: Double
    let repository: HybridPhotoRepository
    var onOpenAssetDetail: ((String) -> Void)?

    private static let sharedMapImageManager: PHCachingImageManager = {
        let mgr = PHCachingImageManager()
        mgr.allowsCachingHighQualityImages = false
        return mgr
    }()

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        mapView.showsCompass = true
        mapView.showsZoomControls = true
        mapView.appearance = NSAppearance(named: .darkAqua)
        mapView.register(PhotoBubbleAnnotationView.self, forAnnotationViewWithReuseIdentifier: PhotoBubbleAnnotationView.reuseID)

        let center = CLLocationCoordinate2D(latitude: 35.68, longitude: 136.90)
        let span = MKCoordinateSpan(latitudeDelta: 18.0, longitudeDelta: 24.0)
        mapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: false)
        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        let targetType: MKMapType = (mapStyle == .satellite) ? .hybridFlyover : .standard
        if mapView.mapType != targetType {
            mapView.mapType = targetType
        }
        context.coordinator.applySliderZoomIfNeeded(on: mapView, zoomLevel: zoomLevel)
        context.coordinator.updateSourceItems(items, on: mapView)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: PhotoClusterMapView
        private var geoItems: [PhotoAssetItem] = []
        private var lastItemCount: Int = -1
        private var lastFirstID: String = ""
        private var lastAppliedZoomLevel: Double = -1.0
        private var activeClusterKeys: Set<String> = []

        init(parent: PhotoClusterMapView) {
            self.parent = parent
        }

        func applySliderZoomIfNeeded(on mapView: MKMapView, zoomLevel: Double) {
            guard abs(zoomLevel - lastAppliedZoomLevel) > 0.05 else { return }
            lastAppliedZoomLevel = zoomLevel
            let spanDelta = max(0.005, min(90.0, 65.0 * pow(0.55, zoomLevel - 1.0)))
            let region = MKCoordinateRegion(
                center: mapView.region.center,
                span: MKCoordinateSpan(latitudeDelta: spanDelta, longitudeDelta: spanDelta * 1.25)
            )
            mapView.setRegion(region, animated: true)
        }

        func updateSourceItems(_ allItems: [PhotoAssetItem], on mapView: MKMapView) {
            let filtered = allItems.filter(\.hasLocation)
            let firstID = filtered.first?.id ?? ""
            guard filtered.count != lastItemCount || firstID != lastFirstID else { return }
            lastItemCount = filtered.count
            lastFirstID = firstID
            geoItems = filtered
            activeClusterKeys.removeAll()
            reclusterVisibleRegion(on: mapView)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            reclusterVisibleRegion(on: mapView)
        }

        private func reclusterVisibleRegion(on mapView: MKMapView) {
            let region = mapView.region
            let latSpan = max(0.0001, region.span.latitudeDelta)
            let lonSpan = max(0.0001, region.span.longitudeDelta)
            let cellLat = latSpan / 7.5
            let cellLon = lonSpan / 9.5

            let minLat = region.center.latitude - latSpan * 0.85
            let maxLat = region.center.latitude + latSpan * 0.85
            let minLon = region.center.longitude - lonSpan * 0.85
            let maxLon = region.center.longitude + lonSpan * 0.85

            var buckets: [String: [PhotoAssetItem]] = [:]
            for item in geoItems {
                guard let lat = item.latitude, let lon = item.longitude,
                      lat >= minLat, lat <= maxLat,
                      lon >= minLon, lon <= maxLon else { continue }
                let gx = Int(floor((lon + 180.0) / cellLon))
                let gy = Int(floor((lat + 90.0) / cellLat))
                let key = "\(gx)_\(gy)"
                buckets[key, default: []].append(item)
            }

            var newAnnotations: [PhotoClusterNodeAnnotation] = []
            var newKeys: Set<String> = []

            for (key, members) in buckets {
                guard let rep = members.first(where: \.isFavorite) ?? members.last,
                      let lat = rep.latitude, let lon = rep.longitude else { continue }
                let clusterID = "\(key)_\(rep.id)_\(members.count)"
                newKeys.insert(clusterID)
                newAnnotations.append(
                    PhotoClusterNodeAnnotation(
                        clusterKey: clusterID,
                        representativeItem: rep,
                        memberItems: members,
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    )
                )
            }

            guard newKeys != activeClusterKeys else { return }
            activeClusterKeys = newKeys
            let existing = mapView.annotations.filter { !($0 is MKUserLocation) }
            mapView.removeAnnotations(existing)
            mapView.addAnnotations(newAnnotations)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            guard let cluster = annotation as? PhotoClusterNodeAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: PhotoBubbleAnnotationView.reuseID,
                for: cluster
            ) as? PhotoBubbleAnnotationView ?? PhotoBubbleAnnotationView(
                annotation: cluster,
                reuseIdentifier: PhotoBubbleAnnotationView.reuseID
            )
            view.configure(with: cluster, repository: parent.repository, imageManager: PhotoClusterMapView.sharedMapImageManager)
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            mapView.deselectAnnotation(view.annotation, animated: false)
            guard let cluster = view.annotation as? PhotoClusterNodeAnnotation else { return }
            if cluster.memberItems.count > 1 && mapView.region.span.latitudeDelta > 0.004 {
                let nextSpan = MKCoordinateSpan(
                    latitudeDelta: mapView.region.span.latitudeDelta * 0.42,
                    longitudeDelta: mapView.region.span.longitudeDelta * 0.42
                )
                mapView.setRegion(MKCoordinateRegion(center: cluster.coordinate, span: nextSpan), animated: true)
            } else {
                parent.onOpenAssetDetail?(cluster.representativeItem.id)
            }
        }
    }
}

// MARK: - 10. Workspace ViewModel (ZPERSON.ZKEYFACE & ZGENERICALBUM.ZKEYASSET Support + O(1) Caching)

@MainActor
@Observable
final class PhotoWorkspaceViewModel {
    private static let persistenceKey = "PhotoVaultMac.PersistedWorkspaceSnapshot.v13"
    private static let legacyPersistenceKeyV12 = "PhotoVaultMac.PersistedWorkspaceSnapshot.v12"
    private static let legacyPersistenceKeyV8 = "PhotoVaultMac.PersistedWorkspaceSnapshot.v8"

    var authorizationStatus: PHAuthorizationStatus = .notDetermined
    var allItems: [PhotoAssetItem] = []
    var systemAlbumTree: [AlbumTreeNode] = []

    struct PersonSummaryEntry: Identifiable, Hashable {
        var id: String { name }
        let name: String
        let isUnnamed: Bool
        let isFavorite: Bool
        let count: Int
        let latestCreationDate: Date?
        let keyAssetID: String
        let keyFace: DetectedFaceInfo?
    }
    var peopleEntries: [PersonSummaryEntry] = []

    var isLoading: Bool = false
    var isDraggingInspector: Bool = false

    // Browser tabs, sidebar expansion state, and resizable sidebar width
    var tabs: [BrowserTabState]
    var activeTabID: UUID
    var expandedSidebarSections: Set<String> = ["mediaTypes", "albums"]
    var expandedFolderIDs: Set<String> = []
    var sidebarWidth: CGFloat = 255.0 // ★ [UI SIZING: Sidebar] Initial width of the left navigation sidebar (pt)

    // People sort order and detail view face tag visibility
    var peopleSortOrder: PeopleSortOrder = .countDesc
    var showPersonNameTagsInDetail: Bool = true
    var pendingScrollToAssetID: String? = nil

    // Modal sheet states (⌘K Keyword Manager, Smart Album editor, Album/Folder creators, Batch Date/Time editor)
    var showTagManagerSheet: Bool = false
    var showSmartAlbumSheet: Bool = false
    var editingSmartAlbum: SmartAlbumDefinition? = nil
    var showNewAlbumSheet: Bool = false
    var showNewFolderSheet: Bool = false
    var pendingNewAlbumParentSystemFolderID: String? = nil
    var pendingNewAlbumParentCustomFolderID: UUID? = nil

    // Date/Time adjustment sheet state (single & multi-selection batch shift)
    var showDateTimeEditSheet: Bool = false
    var dateTimeEditTargetAssetIDs: [String] = []

    // Persisted non-destructive overlay metadata (never modifies the original Photos library)
    var smartAlbums: [SmartAlbumDefinition] = []
    var customAlbums: [CustomAlbumDefinition] = []
    var customFolders: [CustomFolderDefinition] = []
    var allRegisteredTags: [String] = ["Travel", "Family", "Portrait", "Favorite", "Landscape", "Work"]
    var assetTagsByID: [String: [String]] = [:]
    var favoriteOverridesByID: [String: Bool] = [:]
    var hiddenOverridesByID: [String: Bool] = [:]
    var deletedOverridesByID: [String: Bool] = [:]
    var customTitlesByID: [String: String] = [:]
    var customCaptionsByID: [String: String] = [:]
    var customCreationDatesByID: [String: Date] = [:]
    var recentlyViewedIDs: [String] = []
    var personKeyPhotoByPersonName: [String: String] = [:]
    var albumKeyPhotoByAlbumID: [String: String] = [:]
    var renamedPeopleMap: [String: String] = [:]
    var manualFacesByAssetID: [String: [DetectedFaceInfo]] = [:]
    var favoritePeopleByName: [String: Bool] = [:]
    var customLibraryPath: String? = nil

    // High-speed scrolling, 2,000-item page slicing, and year overview card caches
    static let maxItemsPerPage: Int = 2000 // ★ [UI SIZING: Page Capacity] Maximum number of assets displayed per page (e.g. 1000 or 2000)

    static func formatMediaCountSummary(photoCount: Int, videoCount: Int) -> String {
        if photoCount > 0 && videoCount > 0 {
            return "\(photoCount) \(photoCount == 1 ? "Photo" : "Photos"), \(videoCount) \(videoCount == 1 ? "Video" : "Videos")"
        } else if photoCount > 0 {
            return "\(photoCount) \(photoCount == 1 ? "Photo" : "Photos")"
        } else if videoCount > 0 {
            return "\(videoCount) \(videoCount == 1 ? "Video" : "Videos")"
        } else {
            return ""
        }
    }

    struct LibraryYearBucket: Identifiable, Hashable {
        let id: String          // e.g. "2024" or "1970~79"
        let title: String       // e.g. "2024" or "1970–79"
        let assets: [PhotoAssetItem]
        let keyAsset: PhotoAssetItem?
        var count: Int { assets.count }
    }

    struct PagedGridSlice {
        let pageItems: [PhotoAssetItem]
        let totalCount: Int
        let totalPages: Int
        let safePageIndex: Int
        let pagePhotoCount: Int
        let pageVideoCount: Int
        let activeBucketTitle: String?
    }

    private var filterCacheRevision: Int = 0
    @ObservationIgnored private var cachedFilteredItemsByTabID: [UUID: (key: String, items: [PhotoAssetItem])] = [:]
    @ObservationIgnored private var cachedLibraryBucketsByKey: [String: [LibraryYearBucket]] = [:]
    @ObservationIgnored private var cachedPagedSliceByTabID: [UUID: (key: String, slice: PagedGridSlice)] = [:]
    @ObservationIgnored private var albumAssetIDsByNameOrUUIDCache: [String: Set<String>] = [:]
    @ObservationIgnored private var itemByIDMap: [String: PhotoAssetItem] = [:]

    let repository = HybridPhotoRepository()
    let thumbnailCache = ThumbnailCacheController()
    private let geocoder = CLGeocoder()
    private var geocodedCache: [String: String] = [:]
    private var enrichedAssetIDs: Set<String> = []

    init() {
        let defaultTab = BrowserTabState(filterScope: .library)
        self.tabs = [defaultTab]
        self.activeTabID = defaultTab.id
        restoreWorkspaceState()
    }

    var activeTabIndex: Int? {
        tabs.firstIndex(where: { $0.id == activeTabID })
    }

    func invalidateFilterCache() {
        filterCacheRevision &+= 1
        cachedFilteredItemsByTabID.removeAll(keepingCapacity: true)
        cachedLibraryBucketsByKey.removeAll(keepingCapacity: true)
        cachedPagedSliceByTabID.removeAll(keepingCapacity: true)
    }

    // MARK: - Persistence (Save & Restore on Launch)

    func saveWorkspaceState() {
        let snapshot = PersistedWorkspaceSnapshot(
            tabs: tabs,
            activeTabID: activeTabID,
            expandedSidebarSections: expandedSidebarSections,
            expandedFolderIDs: expandedFolderIDs,
            smartAlbums: smartAlbums,
            customAlbums: customAlbums,
            customFolders: customFolders,
            allRegisteredTags: allRegisteredTags,
            assetTagsByID: assetTagsByID,
            favoriteOverridesByID: favoriteOverridesByID,
            hiddenOverridesByID: hiddenOverridesByID,
            deletedOverridesByID: deletedOverridesByID,
            customTitlesByID: customTitlesByID,
            customCaptionsByID: customCaptionsByID,
            customCreationDatesByID: customCreationDatesByID,
            personKeyPhotoByPersonName: personKeyPhotoByPersonName,
            albumKeyPhotoByAlbumID: albumKeyPhotoByAlbumID,
            renamedPeopleMap: renamedPeopleMap,
            manualFacesByAssetID: manualFacesByAssetID,
            favoritePeopleByName: favoritePeopleByName,
            customLibraryPath: customLibraryPath,
            sidebarWidth: Double(sidebarWidth),
            peopleSortOrder: peopleSortOrder,
            showPersonNameTagsInDetail: showPersonNameTagsInDetail
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.persistenceKey)
        }
    }

    func restoreWorkspaceState() {
        let dummySmartAlbumNames: Set<String> = ["お気に入り & 撮影地あり", "動画コレクション", "Favorites with Location", "Video Collection"]

        let rawData = UserDefaults.standard.data(forKey: Self.persistenceKey)
            ?? UserDefaults.standard.data(forKey: Self.legacyPersistenceKeyV12)
            ?? UserDefaults.standard.data(forKey: Self.legacyPersistenceKeyV8)

        if let data = rawData,
           let snapshot = try? JSONDecoder().decode(PersistedWorkspaceSnapshot.self, from: data) {
            if !snapshot.tabs.isEmpty {
                self.tabs = snapshot.tabs
                if snapshot.tabs.contains(where: { $0.id == snapshot.activeTabID }) {
                    self.activeTabID = snapshot.activeTabID
                } else if let first = snapshot.tabs.first {
                    self.activeTabID = first.id
                }
            }
            self.expandedSidebarSections = snapshot.expandedSidebarSections.subtracting(["smartAlbums", "utilities"])
            self.expandedFolderIDs = snapshot.expandedFolderIDs
            self.smartAlbums = snapshot.smartAlbums.filter { !dummySmartAlbumNames.contains($0.name) }
            self.customAlbums = snapshot.customAlbums
            self.customFolders = snapshot.customFolders
            self.allRegisteredTags = snapshot.allRegisteredTags
            self.assetTagsByID = snapshot.assetTagsByID
            self.favoriteOverridesByID = snapshot.favoriteOverridesByID
            self.hiddenOverridesByID = snapshot.hiddenOverridesByID
            self.deletedOverridesByID = snapshot.deletedOverridesByID
            self.customTitlesByID = snapshot.customTitlesByID
            self.customCaptionsByID = snapshot.customCaptionsByID
            self.customCreationDatesByID = snapshot.customCreationDatesByID
            self.personKeyPhotoByPersonName = snapshot.personKeyPhotoByPersonName
            self.albumKeyPhotoByAlbumID = snapshot.albumKeyPhotoByAlbumID
            self.renamedPeopleMap = snapshot.renamedPeopleMap
            self.manualFacesByAssetID = snapshot.manualFacesByAssetID
            self.favoritePeopleByName = snapshot.favoritePeopleByName ?? [:]
            self.customLibraryPath = snapshot.customLibraryPath
            if let sw = snapshot.sidebarWidth {
                self.sidebarWidth = CGFloat(max(170.0, min(380.0, sw)))
            }
            if let sortOrder = snapshot.peopleSortOrder {
                self.peopleSortOrder = sortOrder
            }
            if let showTags = snapshot.showPersonNameTagsInDetail {
                self.showPersonNameTagsInDetail = showTags
            }
        }
    }

    // MARK: - Library Loading & Menu Bar File -> Open Photo Library (`⌘O`)

    func initializeLibrary() async {
        isLoading = true
        authorizationStatus = await repository.requestAuthorization()
        if let customPath = customLibraryPath, FileManager.default.fileExists(atPath: customPath) {
            await reloadLibrary(customSQLiteURL: URL(fileURLWithPath: customPath))
        } else {
            guard authorizationStatus == .authorized || authorizationStatus == .limited else {
                isLoading = false
                return
            }
            await reloadLibrary(customSQLiteURL: nil)
        }
    }

    func selectPhotosLibraryPackageViaPanel() {
        let panel = NSOpenPanel()
        panel.title = "Select Photo Library (.photoslibrary) or Photos.sqlite"
        panel.message = "The selected photo library is opened strictly in read-only mode (your original library is never modified)."
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false

        if panel.runModal() == .OK, let selectedURL = panel.url {
            let dbURL: URL
            if selectedURL.lastPathComponent == "Photos.sqlite" {
                dbURL = selectedURL
            } else {
                dbURL = selectedURL
                    .appendingPathComponent("database", isDirectory: true)
                    .appendingPathComponent("Photos.sqlite", isDirectory: false)
            }
            customLibraryPath = dbURL.path
            saveWorkspaceState()
            Task {
                await reloadLibrary(customSQLiteURL: dbURL)
            }
        }
    }

    func switchToDefaultSystemPhotoLibrary() {
        customLibraryPath = nil
        saveWorkspaceState()
        Task {
            await reloadLibrary(customSQLiteURL: nil)
        }
    }

    func reloadLibrary(customSQLiteURL: URL?) async {
        isLoading = true
        let result = await repository.loadLibrary(sqliteURL: customSQLiteURL)
        self.systemAlbumTree = result.albumTree

        var allFolderIDs: Set<String> = []
        func collectFolders(_ nodes: [AlbumTreeNode]) {
            for n in nodes where n.isFolder {
                allFolderIDs.insert(n.id)
                collectFolders(n.children)
            }
        }
        collectFolders(result.albumTree)
        for cf in customFolders {
            allFolderIDs.insert(cf.id.uuidString)
        }
        self.expandedFolderIDs.formUnion(allFolderIDs)
        self.expandedSidebarSections.insert("albums")

        var albumIndex: [String: Set<String>] = [:]
        func indexAlbums(_ nodes: [AlbumTreeNode]) {
            for n in nodes {
                if !n.assetLocalIdentifiers.isEmpty {
                    let s = Set(n.assetLocalIdentifiers)
                    albumIndex[n.title.lowercased(), default: []].formUnion(s)
                    albumIndex[n.uuid.lowercased(), default: []].formUnion(s)
                    albumIndex[n.id.lowercased(), default: []].formUnion(s)
                }
                indexAlbums(n.children)
            }
        }
        indexAlbums(result.albumTree)
        self.albumAssetIDsByNameOrUUIDCache = albumIndex

        var folderPersonByAssetID: [String: [String]] = [:]
        for node in result.albumTree where node.isFolder {
            let folderTitle = node.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if folderTitle == "人" || folderTitle == "people" || folderTitle == "ピープル" {
                for childAlbum in node.children where !childAlbum.isFolder {
                    let personName = childAlbum.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !personName.isEmpty, !personName.hasPrefix("Untitled"), !personName.hasPrefix("名称未設定") else { continue }
                    for assetID in childAlbum.assetLocalIdentifiers {
                        folderPersonByAssetID[assetID, default: []].append(personName)
                    }
                }
            }
        }

        var mergedItems = result.items
        for i in mergedItems.indices {
            let id = mergedItems[i].id
            if let fav = favoriteOverridesByID[id] {
                mergedItems[i].isFavorite = fav
            }
            if let hid = hiddenOverridesByID[id] {
                mergedItems[i].isHidden = hid
            }
            if let customTitle = customTitlesByID[id], !customTitle.isEmpty {
                mergedItems[i].title = customTitle
            }
            // Prefer in-app edited caption if present; otherwise preserve the native Photos.sqlite (ZASSETDESCRIPTION) caption
            if let customCaption = customCaptionsByID[id], !customCaption.isEmpty {
                mergedItems[i].caption = customCaption
            }
            if let customDate = customCreationDatesByID[id] {
                mergedItems[i].creationDate = customDate
            }
            if let savedTags = assetTagsByID[id] {
                let combined = Array(Set(mergedItems[i].keywords + savedTags)).sorted()
                mergedItems[i].keywords = combined
            }
            if let manualFaces = manualFacesByAssetID[id], !manualFaces.isEmpty {
                mergedItems[i].faces = manualFaces
            }

            if let personNames = folderPersonByAssetID[id] {
                for pName in personNames {
                    if !mergedItems[i].faces.contains(where: { $0.displayName == pName }) {
                        if let unnamedIdx = mergedItems[i].faces.firstIndex(where: { $0.isUnnamed }) {
                            mergedItems[i].faces[unnamedIdx].displayName = pName
                        } else {
                            mergedItems[i].faces.append(
                                DetectedFaceInfo(
                                    id: "\(id)_folderperson_\(pName)",
                                    personUUID: pName,
                                    displayName: pName,
                                    fullName: pName,
                                    centerX: 0.5,
                                    centerY: 0.58,
                                    size: 0.35,
                                    qualityScore: 0.9,
                                    isFavoritePerson: false,
                                    isKeyFaceInSQLite: false
                                )
                            )
                        }
                    }
                }
            }

            for fIdx in mergedItems[i].faces.indices {
                let origName = mergedItems[i].faces[fIdx].displayName
                if let renamed = renamedPeopleMap[origName] {
                    mergedItems[i].faces[fIdx].displayName = renamed
                }
            }
        }

        mergedItems.sort { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        self.allItems = mergedItems

        var idLookup: [String: PhotoAssetItem] = [:]
        idLookup.reserveCapacity(mergedItems.count)
        for item in mergedItems {
            idLookup[item.id] = item
        }
        self.itemByIDMap = idLookup

        let mergedTags = Set(allRegisteredTags).union(result.allKeywords)
        self.allRegisteredTags = mergedTags.sorted()

        invalidateFilterCache()
        rebuildPeopleEntries()
        isLoading = false
    }

    /// Prioritize ZPERSON.ZKEYFACE (`face.isKeyFaceInSQLite == true`) when selecting a person's key thumbnail
    func rebuildPeopleEntries() {
        var faceGroup: [String: (count: Int, latestDate: Date?, bestAssetID: String, bestFace: DetectedFaceInfo?, bestScore: Double, isFavorite: Bool)] = [:]

        for item in allItems where !item.isTrashed && !item.isHidden {
            let itemDate = item.creationDate
            for face in item.faces {
                let name = face.displayName
                guard !face.isUnnamed else { continue }
                // Grant +10000.0 priority score to the key face designated by ZPERSON.ZKEYFACE in macOS Photos
                let keyFaceBonus: Double = face.isKeyFaceInSQLite ? 10_000.0 : 0.0
                let score = keyFaceBonus + face.qualityScore + (item.isFavorite ? 0.5 : 0.0)
                let dbFav = face.isFavoritePerson
                if let existing = faceGroup[name] {
                    let useNewBest = score > existing.bestScore
                    let maxDate: Date?
                    if let d1 = existing.latestDate, let d2 = itemDate {
                        maxDate = max(d1, d2)
                    } else {
                        maxDate = existing.latestDate ?? itemDate
                    }
                    faceGroup[name] = (
                        count: existing.count + 1,
                        latestDate: maxDate,
                        bestAssetID: useNewBest ? item.id : existing.bestAssetID,
                        bestFace: useNewBest ? face : existing.bestFace,
                        bestScore: max(score, existing.bestScore),
                        isFavorite: existing.isFavorite || dbFav
                    )
                } else {
                    faceGroup[name] = (
                        count: 1,
                        latestDate: itemDate,
                        bestAssetID: item.id,
                        bestFace: face,
                        bestScore: score,
                        isFavorite: dbFav
                    )
                }
            }
        }

        var entries: [PersonSummaryEntry] = []
        for (name, info) in faceGroup {
            let customKeyID = personKeyPhotoByPersonName[name] ?? info.bestAssetID
            let customFace = itemByIDMap[customKeyID]?.faces.first(where: { $0.displayName == name }) ?? info.bestFace
            let effectiveFavorite = favoritePeopleByName[name] ?? info.isFavorite
            entries.append(
                PersonSummaryEntry(
                    name: name,
                    isUnnamed: false,
                    isFavorite: effectiveFavorite,
                    count: info.count,
                    latestCreationDate: info.latestDate,
                    keyAssetID: customKeyID,
                    keyFace: customFace
                )
            )
        }

        let sortMode = self.peopleSortOrder
        entries.sort { a, b in
            if a.isFavorite != b.isFavorite { return a.isFavorite && !b.isFavorite }
            switch sortMode {
            case .countDesc:
                if a.count != b.count { return a.count > b.count }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .nameAsc:
                let cmp = a.name.localizedStandardCompare(b.name)
                if cmp != .orderedSame { return cmp == .orderedAscending }
                return a.count > b.count
            case .latestDateDesc:
                let dA = a.latestCreationDate ?? .distantPast
                let dB = b.latestCreationDate ?? .distantPast
                if dA != dB { return dA > dB }
                return a.count > b.count
            }
        }
        self.peopleEntries = entries
    }

    func toggleFavoritePerson(_ personName: String) {
        let current = peopleEntries.first(where: { $0.name == personName })?.isFavorite ?? false
        favoritePeopleByName[personName] = !current
        rebuildPeopleEntries()
        saveWorkspaceState()
    }

    /// Perform on-demand ImageIO EXIF/IPTC caption lookup and reverse geocoding for the selected/active asset
    func enrichAssetMetadata(for assetID: String) async {
        guard let itemIdx = allItems.firstIndex(where: { $0.id == assetID }) else { return }
        let phAsset = repository.phAsset(for: assetID)
        let localURL = repository.localMediaURL(for: assetID)

        if allItems[itemIdx].locationName == nil,
           let lat = allItems[itemIdx].latitude,
           let lon = allItems[itemIdx].longitude,
           allItems[itemIdx].hasLocation {
            let coordKey = String(format: "%.3f,%.3f", lat, lon)
            if let cachedLoc = geocodedCache[coordKey] {
                allItems[itemIdx].locationName = cachedLoc
            } else {
                let loc = CLLocation(latitude: lat, longitude: lon)
                if let placemarks = try? await geocoder.reverseGeocodeLocation(loc),
                   let pm = placemarks.first {
                    let parts = [pm.country, pm.administrativeArea, pm.locality ?? pm.subLocality].compactMap { $0 }
                    if !parts.isEmpty {
                        let formatted = parts.joined(separator: ", ")
                        geocodedCache[coordKey] = formatted
                        if let idx = allItems.firstIndex(where: { $0.id == assetID }) {
                            allItems[idx].locationName = formatted
                        }
                    }
                }
            }
        }

        guard !enrichedAssetIDs.contains(assetID) else { return }
        enrichedAssetIDs.insert(assetID)

        if !allItems[itemIdx].isVideo {
            _ = thumbnailCache.requestRawImageData(for: phAsset, fallbackFileURL: localURL) { [weak self] data, uti in
                guard let self, let data else { return }
                Task.detached(priority: .userInitiated) {
                    let parsedFileSize = Int64(data.count)
                    var cameraMake: String?
                    var cameraModel: String?
                    var lensModel: String?
                    var isoVal: Int?
                    var apertureVal: Double?
                    var shutterVal: Double?
                    var focalVal: Double?
                    var evVal: Double?
                    var embeddedCaption: String?

                    if let src = CGImageSourceCreateWithData(data as CFData, nil),
                       let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] {
                        if let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
                            cameraMake = tiff[kCGImagePropertyTIFFMake] as? String
                            cameraModel = tiff[kCGImagePropertyTIFFModel] as? String
                            if let desc = tiff[kCGImagePropertyTIFFImageDescription] as? String,
                               !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                embeddedCaption = desc
                            }
                        }
                        if let iptc = props[kCGImagePropertyIPTCDictionary] as? [CFString: Any] {
                            if let cap = iptc[kCGImagePropertyIPTCCaptionAbstract] as? String,
                               !cap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                embeddedCaption = cap
                            }
                        }
                        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] {
                            lensModel = exif[kCGImagePropertyExifLensModel] as? String
                            if let isos = exif[kCGImagePropertyExifISOSpeedRatings] as? [Int], let firstISO = isos.first {
                                isoVal = firstISO
                            }
                            apertureVal = exif[kCGImagePropertyExifFNumber] as? Double
                            shutterVal = exif[kCGImagePropertyExifExposureTime] as? Double
                            focalVal = exif[kCGImagePropertyExifFocalLength] as? Double
                            evVal = exif[kCGImagePropertyExifExposureBiasValue] as? Double
                        }
                    }

                    let finalSize = parsedFileSize
                    let finalMake = cameraMake
                    let finalModel = cameraModel
                    let finalLens = lensModel
                    let finalISO = isoVal
                    let finalAperture = apertureVal
                    let finalShutter = shutterVal
                    let finalFocal = focalVal
                    let finalEV = evVal
                    let finalCaption = embeddedCaption

                    await MainActor.run {
                        guard let idx = self.allItems.firstIndex(where: { $0.id == assetID }) else { return }
                        if let uti, self.allItems[idx].uniformTypeIdentifier == nil {
                            self.allItems[idx].uniformTypeIdentifier = uti
                        }
                        if (self.allItems[idx].exif.originalFileSize ?? 0) <= 0 {
                            self.allItems[idx].exif.originalFileSize = finalSize
                        }
                        if self.allItems[idx].exif.cameraMake == nil { self.allItems[idx].exif.cameraMake = finalMake }
                        if self.allItems[idx].exif.cameraModel == nil { self.allItems[idx].exif.cameraModel = finalModel }
                        if self.allItems[idx].exif.lensModel == nil { self.allItems[idx].exif.lensModel = finalLens }
                        if self.allItems[idx].exif.iso == nil { self.allItems[idx].exif.iso = finalISO }
                        if self.allItems[idx].exif.aperture == nil { self.allItems[idx].exif.aperture = finalAperture }
                        if self.allItems[idx].exif.shutterSpeed == nil { self.allItems[idx].exif.shutterSpeed = finalShutter }
                        if self.allItems[idx].exif.focalLength == nil { self.allItems[idx].exif.focalLength = finalFocal }
                        if self.allItems[idx].exif.exposureBias == nil { self.allItems[idx].exif.exposureBias = finalEV }
                        if self.allItems[idx].caption == nil, let finalCaption {
                            self.allItems[idx].caption = finalCaption
                        }
                    }
                }
            }
        }
    }

    func assignNameToFace(assetID: String, faceID: String, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = allItems.firstIndex(where: { $0.id == assetID }) else { return }
        for fIdx in allItems[idx].faces.indices {
            if allItems[idx].faces[fIdx].id == faceID {
                allItems[idx].faces[fIdx].displayName = trimmed
            }
        }
        manualFacesByAssetID[assetID] = allItems[idx].faces
        itemByIDMap[assetID] = allItems[idx]
        invalidateFilterCache()
        rebuildPeopleEntries()
        saveWorkspaceState()
    }

    // MARK: - Non-Destructive Batch Date/Time Adjustment

    func presentDateTimeEditSheet(for assetIDs: [String]) {
        guard !assetIDs.isEmpty else { return }
        dateTimeEditTargetAssetIDs = assetIDs
        showDateTimeEditSheet = true
    }

    func presentDateTimeEditForActiveSelection() {
        guard let tabIdx = activeTabIndex else { return }
        let currentTab = tabs[tabIdx]
        if let detailID = currentTab.activeDetailAssetID {
            presentDateTimeEditSheet(for: [detailID])
        } else if !currentTab.selectedAssetIDs.isEmpty {
            presentDateTimeEditSheet(for: Array(currentTab.selectedAssetIDs))
        } else if let singleID = currentTab.selectedAssetID {
            presentDateTimeEditSheet(for: [singleID])
        }
    }

    func applyBatchDateTimeAdjustment(
        targetAssetIDs: [String],
        newReferenceDate: Date,
        shiftAllByRelativeDelta: Bool
    ) {
        let sortedTargets = targetAssetIDs.compactMap { id in
            allItems.first(where: { $0.id == id })
        }
        guard let firstItem = sortedTargets.first else { return }
        let originalFirstDate = firstItem.creationDate ?? Date()
        let timeDelta = newReferenceDate.timeIntervalSince(originalFirstDate)

        for id in targetAssetIDs {
            guard let idx = allItems.firstIndex(where: { $0.id == id }) else { continue }
            let adjustedDate: Date
            if shiftAllByRelativeDelta, targetAssetIDs.count > 1, let orig = allItems[idx].creationDate {
                adjustedDate = orig.addingTimeInterval(timeDelta)
            } else {
                adjustedDate = newReferenceDate
            }
            allItems[idx].creationDate = adjustedDate
            customCreationDatesByID[id] = adjustedDate
            itemByIDMap[id] = allItems[idx]
        }

        allItems.sort { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        invalidateFilterCache()
        saveWorkspaceState()
    }

    // MARK: - Filtering, Smart Album Evaluation & Duplicate Detection

    func filteredItems(for tab: BrowserTabState) -> [PhotoAssetItem] {
        let cacheKey = "\(tab.filterScope)_\(tab.contentFilter.rawValue)_\(tab.searchQuery)_\(filterCacheRevision)"
        if let cached = cachedFilteredItemsByTabID[tab.id], cached.key == cacheKey {
            return cached.items
        }

        let scopeItems: [PhotoAssetItem]
        switch tab.filterScope {
        case .library:
            scopeItems = allItems.filter { !$0.isTrashed && !$0.isHidden }
        case .favorites:
            scopeItems = allItems.filter { !$0.isTrashed && !$0.isHidden && $0.isFavorite }
        case .peopleOverview:
            scopeItems = allItems.filter { !$0.isTrashed && !$0.isHidden && !$0.faces.filter({ !$0.isUnnamed }).isEmpty }
        case .map:
            scopeItems = allItems.filter { !$0.isTrashed && !$0.isHidden && $0.hasLocation }
        case .recentlyDeleted:
            scopeItems = allItems.filter(\.isTrashed)
        case .hidden:
            scopeItems = allItems.filter { !$0.isTrashed && $0.isHidden }
        case .recentlyViewed:
            let set = Set(recentlyViewedIDs)
            scopeItems = allItems.filter { !$0.isTrashed && !$0.isHidden && set.contains($0.id) }
        case .duplicates:
            scopeItems = detectDuplicateAssets()
        case .imports:
            scopeItems = Array(allItems.filter { !$0.isTrashed && !$0.isHidden }.suffix(200))
        case .videos:
            scopeItems = allItems.filter { !$0.isTrashed && !$0.isHidden && $0.isVideo }
        case .selfies:
            scopeItems = allItems.filter { !$0.isTrashed && !$0.isHidden && !$0.faces.isEmpty }
        case .livePhotos:
            scopeItems = allItems.filter { !$0.isTrashed && !$0.isHidden && $0.isLivePhoto }
        case .portrait:
            scopeItems = allItems.filter { !$0.isTrashed && !$0.isHidden && $0.isPortrait }
        case .panoramas:
            scopeItems = allItems.filter { !$0.isTrashed && !$0.isHidden && $0.isPanorama }
        case .screenshots:
            scopeItems = allItems.filter { !$0.isTrashed && !$0.isHidden && $0.isScreenshot }
        case .animated:
            scopeItems = allItems.filter { !$0.isTrashed && !$0.isHidden && $0.isGIF }
        case .person(let name):
            scopeItems = allItems.filter { !$0.isTrashed && !$0.isHidden && $0.faces.contains { $0.displayName == name } }
        case .systemAlbum(let albumID, let albumTitle):
            if let node = findSystemAlbumNode(id: albumID, in: systemAlbumTree) {
                scopeItems = resolveAssetsForSystemAlbumNode(node)
            } else {
                scopeItems = fallbackMatchByAlbumTitle(albumTitle)
            }
        case .systemFolder(let folderID, _):
            if let folderNode = findSystemAlbumNode(id: folderID, in: systemAlbumTree) {
                scopeItems = resolveAssetsForSystemFolderNode(folderNode)
            } else {
                scopeItems = []
            }
        case .customAlbum(let albumUUID, _):
            let ids = Set(customAlbums.first(where: { $0.id == albumUUID })?.assetIDs ?? [])
            scopeItems = allItems.filter { !$0.isTrashed && !$0.isHidden && ids.contains($0.id) }
        case .customFolder(let folderUUID, _):
            let childAlbums = customAlbums.filter { $0.parentFolderID == folderUUID }
            let ids = Set(childAlbums.flatMap(\.assetIDs))
            scopeItems = allItems.filter { !$0.isTrashed && !$0.isHidden && ids.contains($0.id) }
        case .smartAlbum(let smartID, _):
            if let rule = smartAlbums.first(where: { $0.id == smartID }) {
                scopeItems = allItems.filter { rule.matches($0) }
            } else {
                scopeItems = []
            }
        case .keyword(let tag):
            scopeItems = allItems.filter { !$0.isTrashed && !$0.isHidden && $0.keywords.contains(tag) }
        }

        let contentFiltered: [PhotoAssetItem]
        if tab.contentFilter == .allItems {
            contentFiltered = scopeItems
        } else {
            contentFiltered = scopeItems.filter { tab.contentFilter.matches($0) }
        }

        let q = tab.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalResult: [PhotoAssetItem]
        if q.isEmpty {
            finalResult = contentFiltered
        } else {
            finalResult = contentFiltered.filter { item in
                item.originalFilename.localizedCaseInsensitiveContains(q)
                    || (item.title?.localizedCaseInsensitiveContains(q) ?? false)
                    || (item.caption?.localizedCaseInsensitiveContains(q) ?? false)
                    || item.faces.contains(where: { $0.displayName.localizedCaseInsensitiveContains(q) })
                    || item.keywords.contains(where: { $0.localizedCaseInsensitiveContains(q) })
                    || item.exif.formattedSummary.localizedCaseInsensitiveContains(q)
            }
        }

        cachedFilteredItemsByTabID[tab.id] = (key: cacheKey, items: finalResult)
        return finalResult
    }

    /// Build 3-column Library year overview cards with O(1) caching (consolidating decades with <50 photos into e.g. 1970–79)
    func libraryYearBuckets(for tab: BrowserTabState) -> [LibraryYearBucket] {
        let cacheKey = "\(tab.contentFilter.rawValue)_\(tab.searchQuery)_\(filterCacheRevision)"
        if let cached = cachedLibraryBucketsByKey[cacheKey] {
            return cached
        }

        var libTab = tab
        libTab.filterScope = .library
        let allLibItems = filteredItems(for: libTab)
        let cal = Calendar.current

        var byYear: [Int: [PhotoAssetItem]] = [:]
        for item in allLibItems {
            let y = item.creationDate.map { cal.component(.year, from: $0) } ?? 1970
            byYear[y, default: []].append(item)
        }

        // Calculate total count per decade and group decades with fewer than 50 photos into a single decade range (e.g. "1970–79")
        var byDecadeCount: [Int: Int] = [:]
        for (y, list) in byYear {
            let decade = (y / 10) * 10
            byDecadeCount[decade, default: 0] += list.count
        }

        var groupedMap: [String: (sortKey: Int, title: String, list: [PhotoAssetItem])] = [:]
        for y in byYear.keys.sorted() {
            guard let list = byYear[y] else { continue }
            let decade = (y / 10) * 10
            let decadeTotal = byDecadeCount[decade] ?? 0
            if decadeTotal < 50 {
                let endTwoDigits = (decade + 9) % 100
                let bucketID = String(format: "%d~%02d", decade, endTwoDigits)
                let title = String(format: "%d–%02d", decade, endTwoDigits)
                if groupedMap[bucketID] == nil {
                    groupedMap[bucketID] = (sortKey: decade, title: title, list: list)
                } else {
                    groupedMap[bucketID]?.list.append(contentsOf: list)
                }
            } else {
                let bucketID = "\(y)"
                let title = "\(y)"
                groupedMap[bucketID] = (sortKey: y, title: title, list: list)
            }
        }

        let sortedKeys = groupedMap.keys.sorted { a, b in
            let ka = groupedMap[a]?.sortKey ?? 0
            let kb = groupedMap[b]?.sortKey ?? 0
            if ka != kb { return ka < kb }
            return a < b
        }

        let buckets: [LibraryYearBucket] = sortedKeys.compactMap { key in
            guard let entry = groupedMap[key] else { return nil }
            let preferredKeyID = albumKeyPhotoByAlbumID["LIB_YEAR_\(key)"]
            let keyAsset = preferredKeyID.flatMap { itemByIDMap[$0] }
                ?? entry.list.last(where: \.isFavorite)
                ?? entry.list.last
            return LibraryYearBucket(
                id: key,
                title: entry.title,
                assets: entry.list,
                keyAsset: keyAsset
            )
        }

        cachedLibraryBucketsByKey[cacheKey] = buckets
        return buckets
    }

    /// Return a max 2,000-item page slice and media counts with O(1) caching for instant grid rendering
    func pagedSlice(for tab: BrowserTabState) -> PagedGridSlice {
        let sliceKey = "\(tab.filterScope)_\(tab.selectedLibraryBucketID ?? "nil")_\(tab.currentPageIndex)_\(tab.contentFilter.rawValue)_\(tab.searchQuery)_\(filterCacheRevision)"
        if let cached = cachedPagedSliceByTabID[tab.id], cached.key == sliceKey {
            return cached.slice
        }

        let sourceItems: [PhotoAssetItem]
        let bucketTitle: String?

        if tab.filterScope == .library,
           let bucketID = tab.selectedLibraryBucketID,
           tab.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let buckets = libraryYearBuckets(for: tab)
            if let matched = buckets.first(where: { $0.id == bucketID }) {
                sourceItems = matched.assets
                bucketTitle = matched.title
            } else {
                sourceItems = filteredItems(for: tab)
                bucketTitle = nil
            }
        } else {
            sourceItems = filteredItems(for: tab)
            bucketTitle = nil
        }

        let total = sourceItems.count
        let pageSize = Self.maxItemsPerPage
        let totalPages = max(1, (total + pageSize - 1) / pageSize)
        let safePage = max(0, min(tab.currentPageIndex, totalPages - 1))
        let startIdx = safePage * pageSize
        let endIdx = min(startIdx + pageSize, total)
        let pageItems: [PhotoAssetItem] = (startIdx < endIdx) ? Array(sourceItems[startIdx..<endIdx]) : []

        var pCount = 0
        var vCount = 0
        for item in pageItems {
            if item.isVideo { vCount += 1 } else { pCount += 1 }
        }

        let slice = PagedGridSlice(
            pageItems: pageItems,
            totalCount: total,
            totalPages: totalPages,
            safePageIndex: safePage,
            pagePhotoCount: pCount,
            pageVideoCount: vCount,
            activeBucketTitle: bucketTitle
        )
        cachedPagedSliceByTabID[tab.id] = (key: sliceKey, slice: slice)
        return slice
    }

    private func resolveAssetsForSystemAlbumNode(_ node: AlbumTreeNode) -> [PhotoAssetItem] {
        if !node.assetLocalIdentifiers.isEmpty {
            let idSet = Set(node.assetLocalIdentifiers)
            let direct = allItems.filter { !$0.isTrashed && !$0.isHidden && idSet.contains($0.id) }
            if !direct.isEmpty {
                return direct
            }
        }

        if let criteria = node.smartQueryCriteria {
            let matched = allItems.filter { criteria.matches($0, albumAssetIDsByNameOrUUID: albumAssetIDsByNameOrUUIDCache) }
            if !matched.isEmpty {
                return matched
            }
        }

        if node.isSmartAlbum || node.assetLocalIdentifiers.isEmpty {
            return fallbackMatchByAlbumTitle(node.title)
        }
        return []
    }

    private func resolveAssetsForSystemFolderNode(_ folderNode: AlbumTreeNode) -> [PhotoAssetItem] {
        let collectedIDs: Set<String> = Set(folderNode.assetLocalIdentifiers)
        var resultItems: [PhotoAssetItem] = []
        var seenIDs: Set<String> = []

        func gather(from node: AlbumTreeNode) {
            if node.isFolder {
                for c in node.children { gather(from: c) }
            } else {
                let items = resolveAssetsForSystemAlbumNode(node)
                for item in items where !seenIDs.contains(item.id) {
                    seenIDs.insert(item.id)
                    resultItems.append(item)
                }
            }
        }
        gather(from: folderNode)
        if !resultItems.isEmpty {
            return resultItems.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        }
        return allItems.filter { !$0.isTrashed && !$0.isHidden && collectedIDs.contains($0.id) }
    }

    private func fallbackMatchByAlbumTitle(_ title: String) -> [PhotoAssetItem] {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return [] }
        return allItems.filter { item in
            guard !item.isTrashed && !item.isHidden else { return false }
            if let cap = item.caption, cap.localizedCaseInsensitiveContains(clean) {
                return true
            }
            if item.faces.contains(where: { $0.displayName.localizedCaseInsensitiveContains(clean) || clean.localizedCaseInsensitiveContains($0.displayName) }) {
                return true
            }
            if item.keywords.contains(where: { $0.localizedCaseInsensitiveContains(clean) || clean.localizedCaseInsensitiveContains($0) }) {
                return true
            }
            if let t = item.title, t.localizedCaseInsensitiveContains(clean) {
                return true
            }
            if let cam = item.exif.cameraModel, cam.localizedCaseInsensitiveContains(clean) {
                return true
            }
            if item.originalFilename.localizedCaseInsensitiveContains(clean) {
                return true
            }
            return false
        }
    }

    private func detectDuplicateAssets() -> [PhotoAssetItem] {
        var groups: [String: [PhotoAssetItem]] = [:]
        for item in allItems where !item.isTrashed && !item.isHidden {
            let key = "\(item.originalFilename.lowercased())_\(item.pixelWidth)x\(item.pixelHeight)"
            groups[key, default: []].append(item)
        }
        return groups.values.filter { $0.count > 1 }.flatMap { $0 }
    }

    func findSystemAlbumNode(id: String, in nodes: [AlbumTreeNode]) -> AlbumTreeNode? {
        for node in nodes {
            if node.id == id { return node }
            if let found = findSystemAlbumNode(id: id, in: node.children) { return found }
        }
        return nil
    }

    func albumsContaining(assetID: String, excludingScope: TabFilterScope) -> [(title: String, scope: TabFilterScope)] {
        var results: [(title: String, scope: TabFilterScope)] = []

        func walk(_ nodes: [AlbumTreeNode]) {
            for node in nodes {
                if node.isFolder {
                    walk(node.children)
                } else {
                    let scope = TabFilterScope.systemAlbum(id: node.id, title: node.title)
                    guard scope != excludingScope else { continue }
                    if node.assetLocalIdentifiers.contains(assetID) {
                        results.append((title: node.title, scope: scope))
                    }
                }
            }
        }
        walk(systemAlbumTree)

        for custom in customAlbums {
            let scope = TabFilterScope.customAlbum(id: custom.id, title: custom.name)
            guard scope != excludingScope else { continue }
            if custom.assetIDs.contains(assetID) {
                results.append((title: custom.name, scope: scope))
            }
        }
        return results
    }

    func revealAssetInAllPhotos(_ assetID: String) {
        guard let idx = activeTabIndex else { return }
        navigateToScope(inTab: idx, scope: .library)
        tabs[idx].contentFilter = .allItems
        tabs[idx].searchQuery = ""
        let buckets = libraryYearBuckets(for: tabs[idx])
        if let matchedBucket = buckets.first(where: { $0.assets.contains(where: { $0.id == assetID }) }),
           let posInBucket = matchedBucket.assets.firstIndex(where: { $0.id == assetID }) {
            tabs[idx].selectedLibraryBucketID = matchedBucket.id
            tabs[idx].currentPageIndex = posInBucket / Self.maxItemsPerPage
        }
        tabs[idx].selectedAssetID = assetID
        tabs[idx].selectedAssetIDs = [assetID]
        pendingScrollToAssetID = assetID
        invalidateFilterCache()
        saveWorkspaceState()
    }

    struct FolderAlbumCardItem: Identifiable, Hashable {
        let id: String
        let title: String
        let scope: TabFilterScope
        let previewAssets: [PhotoAssetItem]
        let keyAsset: PhotoAssetItem?
        var count: Int { previewAssets.count }
    }

    /// Resolve folder album cards using ZGENERICALBUM.ZCUSTOMKEYASSET / ZKEYASSET or user-assigned key photos
    func childAlbumCards(for folderScope: TabFilterScope) -> [FolderAlbumCardItem] {
        switch folderScope {
        case .systemFolder(let folderID, _):
            var cards: [FolderAlbumCardItem] = []
            if let node = findSystemAlbumNode(id: folderID, in: systemAlbumTree) {
                for child in node.children {
                    let childScope: TabFilterScope = child.isFolder
                        ? .systemFolder(id: child.id, title: child.title)
                        : .systemAlbum(id: child.id, title: child.title)
                    let assets = child.isFolder
                        ? resolveAssetsForSystemFolderNode(child)
                        : resolveAssetsForSystemAlbumNode(child)
                    let preferredKeyID = albumKeyPhotoByAlbumID[child.id] ?? child.customKeyAssetID
                    let resolvedKeyAsset = preferredKeyID.flatMap { itemByIDMap[$0] } ?? assets.first
                    cards.append(
                        FolderAlbumCardItem(
                            id: child.id,
                            title: child.title,
                            scope: childScope,
                            previewAssets: assets,
                            keyAsset: resolvedKeyAsset
                        )
                    )
                }
            }
            for custom in customAlbums where custom.parentSystemFolderIdentifier == folderID {
                let idSet = Set(custom.assetIDs)
                let assets = allItems.filter { !$0.isTrashed && !$0.isHidden && idSet.contains($0.id) }
                let preferredKeyID = albumKeyPhotoByAlbumID[custom.id.uuidString] ?? custom.keyAssetID
                let resolvedKeyAsset = preferredKeyID.flatMap { itemByIDMap[$0] } ?? assets.first
                cards.append(
                    FolderAlbumCardItem(
                        id: custom.id.uuidString,
                        title: custom.name,
                        scope: .customAlbum(id: custom.id, title: custom.name),
                        previewAssets: assets,
                        keyAsset: resolvedKeyAsset
                    )
                )
            }
            return cards

        case .customFolder(let folderUUID, _):
            return customAlbums
                .filter { $0.parentFolderID == folderUUID }
                .map { album in
                    let idSet = Set(album.assetIDs)
                    let assets = allItems.filter { !$0.isTrashed && !$0.isHidden && idSet.contains($0.id) }
                    let preferredKeyID = albumKeyPhotoByAlbumID[album.id.uuidString] ?? album.keyAssetID
                    let resolvedKeyAsset = preferredKeyID.flatMap { itemByIDMap[$0] } ?? assets.first
                    return FolderAlbumCardItem(
                        id: album.id.uuidString,
                        title: album.name,
                        scope: .customAlbum(id: album.id, title: album.name),
                        previewAssets: assets,
                        keyAsset: resolvedKeyAsset
                    )
                }
        default:
            return []
        }
    }

    // MARK: - Actions (Tabs, Tags, Smart Albums, Custom Albums, External Apps)

    func navigateToScope(inTab tabIdx: Int, scope: TabFilterScope) {
        guard tabs.indices.contains(tabIdx) else { return }
        let currentScope = tabs[tabIdx].filterScope
        if currentScope != scope {
            tabs[tabIdx].navigationHistory.append(currentScope)
        }
        tabs[tabIdx].filterScope = scope
        // Return to the 3-column year overview grid when Library is selected in the sidebar
        if scope == .library {
            tabs[tabIdx].selectedLibraryBucketID = nil
        }
        tabs[tabIdx].currentPageIndex = 0
        // Default to a 5-column layout when opening an individual person's page
        if case .person = scope {
            tabs[tabIdx].gridConfig.columnCountDouble = 5.0
        }
        tabs[tabIdx].activeDetailAssetID = nil
        tabs[tabIdx].selectedFolderAlbumID = nil
        saveWorkspaceState()
    }

    func navigateBack(inTab tabIdx: Int) {
        guard tabs.indices.contains(tabIdx) else { return }
        if tabs[tabIdx].activeDetailAssetID != nil {
            tabs[tabIdx].activeDetailAssetID = nil
            saveWorkspaceState()
            return
        }
        // When viewing a specific year page inside Library, the Back button returns to the 3-column year overview grid
        if tabs[tabIdx].filterScope == .library && tabs[tabIdx].selectedLibraryBucketID != nil {
            tabs[tabIdx].selectedLibraryBucketID = nil
            tabs[tabIdx].currentPageIndex = 0
            saveWorkspaceState()
            return
        }
        if let prev = tabs[tabIdx].navigationHistory.popLast() {
            tabs[tabIdx].filterScope = prev
            tabs[tabIdx].currentPageIndex = 0
            saveWorkspaceState()
        }
    }

    func openNewTab(scope: TabFilterScope = .library) {
        var newTab = BrowserTabState(filterScope: scope)
        if case .person = scope {
            newTab.gridConfig.columnCountDouble = 5.0
        }
        tabs.append(newTab)
        activeTabID = newTab.id
        saveWorkspaceState()
    }

    func closeTab(id: UUID) {
        guard tabs.count > 1, let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: idx)
        if activeTabID == id {
            activeTabID = tabs[min(idx, tabs.count - 1)].id
        }
        saveWorkspaceState()
    }

    func navigateDetailAsset(inTabIndex tabIdx: Int, direction: Int) {
        guard tabs.indices.contains(tabIdx),
              let currentID = tabs[tabIdx].activeDetailAssetID else { return }
        let list = pagedSlice(for: tabs[tabIdx]).pageItems
        guard let currentPos = list.firstIndex(where: { $0.id == currentID }) else { return }
        let nextPos = currentPos + direction
        guard list.indices.contains(nextPos) else { return }
        let nextID = list[nextPos].id
        tabs[tabIdx].activeDetailAssetID = nextID
        tabs[tabIdx].selectedAssetID = nextID
        tabs[tabIdx].selectedAssetIDs = [nextID]
        recordRecentlyViewed(nextID)
        saveWorkspaceState()
    }

    func toggleSpacebarQuickLook() {
        guard let tabIdx = activeTabIndex else { return }
        if tabs[tabIdx].activeDetailAssetID != nil {
            tabs[tabIdx].activeDetailAssetID = nil
        } else if let selectedID = tabs[tabIdx].selectedAssetID ?? tabs[tabIdx].selectedAssetIDs.first {
            tabs[tabIdx].activeDetailAssetID = selectedID
            recordRecentlyViewed(selectedID)
        }
        saveWorkspaceState()
    }

    func recordRecentlyViewed(_ assetID: String) {
        recentlyViewedIDs.removeAll(where: { $0 == assetID })
        recentlyViewedIDs.insert(assetID, at: 0)
        if recentlyViewedIDs.count > 200 {
            recentlyViewedIDs.removeLast()
        }
    }

    func toggleFavorite(for assetID: String) {
        guard let idx = allItems.firstIndex(where: { $0.id == assetID }) else { return }
        let newState = !allItems[idx].isFavorite
        allItems[idx].isFavorite = newState
        itemByIDMap[assetID] = allItems[idx]
        favoriteOverridesByID[assetID] = newState
        invalidateFilterCache()
        saveWorkspaceState()
    }

    func toggleHidden(for assetID: String) {
        guard let idx = allItems.firstIndex(where: { $0.id == assetID }) else { return }
        let newState = !allItems[idx].isHidden
        allItems[idx].isHidden = newState
        itemByIDMap[assetID] = allItems[idx]
        hiddenOverridesByID[assetID] = newState
        invalidateFilterCache()
        saveWorkspaceState()
    }

    func updateCustomTitle(_ title: String, for assetID: String) {
        guard let idx = allItems.firstIndex(where: { $0.id == assetID }) else { return }
        allItems[idx].title = title.isEmpty ? nil : title
        itemByIDMap[assetID] = allItems[idx]
        customTitlesByID[assetID] = title
        invalidateFilterCache()
        saveWorkspaceState()
    }

    func updateCustomCaption(_ caption: String, for assetID: String) {
        guard let idx = allItems.firstIndex(where: { $0.id == assetID }) else { return }
        allItems[idx].caption = caption.isEmpty ? nil : caption
        itemByIDMap[assetID] = allItems[idx]
        customCaptionsByID[assetID] = caption
        invalidateFilterCache()
        saveWorkspaceState()
    }

    func addTag(_ tag: String, toAssetID assetID: String) {
        let clean = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if !allRegisteredTags.contains(clean) {
            allRegisteredTags.append(clean)
            allRegisteredTags.sort()
        }
        guard let idx = allItems.firstIndex(where: { $0.id == assetID }) else { return }
        if !allItems[idx].keywords.contains(clean) {
            allItems[idx].keywords.append(clean)
            allItems[idx].keywords.sort()
        }
        itemByIDMap[assetID] = allItems[idx]
        assetTagsByID[assetID] = allItems[idx].keywords
        invalidateFilterCache()
        saveWorkspaceState()
    }

    func removeTag(_ tag: String, fromAssetID assetID: String) {
        guard let idx = allItems.firstIndex(where: { $0.id == assetID }) else { return }
        allItems[idx].keywords.removeAll(where: { $0 == tag })
        itemByIDMap[assetID] = allItems[idx]
        assetTagsByID[assetID] = allItems[idx].keywords
        invalidateFilterCache()
        saveWorkspaceState()
    }

    func setKeyPhotoForPerson(personName: String, assetID: String) {
        personKeyPhotoByPersonName[personName] = assetID
        rebuildPeopleEntries()
        saveWorkspaceState()
    }

    func setKeyPhotoForAlbum(albumID: String, assetID: String) {
        albumKeyPhotoByAlbumID[albumID] = assetID
        if let idx = customAlbums.firstIndex(where: { $0.id.uuidString == albumID }) {
            customAlbums[idx].keyAssetID = assetID
        }
        saveWorkspaceState()
    }

    func createOrUpdateSmartAlbum(_ definition: SmartAlbumDefinition) {
        if let idx = smartAlbums.firstIndex(where: { $0.id == definition.id }) {
            smartAlbums[idx] = definition
        } else {
            smartAlbums.append(definition)
        }
        invalidateFilterCache()
        saveWorkspaceState()
    }

    func createCustomAlbum(
        name: String,
        parentFolderID: UUID? = nil,
        parentSystemFolderIdentifier: String? = nil,
        initialAssetIDs: [String] = []
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Untitled Album" : trimmed
        let album = CustomAlbumDefinition(
            name: finalName,
            parentFolderID: parentFolderID,
            parentSystemFolderIdentifier: parentSystemFolderIdentifier,
            assetIDs: initialAssetIDs,
            keyAssetID: initialAssetIDs.first
        )
        customAlbums.append(album)
        invalidateFilterCache()
        saveWorkspaceState()
    }

    func createCustomFolder(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Untitled Folder" : trimmed
        let folder = CustomFolderDefinition(name: finalName)
        customFolders.append(folder)
        expandedFolderIDs.insert(folder.id.uuidString)
        saveWorkspaceState()
    }

    func addAsset(_ assetID: String, toCustomAlbum albumID: UUID) {
        guard let idx = customAlbums.firstIndex(where: { $0.id == albumID }) else { return }
        if !customAlbums[idx].assetIDs.contains(assetID) {
            customAlbums[idx].assetIDs.append(assetID)
            if customAlbums[idx].keyAssetID == nil {
                customAlbums[idx].keyAssetID = assetID
            }
            invalidateFilterCache()
            saveWorkspaceState()
        }
    }

    func availableExternalApps(for item: PhotoAssetItem) -> [URL] {
        let ext = (item.originalFilename as NSString).pathExtension
        let effectiveExt = ext.isEmpty ? (item.isVideo ? "mov" : "jpg") : ext
        let dummyURL = FileManager.default.temporaryDirectory.appendingPathComponent("sample.\(effectiveExt)")
        if !FileManager.default.fileExists(atPath: dummyURL.path) {
            try? Data().write(to: dummyURL)
        }
        return NSWorkspace.shared.urlsForApplications(toOpen: dummyURL)
    }

    func openAsset(_ item: PhotoAssetItem, withApplication appURL: URL) {
        let phAsset = repository.phAsset(for: item.id)
        let fallbackURL = repository.localMediaURL(for: item.id)
        Task {
            guard let fileURL = await thumbnailCache.resolveExternalOpenFileURL(
                for: phAsset,
                fallbackFileURL: fallbackURL,
                originalFilename: item.originalFilename
            ) else { return }
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: config, completionHandler: nil)
        }
    }
}

// MARK: - 11. Window Titlebar Accessor, Multi-Monitor Safe Top-Edge & Fullscreen Titlebar Monitor

private struct WindowAndInputBridgeView: NSViewRepresentable {
    var isDetailFullscreen: Bool
    @Binding var isHoveringTopBarArea: Bool
    @Binding var isFullscreenTitlebarRevealed: Bool
    var onSpacebarPressed: () -> Void
    var onEscapePressed: () -> Void
    var onArrowNavigate: (Int) -> Void

    func makeNSView(context: Context) -> BridgeNSView {
        let v = BridgeNSView()
        v.onCursorNearTop = { nearTop in
            if isHoveringTopBarArea != nearTop {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isHoveringTopBarArea = nearTop
                }
            }
        }
        v.onFullscreenTitlebarRevealed = { revealed in
            if isFullscreenTitlebarRevealed != revealed {
                withAnimation(.interpolatingSpring(stiffness: 340, damping: 32)) {
                    isFullscreenTitlebarRevealed = revealed
                }
            }
        }
        v.onSpacebarPressed = onSpacebarPressed
        v.onEscapePressed = onEscapePressed
        v.onArrowNavigate = onArrowNavigate
        return v
    }

    func updateNSView(_ nsView: BridgeNSView, context: Context) {
        nsView.isDetailFullscreen = isDetailFullscreen
        nsView.onCursorNearTop = { nearTop in
            if isHoveringTopBarArea != nearTop {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isHoveringTopBarArea = nearTop
                }
            }
        }
        nsView.onFullscreenTitlebarRevealed = { revealed in
            if isFullscreenTitlebarRevealed != revealed {
                withAnimation(.interpolatingSpring(stiffness: 340, damping: 32)) {
                    isFullscreenTitlebarRevealed = revealed
                }
            }
        }
        nsView.onSpacebarPressed = onSpacebarPressed
        nsView.onEscapePressed = onEscapePressed
        nsView.onArrowNavigate = onArrowNavigate
        nsView.configureWindowIfNeeded()
        nsView.updateStandardWindowButtonsVisibility()
    }

    final class BridgeNSView: NSView {
        var isDetailFullscreen: Bool = false
        var onCursorNearTop: ((Bool) -> Void)?
        var onFullscreenTitlebarRevealed: ((Bool) -> Void)?
        var onSpacebarPressed: (() -> Void)?
        var onEscapePressed: (() -> Void)?
        var onArrowNavigate: ((Int) -> Void)?

        private nonisolated(unsafe) var mouseMonitor: Any?
        private nonisolated(unsafe) var keyMonitor: Any?
        private nonisolated(unsafe) var fullscreenPollTimer: Timer?
        private var currentFullscreenRevealed: Bool = false
        private var currentDetailTopBarShown: Bool = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            configureWindowIfNeeded()
            updateStandardWindowButtonsVisibility()
            installMonitorsIfNeeded()
        }

        func configureWindowIfNeeded() {
            guard let window else { return }
            if window.toolbar != nil {
                window.toolbar = nil
            }
            if !window.styleMask.contains(.fullSizeContentView) {
                window.styleMask.insert(.fullSizeContentView)
            }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = false
        }

        /// Synchronize macOS window traffic-light buttons (Close / Minimize / Zoom) with the auto-hiding top bar in detail view,
        /// revealing the traffic-light buttons smoothly whenever the top bar slides down
        func updateStandardWindowButtonsVisibility() {
            guard let win = self.window else { return }
            let isFS = win.styleMask.contains(.fullScreen)
            if isFS {
                for btnType: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
                    win.standardWindowButton(btnType)?.isHidden = false
                }
            } else {
                let shouldHideButtons = isDetailFullscreen && !currentDetailTopBarShown
                for btnType: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
                    win.standardWindowButton(btnType)?.isHidden = shouldHideButtons
                }
            }
        }

        private func evaluateTopBarAndFullscreenState() {
            guard let win = self.window, let winScreen = win.screen else { return }
            let isFS = win.styleMask.contains(.fullScreen)
            let mouseScreenLoc = NSEvent.mouseLocation

            // In multi-monitor setups, ignore cursor movement on other displays so the top bar never triggers accidentally
            let isCursorOnThisScreen = winScreen.frame.insetBy(dx: -1.0, dy: -2.0).contains(mouseScreenLoc)
            let isCursorWithinWindowX = (mouseScreenLoc.x >= win.frame.minX - 2.0 && mouseScreenLoc.x <= win.frame.maxX + 2.0)

            if !isCursorOnThisScreen || !isCursorWithinWindowX {
                if currentDetailTopBarShown {
                    currentDetailTopBarShown = false
                    onCursorNearTop?(false)
                    updateStandardWindowButtonsVisibility()
                }
                if currentFullscreenRevealed {
                    currentFullscreenRevealed = false
                    onFullscreenTitlebarRevealed?(false)
                }
                return
            }

            // 1. Native macOS fullscreen: directly detect NSToolbarFullScreenWindow sliding down with the system menu bar
            if isFS {
                let systemTitlebarRevealed = NSApplication.shared.windows.contains { w in
                    guard w.screen == winScreen else { return false }
                    let typeName = String(describing: type(of: w))
                    guard typeName.contains("ToolbarFullScreen") && w.isVisible && w.alphaValue > 0.05 else {
                        return false
                    }
                    // Check whether the fullscreen titlebar is descending from the top edge of the active screen
                    return w.frame.minY < winScreen.frame.maxY - 4.0
                }

                if systemTitlebarRevealed != currentFullscreenRevealed {
                    currentFullscreenRevealed = systemTitlebarRevealed
                    onFullscreenTitlebarRevealed?(systemTitlebarRevealed)
                }

                if isDetailFullscreen {
                    let distFromScreenTop = max(0.0, winScreen.frame.maxY - mouseScreenLoc.y)
                    let shouldShowDetailTop = systemTitlebarRevealed || distFromScreenTop <= 18.0
                    let shouldHideDetailTop = !systemTitlebarRevealed && distFromScreenTop > 104.0
                    if shouldShowDetailTop && !currentDetailTopBarShown {
                        currentDetailTopBarShown = true
                        onCursorNearTop?(true)
                    } else if shouldHideDetailTop && currentDetailTopBarShown {
                        currentDetailTopBarShown = false
                        onCursorNearTop?(false)
                    }
                }
            } else {
                if currentFullscreenRevealed {
                    currentFullscreenRevealed = false
                    onFullscreenTitlebarRevealed?(false)
                }

                // 2. Windowed detail view: reveal the top bar and traffic-light buttons only when the cursor enters this window's top edge
                if isDetailFullscreen {
                    let isCursorInsideWindowY = (mouseScreenLoc.y >= win.frame.minY && mouseScreenLoc.y <= win.frame.maxY + 4.0)
                    let distFromWindowTop = win.frame.maxY - mouseScreenLoc.y
                    if isCursorInsideWindowY && distFromWindowTop >= -4.0 && distFromWindowTop <= 22.0 {
                        if !currentDetailTopBarShown {
                            currentDetailTopBarShown = true
                            onCursorNearTop?(true)
                            updateStandardWindowButtonsVisibility()
                        }
                    } else if distFromWindowTop > 96.0 || !isCursorInsideWindowY {
                        if currentDetailTopBarShown {
                            currentDetailTopBarShown = false
                            onCursorNearTop?(false)
                            updateStandardWindowButtonsVisibility()
                        }
                    }
                } else if currentDetailTopBarShown {
                    currentDetailTopBarShown = false
                    updateStandardWindowButtonsVisibility()
                }
            }
        }

        private func installMonitorsIfNeeded() {
            if mouseMonitor == nil {
                mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
                    self?.evaluateTopBarAndFullscreenState()
                    return event
                }
            }
            if fullscreenPollTimer == nil {
                fullscreenPollTimer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.evaluateTopBarAndFullscreenState()
                    }
                }
            }
            if keyMonitor == nil {
                keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                    guard let self else { return event }
                    if let firstResp = self.window?.firstResponder as? NSTextView, firstResp.isEditable {
                        return event
                    }
                    if event.keyCode == 49 && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                        self.onSpacebarPressed?()
                        return nil
                    } else if event.keyCode == 53 {
                        if self.isDetailFullscreen {
                            self.onEscapePressed?()
                            return nil
                        }
                    } else if self.isDetailFullscreen && event.keyCode == 123 {
                        self.onArrowNavigate?(-1)
                        return nil
                    } else if self.isDetailFullscreen && event.keyCode == 124 {
                        self.onArrowNavigate?(1)
                        return nil
                    }
                    return event
                }
            }
        }

        deinit {
            if let m = mouseMonitor { NSEvent.removeMonitor(m) }
            if let k = keyMonitor { NSEvent.removeMonitor(k) }
            fullscreenPollTimer?.invalidate()
        }
    }
}

// MARK: - 12. Root Window View (Fullscreen Push-Down + Persistent Grid Scroll Position + Drag-Resizable Sidebar)

struct PhotoVaultCompleteRootView: View {
    @Bindable var viewModel: PhotoWorkspaceViewModel
    @State private var isHoveringTopInFullscreen: Bool = false
    @State private var isFullscreenTitlebarRevealed: Bool = false

    var body: some View {
        let activeIdx = viewModel.activeTabIndex
        let isDetailActive = (activeIdx != nil && viewModel.tabs[activeIdx!].activeDetailAssetID != nil)
        let fullscreenPushDownHeight: CGFloat = isFullscreenTitlebarRevealed ? 28.0 : 0.0

        ZStack(alignment: .top) {
            // Base layer: Left sidebar + Right main pane (kept mounted underneath detail view so sidebar & grid scroll positions are 100% preserved)
            HStack(spacing: 0) {
                // 1. Left sidebar column (permanently mounted to preserve exact scroll position)
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Spacer().frame(width: 72)
                        Spacer()
                    }
                    .frame(height: 38 + fullscreenPushDownHeight) // ★ [UI SIZING: Sidebar] Top inset height reserved for macOS window traffic-light buttons (pt)

                    UnifiedSidebarView(viewModel: viewModel)
                }
                .frame(width: viewModel.sidebarWidth)
                .background(Color(red: 0.14, green: 0.14, blue: 0.15))

                SidebarResizeDividerView(sidebarWidth: $viewModel.sidebarWidth) {
                    viewModel.saveWorkspaceState()
                }

                // 2. Right main pane (Row 1: Action toolbar, Row 2: Chrome-style multi-tab bar, Row 3: Active content)
                if let activeIdx {
                    let currentTab = viewModel.tabs[activeIdx]

                    VStack(spacing: 0) {
                        if fullscreenPushDownHeight > 0 {
                            Color(red: 0.16, green: 0.16, blue: 0.17)
                                .frame(height: fullscreenPushDownHeight)
                        }

                        TopActionToolbarView(
                            tab: $viewModel.tabs[activeIdx],
                            viewModel: viewModel,
                            needsTrafficLightLeadingSpace: false
                        )
                        .frame(height: 62) // ★ [UI SIZING: Top Toolbar & Tabs] Height of the top action toolbar row (pt)

                        Divider().overlay(Color.white.opacity(0.10))

                        ChromeStyleTabBarView(viewModel: viewModel)
                            .frame(height: 44) // ★ [UI SIZING: Top Toolbar & Tabs] Height of the second-row Chrome-style multi-tab bar (pt)

                        Divider().overlay(Color.white.opacity(0.10))

                        // Row 3: Active tab content area
                        ZStack {
                            if currentTab.filterScope == .peopleOverview {
                                PeopleThumbnailGridView(
                                    tab: $viewModel.tabs[activeIdx],
                                    viewModel: viewModel
                                )
                            } else if currentTab.filterScope.isFolderScope {
                                FolderAlbumCardsView(
                                    tab: $viewModel.tabs[activeIdx],
                                    viewModel: viewModel
                                )
                            } else if currentTab.filterScope == .map {
                                if currentTab.mapStyle == .grid {
                                    CustomizableTabGridView(
                                        tab: $viewModel.tabs[activeIdx],
                                        viewModel: viewModel
                                    )
                                } else {
                                    ZStack {
                                        PhotoClusterMapView(
                                            items: viewModel.filteredItems(for: currentTab),
                                            mapStyle: currentTab.mapStyle,
                                            zoomLevel: currentTab.mapZoomLevel,
                                            repository: viewModel.repository,
                                            onOpenAssetDetail: { assetID in
                                                viewModel.tabs[activeIdx].selectedAssetID = assetID
                                                viewModel.tabs[activeIdx].selectedAssetIDs = [assetID]
                                                withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                                                    viewModel.tabs[activeIdx].activeDetailAssetID = assetID
                                                }
                                                viewModel.saveWorkspaceState()
                                            }
                                        )

                                        if currentTab.showInspectorPanel,
                                           let selectedID = currentTab.selectedAssetID ?? currentTab.selectedAssetIDs.first ?? viewModel.filteredItems(for: currentTab).last?.id,
                                           let selectedItem = viewModel.allItems.first(where: { $0.id == selectedID }) {
                                            DraggableInspectorOverlayView(
                                                item: selectedItem,
                                                viewModel: viewModel,
                                                onClose: { viewModel.tabs[activeIdx].showInspectorPanel = false }
                                            )
                                        }
                                    }
                                }
                            } else if currentTab.isShowingLibraryYearOverview {
                                LibraryYearOverviewGridView(
                                    tab: $viewModel.tabs[activeIdx],
                                    viewModel: viewModel
                                )
                            } else {
                                CustomizableTabGridView(
                                    tab: $viewModel.tabs[activeIdx],
                                    viewModel: viewModel
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .opacity(isDetailActive ? 0.0 : 1.0)
            .allowsHitTesting(!isDetailActive)
            .ignoresSafeArea(.all, edges: .top)

            // Overlay layer: Full-window photo/video detail player (closing reveals the underlying sidebar & grid at their exact prior scroll positions)
            if let activeIdx {
                let currentTab = viewModel.tabs[activeIdx]
                if let detailID = currentTab.activeDetailAssetID,
                   let detailItem = viewModel.allItems.first(where: { $0.id == detailID }) {
                    let currentList = viewModel.pagedSlice(for: currentTab).pageItems
                    let pos = currentList.firstIndex(where: { $0.id == detailID })
                    let prevItem = (pos != nil && pos! > 0) ? currentList[pos! - 1] : nil
                    let nextItem = (pos != nil && pos! + 1 < currentList.count) ? currentList[pos! + 1] : nil

                    DetailMediaPlayerView(
                        item: detailItem,
                        prevItem: prevItem,
                        nextItem: nextItem,
                        viewModel: viewModel,
                        showInspector: $viewModel.tabs[activeIdx].showInspectorPanel,
                        onCloseDetail: {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                                viewModel.tabs[activeIdx].activeDetailAssetID = nil
                            }
                            viewModel.saveWorkspaceState()
                        },
                        onNavigateRelative: { direction in
                            viewModel.navigateDetailAsset(inTabIndex: activeIdx, direction: direction)
                        }
                    )
                    .ignoresSafeArea(.all, edges: .top)
                    .transition(.opacity)
                    .zIndex(10)
                }

                // Auto-revealing top toolbar + tab bar synchronized with the window traffic-light buttons when hovering near the top edge in detail view
                if isDetailActive && (isHoveringTopInFullscreen || isFullscreenTitlebarRevealed) {
                    VStack(spacing: 0) {
                        if fullscreenPushDownHeight > 0 {
                            Color.clear.frame(height: fullscreenPushDownHeight)
                        }

                        TopActionToolbarView(
                            tab: $viewModel.tabs[activeIdx],
                            viewModel: viewModel,
                            needsTrafficLightLeadingSpace: !isFullscreenTitlebarRevealed
                        )
                        .frame(height: 38)

                        Divider().overlay(Color.white.opacity(0.12))

                        ChromeStyleTabBarView(viewModel: viewModel)
                            .frame(height: 34)

                        Divider().overlay(Color.white.opacity(0.12))
                    }
                    .background(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.45), radius: 8, y: 3)
                    .ignoresSafeArea(.all, edges: .top)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
                }
            }

            WindowAndInputBridgeView(
                isDetailFullscreen: isDetailActive,
                isHoveringTopBarArea: $isHoveringTopInFullscreen,
                isFullscreenTitlebarRevealed: $isFullscreenTitlebarRevealed,
                onSpacebarPressed: {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                        viewModel.toggleSpacebarQuickLook()
                    }
                },
                onEscapePressed: {
                    if let idx = viewModel.activeTabIndex, viewModel.tabs[idx].activeDetailAssetID != nil {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                            viewModel.tabs[idx].activeDetailAssetID = nil
                        }
                        viewModel.saveWorkspaceState()
                    }
                },
                onArrowNavigate: { dir in
                    if let idx = viewModel.activeTabIndex {
                        viewModel.navigateDetailAsset(inTabIndex: idx, direction: dir)
                    }
                }
            )
            .frame(width: 0, height: 0)
        }
        .preferredColorScheme(.dark)
        .onChange(of: isDetailActive) { _, active in
            if !active {
                isHoveringTopInFullscreen = false
            }
        }
        .sheet(isPresented: $viewModel.showTagManagerSheet) {
            TagManagerModalSheetView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showSmartAlbumSheet) {
            SmartAlbumEditorSheetView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showNewAlbumSheet) {
            NewCustomAlbumSheetView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showNewFolderSheet) {
            NewCustomFolderSheetView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showDateTimeEditSheet) {
            DateTimeBatchEditSheetView(viewModel: viewModel)
        }
        .task {
            await viewModel.initializeLibrary()
        }
    }
}

/// Draggable resize handle on the right edge of the sidebar
private struct SidebarResizeDividerView: View {
    @Binding var sidebarWidth: CGFloat
    var onDragEnded: () -> Void
    @State private var dragStartWidth: CGFloat? = nil
    @State private var isHovering: Bool = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isHovering ? Color.accentColor.opacity(0.6) : Color.white.opacity(0.11))
                .frame(width: 1)
        }
        .frame(width: 6)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active:
                if !isHovering {
                    isHovering = true
                    NSCursor.resizeLeftRight.push()
                }
            case .ended:
                if isHovering {
                    isHovering = false
                    NSCursor.pop()
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if dragStartWidth == nil {
                        dragStartWidth = sidebarWidth
                    }
                    if let base = dragStartWidth {
                        sidebarWidth = max(170.0, min(380.0, base + value.translation.width)) // ★ [UI SIZING: Sidebar] Min (170pt) and max (380pt) draggable width for the left sidebar
                    }
                }
                .onEnded { _ in
                    dragStartWidth = nil
                    onDragEnded()
                }
        )
    }
}

// MARK: - 13. Top Action Toolbar & Chrome-Style Tab Bar

private struct TopActionToolbarView: View {
    @Binding var tab: BrowserTabState
    @Bindable var viewModel: PhotoWorkspaceViewModel
    var needsTrafficLightLeadingSpace: Bool

    private var isMapCanvasActive: Bool {
        tab.filterScope == .map && tab.mapStyle != .grid && tab.activeDetailAssetID == nil
    }

    var body: some View {
        HStack(spacing: 12) {
            if needsTrafficLightLeadingSpace {
                Spacer().frame(width: 70)
            }

            if !tab.navigationHistory.isEmpty || tab.activeDetailAssetID != nil || (tab.filterScope == .library && tab.selectedLibraryBucketID != nil) {
                Button {
                    if let idx = viewModel.activeTabIndex {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                            viewModel.navigateBack(inTab: idx)
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Back")
            }

            // 1. Left controls: Aspect ratio toggle (Square / Original) + Thumbnail zoom slider (hidden on the 3-column Library year overview)
            if tab.activeDetailAssetID == nil && !tab.isShowingLibraryYearOverview {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            tab.gridConfig.cropToSquare.toggle()
                        }
                        viewModel.saveWorkspaceState()
                    } label: {
                        Image(systemName: tab.gridConfig.cropToSquare ? "square.grid.2x2" : "aspectratio")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .help(tab.gridConfig.cropToSquare ? "Show Original Aspect Ratio" : "Show Square Grid")

                    HStack(spacing: 5) {
                        Button {
                            if isMapCanvasActive {
                                tab.mapZoomLevel = max(1.0, tab.mapZoomLevel - 1.0)
                            } else {
                                withAnimation(.interactiveSpring(response: 0.20, dampingFraction: 0.85)) {
                                    tab.gridConfig.columnCountDouble = min(10.0, tab.gridConfig.columnCountDouble + 1.0)
                                }
                            }
                            viewModel.saveWorkspaceState()
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Slider(
                            value: Binding(
                                get: {
                                    isMapCanvasActive ? tab.mapZoomLevel : (12.0 - tab.gridConfig.columnCountDouble)
                                },
                                set: { newVal in
                                    if isMapCanvasActive {
                                        tab.mapZoomLevel = max(1.0, min(12.0, newVal))
                                    } else {
                                        tab.gridConfig.columnCountDouble = max(2.0, min(10.0, 12.0 - newVal))
                                    }
                                    viewModel.saveWorkspaceState()
                                }
                            ),
                            in: isMapCanvasActive ? 1.0...12.0 : 2.0...10.0
                        )
                        .controlSize(.small)
                        .frame(width: 92) // ★ [UI SIZING: Top Toolbar & Tabs] Width of the top-left thumbnail zoom slider (pt)

                        Button {
                            if isMapCanvasActive {
                                tab.mapZoomLevel = min(12.0, tab.mapZoomLevel + 1.0)
                            } else {
                                withAnimation(.interactiveSpring(response: 0.20, dampingFraction: 0.85)) {
                                    tab.gridConfig.columnCountDouble = max(2.0, tab.gridConfig.columnCountDouble - 1.0)
                                }
                            }
                            viewModel.saveWorkspaceState()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            // 2. Center controls: Map mode picker or 2,000-item page number buttons (1, 2, 3...)
            if tab.filterScope == .map {
                Picker("", selection: $tab.mapStyle) {
                    ForEach(MapDisplayStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 230)
            } else if tab.isShowingLibraryYearOverview {
                Text("Library")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
            } else if tab.activeDetailAssetID == nil && !tab.filterScope.isFolderScope && tab.filterScope != .peopleOverview {
                let slice = viewModel.pagedSlice(for: tab)
                let showPageNumbers = (tab.filterScope == .library && tab.selectedLibraryBucketID != nil) || slice.totalPages > 1
                HStack(spacing: 10) {
                    Text(slice.activeBucketTitle ?? tab.filterScope.displayTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)

                    if showPageNumbers {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) { // ★ [UI SIZING: Top Toolbar & Tabs] Spacing between page number buttons (1, 2, 3...) in the top bar (pt)
                                ForEach(0..<slice.totalPages, id: \.self) { pageIdx in
                                    let isCurrentPage = (pageIdx == slice.safePageIndex)
                                    Button {
                                        tab.currentPageIndex = pageIdx
                                        viewModel.saveWorkspaceState()
                                    } label: {
                                        Text("\(pageIdx + 1)")
                                            .font(.system(size: 13.5, weight: isCurrentPage ? .bold : .medium)) // ★ [UI SIZING: Top Toolbar & Tabs] Font size of page number buttons (1, 2, 3...) (pt)
                                            .monospacedDigit()
                                            .foregroundStyle(isCurrentPage ? .white : .white.opacity(0.72))
                                            .padding(.horizontal, 8) // ★ [UI SIZING: Top Toolbar & Tabs] Horizontal padding of page number buttons
                                            .padding(.vertical, 3)   // ★ [UI SIZING: Top Toolbar & Tabs] Vertical padding of page number buttons
                                            .background(
                                                RoundedRectangle(cornerRadius: 5)
                                                    .fill(isCurrentPage ? Color.accentColor : Color.white.opacity(0.08))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxWidth: 360)
                    }
                }
            } else {
                Text(tab.filterScope.displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()

            // 3. Right controls: Favorite toggle, Face Name Tag toggle, Info (i) button, and Search field
            HStack(spacing: 11) {
                if let targetID = tab.activeDetailAssetID ?? tab.selectedAssetID ?? tab.selectedAssetIDs.first,
                   let currentItem = viewModel.allItems.first(where: { $0.id == targetID }) {
                    Button {
                        viewModel.toggleFavorite(for: targetID)
                    } label: {
                        Image(systemName: currentItem.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(currentItem.isFavorite ? .white : .secondary)
                            .font(.system(size: 13.5))
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Favorite")
                }

                if tab.activeDetailAssetID != nil {
                    Button {
                        viewModel.showPersonNameTagsInDetail.toggle()
                        viewModel.saveWorkspaceState()
                    } label: {
                        Image(systemName: viewModel.showPersonNameTagsInDetail ? "person.crop.rectangle.fill" : "person.crop.rectangle")
                            .font(.system(size: 13.5))
                            .foregroundStyle(viewModel.showPersonNameTagsInDetail ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Show/Hide Face Name Tags (⌘P)")
                }

                Button {
                    tab.showInspectorPanel.toggle()
                    viewModel.saveWorkspaceState()
                } label: {
                    Image(systemName: tab.showInspectorPanel ? "info.circle.fill" : "info.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(tab.showInspectorPanel ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help("Show/Hide Info Panel (⌘I)")

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11.5))
                    TextField("Search", text: $tab.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !tab.searchQuery.isEmpty {
                        Button {
                            tab.searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(width: 385) // ★ [UI SIZING: Top Toolbar & Tabs] Width of the top-right Search field (pt)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
                        )
                )
            }
        }
        .padding(.horizontal, 12)
        .background(Color(red: 0.16, green: 0.16, blue: 0.17))
    }
}

/// Chrome-style dynamic tab bar that spans the full window width and automatically shrinks tabs as more are opened
private struct ChromeStyleTabBarView: View {
    @Bindable var viewModel: PhotoWorkspaceViewModel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(viewModel.tabs) { tab in
                let isSelected = (tab.id == viewModel.activeTabID)
                HStack(spacing: 6) {
                    Image(systemName: tab.activeDetailAssetID != nil ? "photo.fill" : tab.filterScope.systemIcon)
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                    Text(tab.tabTitle)
                        .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular)) // ★ [UI SIZING: Top Toolbar & Tabs] Font size of tab titles inside the Chrome-style tab bar (pt)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 2)

                    if viewModel.tabs.count > 1 {
                        Button {
                            viewModel.closeTab(id: tab.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(3)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.white.opacity(0.26) : Color.white.opacity(0.07), lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.activeTabID = tab.id
                    viewModel.saveWorkspaceState()
                }
            }

            Button {
                viewModel.openNewTab(scope: .library)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 26, height: 24)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("New Tab (⌘T)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(red: 0.16, green: 0.16, blue: 0.17))
    }
}

// MARK: - 14. Sidebar View (Compact Row Spacing & Persistent Scroll Position)

private struct UnifiedSidebarView: View {
    @Bindable var viewModel: PhotoWorkspaceViewModel

    var body: some View {
        List {
            Section("Photos") {
                sidebarEntry(title: "Library", icon: "photo.on.rectangle", scope: .library)
                sidebarEntry(title: "Favorites", icon: "heart", scope: .favorites)
                sidebarEntry(title: "People", icon: "person.crop.circle", scope: .peopleOverview)
                sidebarEntry(title: "Map", icon: "map", scope: .map)
                sidebarEntry(title: "Imports", icon: "square.and.arrow.down", scope: .imports)
            }

            Section("Collections") {
                DisclosureGroup(
                    isExpanded: sectionBinding("mediaTypes")
                ) {
                    sidebarEntry(title: "Videos", icon: "video", scope: .videos)
                    sidebarEntry(title: "Selfies", icon: "camera.aperture", scope: .selfies)
                    sidebarEntry(title: "Live Photos", icon: "livephoto", scope: .livePhotos)
                    sidebarEntry(title: "Portrait", icon: "cube", scope: .portrait)
                    sidebarEntry(title: "Panoramas", icon: "pano", scope: .panoramas)
                    sidebarEntry(title: "Screenshots", icon: "camera.viewfinder", scope: .screenshots)
                    sidebarEntry(title: "Animated", icon: "square.stack.3d.forward.dottedline", scope: .animated)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 16)
                        Text("Media Types")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .padding(.vertical, 1.0)
                }
                .listRowInsets(EdgeInsets(top: 0.5, leading: 6, bottom: 0.5, trailing: 6))

                DisclosureGroup(
                    isExpanded: sectionBinding("albums")
                ) {
                    ForEach(viewModel.systemAlbumTree) { node in
                        SidebarAlbumTreeNodeRow(node: node, viewModel: viewModel)
                    }

                    ForEach(viewModel.customFolders) { folder in
                        SidebarCustomFolderRow(folder: folder, viewModel: viewModel)
                    }

                    ForEach(viewModel.customAlbums.filter { $0.parentFolderID == nil && $0.parentSystemFolderIdentifier == nil }) { album in
                        sidebarEntry(
                            title: album.name,
                            icon: "rectangle.stack",
                            scope: .customAlbum(id: album.id, title: album.name)
                        )
                    }

                    ForEach(viewModel.smartAlbums) { smart in
                        sidebarEntry(
                            title: smart.name,
                            icon: "gearshape",
                            scope: .smartAlbum(id: smart.id, title: smart.name)
                        )
                        .contextMenu {
                            Button("Edit Smart Album Rules...") {
                                viewModel.editingSmartAlbum = smart
                                viewModel.showSmartAlbumSheet = true
                            }
                        }
                    }
                } label: {
                    HoverAddHeaderRow(
                        title: "Albums",
                        systemImage: "rectangle.stack",
                        isSelected: false
                    ) {
                        Button("New Album...") {
                            viewModel.pendingNewAlbumParentSystemFolderID = nil
                            viewModel.pendingNewAlbumParentCustomFolderID = nil
                            viewModel.showNewAlbumSheet = true
                        }
                        Button("New Smart Album...") {
                            viewModel.editingSmartAlbum = nil
                            viewModel.showSmartAlbumSheet = true
                        }
                        Button("New Folder...") {
                            viewModel.showNewFolderSheet = true
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 0.5, leading: 6, bottom: 0.5, trailing: 6))
            }
        }
        .listStyle(.sidebar)
        .environment(\.defaultMinListRowHeight, 20) // ★ [UI SIZING: Sidebar] Minimum row height in the sidebar (smaller = tighter rows, larger = more spacing)
        .scrollContentBackground(.hidden)
    }

    private func sectionBinding(_ key: String) -> Binding<Bool> {
        Binding(
            get: { viewModel.expandedSidebarSections.contains(key) },
            set: { isExpanded in
                if isExpanded {
                    viewModel.expandedSidebarSections.insert(key)
                } else {
                    viewModel.expandedSidebarSections.remove(key)
                }
                viewModel.saveWorkspaceState()
            }
        )
    }

    /// Blue accent icons, crisp white labels, and compact vertical row spacing
    @ViewBuilder
    fileprivate func sidebarEntry(
        title: String,
        icon: String,
        scope: TabFilterScope
    ) -> some View {
        let isCurrent = (viewModel.activeTabIndex != nil && viewModel.tabs[viewModel.activeTabIndex!].filterScope == scope)
        HStack(spacing: 7) { // ★ [UI SIZING: Sidebar] Horizontal spacing between sidebar icon and label (pt)
            Image(systemName: icon)
                .font(.system(size: 12.5, weight: .regular)) // ★ [UI SIZING: Sidebar] Sidebar icon font size (pt)
                .foregroundStyle(Color.accentColor)
                .frame(width: 16)
            Text(title)
                .font(.system(size: 12.5, weight: isCurrent ? .semibold : .regular)) // ★ [UI SIZING: Sidebar] Sidebar item label font size (pt)
                .foregroundStyle(.white.opacity(isCurrent ? 0.98 : 0.88))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 0.8) // ★ [UI SIZING: Sidebar] Vertical inner padding per sidebar row (adjust to tighten/loosen row spacing)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isCurrent ? Color.white.opacity(0.15) : Color.clear)
        )
        .listRowInsets(EdgeInsets(top: 0.5, leading: 6, bottom: 0.5, trailing: 6)) // ★ [UI SIZING: Sidebar] List row insets (top/bottom: 0.5, leading/trailing: 6)
        .listRowBackground(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if let idx = viewModel.activeTabIndex {
                viewModel.navigateToScope(inTab: idx, scope: scope)
            }
        }
        .contextMenu {
            Button("Open in New Tab") {
                viewModel.openNewTab(scope: scope)
            }
        }
    }
}

private struct HoverAddHeaderRow<MenuItems: View>: View {
    let title: String
    let systemImage: String
    var isSelected: Bool = false
    var onSelectRow: (() -> Void)? = nil
    @ViewBuilder var menuItems: () -> MenuItems

    @State private var isHovering: Bool = false

    var body: some View {
        HStack(spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(.white.opacity(isSelected ? 0.98 : 0.90))
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onSelectRow?()
            }
            Spacer()
            if isHovering {
                Menu {
                    menuItems()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Add")
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 1.0)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active: isHovering = true
            case .ended: isHovering = false
            }
        }
    }
}

private struct SidebarAlbumTreeNodeRow: View {
    let node: AlbumTreeNode
    @Bindable var viewModel: PhotoWorkspaceViewModel

    var body: some View {
        if node.isFolder {
            let folderScope = TabFilterScope.systemFolder(id: node.id, title: node.title)
            let isFolderSelected = (viewModel.activeTabIndex != nil && viewModel.tabs[viewModel.activeTabIndex!].filterScope == folderScope)

            DisclosureGroup(
                isExpanded: Binding(
                    get: { viewModel.expandedFolderIDs.contains(node.id) },
                    set: { expanded in
                        if expanded {
                            viewModel.expandedFolderIDs.insert(node.id)
                        } else {
                            viewModel.expandedFolderIDs.remove(node.id)
                        }
                        viewModel.saveWorkspaceState()
                    }
                )
            ) {
                ForEach(node.children) { child in
                    SidebarAlbumTreeNodeRow(node: child, viewModel: viewModel)
                }
                ForEach(viewModel.customAlbums.filter { $0.parentSystemFolderIdentifier == node.id }) { custom in
                    SidebarAlbumLeafRow(
                        title: custom.name,
                        icon: "rectangle.stack",
                        scope: .customAlbum(id: custom.id, title: custom.name),
                        viewModel: viewModel
                    )
                }
            } label: {
                HoverAddHeaderRow(
                    title: node.title,
                    systemImage: "folder",
                    isSelected: isFolderSelected,
                    onSelectRow: {
                        if let idx = viewModel.activeTabIndex {
                            viewModel.navigateToScope(inTab: idx, scope: folderScope)
                        }
                    }
                ) {
                    Button("New Album in Folder...") {
                        viewModel.pendingNewAlbumParentSystemFolderID = node.id
                        viewModel.pendingNewAlbumParentCustomFolderID = nil
                        viewModel.showNewAlbumSheet = true
                    }
                    Button("New Smart Album in Folder...") {
                        viewModel.editingSmartAlbum = nil
                        viewModel.showSmartAlbumSheet = true
                    }
                    Divider()
                    Button("Open Folder in New Tab") {
                        viewModel.openNewTab(scope: folderScope)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 0.5, leading: 6, bottom: 0.5, trailing: 6))
        } else {
            SidebarAlbumLeafRow(
                title: node.title,
                icon: node.isSmartAlbum ? "gearshape" : "rectangle.stack",
                scope: .systemAlbum(id: node.id, title: node.title),
                viewModel: viewModel
            )
        }
    }
}

private struct SidebarCustomFolderRow: View {
    let folder: CustomFolderDefinition
    @Bindable var viewModel: PhotoWorkspaceViewModel

    var body: some View {
        let key = folder.id.uuidString
        let folderScope = TabFilterScope.customFolder(id: folder.id, title: folder.name)
        let isFolderSelected = (viewModel.activeTabIndex != nil && viewModel.tabs[viewModel.activeTabIndex!].filterScope == folderScope)

        DisclosureGroup(
            isExpanded: Binding(
                get: { viewModel.expandedFolderIDs.contains(key) },
                set: { exp in
                    if exp { viewModel.expandedFolderIDs.insert(key) }
                    else { viewModel.expandedFolderIDs.remove(key) }
                    viewModel.saveWorkspaceState()
                }
            )
        ) {
            ForEach(viewModel.customAlbums.filter { $0.parentFolderID == folder.id }) { album in
                SidebarAlbumLeafRow(
                    title: album.name,
                    icon: "rectangle.stack",
                    scope: .customAlbum(id: album.id, title: album.name),
                    viewModel: viewModel
                )
            }
        } label: {
            HoverAddHeaderRow(
                title: folder.name,
                systemImage: "folder",
                isSelected: isFolderSelected,
                onSelectRow: {
                    if let idx = viewModel.activeTabIndex {
                        viewModel.navigateToScope(inTab: idx, scope: folderScope)
                    }
                }
            ) {
                Button("New Album in This Folder...") {
                    viewModel.pendingNewAlbumParentCustomFolderID = folder.id
                    viewModel.pendingNewAlbumParentSystemFolderID = nil
                    viewModel.showNewAlbumSheet = true
                }
                Button("New Smart Album...") {
                    viewModel.editingSmartAlbum = nil
                    viewModel.showSmartAlbumSheet = true
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 0.5, leading: 6, bottom: 0.5, trailing: 6))
    }
}

private struct SidebarAlbumLeafRow: View {
    let title: String
    var icon: String = "rectangle.stack"
    let scope: TabFilterScope
    @Bindable var viewModel: PhotoWorkspaceViewModel

    var body: some View {
        let isCurrent = (viewModel.activeTabIndex != nil && viewModel.tabs[viewModel.activeTabIndex!].filterScope == scope)
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12.5)) // ★ [UI SIZING: Sidebar] Album row icon size (pt)
                .foregroundStyle(Color.accentColor)
                .frame(width: 16)
            Text(title)
                .font(.system(size: 13.5, weight: isCurrent ? .semibold : .regular)) // ★ [UI SIZING: Sidebar] Album row title font size (pt)
                .foregroundStyle(.white.opacity(isCurrent ? 0.98 : 0.88))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 1.3) // ★ [UI SIZING: Sidebar] Vertical padding for album rows in the sidebar
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isCurrent ? Color.white.opacity(0.15) : Color.clear)
        )
        .listRowInsets(EdgeInsets(top: 0.5, leading: 6, bottom: 0.5, trailing: 6))
        .listRowBackground(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if let idx = viewModel.activeTabIndex {
                viewModel.navigateToScope(inTab: idx, scope: scope)
            }
        }
        .contextMenu {
            Button("Open in New Tab") {
                viewModel.openNewTab(scope: scope)
            }
        }
    }
}

// MARK: - 15. Folder Album Cards View (ZGENERICALBUM.ZCUSTOMKEYASSET / ZKEYASSET Cover Support)

private struct FolderAlbumCardsView: View {
    @Binding var tab: BrowserTabState
    @Bindable var viewModel: PhotoWorkspaceViewModel

    var body: some View {
        let cards = viewModel.childAlbumCards(for: tab.filterScope)
        let cardWidth: CGFloat = max(210, min(340, 1450.0 / CGFloat(max(3, tab.gridConfig.columnCount)))) // ★ [UI SIZING: Folder Album Cards] Width of album cards inside a folder view (min: 210pt, max: 340pt)

        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tab.filterScope.displayTitle)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                        Text("\(cards.count) \(cards.count == 1 ? "Album" : "Albums")")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 16)

                    if cards.isEmpty {
                        ContentUnavailableView(
                            "No Albums in This Folder",
                            systemImage: "folder",
                            description: Text("Click the + button next to the folder in the sidebar to create a new album.")
                        )
                        .padding(.top, 60)
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: cardWidth, maximum: cardWidth + 40), spacing: 20)],
                            alignment: .leading,
                            spacing: 20
                        ) {
                            ForEach(cards) { card in
                                FolderAlbumCollageCardCell(
                                    card: card,
                                    cardWidth: cardWidth,
                                    isSelected: tab.selectedFolderAlbumID == card.id,
                                    viewModel: viewModel
                                )
                                .onTapGesture(count: 2) {
                                    if let idx = viewModel.activeTabIndex {
                                        viewModel.navigateToScope(inTab: idx, scope: card.scope)
                                    }
                                }
                                .onTapGesture(count: 1) {
                                    tab.selectedFolderAlbumID = card.id
                                    if let keyOrFirst = card.keyAsset ?? card.previewAssets.first {
                                        tab.selectedAssetID = keyOrFirst.id
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 30)
                    }
                }
            }

            if tab.showInspectorPanel,
               let selectedID = tab.selectedAssetID,
               let item = viewModel.allItems.first(where: { $0.id == selectedID }) {
                DraggableInspectorOverlayView(
                    item: item,
                    viewModel: viewModel,
                    onClose: { tab.showInspectorPanel = false }
                )
            }
        }
    }
}

private struct FolderAlbumCollageCardCell: View {
    let card: PhotoWorkspaceViewModel.FolderAlbumCardItem
    let cardWidth: CGFloat
    let isSelected: Bool
    @Bindable var viewModel: PhotoWorkspaceViewModel

    @State private var thumb0: NSImage?

    var body: some View {
        let innerPadding: CGFloat = 12                              // ★ [UI SIZING: Folder Album Cards] Inner padding of the album card frame (pt)
        let contentWidth = max(120, cardWidth - innerPadding * 2)
        let imageHeight = floor(contentWidth * 0.78)                // ★ [UI SIZING: Folder Album Cards] Thumbnail height-to-width ratio (0.78 = landscape, 1.0 = square)
        let coverAssetID = card.keyAsset?.id ?? card.previewAssets.first?.id ?? ""

        VStack(alignment: .leading, spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.06))
                if let thumb0 {
                    Image(nsImage: thumb0)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: contentWidth, height: imageHeight)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: contentWidth, height: imageHeight)

            Text("\(card.title) · \(card.count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .padding(.leading, 2)
        }
        .padding(innerPadding)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.20, green: 0.20, blue: 0.22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.08), lineWidth: isSelected ? 2.5 : 1.0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .task(id: "\(card.id)_\(coverAssetID)") {
            loadCoverThumbnail()
        }
    }

    private func loadCoverThumbnail() {
        guard let coverAsset = card.keyAsset ?? card.previewAssets.first else { return }
        let phAsset = viewModel.repository.phAsset(for: coverAsset.id)
        let localURL = viewModel.repository.localMediaURL(for: coverAsset.id)
        _ = viewModel.thumbnailCache.requestThumbnail(
            for: phAsset,
            fallbackFileURL: localURL,
            targetSize: CGSize(width: 480, height: 480),
            cropToSquare: true
        ) { img, _ in
            if let img {
                self.thumb0 = img
            }
        }
    }
}

// MARK: - 15B. Library 3-Column Year Overview Grid View (Double-Click Year Card to Open First 2,000 Photos)

private struct LibraryYearOverviewGridView: View {
    @Binding var tab: BrowserTabState
    @Bindable var viewModel: PhotoWorkspaceViewModel
    @State private var didPerformInitialScrollToBottom: Bool = false

    var body: some View {
        let buckets = viewModel.libraryYearBuckets(for: tab)
        let allAssets = buckets.flatMap(\.assets)
        let photoCount = allAssets.filter { !$0.isVideo }.count
        let videoCount = allAssets.filter(\.isVideo).count
        let countSummary = PhotoWorkspaceViewModel.formatMediaCountSummary(photoCount: photoCount, videoCount: videoCount)

        GeometryReader { geo in
            let horizontalPad: CGFloat = max(64.0, min(198.0, geo.size.width * 0.095)) // ★ [UI SIZING: Library Year Grid] Horizontal outer margins for the 3-column year overview grid (pt)
            let spacing: CGFloat = 32.0                                              // ★ [UI SIZING: Library Year Grid] Spacing between year overview cards (pt)
            let colCount = 3                                                         // ★ [UI SIZING: Library Year Grid] Number of columns in the Library year overview grid (default: 3)

            ZStack(alignment: .topLeading) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack(alignment: .bottom) {
                                Text("Library")
                                    .font(.system(size: 32, weight: .bold)) // ★ [UI SIZING: Library Year Grid] Font size of the top "Library" header title (pt)
                                    .foregroundStyle(.white)
                                Spacer()
                                FilterPopoverButtonView(tab: $tab, viewModel: viewModel)
                            }
                            .padding(.horizontal, horizontalPad)
                            .padding(.top, 18)

                            if buckets.isEmpty {
                                ContentUnavailableView(
                                    "No Matching Photos",
                                    systemImage: "photo.on.rectangle",
                                    description: Text("There are no photos in the library or no items match the current filter.")
                                )
                                .padding(.top, 60)
                            } else {
                                LazyVGrid(
                                    columns: Array(
                                        repeating: GridItem(.flexible(), spacing: spacing),
                                        count: colCount
                                    ),
                                    spacing: spacing
                                ) {
                                    ForEach(buckets) { bucket in
                                        LibraryYearSquareCardCell(
                                            bucket: bucket,
                                            isSelected: tab.selectedFolderAlbumID == bucket.id,
                                            viewModel: viewModel,
                                            onSingleClick: {
                                                tab.selectedFolderAlbumID = bucket.id
                                                if let key = bucket.keyAsset {
                                                    tab.selectedAssetID = key.id
                                                }
                                            },
                                            onDoubleClick: {
                                                withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                                                    tab.selectedLibraryBucketID = bucket.id
                                                    tab.currentPageIndex = 0
                                                }
                                                viewModel.saveWorkspaceState()
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, horizontalPad)

                                if !countSummary.isEmpty {
                                    HStack {
                                        Spacer()
                                        Text(countSummary)
                                            .font(.system(size: 13, weight: .semibold))
                                            .monospacedDigit()
                                            .foregroundStyle(.primary.opacity(0.85))
                                        Spacer()
                                    }
                                    .padding(.vertical, 24)
                                }
                            }

                            Color.clear
                                .frame(height: 1)
                                .id("LIBRARY_OVERVIEW_BOTTOM_ANCHOR")
                        }
                    }
                    .onAppear {
                        if !didPerformInitialScrollToBottom && !buckets.isEmpty {
                            didPerformInitialScrollToBottom = true
                            proxy.scrollTo("LIBRARY_OVERVIEW_BOTTOM_ANCHOR", anchor: .bottom)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                proxy.scrollTo("LIBRARY_OVERVIEW_BOTTOM_ANCHOR", anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: buckets.count) { oldCount, newCount in
                        if newCount > 0 && (!didPerformInitialScrollToBottom || oldCount == 0) {
                            didPerformInitialScrollToBottom = true
                            proxy.scrollTo("LIBRARY_OVERVIEW_BOTTOM_ANCHOR", anchor: .bottom)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                proxy.scrollTo("LIBRARY_OVERVIEW_BOTTOM_ANCHOR", anchor: .bottom)
                            }
                        }
                    }
                }

                if tab.showInspectorPanel,
                   let selectedID = tab.selectedAssetID ?? viewModel.allItems.last?.id,
                   let item = viewModel.allItems.first(where: { $0.id == selectedID }) {
                    DraggableInspectorOverlayView(
                        item: item,
                        viewModel: viewModel,
                        onClose: { tab.showInspectorPanel = false }
                    )
                }
            }
        }
    }
}

private struct LibraryYearSquareCardCell: View {
    let bucket: PhotoWorkspaceViewModel.LibraryYearBucket
    let isSelected: Bool
    @Bindable var viewModel: PhotoWorkspaceViewModel
    var onSingleClick: () -> Void
    var onDoubleClick: () -> Void

    @State private var coverThumbnail: NSImage?

    var body: some View {
        let coverID = bucket.keyAsset?.id ?? ""

        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.06))

                    if let coverThumbnail {
                        Image(nsImage: coverThumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    // Bottom gradient + Year title & photo count
                    HStack(alignment: .firstTextBaseline) {
                        Text(bucket.title)
                            .font(.system(size: 22, weight: .bold))      // ★ [UI SIZING: Library Year Grid] Font size of the year label at the bottom-left of each card (pt)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(bucket.count)")
                            .font(.system(size: 16, weight: .semibold))  // ★ [UI SIZING: Library Year Grid] Font size of the item count at the bottom-right of each card (pt)
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .padding(.horizontal, 12)                            // ★ [UI SIZING: Library Year Grid] Horizontal padding of the year & count overlay labels
                    .padding(.vertical, 10)                              // ★ [UI SIZING: Library Year Grid] Vertical padding of the year & count overlay labels
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [.black.opacity(0.78), .clear],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.12), lineWidth: isSelected ? 2.5 : 1.0)
                )
                .contentShape(RoundedRectangle(cornerRadius: 10))
                .gesture(
                    TapGesture(count: 2).onEnded {
                        onDoubleClick()
                    }
                    .exclusively(before: TapGesture(count: 1).onEnded {
                        onSingleClick()
                    })
                )
            }
            .aspectRatio(0.74, contentMode: .fit) // ★ [UI SIZING: Library Year Grid] Aspect ratio of year overview cards (1.0 = square, 0.74 = portrait)
        }
        .task(id: "\(bucket.id)_\(coverID)") {
            guard let cover = bucket.keyAsset else { return }
            let phAsset = viewModel.repository.phAsset(for: cover.id)
            let localURL = viewModel.repository.localMediaURL(for: cover.id)
            _ = viewModel.thumbnailCache.requestThumbnail(
                for: phAsset,
                fallbackFileURL: localURL,
                targetSize: CGSize(width: 512, height: 512),
                cropToSquare: true
            ) { img, _ in
                if let img {
                    self.coverThumbnail = img
                }
            }
        }
    }
}

// MARK: - 16. People Overview Grid View & Individual Person Portrait Header

private struct PeopleThumbnailGridView: View {
    @Binding var tab: BrowserTabState
    @Bindable var viewModel: PhotoWorkspaceViewModel

    var body: some View {
        let namedPeople = viewModel.peopleEntries.filter { !$0.isUnnamed }
        let favoritePeople = namedPeople.filter(\.isFavorite)
        let regularPeople = namedPeople.filter { !$0.isFavorite }

        let regularColsCount = max(3, min(6, tab.gridConfig.columnCount)) // ★ [UI SIZING: People Grid & Header] Column count for "All People" (min: 3, max: 6)
        let favoriteColsCount = max(2, regularColsCount - 1)              // ★ [UI SIZING: People Grid & Header] Column count for "Favorites" row (1 fewer column so cards appear larger)

        GeometryReader { geo in
            let horizontalMargin: CGFloat = max(96.0, min(160.0, geo.size.width * 0.095)) // ★ [UI SIZING: People Grid & Header] Horizontal outer margins for the People grid view (pt)

            ZStack(alignment: .topLeading) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(alignment: .bottom) {
                            Text("People")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            HStack(spacing: 6) {
                                Text("Sort:")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Picker("", selection: Binding(
                                    get: { viewModel.peopleSortOrder },
                                    set: { newOrder in
                                        viewModel.peopleSortOrder = newOrder
                                        viewModel.rebuildPeopleEntries()
                                        viewModel.saveWorkspaceState()
                                    }
                                )) {
                                    ForEach(PeopleSortOrder.allCases) { order in
                                        Text(order.rawValue).tag(order)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(width: 145)
                            }
                        }
                        .padding(.horizontal, horizontalMargin)
                        .padding(.top, 18)

                        if namedPeople.isEmpty {
                            ContentUnavailableView(
                                "No Named People Found",
                                systemImage: "person.2.slash",
                                description: Text("People named in the macOS Photos app (Photos.sqlite) will automatically appear here.")
                            )
                            .padding(.top, 60)
                        } else {
                            // 1. Favorite People section (pinned at top with 1 fewer column for larger portrait cards)
                            if !favoritePeople.isEmpty {
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white.opacity(0.9))
                                        Text("Favorites")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white.opacity(0.92))
                                    }
                                    .padding(.horizontal, horizontalMargin)

                                    LazyVGrid(
                                        columns: Array(
                                            repeating: GridItem(.flexible(), spacing: 20), // ★ [UI SIZING: People Grid & Header] Horizontal spacing between Favorite people cards (pt)
                                            count: favoriteColsCount
                                        ),
                                        spacing: 22 // ★ [UI SIZING: People Grid & Header] Vertical spacing between Favorite people cards (pt)
                                    ) {
                                        ForEach(favoritePeople) { entry in
                                            PersonAvatarCardView(
                                                entry: entry,
                                                isLargeFavoriteCard: true,
                                                viewModel: viewModel
                                            ) {
                                                if let idx = viewModel.activeTabIndex {
                                                    viewModel.navigateToScope(inTab: idx, scope: .person(name: entry.name))
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, horizontalMargin)
                                }
                            }

                            if !favoritePeople.isEmpty && !regularPeople.isEmpty {
                                Divider()
                                    .overlay(Color.white.opacity(0.10))
                                    .padding(.horizontal, horizontalMargin)
                            }

                            // 2. All People section (vertical portrait cards in standard column grid)
                            if !regularPeople.isEmpty {
                                VStack(alignment: .leading, spacing: 14) {
                                    if !favoritePeople.isEmpty {
                                        Text("All People")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white.opacity(0.85))
                                            .padding(.horizontal, horizontalMargin)
                                    }

                                    LazyVGrid(
                                        columns: Array(
                                            repeating: GridItem(.flexible(), spacing: 18), // ★ [UI SIZING: People Grid & Header] Horizontal spacing between regular people cards (pt)
                                            count: regularColsCount
                                        ),
                                        spacing: 20 // ★ [UI SIZING: People Grid & Header] Vertical spacing between regular people cards (pt)
                                    ) {
                                        ForEach(regularPeople) { entry in
                                            PersonAvatarCardView(
                                                entry: entry,
                                                isLargeFavoriteCard: false,
                                                viewModel: viewModel
                                            ) {
                                                if let idx = viewModel.activeTabIndex {
                                                    viewModel.navigateToScope(inTab: idx, scope: .person(name: entry.name))
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, horizontalMargin)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 34)
                }

                if tab.showInspectorPanel,
                   let selectedID = tab.selectedAssetID ?? viewModel.allItems.last?.id,
                   let item = viewModel.allItems.first(where: { $0.id == selectedID }) {
                    DraggableInspectorOverlayView(
                        item: item,
                        viewModel: viewModel,
                        onClose: { tab.showInspectorPanel = false }
                    )
                }
            }
        }
    }
}

/// Vertical portrait card for People grid (displays full-head portrait thumbnail and person name)
private struct PersonAvatarCardView: View {
    let entry: PhotoWorkspaceViewModel.PersonSummaryEntry
    let isLargeFavoriteCard: Bool
    @Bindable var viewModel: PhotoWorkspaceViewModel
    var onSelect: () -> Void

    @State private var avatar: NSImage?
    @State private var showRenamePopover: Bool = false
    @State private var newNameInput: String = ""
    @State private var isHovering: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            GeometryReader { geo in
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))

                    if let avatar {
                        Image(nsImage: avatar)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: isLargeFavoriteCard ? 46 : 34))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    // Bottom gradient + person name overlay
                    Text(entry.name)
                        .font(.system(size: isLargeFavoriteCard ? 15 : 13, weight: .bold)) // ★ [UI SIZING: People Grid & Header] Person name font size on people cards (Favorite: 15pt, Regular: 13pt)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(
                                colors: [.black.opacity(0.75), .clear],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )

                    // Subtle white favorite heart button at top-right on hover
                    VStack {
                        HStack {
                            Spacer()
                            if entry.isFavorite || isHovering {
                                Button {
                                    viewModel.toggleFavoritePerson(entry.name)
                                } label: {
                                    Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                                        .font(.system(size: isLargeFavoriteCard ? 11.5 : 10.5, weight: .semibold))
                                        .foregroundStyle(.white.opacity(entry.isFavorite ? 0.95 : 0.80))
                                        .shadow(color: .black.opacity(0.55), radius: 2, y: 1)
                                        .padding(6)
                                }
                                .buttonStyle(.plain)
                                .help(entry.isFavorite ? "Remove from Favorite People" : "Add to Favorite People")
                            }
                        }
                        .padding(6)
                        Spacer()
                    }
                }
            }
            // Vertical portrait aspect ratio (width:height = 0.74 : 1.0)
            .aspectRatio(0.74, contentMode: .fit)          // ★ [UI SIZING: People Grid & Header] Portrait aspect ratio of people cards (width/height; 1.0 = square)
            .clipShape(RoundedRectangle(cornerRadius: 14)) // ★ [UI SIZING: People Grid & Header] Corner radius of people portrait cards (pt)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active: isHovering = true
            case .ended: isHovering = false
            }
        }
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button(entry.isFavorite ? "Remove from Favorite People" : "Favorite This Person") {
                viewModel.toggleFavoritePerson(entry.name)
            }
            Divider()
            Button("Rename Person...") {
                newNameInput = entry.name
                showRenamePopover = true
            }
        }
        .popover(isPresented: $showRenamePopover) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Set Person Name")
                    .font(.system(size: 12, weight: .semibold))
                TextField("Enter Name", text: $newNameInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                HStack {
                    Spacer()
                    Button("Cancel") { showRenamePopover = false }
                    Button("Save") {
                        let trimmed = newNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            viewModel.renamedPeopleMap[entry.name] = trimmed
                            if let fav = viewModel.favoritePeopleByName[entry.name] {
                                viewModel.favoritePeopleByName[trimmed] = fav
                            }
                            for i in viewModel.allItems.indices {
                                for f in viewModel.allItems[i].faces.indices {
                                    if viewModel.allItems[i].faces[f].displayName == entry.name {
                                        viewModel.allItems[i].faces[f].displayName = trimmed
                                    }
                                }
                            }
                            viewModel.invalidateFilterCache()
                            viewModel.rebuildPeopleEntries()
                            viewModel.saveWorkspaceState()
                        }
                        showRenamePopover = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(10)
        }
        .task(id: "\(entry.name)_\(entry.keyAssetID)_\(entry.keyFace?.id ?? "")") {
            let phAsset = viewModel.repository.phAsset(for: entry.keyAssetID)
            let localURL = viewModel.repository.localMediaURL(for: entry.keyAssetID)
            viewModel.thumbnailCache.requestFaceAvatar(
                for: phAsset,
                fallbackFileURL: localURL,
                face: entry.keyFace,
                portraitRectangular: true
            ) { img in
                self.avatar = img
            }
        }
    }
}

/// Individual person page header featuring a vertical portrait card and person name
private struct PersonHeroHeaderBannerView: View {
    let personName: String
    let cardWidth: CGFloat
    @Bindable var viewModel: PhotoWorkspaceViewModel

    @State private var portraitImage: NSImage?

    private var personEntry: PhotoWorkspaceViewModel.PersonSummaryEntry? {
        viewModel.peopleEntries.first(where: { $0.name == personName })
    }

    var body: some View {
        let effectiveWidth = max(320.0, min(1640.0, cardWidth)) // ★ [UI SIZING: People Grid & Header] Width of the header portrait card on an individual person page (pt)

        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.07))

            if let portraitImage {
                GeometryReader { geo in
                    Image(nsImage: portraitImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Bottom gradient + person name overlay
            Text(personName)
                .font(.system(size: 18, weight: .bold)) // ★ [UI SIZING: People Grid & Header] Font size of the person name inside the individual person header card (pt)
                .foregroundStyle(.white)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.55), radius: 3, y: 1)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.76), .clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
        }
        .frame(width: effectiveWidth)
        .aspectRatio(0.74, contentMode: .fit)          // ★ [UI SIZING: People Grid & Header] Aspect ratio of the individual person header card (0.74)
        .clipShape(RoundedRectangle(cornerRadius: 14)) // ★ [UI SIZING: People Grid & Header] Corner radius of the individual person header card (14pt)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
        .task(id: "\(personName)_\(personEntry?.keyAssetID ?? "")_\(personEntry?.keyFace?.id ?? "")") {
            guard let entry = personEntry else { return }
            let ph = viewModel.repository.phAsset(for: entry.keyAssetID)
            let url = viewModel.repository.localMediaURL(for: entry.keyAssetID)
            viewModel.thumbnailCache.requestFaceAvatar(
                for: ph,
                fallbackFileURL: url,
                face: entry.keyFace,
                portraitRectangular: true
            ) { img in
                if let img { self.portraitImage = img }
            }
        }
    }
}

// MARK: - 17. Customizable Photo Grid View (Fast 100k+ Row-Chunked LazyVStack + Screenshot-Matched Filter Popover)

private struct FilterPopoverButtonView: View {
    @Binding var tab: BrowserTabState
    @Bindable var viewModel: PhotoWorkspaceViewModel
    @State private var showFilterPopover: Bool = false

    var body: some View {
        Button {
            showFilterPopover.toggle()
        } label: {
            HStack(spacing: 5) {
                Text("Filter: \(tab.contentFilter.rawValue)")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(tab.contentFilter == .allItems ? .white.opacity(0.92) : Color.accentColor)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showFilterPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                filterMenuRow(.allItems)

                Divider()
                    .overlay(Color.white.opacity(0.15))
                    .padding(.vertical, 4)

                filterMenuRow(.favorites)
                filterMenuRow(.edited)
                filterMenuRow(.photos)
                filterMenuRow(.videos)
                filterMenuRow(.screenshots)

                Divider()
                    .overlay(Color.white.opacity(0.15))
                    .padding(.vertical, 4)

                Button {
                    showFilterPopover = false
                    viewModel.showTagManagerSheet = true
                } label: {
                    HStack(spacing: 9) {
                        Color.clear.frame(width: 14, height: 14)
                        Image(systemName: "tag")
                            .font(.system(size: 13))
                            .frame(width: 18)
                        Text("Keyword Manager...")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                    }
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .frame(width: 225)
            .background(Color(red: 0.16, green: 0.15, blue: 0.15))
        }
    }

    @ViewBuilder
    private func filterMenuRow(_ filter: GridContentFilter) -> some View {
        let isSelected = (tab.contentFilter == filter)
        Button {
            tab.contentFilter = filter
            viewModel.invalidateFilterCache()
            viewModel.saveWorkspaceState()
            showFilterPopover = false
        } label: {
            HStack(spacing: 9) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 14, height: 14)
                } else {
                    Color.clear.frame(width: 14, height: 14)
                }

                Image(systemName: filter.systemIcon)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 18)

                Text(filter.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(.white.opacity(0.95))

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct CustomizableTabGridView: View {
    @Binding var tab: BrowserTabState
    @Bindable var viewModel: PhotoWorkspaceViewModel

    @State private var visibleRowIndices: Set<Int> = []
    @State private var headerDateRangeText: String = ""
    @State private var headerLocationText: String? = nil
    @State private var pinchAccumulator: CGFloat = 0.0
    @State private var lastAutoScrolledScopeKey: String = "" 

    @State private var marqueeStartPoint: CGPoint? = nil
    @State private var marqueeCurrentPoint: CGPoint? = nil
    @State private var marqueeBaseSelection: Set<String> = []

    private var activeMarqueeRect: CGRect? {
        guard let s = marqueeStartPoint, let c = marqueeCurrentPoint else { return nil }
        let rect = CGRect(
            x: min(s.x, c.x),
            y: min(s.y, c.y),
            width: abs(c.x - s.x),
            height: abs(c.y - s.y)
        )
        return (rect.width > 4 || rect.height > 4) ? rect : nil
    }

    var body: some View {
        let slice = viewModel.pagedSlice(for: tab)
        let items = slice.pageItems
        let isPersonScope: String? = {
            if case .person(let name) = tab.filterScope { return name }
            return nil
        }()
        let colCount = max(2, tab.gridConfig.columnCount)
        let totalRows = (items.count + colCount - 1) / colCount
        let photoCount = slice.pagePhotoCount
        let videoCount = slice.pageVideoCount

        GeometryReader { outerGeo in
            let horizontalPad: CGFloat = (isPersonScope != nil)
                ? max(76.0, min(160.0, outerGeo.size.width * 0.095)) // ★ [UI SIZING: Photo Grid & Cells] Horizontal grid margins on an individual person page (pt)
                : max(16.0, tab.gridConfig.spacing)                  // ★ [UI SIZING: Photo Grid & Cells] Horizontal grid margins on standard album/library pages (pt)
            let spacing = tab.gridConfig.spacing                     // ★ [UI SIZING: Photo Grid & Cells] Spacing between photo cells (configured via GridCustomizationConfig.spacing)
            let availableWidth = max(100.0, outerGeo.size.width - horizontalPad * 2 - spacing * CGFloat(colCount - 1))
            let cellSide = floor(availableWidth / CGFloat(colCount)) // ★ [UI SIZING: Photo Grid & Cells] Computed cell side length based on column count and spacing
            let topBannerHeight: CGFloat = (isPersonScope != nil) ? (max(145.0, min(230.0, cellSide)) / 0.74 + 22.0) : 0.0
            let topBannerOffset: CGFloat = 48.0 + topBannerHeight

            ZStack(alignment: .topLeading) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Spacer()
                                .frame(height: 38)
                                .id("GRID_TOP_ANCHOR")

                            // Show the vertical portrait header card at the top when viewing an individual person page
                            if let personName = isPersonScope {
                                PersonHeroHeaderBannerView(
                                    personName: personName,
                                    cardWidth: cellSide,
                                    viewModel: viewModel
                                )
                                .padding(.horizontal, horizontalPad)
                                .padding(.bottom, 6)
                            }

                            if items.isEmpty {
                                ContentUnavailableView(
                                    "No Matching Items",
                                    systemImage: "photo.on.rectangle.angled",
                                    description: Text(tab.contentFilter == .allItems ? "Try selecting another album or changing your search query." : "No items match the filter \"\(tab.contentFilter.rawValue)\".")
                                )
                                .padding(.top, 80)
                            } else {
                                // Row-chunked LazyVStack for zero-frame-drop scrolling even on 100,000+ photo libraries
                                LazyVStack(alignment: .leading, spacing: spacing) {
                                    ForEach(0..<totalRows, id: \.self) { rowIdx in
                                        let startIdx = rowIdx * colCount
                                        let endIdx = min(startIdx + colCount, items.count)

                                        HStack(spacing: spacing) {
                                            ForEach(startIdx..<endIdx, id: \.self) { itemIdx in
                                                let item = items[itemIdx]
                                                GridAssetCellView(
                                                    item: item,
                                                    config: tab.gridConfig,
                                                    isSelected: tab.selectedAssetIDs.contains(item.id) || tab.selectedAssetID == item.id,
                                                    currentScope: tab.filterScope,
                                                    viewModel: viewModel,
                                                    onSingleClick: {
                                                        handleGridCellSelection(item: item, in: items)
                                                    },
                                                    onDoubleClick: {
                                                        tab.selectedAssetID = item.id
                                                        tab.selectedAssetIDs = [item.id]
                                                        viewModel.recordRecentlyViewed(item.id)
                                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
                                                            tab.activeDetailAssetID = item.id
                                                        }
                                                        viewModel.saveWorkspaceState()
                                                    }
                                                )
                                                .frame(width: cellSide, height: cellSide)
                                            }
                                            if endIdx - startIdx < colCount {
                                                ForEach(0..<(colCount - (endIdx - startIdx)), id: \.self) { _ in
                                                    Color.clear.frame(width: cellSide, height: cellSide)
                                                }
                                            }
                                        }
                                        .id("ROW_\(rowIdx)")
                                        .onAppear {
                                            visibleRowIndices.insert(rowIdx)
                                            updateVisibleHeaderIfNeeded(items: items, colCount: colCount)
                                        }
                                        .onDisappear {
                                            visibleRowIndices.remove(rowIdx)
                                        }
                                    }
                                }
                                .padding(.horizontal, horizontalPad)
                            }

                            let countSummary = PhotoWorkspaceViewModel.formatMediaCountSummary(photoCount: photoCount, videoCount: videoCount)
                            if !items.isEmpty && !countSummary.isEmpty {
                                HStack {
                                    Spacer()
                                    Text(countSummary)
                                        .font(.system(size: 14, weight: .semibold)) // ★ [UI SIZING: Photo Grid & Cells] Font size of the bottom media count summary footer (pt)
                                        .monospacedDigit()
                                        .foregroundStyle(.primary.opacity(0.85))
                                    Spacer()
                                }
                                .padding(.vertical, 26)
                                .id("LIBRARY_BOTTOM_ANCHOR")
                            } else {
                                Spacer()
                                    .frame(height: 24)
                                    .id("LIBRARY_BOTTOM_ANCHOR")
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 500, alignment: .topLeading)
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 8, coordinateSpace: .named("GridScrollCanvasSpace"))
                                .onChanged { value in
                                    guard !viewModel.isDraggingInspector else { return }
                                    if marqueeStartPoint == nil {
                                        marqueeStartPoint = value.startLocation
                                        let flags = NSEvent.modifierFlags
                                        if flags.contains(.command) || flags.contains(.shift) {
                                            marqueeBaseSelection = tab.selectedAssetIDs
                                        } else {
                                            marqueeBaseSelection = []
                                        }
                                    }
                                    marqueeCurrentPoint = value.location
                                    if let rect = activeMarqueeRect {
                                        let hitIDs = computeMarqueeHitAssetIDs(
                                            rect: rect,
                                            items: items,
                                            colCount: colCount,
                                            cellSide: cellSide,
                                            spacing: spacing,
                                            horizontalPad: horizontalPad,
                                            topOffset: topBannerOffset
                                        )
                                        let combined = marqueeBaseSelection.union(hitIDs)
                                        if tab.selectedAssetIDs != combined {
                                            tab.selectedAssetIDs = combined
                                            if let firstHit = hitIDs.first {
                                                tab.selectedAssetID = firstHit
                                            }
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    marqueeStartPoint = nil
                                    marqueeCurrentPoint = nil
                                    viewModel.saveWorkspaceState()
                                }
                        )
                        .coordinateSpace(name: "GridScrollCanvasSpace")
                    }
                    .onAppear {
                        updateVisibleHeaderIfNeeded(items: items, colCount: colCount)
                        scrollToBottomByDefaultIfNeeded(proxy: proxy, items: items)
                    }
                    .onChange(of: items.count) { _, _ in
                        updateVisibleHeaderIfNeeded(items: items, colCount: colCount)
                        scrollToBottomByDefaultIfNeeded(proxy: proxy, items: items)
                    }
                    .onChange(of: tab.filterScope) { _, _ in
                        visibleRowIndices.removeAll()
                        updateVisibleHeaderIfNeeded(items: items, colCount: colCount)
                        scrollToBottomByDefaultIfNeeded(proxy: proxy, items: items)
                    }
                    .onChange(of: tab.currentPageIndex) { _, _ in
                        visibleRowIndices.removeAll()
                        updateVisibleHeaderIfNeeded(items: items, colCount: colCount)
                        scrollToBottomByDefaultIfNeeded(proxy: proxy, items: items)
                    }
                    .onChange(of: tab.selectedLibraryBucketID) { _, _ in
                        visibleRowIndices.removeAll()
                        updateVisibleHeaderIfNeeded(items: items, colCount: colCount)
                        scrollToBottomByDefaultIfNeeded(proxy: proxy, items: items)
                    }
                    .onChange(of: viewModel.pendingScrollToAssetID) { _, targetID in
                        guard let targetID,
                              let pos = items.firstIndex(where: { $0.id == targetID }) else { return }
                        let targetRow = pos / colCount
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                proxy.scrollTo("ROW_\(targetRow)", anchor: .center)
                            }
                            viewModel.pendingScrollToAssetID = nil
                        }
                    }
                }

                // Rubber-band marquee selection rectangle when dragging from grid whitespace
                if let rect = activeMarqueeRect {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.20))
                        .overlay(
                            Rectangle()
                                .stroke(Color.accentColor.opacity(0.88), lineWidth: 1.2)
                        )
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }

                // Top-left: Visible date range pill badge + Top-right: Content Filter menu button
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(headerDateRangeText.isEmpty ? tab.filterScope.displayTitle : headerDateRangeText)
                            .font(.system(size: 22, weight: .bold))     // ★ [UI SIZING: Photo Grid & Cells] Font size of the top-left floating date range / title badge (pt)
                            .foregroundStyle(.white)
                        if let sub = headerLocationText {
                            Text(sub)
                                .font(.system(size: 11.5, weight: .medium)) // ★ [UI SIZING: Photo Grid & Cells] Font size of the top-left floating location subtitle badge (pt)
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .allowsHitTesting(false)

                    Spacer()

                    FilterPopoverButtonView(tab: $tab, viewModel: viewModel)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)

                // Freely draggable floating Info (i) inspector window
                if tab.showInspectorPanel,
                   let selectedID = tab.selectedAssetID ?? tab.selectedAssetIDs.first ?? items.last?.id,
                   let selectedItem = viewModel.allItems.first(where: { $0.id == selectedID }) {
                    DraggableInspectorOverlayView(
                        item: selectedItem,
                        viewModel: viewModel,
                        onClose: { tab.showInspectorPanel = false }
                    )
                }
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { val in
                        let delta = val - 1.0
                        if abs(delta - pinchAccumulator) > 0.22 {
                            let zoomingOut = delta < pinchAccumulator
                            pinchAccumulator = delta
                            handlePinchZoomInGrid(zoomingOut: zoomingOut)
                        }
                    }
                    .onEnded { _ in
                        pinchAccumulator = 0.0
                    }
            )
        }
    }

    private func computeMarqueeHitAssetIDs(
        rect: CGRect,
        items: [PhotoAssetItem],
        colCount: Int,
        cellSide: CGFloat,
        spacing: CGFloat,
        horizontalPad: CGFloat,
        topOffset: CGFloat
    ) -> Set<String> {
        guard !items.isEmpty, cellSide > 0 else { return [] }
        let stride = cellSide + spacing
        let minCol = max(0, Int(floor((rect.minX - horizontalPad) / stride)))
        let maxCol = min(colCount - 1, Int(floor((rect.maxX - horizontalPad) / stride)))
        let minRow = max(0, Int(floor((rect.minY - topOffset) / stride)))
        let totalRows = (items.count + colCount - 1) / colCount
        let maxRow = min(totalRows - 1, Int(floor((rect.maxY - topOffset) / stride)))

        guard minRow <= maxRow && minCol <= maxCol else { return [] }
        var hit: Set<String> = []
        for r in minRow...maxRow {
            for c in minCol...maxCol {
                let idx = r * colCount + c
                if idx >= 0 && idx < items.count {
                    hit.insert(items[idx].id)
                }
            }
        }
        return hit
    }

    /// Default to scrolling to the bottom (most recent photos) when opening an album or library page
    private func scrollToBottomByDefaultIfNeeded(proxy: ScrollViewProxy, items: [PhotoAssetItem]) {
        guard !items.isEmpty, viewModel.pendingScrollToAssetID == nil else { return }
        let scopeKey = "\(tab.filterScope)_\(tab.selectedLibraryBucketID ?? "nil")_\(tab.currentPageIndex)"
        guard lastAutoScrolledScopeKey != scopeKey else { return }
        lastAutoScrolledScopeKey = scopeKey
        proxy.scrollTo("LIBRARY_BOTTOM_ANCHOR", anchor: .bottom)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            proxy.scrollTo("LIBRARY_BOTTOM_ANCHOR", anchor: .bottom)
        }
    }

    private static let rangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private func updateVisibleHeaderIfNeeded(items: [PhotoAssetItem], colCount: Int) {
        guard !items.isEmpty else {
            headerDateRangeText = tab.filterScope.displayTitle
            headerLocationText = nil
            return
        }
        let minRow = visibleRowIndices.min() ?? max(0, (items.count - 1) / colCount - 2)
        let maxRow = visibleRowIndices.max() ?? ((items.count - 1) / colCount)
        let startIdx = max(0, min(items.count - 1, minRow * colCount))
        let endIdx = max(startIdx, min(items.count - 1, (maxRow + 1) * colCount - 1))

        let firstDate = items[startIdx].creationDate
        let lastDate = items[endIdx].creationDate
        if let d1 = firstDate, let d2 = lastDate {
            let s1 = Self.rangeFormatter.string(from: min(d1, d2))
            let s2 = Self.rangeFormatter.string(from: max(d1, d2))
            headerDateRangeText = (s1 == s2) ? s1 : "\(s1) – \(s2)"
        } else {
            headerDateRangeText = tab.filterScope.displayTitle
        }

        var foundLoc: String? = nil
        for i in startIdx...endIdx {
            if let loc = items[i].locationName, !loc.isEmpty {
                foundLoc = loc
                break
            }
        }
        headerLocationText = foundLoc
    }

    private func handleGridCellSelection(item: PhotoAssetItem, in items: [PhotoAssetItem]) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            if tab.selectedAssetIDs.contains(item.id) {
                tab.selectedAssetIDs.remove(item.id)
            } else {
                tab.selectedAssetIDs.insert(item.id)
            }
            tab.selectedAssetID = item.id
        } else if flags.contains(.shift),
                  let anchorID = tab.selectedAssetID,
                  let startIdx = items.firstIndex(where: { $0.id == anchorID }),
                  let endIdx = items.firstIndex(where: { $0.id == item.id }) {
            let lower = min(startIdx, endIdx)
            let upper = max(startIdx, endIdx)
            let rangeIDs = items[lower...upper].map(\.id)
            tab.selectedAssetIDs.formUnion(rangeIDs)
            tab.selectedAssetID = item.id
        } else {
            tab.selectedAssetID = item.id
            tab.selectedAssetIDs = [item.id]
        }

        Task {
            await viewModel.enrichAssetMetadata(for: item.id)
        }
        viewModel.saveWorkspaceState()
    }

    private func handlePinchZoomInGrid(zoomingOut: Bool) {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.85)) {
            if zoomingOut {
                if tab.gridConfig.columnCount < 8 {
                    tab.gridConfig.columnCountDouble = min(10.0, tab.gridConfig.columnCountDouble + 1.0)
                } else if tab.filterScope == .library {
                    switch tab.gridConfig.timeGranularity {
                    case .allPhotos: tab.gridConfig.timeGranularity = .months
                    case .months: tab.gridConfig.timeGranularity = .years
                    case .years: break
                    }
                }
            } else {
                if tab.filterScope == .library && tab.gridConfig.timeGranularity != .allPhotos {
                    switch tab.gridConfig.timeGranularity {
                    case .years: tab.gridConfig.timeGranularity = .months
                    case .months: tab.gridConfig.timeGranularity = .allPhotos
                    case .allPhotos: break
                    }
                } else {
                    tab.gridConfig.columnCountDouble = max(2.0, tab.gridConfig.columnCountDouble - 1.0)
                }
            }
        }
        viewModel.saveWorkspaceState()
    }
}

/// Individual photo grid cell (inline animated GIF playback, strict image hit-testing, and context menu)
private struct GridAssetCellView: View {
    let item: PhotoAssetItem
    let config: GridCustomizationConfig
    let isSelected: Bool
    let currentScope: TabFilterScope
    @Bindable var viewModel: PhotoWorkspaceViewModel
    var onSingleClick: () -> Void
    var onDoubleClick: () -> Void

    @State private var thumbnail: NSImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        ZStack {
            if config.cropToSquare {
                GeometryReader { geo in
                    cellMediaContent(explicitSize: geo.size)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .contentShape(RoundedRectangle(cornerRadius: 4))
                        .gesture(
                            TapGesture(count: 2).onEnded {
                                onDoubleClick()
                            }
                            .exclusively(before: TapGesture(count: 1).onEnded {
                                onSingleClick()
                            })
                        )
                        .contextMenu {
                            AssetContextMenuItems(item: item, currentScope: currentScope, viewModel: viewModel)
                        }
                }
                .aspectRatio(1.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4)) // ★ [UI SIZING: Photo Grid & Cells] Corner radius of square grid thumbnails (4pt; set 0–2 for sharp corners)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3.0) // ★ [UI SIZING: Photo Grid & Cells] Selection highlight border width (3.0pt)
                )
            } else {
                cellMediaContent(explicitSize: nil)
                    .aspectRatio(max(0.35, min(2.8, item.aspectRatio)), contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3.0)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 4))
                    .gesture(
                        TapGesture(count: 2).onEnded {
                            onDoubleClick()
                        }
                        .exclusively(before: TapGesture(count: 1).onEnded {
                            onSingleClick()
                        })
                    )
                    .contextMenu {
                        AssetContextMenuItems(item: item, currentScope: currentScope, viewModel: viewModel)
                    }
                    .padding(2)
            }
        }
        .task(id: "\(item.id)_\(Int(config.bucketedTargetSize.width))_\(config.cropToSquare)") {
            guard !item.isGIF else { return }

            let phAsset = viewModel.repository.phAsset(for: item.id)
            let localURL = viewModel.repository.localMediaURL(for: item.id)
            requestID = viewModel.thumbnailCache.requestThumbnail(
                for: phAsset,
                fallbackFileURL: localURL,
                targetSize: config.bucketedTargetSize,
                cropToSquare: config.cropToSquare
            ) { img, _ in
                if let img { self.thumbnail = img }
            }
        }
        .onDisappear {
            if let reqID = requestID {
                viewModel.thumbnailCache.cancelRequest(reqID)
                requestID = nil
            }
        }
    }

    @ViewBuilder
    private func cellMediaContent(explicitSize: CGSize?) -> some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle().fill(Color.white.opacity(0.05))

            if item.isGIF {
                if let explicitSize {
                    AnimatedGIFSurfaceView(
                        asset: viewModel.repository.phAsset(for: item.id),
                        fallbackFileURL: viewModel.repository.localMediaURL(for: item.id),
                        assetID: item.id,
                        thumbnailCache: viewModel.thumbnailCache,
                        contentScaling: config.cropToSquare ? .scaleAxesIndependently : .scaleProportionallyUpOrDown
                    )
                    .frame(width: explicitSize.width, height: explicitSize.height)
                    .clipped()
                } else {
                    AnimatedGIFSurfaceView(
                        asset: viewModel.repository.phAsset(for: item.id),
                        fallbackFileURL: viewModel.repository.localMediaURL(for: item.id),
                        assetID: item.id,
                        thumbnailCache: viewModel.thumbnailCache,
                        contentScaling: config.cropToSquare ? .scaleAxesIndependently : .scaleProportionallyUpOrDown
                    )
                }
            } else if let thumbnail {
                if let explicitSize {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: config.cropToSquare ? .fill : .fit)
                        .frame(width: explicitSize.width, height: explicitSize.height)
                        .clipped()
                } else {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: config.cropToSquare ? .fill : .fit)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    if item.isVideo {
                        Text(String(format: "%d:%02d", Int(item.duration) / 60, Int(item.duration) % 60))
                            .font(.system(size: 10, weight: .semibold)) // ★ [UI SIZING: Photo Grid & Cells] Font size of the video duration badge at top-right of a cell (10pt)
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.68), in: Capsule())
                    }
                }
                .padding(5)

                Spacer()

                // Display a pure white favorite heart icon at the bottom-left corner without background pill
                HStack {
                    if item.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12.5, weight: .semibold)) // ★ [UI SIZING: Photo Grid & Cells] Size of the white favorite heart icon at bottom-left of a cell (pt)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.65), radius: 2, y: 1)
                    }
                    Spacer()
                }
                .padding(6) // ★ [UI SIZING: Photo Grid & Cells] Padding around the bottom-left favorite heart icon (6pt)
            }
        }
    }
}

/// Right-click context menu for photo/video cells
private struct AssetContextMenuItems: View {
    let item: PhotoAssetItem
    let currentScope: TabFilterScope
    @Bindable var viewModel: PhotoWorkspaceViewModel

    var body: some View {
        Button(item.isFavorite ? "Unfavorite" : "Favorite") {
            viewModel.toggleFavorite(for: item.id)
        }

        if currentScope != .library {
            Button("Show in All Photos") {
                viewModel.revealAssetInAllPhotos(item.id)
            }
        }

        let belongedAlbums = viewModel.albumsContaining(assetID: item.id, excludingScope: currentScope)
        if belongedAlbums.isEmpty {
            Button("Show in Album") {}
                .disabled(true)
        } else {
            Menu("Show in Album") {
                ForEach(belongedAlbums, id: \.title) { entry in
                    Button(entry.title) {
                        if let idx = viewModel.activeTabIndex {
                            viewModel.navigateToScope(inTab: idx, scope: entry.scope)
                            viewModel.tabs[idx].selectedAssetID = item.id
                            viewModel.tabs[idx].selectedAssetIDs = [item.id]
                            viewModel.pendingScrollToAssetID = item.id
                        }
                    }
                }
            }
        }

        Button("Adjust Date and Time...") {
            if let idx = viewModel.activeTabIndex,
               viewModel.tabs[idx].selectedAssetIDs.contains(item.id),
               viewModel.tabs[idx].selectedAssetIDs.count > 1 {
                viewModel.presentDateTimeEditSheet(for: Array(viewModel.tabs[idx].selectedAssetIDs))
            } else {
                viewModel.presentDateTimeEditSheet(for: [item.id])
            }
        }

        Divider()

        Menu("Edit With") {
            let apps = viewModel.availableExternalApps(for: item)
            if apps.isEmpty {
                Text("No Compatible Applications Found")
            } else {
                ForEach(apps, id: \.path) { appURL in
                    let appName = appURL.deletingPathExtension().lastPathComponent
                    Button("\(appName)") {
                        viewModel.openAsset(item, withApplication: appURL)
                    }
                }
            }
        }

        switch currentScope {
        case .person(let personName):
            Button("Make Key Photo for \"\(personName)\"") {
                viewModel.setKeyPhotoForPerson(personName: personName, assetID: item.id)
            }
        case .systemAlbum(let albumID, let title):
            Button("Make Key Photo for Album \"\(title)\"") {
                viewModel.setKeyPhotoForAlbum(albumID: albumID, assetID: item.id)
            }
        case .customAlbum(let albumUUID, let title):
            Button("Make Key Photo for Album \"\(title)\"") {
                viewModel.setKeyPhotoForAlbum(albumID: albumUUID.uuidString, assetID: item.id)
            }
        default:
            EmptyView()
        }

        if !viewModel.customAlbums.isEmpty {
            Menu("Add to Custom Album") {
                ForEach(viewModel.customAlbums) { album in
                    Button(album.name) {
                        viewModel.addAsset(item.id, toCustomAlbum: album.id)
                    }
                }
            }
        }

        Menu("Assign Keyword Tag") {
            ForEach(viewModel.allRegisteredTags, id: \.self) { tag in
                let hasTag = item.keywords.contains(tag)
                Button(hasTag ? "✓ \(tag)" : tag) {
                    if hasTag {
                        viewModel.removeTag(tag, fromAssetID: item.id)
                    } else {
                        viewModel.addTag(tag, toAssetID: item.id)
                    }
                }
            }
            Divider()
            Button("Open Keyword Manager (⌘K)...") {
                viewModel.showTagManagerSheet = true
            }
        }

        Divider()

        Button(item.isHidden ? "Unhide Photo" : "Hide Photo") {
            viewModel.toggleHidden(for: item.id)
        }
    }
}

// MARK: - 18. Modals: Batch Date/Time Editor, ⌘K Keyword Manager, Smart Album & Album Creators

private struct DateTimeBatchEditSheetView: View {
    @Bindable var viewModel: PhotoWorkspaceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var adjustedDate: Date = Date()
    @State private var shiftAllRelatively: Bool = true

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d, yyyy  HH:mm:ss"
        return f
    }()

    private var targetItems: [PhotoAssetItem] {
        viewModel.dateTimeEditTargetAssetIDs.compactMap { id in
            viewModel.allItems.first(where: { $0.id == id })
        }
    }

    var body: some View {
        let count = targetItems.count
        let firstDate = targetItems.first?.creationDate ?? Date()
        let deltaSeconds = Int(adjustedDate.timeIntervalSince(firstDate))

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(
                    count > 1 ? "Batch Adjust Date & Time (\(count) Items)" : "Adjust Date and Time",
                    systemImage: "calendar.badge.clock"
                )
                .font(.system(size: 16, weight: .bold))
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Original Date:")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .frame(width: 110, alignment: .leading)
                    Text(Self.displayFormatter.string(from: firstDate))
                        .font(.system(size: 12.5, weight: .medium))
                }

                HStack {
                    Text("Adjusted Date:")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .frame(width: 110, alignment: .leading)
                    DatePicker(
                        "",
                        selection: $adjustedDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.field)
                }

                HStack(spacing: 8) {
                    Text("Quick Shift:")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 110, alignment: .leading)
                    Button("-1 Hour") { adjustedDate = adjustedDate.addingTimeInterval(-3600) }
                        .controlSize(.small)
                    Button("+1 Hour") { adjustedDate = adjustedDate.addingTimeInterval(3600) }
                        .controlSize(.small)
                    Button("-1 Day") { adjustedDate = adjustedDate.addingTimeInterval(-86400) }
                        .controlSize(.small)
                    Button("+1 Day") { adjustedDate = adjustedDate.addingTimeInterval(86400) }
                        .controlSize(.small)
                }

                if count > 1 {
                    Toggle(
                        "Shift all \(count) selected items while preserving relative time intervals (Delta: \(deltaSeconds / 60) min)",
                        isOn: $shiftAllRelatively
                    )
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                    .padding(.top, 4)
                }
            }

            Text("* Your original system Photos library (Photos Library.photoslibrary) is never modified. Changes are saved safely as a non-destructive overlay inside PhotoVault.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Adjust") {
                    viewModel.applyBatchDateTimeAdjustment(
                        targetAssetIDs: viewModel.dateTimeEditTargetAssetIDs,
                        newReferenceDate: adjustedDate,
                        shiftAllByRelativeDelta: shiftAllRelatively
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear {
            adjustedDate = targetItems.first?.creationDate ?? Date()
        }
    }
}

private struct TagManagerModalSheetView: View {
    @Bindable var viewModel: PhotoWorkspaceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var newTagText: String = ""

    private var selectedAssetIDs: [String] {
        guard let idx = viewModel.activeTabIndex else { return [] }
        let tab = viewModel.tabs[idx]
        if let detailID = tab.activeDetailAssetID { return [detailID] }
        if !tab.selectedAssetIDs.isEmpty { return Array(tab.selectedAssetIDs) }
        if let single = tab.selectedAssetID { return [single] }
        return []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Keyword Manager (⌘K)", systemImage: "tag.fill")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            HStack(spacing: 8) {
                TextField("Enter new keyword tag...", text: $newTagText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { createNewTag() }
                Button("Add Tag") { createNewTag() }
                    .buttonStyle(.borderedProminent)
            }

            if !selectedAssetIDs.isEmpty {
                Text("Click tags below to toggle them on/off for the \(selectedAssetIDs.count) selected photo(s)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                Text("Registered Keywords (click a tag to browse matching photos)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 8)], spacing: 8) {
                    ForEach(viewModel.allRegisteredTags, id: \.self) { tag in
                        let isAppliedToAll = !selectedAssetIDs.isEmpty && selectedAssetIDs.allSatisfy { id in
                            viewModel.allItems.first(where: { $0.id == id })?.keywords.contains(tag) ?? false
                        }
                        HStack(spacing: 6) {
                            Image(systemName: isAppliedToAll ? "checkmark.circle.fill" : "tag")
                                .font(.system(size: 11))
                            Text(tag)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(isAppliedToAll ? Color.accentColor.opacity(0.32) : Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(isAppliedToAll ? Color.accentColor : Color.white.opacity(0.14), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !selectedAssetIDs.isEmpty {
                                for id in selectedAssetIDs {
                                    if isAppliedToAll {
                                        viewModel.removeTag(tag, fromAssetID: id)
                                    } else {
                                        viewModel.addTag(tag, toAssetID: id)
                                    }
                                }
                            } else if let idx = viewModel.activeTabIndex {
                                viewModel.navigateToScope(inTab: idx, scope: .keyword(tag: tag))
                                dismiss()
                            }
                        }
                    }
                }
            }
            .frame(minHeight: 180)
        }
        .padding(18)
        .frame(width: 480, height: 360)
    }

    private func createNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !viewModel.allRegisteredTags.contains(trimmed) {
            viewModel.allRegisteredTags.append(trimmed)
            viewModel.allRegisteredTags.sort()
        }
        for id in selectedAssetIDs {
            viewModel.addTag(trimmed, toAssetID: id)
        }
        viewModel.saveWorkspaceState()
        newTagText = ""
    }
}

private struct SmartAlbumEditorSheetView: View {
    @Bindable var viewModel: PhotoWorkspaceViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = "New Smart Album"
    @State private var captionContains: String = ""
    @State private var keywordContains: String = ""
    @State private var cameraContains: String = ""
    @State private var personContains: String = ""
    @State private var filenameContains: String = ""
    @State private var onlyFavorites: Bool = false
    @State private var onlyVideos: Bool = false
    @State private var onlyPhotos: Bool = false
    @State private var onlyWithLocation: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.editingSmartAlbum == nil ? "New Smart Album" : "Edit Smart Album")
                .font(.system(size: 16, weight: .bold))

            Form {
                TextField("Smart Album Name:", text: $name)
                TextField("Caption contains:", text: $captionContains)
                TextField("Keyword contains:", text: $keywordContains)
                TextField("Camera / Make / Lens contains:", text: $cameraContains)
                TextField("Person name contains:", text: $personContains)
                TextField("Filename / Title contains:", text: $filenameContains)

                Toggle("Favorites Only", isOn: $onlyFavorites)
                Toggle("Videos Only", isOn: $onlyVideos)
                Toggle("Photos Only", isOn: $onlyPhotos)
                Toggle("With Location Only", isOn: $onlyWithLocation)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    let def = SmartAlbumDefinition(
                        id: viewModel.editingSmartAlbum?.id ?? UUID(),
                        name: name.isEmpty ? "Smart Album" : name,
                        captionContains: captionContains,
                        keywordContains: keywordContains,
                        cameraContains: cameraContains,
                        personContains: personContains,
                        onlyFavorites: onlyFavorites,
                        onlyVideos: onlyVideos,
                        onlyPhotos: onlyPhotos,
                        onlyWithLocation: onlyWithLocation,
                        filenameContains: filenameContains
                    )
                    viewModel.createOrUpdateSmartAlbum(def)
                    if let idx = viewModel.activeTabIndex {
                        viewModel.navigateToScope(inTab: idx, scope: .smartAlbum(id: def.id, title: def.name))
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 450)
        .onAppear {
            if let existing = viewModel.editingSmartAlbum {
                name = existing.name
                captionContains = existing.captionContains
                keywordContains = existing.keywordContains
                cameraContains = existing.cameraContains
                personContains = existing.personContains
                filenameContains = existing.filenameContains
                onlyFavorites = existing.onlyFavorites
                onlyVideos = existing.onlyVideos
                onlyPhotos = existing.onlyPhotos
                onlyWithLocation = existing.onlyWithLocation
            }
        }
    }
}

private struct NewCustomAlbumSheetView: View {
    @Bindable var viewModel: PhotoWorkspaceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var albumName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Album")
                .font(.system(size: 15, weight: .bold))

            TextField("Album Name", text: $albumName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") {
                    let initialIDs: [String]
                    if let idx = viewModel.activeTabIndex {
                        initialIDs = Array(viewModel.tabs[idx].selectedAssetIDs)
                    } else {
                        initialIDs = []
                    }
                    viewModel.createCustomAlbum(
                        name: albumName,
                        parentFolderID: viewModel.pendingNewAlbumParentCustomFolderID,
                        parentSystemFolderIdentifier: viewModel.pendingNewAlbumParentSystemFolderID,
                        initialAssetIDs: initialIDs
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 340)
    }
}

private struct NewCustomFolderSheetView: View {
    @Bindable var viewModel: PhotoWorkspaceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var folderName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Folder")
                .font(.system(size: 15, weight: .bold))

            TextField("Folder Name", text: $folderName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") {
                    viewModel.createCustomFolder(name: folderName)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 340)
    }
}

// MARK: - 19. App Entry Point (@main) & macOS Menu Bar Commands

@main
struct PhotoVaultMacApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
    @State private var workspaceVM = PhotoWorkspaceViewModel()

    var body: some Scene {
        WindowGroup("PhotoVault") {
            PhotoVaultCompleteRootView(viewModel: workspaceVM)
                .frame(minWidth: 1080, minHeight: 720) // ★ [UI SIZING: Window Minimum Size] Minimum window width (1080pt) and height (720pt)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Photo Library...") {
                    workspaceVM.selectPhotosLibraryPackageViaPanel()
                }
                .keyboardShortcut("o", modifiers: [.command])

                if workspaceVM.customLibraryPath != nil {
                    Button("Reset to Default System Photo Library") {
                        workspaceVM.switchToDefaultSystemPhotoLibrary()
                    }
                }

                Divider()

                Button("New Tab") {
                    workspaceVM.openNewTab(scope: .library)
                }
                .keyboardShortcut("t", modifiers: [.command])

                Button("Close Tab") {
                    workspaceVM.closeTab(id: workspaceVM.activeTabID)
                }
                .keyboardShortcut("w", modifiers: [.command])

                Divider()

                Button("Open Keyword Manager...") {
                    workspaceVM.showTagManagerSheet = true
                }
                .keyboardShortcut("k", modifiers: [.command])

                Button("New Smart Album...") {
                    workspaceVM.editingSmartAlbum = nil
                    workspaceVM.showSmartAlbumSheet = true
                }
                .keyboardShortcut("n", modifiers: [.command, .option])

                Button("Show/Hide Info Panel") {
                    if let idx = workspaceVM.activeTabIndex {
                        workspaceVM.tabs[idx].showInspectorPanel.toggle()
                        workspaceVM.saveWorkspaceState()
                    }
                }
                .keyboardShortcut("i", modifiers: [.command])

                Button("Show/Hide Face Name Tags") {
                    workspaceVM.showPersonNameTagsInDetail.toggle()
                    workspaceVM.saveWorkspaceState()
                }
                .keyboardShortcut("p", modifiers: [.command])
            }

            CommandGroup(after: .pasteboard) {
                Divider()

                Button("Select All") {
                    if let idx = workspaceVM.activeTabIndex {
                        let allIDs = workspaceVM.pagedSlice(for: workspaceVM.tabs[idx]).pageItems.map(\.id)
                        workspaceVM.tabs[idx].selectedAssetIDs = Set(allIDs)
                        workspaceVM.tabs[idx].selectedAssetID = allIDs.first
                    }
                }
                .keyboardShortcut("a", modifiers: [.command])

                Button("Adjust Date and Time...") {
                    workspaceVM.presentDateTimeEditForActiveSelection()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
    }
}