import Foundation
import SwiftUI

/// Represents a file or folder item returned by the FluxCDN /api/files endpoint.
public struct FileItem: Identifiable, Codable, Hashable {
    public var id: String { relativePath }
    
    public let name: String
    public let relativePath: String
    public let isDirectory: Bool
    public let size: Int64
    public let createdAt: String?
    public let modifiedAt: String?
    public let url: String?
    public let thumbnailUrl: String?
    public let mimeType: String?
    public let extensionName: String?
    public let isFavorite: Bool?
    public let isShared: Bool?
    public let shareId: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case relativePath
        case isDirectory
        case size
        case createdAt
        case modifiedAt
        case url
        case thumbnailUrl
        case mimeType
        case extensionName = "extension"
        case isFavorite
        case isShared
        case shareId
    }
    
    public init(
        name: String,
        relativePath: String,
        isDirectory: Bool,
        size: Int64 = 0,
        createdAt: String? = nil,
        modifiedAt: String? = nil,
        url: String? = nil,
        thumbnailUrl: String? = nil,
        mimeType: String? = nil,
        extensionName: String? = nil,
        isFavorite: Bool? = false,
        isShared: Bool? = false,
        shareId: String? = nil
    ) {
        self.name = name
        self.relativePath = relativePath
        self.isDirectory = isDirectory
        self.size = size
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.url = url
        self.thumbnailUrl = thumbnailUrl
        self.mimeType = mimeType
        self.extensionName = extensionName
        self.isFavorite = isFavorite
        self.isShared = isShared
        self.shareId = shareId
    }
    
    // MARK: - Helper Computed Properties
    
    public var formattedSize: String {
        if isDirectory {
            return "Folder"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    public var formattedDate: String {
        guard let dateString = modifiedAt ?? createdAt else { return "" }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = isoFormatter.date(from: dateString)
        if date == nil {
            let standardIso = ISO8601DateFormatter()
            date = standardIso.date(from: dateString)
        }
        
        guard let finalDate = date else { return dateString }
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: finalDate)
    }
    
    public var isImage: Bool {
        let ext = (extensionName ?? (name as NSString).pathExtension).lowercased().replacingOccurrences(of: ".", with: "")
        return ["png", "jpg", "jpeg", "webp", "gif", "svg", "bmp", "heic", "tiff"].contains(ext)
    }
    
    public var isVideo: Bool {
        let ext = (extensionName ?? (name as NSString).pathExtension).lowercased().replacingOccurrences(of: ".", with: "")
        return ["mp4", "webm", "mov", "mkv", "avi", "m4v"].contains(ext)
    }
    
    public var isAudio: Bool {
        let ext = (extensionName ?? (name as NSString).pathExtension).lowercased().replacingOccurrences(of: ".", with: "")
        return ["mp3", "wav", "ogg", "flac", "aac", "m4a", "wma"].contains(ext)
    }
    
    public var isDocument: Bool {
        let ext = (extensionName ?? (name as NSString).pathExtension).lowercased().replacingOccurrences(of: ".", with: "")
        return ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "md", "csv", "rtf"].contains(ext)
    }
    
    public var isCode: Bool {
        let ext = (extensionName ?? (name as NSString).pathExtension).lowercased().replacingOccurrences(of: ".", with: "")
        return ["js", "ts", "vue", "json", "html", "css", "scss", "py", "swift", "c", "cpp", "cs", "go", "rs", "java", "php", "sh", "yml", "yaml", "xml", "sql"].contains(ext)
    }
    
    public var isArchive: Bool {
        let ext = (extensionName ?? (name as NSString).pathExtension).lowercased().replacingOccurrences(of: ".", with: "")
        return ["zip", "tar", "gz", "7z", "rar", "bz2", "xz"].contains(ext)
    }
    
    public var systemIconName: String {
        if isDirectory {
            return "folder.fill"
        }
        if isImage {
            return "photo.fill"
        }
        if isVideo {
            return "play.rectangle.fill"
        }
        if isAudio {
            return "music.note"
        }
        if isDocument {
            if extensionName?.contains("pdf") == true || name.hasSuffix(".pdf") {
                return "doc.richtext.fill"
            }
            return "doc.text.fill"
        }
        if isCode {
            return "chevron.left.forwardslash.chevron.right"
        }
        if isArchive {
            return "doc.zipper"
        }
        return "doc.fill"
    }
    
    public var iconColor: Color {
        if isDirectory {
            return .blue
        }
        if isImage {
            return .purple
        }
        if isVideo {
            return .red
        }
        if isAudio {
            return .pink
        }
        if isDocument {
            return .orange
        }
        if isCode {
            return .teal
        }
        if isArchive {
            return .yellow
        }
        return .gray
    }
}
