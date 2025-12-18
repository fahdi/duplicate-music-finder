import Foundation
import iTunesLibrary
import AVFoundation


class MusicScanner {
    enum ScanError: Error {
        case libraryAccessDenied
        case libraryNotFound
        case unknown
    }
    
    func scanAppleMusicLibrary() async throws -> [TrackModel] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // Initialize ITLibrary to access the user's Music app data
                    // This requires the NSAppleMusicUsageDescription key in Info.plist
                    let library = try ITLibrary(apiVersion: "1.0")
                    
                    let allItems = library.allMediaItems
                    var tracks: [TrackModel] = []
                    
                    for item in allItems {
                        // Filter for music tracks only (ignoring podcasts, videos if desired, though prompt said duplicate tracks)
                        // For now we include all "audio" that has a location
                        guard item.mediaKind == .kindSong,
                              let location = item.location else {
                            continue
                        }
                        
                        let track = TrackModel(
                            id: String(format: "%llx", item.persistentID.uint64Value), // Convert persistent ID number to hex string for stability
                            title: item.title,
                            artist: item.artist?.name ?? "Unknown Artist",
                            album: item.album.title ?? "Unknown Album",
                            duration: Double(item.totalTime) / 1000.0, // ITLibrary provides milliseconds
                            fileURL: location,
                            bitRate: Int(item.bitrate),
                            sampleRate: Int(item.sampleRate),
                            dateAdded: item.addedDate,
                            fileFormat: location.pathExtension.lowercased()
                        )
                        tracks.append(track)
                    }
                    
                    print("Scanned \(tracks.count) tracks from Music.app")
                    continuation.resume(returning: tracks)
                    
                } catch {
                    print("Error accessing music library: \(error)")
                    continuation.resume(throwing: ScanError.unknown)
                }
            }
        }
    }

    func scanFolder(at url: URL) async throws -> [TrackModel] {
        var tracks: [TrackModel] = []
        let fileManager = FileManager.default
        
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .nameKey]
        
        // Create enumerator to recursive scan
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return []
        }
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                  resourceValues.isRegularFile == true else {
                continue
            }
            
            let ext = fileURL.pathExtension.lowercased()
            if ["mp3", "m4a", "wav", "aac", "flac", "aiff"].contains(ext) {
                if let track = await processFile(at: fileURL) {
                    tracks.append(track)
                }
            }
        }
        
        return tracks
    }
    
    private func processFile(at url: URL) async -> TrackModel? {
        // Use AVAsset to read metadata
        let asset = AVAsset(url: url)
        
        do {
            let duration = try await asset.load(.duration)
            let metadata = try await asset.load(.commonMetadata)
            
            let titleItem = AVMetadataItem.metadataItems(from: metadata, withKey: AVMetadataKey.commonKeyTitle, keySpace: .common).first
            let artistItem = AVMetadataItem.metadataItems(from: metadata, withKey: AVMetadataKey.commonKeyArtist, keySpace: .common).first
            let albumItem = AVMetadataItem.metadataItems(from: metadata, withKey: AVMetadataKey.commonKeyAlbumName, keySpace: .common).first
            
            let title = (try? await titleItem?.load(.stringValue)) ?? url.deletingPathExtension().lastPathComponent
            let artist = (try? await artistItem?.load(.stringValue)) ?? "Unknown Artist"
            let album = (try? await albumItem?.load(.stringValue)) ?? "Unknown Album"
            
            // Generate a unique ID based on file path hash or similar since we don't have persistent ID
            let id = String(format: "%llx", url.path.hashValue) 
            
            return TrackModel(
                id: id,
                title: title,
                artist: artist,
                album: album,
                duration: CMTimeGetSeconds(duration),
                fileURL: url,
                bitRate: 0, // Harder to get from AVAsset without deeper inspection
                sampleRate: 0,
                dateAdded: nil, // Could get file creation date
                fileFormat: url.pathExtension.lowercased()
            )
            
        } catch {
            print("Failed to process file \(url.lastPathComponent): \(error)")
            return nil
        }
    }
}
