import Foundation

class SelectionManager {
    
    func applyRule(_ rule: AutoSelectionRule, to groups: [DuplicateGroup]) -> [DuplicateGroup] {
        if rule == .manual {
            // Do not modify existing selections if manual is chosen, or clear them?
            // Usually "Manual" just means "Stop auto-selecting", but here we might want to reset?
            // Let's assume applying "Manual" clears auto selections, or does nothing.
            // For now, let's clear selections to be safe if user explicitly clicks "Manual" after having a rule.
            return groups.map { group in
                var newGroup = group
                newGroup.tracksToKeep = []
                newGroup.tracksToRemove = []
                return newGroup
            }
        }
        
        return groups.map { group in
            var newGroup = group
            newGroup.tracksToKeep = []
            newGroup.tracksToRemove = []
            
            guard let keeper = determineKeeper(for: group, rule: rule) else {
                return newGroup
            }
            
            newGroup.tracksToKeep.insert(keeper.id)
            
            // Mark all others as remove
            for track in group.tracks {
                if track.id != keeper.id {
                    newGroup.tracksToRemove.insert(track.id)
                }
            }
            
            return newGroup
        }
    }
    
    private func determineKeeper(for group: DuplicateGroup, rule: AutoSelectionRule) -> TrackModel? {
        guard !group.tracks.isEmpty else { return nil }
        
        switch rule {
        case .highestBitrate:
            // Prefer higher bitrate. If equal, stabilize sort (e.g. by index or ID)
            return group.tracks.max(by: { ($0.bitRate ?? 0) < ($1.bitRate ?? 0) })
            
        case .longestDuration:
             return group.tracks.max(by: { $0.duration < $1.duration })
            
        case .oldesetAdded:
             // Need dateAdded. If nil, handle gracefully.
             // Min date is oldest.
             return group.tracks.min(by: {
                 ($0.dateAdded ?? Date.distantFuture) < ($1.dateAdded ?? Date.distantFuture)
             })
            
        case .latestAdded:
             return group.tracks.max(by: {
                 ($0.dateAdded ?? Date.distantPast) < ($1.dateAdded ?? Date.distantPast)
             })

        case .preferM4A:
             // Keep one that is m4a, if multiple, pick first/best.
             return group.tracks.first(where: { $0.fileFormat == "m4a" }) ?? group.tracks.first
             
        case .preferMP3:
             return group.tracks.first(where: { $0.fileFormat == "mp3" }) ?? group.tracks.first

        case .manual:
            return nil
        }
    }
}
