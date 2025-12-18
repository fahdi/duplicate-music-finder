import Foundation

struct DuplicateGroup: Identifiable, Hashable {
    let id: UUID = UUID()
    let commonKey: String // Debugging key
    var tracks: [TrackModel]
    var tracksToKeep: Set<String> = [] // IDs of tracks to keep
    var tracksToRemove: Set<String> = [] // IDs of tracks marked for removal
    
    // Helper to determine if a specific track is marked for removal
    func isMarkedForRemoval(_ track: TrackModel) -> Bool {
        return tracksToRemove.contains(track.id)
    }
}
