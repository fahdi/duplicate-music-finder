import Foundation

struct TrackModel: Identifiable, Hashable {
    let id: String // Persistent ID from iTunes library
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let fileURL: URL?
    let bitRate: Int?
    let sampleRate: Int?
    let dateAdded: Date?
    let fileFormat: String // e.g., "mp3", "m4a"
    
    // Audio fingerprint for duplicate detection
    var fingerprint: AudioFingerprint?

    // Helper for debugging
    var debugDescription: String {
        "\(title) - \(artist) [\(id)]"
    }
}
