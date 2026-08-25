import Foundation

/// Model for GitHub Release response from GitHub REST API
public struct GitHubRelease: Codable, Identifiable {
    public let id: Int
    public let name: String?
    public let tagName: String?
    public let publishedAt: String?
    public let createdAt: String?
    public let body: String?
    public let assets: [GitHubReleaseAsset]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tagName = "tag_name"
        case publishedAt = "published_at"
        case createdAt = "created_at"
        case body
        case assets
    }
    
    public var effectiveDate: Date? {
        guard let dateString = publishedAt ?? createdAt else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: dateString) {
            return d
        }
        let standardIso = ISO8601DateFormatter()
        return standardIso.date(from: dateString)
    }
    
    public var ipaAsset: GitHubReleaseAsset? {
        return assets?.first(where: { $0.name.lowercased().hasSuffix(".ipa") }) ?? assets?.first
    }
    
    public var formattedDate: String {
        guard let date = effectiveDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

public struct GitHubReleaseAsset: Codable, Identifiable {
    public let id: Int
    public let name: String
    public let size: Int64?
    public let browserDownloadUrl: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case size
        case browserDownloadUrl = "browser_download_url"
    }
    
    public var formattedSize: String {
        guard let size = size else { return "" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
