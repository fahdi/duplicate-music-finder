import SwiftUI

class AppViewModel: ObservableObject {
    @Published var tracks: [TrackModel] = []
    @Published var isScanning: Bool = false
    @Published var statusMessage: String = "Ready to scan"
    
    // Duplicate State
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var criteria = DuplicateCriteria()
    @Published var activeRule: AutoSelectionRule = .manual
    @Published var showingDeleteConfirmation: Bool = false
    
    private let scanner = MusicScanner()
    private let duplicateEngine = DuplicateEngine()
    private let selectionManager = SelectionManager()
    private let trashHandler = FileTrashHandler()

    @MainActor
    func applySelectionRule() {
        self.duplicateGroups = selectionManager.applyRule(activeRule, to: self.duplicateGroups)
    }

    @MainActor
    func deleteSelectedTracks() {
        Task {
            // Collect all tracks marked for removal
            var tracksToDelete: [TrackModel] = []
            for group in duplicateGroups {
                for trackID in group.tracksToRemove {
                    if let track = group.tracks.first(where: { $0.id == trackID }) {
                        tracksToDelete.append(track)
                    }
                }
            }
            
            guard !tracksToDelete.isEmpty else { return }
            
            statusMessage = "Moving \(tracksToDelete.count) tracks to Trash..."
            
            do {
                let deletedCount = try await trashHandler.moveTracksToTrash(tracksToDelete)
                
                // Remove from local state
                let deletedIDs = Set(tracksToDelete.map { $0.id })
                self.tracks.removeAll(where: { deletedIDs.contains($0.id) })
                
                // Re-calculate duplicates (or just remove them from groups locally for speed)
                // For simplicity, we just filter them out of current groups and cleanup empty groups
                self.duplicateGroups = self.duplicateGroups.compactMap { group in
                    var newGroup = group
                    newGroup.tracks.removeAll(where: { deletedIDs.contains($0.id) })
                    // Reset selection state for safely
                    newGroup.tracksToRemove.subtract(deletedIDs)
                    newGroup.tracksToKeep.subtract(deletedIDs) // Should not happen if logic correct
                    
                    return newGroup.tracks.count > 1 ? newGroup : nil
                }
                
                statusMessage = "Moved \(deletedCount) tracks to Trash."
            } catch {
                statusMessage = "Error deleting tracks: \(error.localizedDescription)"
            }
        }
    }

    @MainActor
    func scanLibrary() {
        guard !isScanning else { return }
        
        isScanning = true
        statusMessage = "Scanning Music Library..."
        
        Task {
            do {
                // Scan
                let scannedTracks = try await scanner.scanAppleMusicLibrary()
                self.tracks = scannedTracks
                self.statusMessage = "Scan complete. Found \(scannedTracks.count) tracks. Finding duplicates..."
                
                // Find Duplicates
                let groups = await duplicateEngine.findDuplicates(in: scannedTracks, criteria: self.criteria)
                self.duplicateGroups = groups
                
                self.statusMessage = "Found \(groups.count) duplicate groups."
                
            } catch {
                self.statusMessage = "Error scanning: \(error.localizedDescription)"
            }
            self.isScanning = false
        }
    }
}
