import Foundation

class DuplicateEngine {
    
    func findDuplicates(in tracks: [TrackModel], criteria: DuplicateCriteria) async -> [DuplicateGroup] {
        guard tracks.count > 1 else { return [] }
        
        return await Task.detached(priority: .userInitiated) {
            var groups: [DuplicateGroup] = []
            
            // Dictionary to group tracks by a strict key first (usually Title + Artist is a good start)
            // If fuzzy matching is needed (like duration tolerance), we might need a more complex approach.
            // Approach:
            // 1. Group by strict string keys requested.
            // 2. Iterate groups and Refine by duration if requested.
            
            // Step 1: Group by String Keys
            let groupedFn = Dictionary(grouping: tracks) { track -> String in
                var key = ""
                if criteria.matchTitle { key += track.title.lowercased() + "|" }
                if criteria.matchArtist { key += track.artist.lowercased() + "|" }
                if criteria.matchAlbum { key += track.album.lowercased() + "|" }
                // We don't include duration in key if we want tolerance support
                return key
            }
            
            // Step 2: Process subgroups
            for (commonKey, subTracks) in groupedFn {
                if subTracks.count < 2 { continue }
                
                if criteria.matchDuration {
                    // Split subTracks into clusters based on duration tolerance
                    let durationClusters = self.clusterByDuration(tracks: subTracks, tolerance: criteria.durationTolerance)
                    for cluster in durationClusters {
                        if cluster.count > 1 {
                            groups.append(DuplicateGroup(commonKey: commonKey, tracks: cluster))
                        }
                    }
                } else {
                    // Just add the group
                    groups.append(DuplicateGroup(commonKey: commonKey, tracks: subTracks))
                }
            }
            
            return groups.sorted(by: { $0.tracks.first?.title ?? "" < $1.tracks.first?.title ?? "" })
        }.value
    }
    
    private func clusterByDuration(tracks: [TrackModel], tolerance: TimeInterval) -> [[TrackModel]] {
        // Simple O(N^2) clustering or sorting approach. 
        // Since N (subTracks) is usually very small (2-10 duplicates), O(N^2) is fine.
        
        var clusters: [[TrackModel]] = []
        let sortedTracks = tracks.sorted(by: { $0.duration < $1.duration })
        
        var currentCluster: [TrackModel] = []
        
        for track in sortedTracks {
            if currentCluster.isEmpty {
                currentCluster.append(track)
                continue
            }
            
            // Compare with the first in cluster (or average). 
            // If within tolerance of the *first* item, add to cluster. 
            // Note: This matches "all in group are within tolerance of each other" roughly? 
            // Actually, usually we want "within tolerance of ANY in cluster" or "all within tolerance".
            // Let's assume absolute difference vs first element < tolerance.
            
            let reference = currentCluster[0]
            if abs(track.duration - reference.duration) <= tolerance {
                currentCluster.append(track)
            } else {
                clusters.append(currentCluster)
                currentCluster = [track]
            }
        }
        
        if !currentCluster.isEmpty {
            clusters.append(currentCluster)
        }
        
        return clusters
    }
}
