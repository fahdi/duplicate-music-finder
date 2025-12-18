import SwiftUI

struct DuplicateGroupView: View {
    let group: DuplicateGroup
    @EnvironmentObject var viewModel: AppViewModel
    
    var body: some View {
        Section(header: Text(groupHeader)) {
            ForEach(group.tracks) { track in
                TrackRowView(
                    track: track,
                    isSelected: group.tracksToRemove.contains(track.id),
                    isKept: group.tracksToKeep.contains(track.id),
                    onToggle: {
                        toggleInternal(track)
                    }
                )
            }
        }
    }
    
    private var groupHeader: String {
        guard let first = group.tracks.first else { return "Group" }
        return "\(first.title) - \(first.artist) (\(group.tracks.count) items)"
    }
    
    private func toggleInternal(_ track: TrackModel) {
        // Find index of group in viewModel and update
        // In a real app we might pass a Binding or use a more efficient update mechanism
        if let index = viewModel.duplicateGroups.firstIndex(where: { $0.id == group.id }) {
            var updatedGroup = viewModel.duplicateGroups[index]
            
            if updatedGroup.tracksToKeep.contains(track.id) {
                // If it was kept, unkeep it (manual override)
                updatedGroup.tracksToKeep.remove(track.id)
            } else if updatedGroup.tracksToRemove.contains(track.id) {
                // If it was removed, uncheck it
                updatedGroup.tracksToRemove.remove(track.id)
            } else {
                // Toggle to Remove (default action when clicking non-kept)
                updatedGroup.tracksToRemove.insert(track.id)
            }
            
            viewModel.duplicateGroups[index] = updatedGroup
        }
    }
}
