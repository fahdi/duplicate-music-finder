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
    
    // Smart Tag / Identify State
    @Published var identifyResults: [IdentifyResult] = []
    @Published var isIdentifying: Bool = false
    @Published var showIdentifyView: Bool = false
    private var shouldAbortIdentify = false
    
    // AcoustID API Key from https://acoustid.org/my-applications
    var acoustidApiKey: String = "RsAFCdlGZU"
    
    private let scanner = MusicScanner()
    private let duplicateEngine = DuplicateEngine()
    private let selectionManager = SelectionManager()
    private let trashHandler = FileTrashHandler()
    private let fingerprintService = AudioFingerprintService()
    
    // Smart Tag Services
    private let chromaprintService = ChromaprintService()
    private lazy var acoustidService = AcoustIDService(apiKey: acoustidApiKey)
    private let musicBrainzService = MusicBrainzService()
    private let coverArtService = CoverArtService()
    private let metadataWriterService = MetadataWriterService()
    
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
    
    // MARK: - Smart Tag / Identify
    
    @MainActor
    func identifyTracks(_ tracksToIdentify: [TrackModel]) {
        guard !isIdentifying else { return }
        guard !acoustidApiKey.isEmpty else {
            statusMessage = "Please set your AcoustID API key first"
            return
        }
        
        isIdentifying = true
        showIdentifyView = true
        
        // Initialize results with pending status
        identifyResults = tracksToIdentify.map { track in
            IdentifyResult(
                originalTrack: track,
                suggestedMetadata: [],
                selectedMetadataIndex: nil,
                status: .pending
            )
        }
        
        Task {
            for i in 0..<identifyResults.count {
                // Check for abort
                if shouldAbortIdentify {
                    shouldAbortIdentify = false
                    statusMessage = "Identification aborted"
                    break
                }
                await identifySingleTrack(at: i)
            }
            
            isIdentifying = false
            let foundCount = identifyResults.filter { 
                if case .found = $0.status { return true }
                return false
            }.count
            statusMessage = "Identified \(foundCount)/\(identifyResults.count) tracks"
        }
    }
    
    @MainActor
    private func identifySingleTrack(at index: Int) async {
        let track = identifyResults[index].originalTrack
        guard let fileURL = track.fileURL else {
            identifyResults[index].status = .error("No file URL")
            return
        }
        
        identifyResults[index].status = .identifying
        statusMessage = "Identifying: \(track.title)..."
        
        do {
            // Step 1: Generate Chromaprint fingerprint
            let (fingerprint, duration) = try await chromaprintService.generateFingerprint(for: fileURL)
            
            // Step 2: Look up in AcoustID
            let acoustResults = try await acoustidService.lookup(fingerprint: fingerprint, duration: duration)
            
            // Step 3: Get detailed metadata from MusicBrainz for top matches
            var metadataResults: [MusicMetadata] = []
            
            // Get detailed info for top 3 matches
            for acoustResult in acoustResults.prefix(3) {
                do {
                    var metadata = try await musicBrainzService.getRecording(id: acoustResult.recordingId)
                    metadata.confidence = acoustResult.score
                    
                    // Try to get artwork
                    if let releaseId = metadata.releaseId ?? acoustResult.releaseId {
                        if let artworkURL = try? await coverArtService.getArtworkURL(releaseId: releaseId) {
                            metadata.artworkURL = artworkURL
                        }
                    }
                    
                    metadataResults.append(metadata)
                } catch {
                    print("[Identify] MusicBrainz error for \(acoustResult.recordingId): \(error)")
                    // Still add basic info from AcoustID
                    metadataResults.append(MusicMetadata(
                        recordingId: acoustResult.recordingId,
                        releaseId: acoustResult.releaseId,
                        title: acoustResult.title,
                        artist: acoustResult.artists.joined(separator: ", "),
                        album: acoustResult.album ?? "Unknown Album",
                        confidence: acoustResult.score
                    ))
                }
            }
            
            identifyResults[index].suggestedMetadata = metadataResults
            identifyResults[index].selectedMetadataIndex = 0 // Auto-select first match
            identifyResults[index].status = .found(matchCount: metadataResults.count)
            
            // Auto-write metadata if match found with high confidence
            if let bestMatch = metadataResults.first, bestMatch.confidence >= 0.7 {
                do {
                    try await metadataWriterService.writeMetadata(bestMatch, to: fileURL)
                    print("[Identify] ✅ Auto-wrote metadata for: \(track.title)")
                } catch {
                    print("[Identify] ⚠️ Could not write metadata: \(error)")
                }
            }
            
        } catch {
            print("[Identify] Error for \(track.title): \(error)")
            identifyResults[index].status = .error(error.localizedDescription)
        }
    }
    
    @MainActor
    func identifyAllTracks() {
        identifyTracks(tracks)
    }
    
    @MainActor
    func abortIdentification() {
        shouldAbortIdentify = true
        isIdentifying = false
        statusMessage = "Aborting identification..."
    }
    
    // MARK: - Standalone Metadata Fixing
    
    @MainActor
    func fixMetadataForLibrary() {
        guard !isIdentifying && !isScanning else { return }
        
        isScanning = true
        statusMessage = "Scanning Music Library for metadata fix..."
        
        Task {
            do {
                let scannedTracks = try await scanner.scanAppleMusicLibrary()
                self.tracks = scannedTracks
                self.statusMessage = "Found \(scannedTracks.count) tracks. Starting identification..."
                isScanning = false
                
                // Now identify all tracks
                identifyTracks(scannedTracks)
                
            } catch {
                self.statusMessage = "Error scanning: \(error.localizedDescription)"
                isScanning = false
            }
        }
    }
    
    @MainActor
    func fixMetadataForFolder(at url: URL) {
        guard !isIdentifying && !isScanning else { return }
        
        isScanning = true
        statusMessage = "Scanning folder for metadata fix..."
        
        Task {
            do {
                let scannedTracks = try await scanner.scanFolder(at: url)
                self.tracks = scannedTracks
                self.statusMessage = "Found \(scannedTracks.count) audio files. Starting identification..."
                isScanning = false
                
                // Now identify all tracks
                identifyTracks(scannedTracks)
                
            } catch {
                self.statusMessage = "Error scanning folder: \(error.localizedDescription)"
                isScanning = false
            }
        }
    }
    
    /// Apply metadata to a file (called from UI when user clicks Apply)
    func applyMetadata(_ metadata: MusicMetadata, to fileURL: URL) async throws {
        try await metadataWriterService.writeMetadata(metadata, to: fileURL)
        await MainActor.run {
            statusMessage = "Applied: \(metadata.title) by \(metadata.artist)"
        }
    }
}
