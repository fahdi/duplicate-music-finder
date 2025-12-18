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
    
    // Fingerprint Settings
    @Published var fingerprintSettings = FingerprintSettings()
    
    // Audio Playback
    @Published var autoPlayEnabled: Bool = true
    let audioPlayer = AudioPlayerService()
    
    private let scanner = MusicScanner()
    private let duplicateEngine = DuplicateEngine()
    private let selectionManager = SelectionManager()
    private let trashHandler = FileTrashHandler()
    private let fingerprintService = AudioFingerprintService()
    
    /// Play a track if auto-play is enabled
    func playTrackIfEnabled(_ track: TrackModel) {
        guard autoPlayEnabled, let url = track.fileURL else { return }
        audioPlayer.play(url: url, trackId: track.id)
    }
    
    /// Stop current playback
    func stopPlayback() {
        audioPlayer.stop()
    }

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
        
        // Stop any playback and clear previous results
        stopPlayback()
        duplicateGroups = []
        tracks = []
        
        isScanning = true
        statusMessage = "Scanning Music Library..."
        
        Task {
            do {
                // Scan
                var scannedTracks = try await scanner.scanAppleMusicLibrary()
                self.statusMessage = "Scan complete. Found \(scannedTracks.count) tracks."
                
                // Generate fingerprints if enabled (in parallel for speed)
                if criteria.matchFingerprint {
                    self.statusMessage = "Generating audio fingerprints..."
                    
                    // Process in parallel using TaskGroup
                    let settings = fingerprintSettings
                    let service = fingerprintService
                    
                    await withTaskGroup(of: (Int, AudioFingerprint?).self) { group in
                        for i in 0..<scannedTracks.count {
                            guard let url = scannedTracks[i].fileURL else { continue }
                            
                            group.addTask {
                                do {
                                    let fingerprint = try await service.generateFingerprint(for: url, settings: settings)
                                    return (i, fingerprint)
                                } catch {
                                    print("Failed to fingerprint \(scannedTracks[i].title): \(error)")
                                    return (i, nil)
                                }
                            }
                        }
                        
                        var fingerprintedCount = 0
                        for await (index, fingerprint) in group {
                            if let fp = fingerprint {
                                scannedTracks[index].fingerprint = fp
                                fingerprintedCount += 1
                                
                                // Update progress
                                if fingerprintedCount % 5 == 0 {
                                    self.statusMessage = "Fingerprinting... \(fingerprintedCount)/\(scannedTracks.count)"
                                }
                            }
                        }
                        
                        self.statusMessage = "Fingerprinted \(fingerprintedCount) tracks. Finding duplicates..."
                    }
                }
                
                self.tracks = scannedTracks
                
                // Find Duplicates
                let groups = await duplicateEngine.findDuplicates(
                    in: scannedTracks,
                    criteria: self.criteria,
                    fingerprintSettings: criteria.matchFingerprint ? fingerprintSettings : nil
                )
                self.duplicateGroups = groups
                
                self.statusMessage = "Found \(groups.count) duplicate groups."
                
            } catch {
                self.statusMessage = "Error scanning: \(error.localizedDescription)"
            }
            self.isScanning = false
        }
    }
    
    @MainActor
    func scanFolder(at url: URL) {
        guard !isScanning else { return }
        
        // Stop any playback and clear previous results
        stopPlayback()
        duplicateGroups = []
        tracks = []
        
        isScanning = true
        statusMessage = "Scanning folder..."
        
        Task {
            do {
                // Scan folder
                var scannedTracks = try await scanner.scanFolder(at: url)
                self.statusMessage = "Found \(scannedTracks.count) audio files."
                
                // Generate fingerprints if enabled (in parallel for speed)
                if criteria.matchFingerprint {
                    self.statusMessage = "Generating audio fingerprints..."
                    
                    let settings = fingerprintSettings
                    let service = fingerprintService
                    
                    await withTaskGroup(of: (Int, AudioFingerprint?).self) { group in
                        for i in 0..<scannedTracks.count {
                            guard let url = scannedTracks[i].fileURL else { continue }
                            
                            group.addTask {
                                do {
                                    let fingerprint = try await service.generateFingerprint(for: url, settings: settings)
                                    return (i, fingerprint)
                                } catch {
                                    print("Failed to fingerprint \(scannedTracks[i].title): \(error)")
                                    return (i, nil)
                                }
                            }
                        }
                        
                        var fingerprintedCount = 0
                        for await (index, fingerprint) in group {
                            if let fp = fingerprint {
                                scannedTracks[index].fingerprint = fp
                                fingerprintedCount += 1
                                
                                if fingerprintedCount % 5 == 0 {
                                    self.statusMessage = "Fingerprinting... \(fingerprintedCount)/\(scannedTracks.count)"
                                }
                            }
                        }
                        
                        self.statusMessage = "Fingerprinted \(fingerprintedCount) tracks. Finding duplicates..."
                    }
                }
                
                self.tracks = scannedTracks
                
                // Find Duplicates
                let groups = await duplicateEngine.findDuplicates(
                    in: scannedTracks,
                    criteria: self.criteria,
                    fingerprintSettings: criteria.matchFingerprint ? fingerprintSettings : nil
                )
                self.duplicateGroups = groups
                
                self.statusMessage = "Found \(groups.count) duplicate groups in folder."
                
            } catch {
                self.statusMessage = "Error scanning folder: \(error.localizedDescription)"
            }
            self.isScanning = false
        }
    }
}
