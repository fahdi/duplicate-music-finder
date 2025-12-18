import Foundation

/// Metadata fetched from MusicBrainz via AcoustID fingerprint lookup
struct MusicMetadata: Identifiable, Equatable {
    var id: String { recordingId ?? UUID().uuidString }
    
    // MusicBrainz IDs
    var recordingId: String?
    var releaseId: String?
    var artistId: String?
    
    // Core metadata
    var title: String
    var artist: String
    var album: String
    var albumArtist: String?
    
    // Track info
    var trackNumber: Int?
    var discNumber: Int?
    var totalTracks: Int?
    var year: Int?
    
    // Additional
    var genre: String?
    var artworkURL: URL?
    
    // Confidence from AcoustID (0.0 - 1.0)
    var confidence: Float
    
    /// Creates empty metadata
    static var empty: MusicMetadata {
        MusicMetadata(
            title: "Unknown",
            artist: "Unknown Artist",
            album: "Unknown Album",
            confidence: 0
        )
    }
}

/// Result of identifying a track via fingerprint
struct IdentifyResult: Identifiable {
    let id = UUID()
    let originalTrack: TrackModel
    var suggestedMetadata: [MusicMetadata]  // Multiple matches possible
    var selectedMetadataIndex: Int?         // User's selection
    var status: IdentifyStatus
    
    enum IdentifyStatus: Equatable {
        case pending
        case identifying
        case found(matchCount: Int)
        case notFound
        case error(String)
    }
    
    var selectedMetadata: MusicMetadata? {
        guard let index = selectedMetadataIndex, index < suggestedMetadata.count else {
            return suggestedMetadata.first
        }
        return suggestedMetadata[index]
    }
    
    var isSelected: Bool {
        selectedMetadataIndex != nil || !suggestedMetadata.isEmpty
    }
}
