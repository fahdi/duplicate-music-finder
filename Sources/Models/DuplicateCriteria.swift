import Foundation

struct DuplicateCriteria: Equatable {
    var matchTitle: Bool = true
    var matchArtist: Bool = true
    var matchAlbum: Bool = true
    var matchDuration: Bool = true
    var durationTolerance: TimeInterval = 2.0 // Seconds
    
    // Audio fingerprint matching
    var matchFingerprint: Bool = false
}
