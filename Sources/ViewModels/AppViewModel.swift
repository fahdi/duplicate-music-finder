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
            
            statusMessage = "Processing \(tracksToDelete.count) tracks..."
            
            // 1. Remove from Music.app Library (Ghost Track Fix)
            // We do this first so the entry is gone.
            var libraryDeletionCount = 0
            for track in tracksToDelete {
                do {
                    try await MusicAppBridge.deleteTrack(persistentID: track.id)
                    libraryDeletionCount += 1
                } catch {
                    print("Failed to remove track \(track.title) from Music library: \(error)")
                    // Continue anyway to try and delete the file
                }
            }
            
            // 2. Move Physical Files to Trash
            statusMessage = "Removed \(libraryDeletionCount) from Library. Moving files to Trash..."
            
            do {
                let deletedCount = try await trashHandler.moveTracksToTrash(tracksToDelete)
                
                // Remove from local state
                let deletedIDs = Set(tracksToDelete.map { $0.id })
                self.tracks.removeAll(where: { deletedIDs.contains($0.id) })
                
                // Re-calculate duplicates
                self.duplicateGroups = self.duplicateGroups.compactMap { group in
                    var newGroup = group
                    newGroup.tracks.removeAll(where: { deletedIDs.contains($0.id) })
                    newGroup.tracksToRemove.subtract(deletedIDs)
                    
                    return newGroup.tracks.count > 1 ? newGroup : nil
                }
                
                statusMessage = "Cleaned up \(deletedCount) files (\(libraryDeletionCount) from Library)."
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
