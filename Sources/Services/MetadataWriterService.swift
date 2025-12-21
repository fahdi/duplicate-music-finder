import Foundation
import ID3TagEditor
import AVFoundation

/// Service for writing metadata and artwork back to audio files.
/// Uses ID3TagEditor for MP3 files.
class MetadataWriterService {
    
    private let id3TagEditor = ID3TagEditor()
    private let coverArtService = CoverArtService()
    
    enum WriterError: Error, LocalizedError {
        case unsupportedFormat(String)
        case writeFailed(Error)
        case artworkDownloadFailed
        
        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let format):
                return "Cannot write metadata to \(format) files"
            case .writeFailed(let error):
                return "Failed to write: \(error.localizedDescription)"
            case .artworkDownloadFailed:
                return "Failed to download artwork"
            }
        }
    }
    
    /// Writes metadata to an audio file
    /// - Parameters:
    ///   - metadata: The metadata to write
    ///   - fileURL: URL of the audio file
    func writeMetadata(_ metadata: MusicMetadata, to fileURL: URL) async throws {
        let ext = fileURL.pathExtension.lowercased()
        
        switch ext {
        case "mp3":
            try await writeMP3Metadata(metadata, to: fileURL)
        case "m4a", "aac", "mp4":
            try await writeM4AMetadata(metadata, to: fileURL)
        case "flac":
            try await writeFLACMetadata(metadata, to: fileURL)
        default:
            throw WriterError.unsupportedFormat(ext.uppercased())
        }
    }
    
    /// Writes metadata to an MP3 file using ID3TagEditor
    private func writeMP3Metadata(_ metadata: MusicMetadata, to fileURL: URL) async throws {
        print("[MetadataWriter] Writing to: \(fileURL.lastPathComponent)")
        
        // Build ID3 tag
        var tagBuilder = ID32v3TagBuilder()
            .title(frame: ID3FrameWithStringContent(content: metadata.title))
            .artist(frame: ID3FrameWithStringContent(content: metadata.artist))
            .album(frame: ID3FrameWithStringContent(content: metadata.album))
        
        // Add optional fields
        if let albumArtist = metadata.albumArtist {
            tagBuilder = tagBuilder.albumArtist(frame: ID3FrameWithStringContent(content: albumArtist))
        }
        
        if let trackNumber = metadata.trackNumber {
            tagBuilder = tagBuilder.trackPosition(frame: ID3FramePartOfTotal(part: trackNumber, total: metadata.totalTracks))
        }
        
        if let year = metadata.year {
            tagBuilder = tagBuilder.recordingYear(frame: ID3FrameWithIntegerContent(value: year))
        }
        
        if let genre = metadata.genre {
            tagBuilder = tagBuilder.genre(frame: ID3FrameGenre(genre: nil, description: genre))
        }
        
        // Download and add artwork if available
        if let artworkURL = metadata.artworkURL {
            do {
                let artworkData = try await coverArtService.downloadArtwork(from: artworkURL)
                let artworkFrame = ID3FrameAttachedPicture(
                    picture: artworkData,
                    type: .frontCover,
                    format: .jpeg
                )
                tagBuilder = tagBuilder.attachedPicture(pictureType: .frontCover, frame: artworkFrame)
                print("[MetadataWriter] ✅ Added artwork (\(artworkData.count / 1024) KB)")
            } catch {
                print("[MetadataWriter] ⚠️ Could not download artwork: \(error)")
                // Continue without artwork
            }
        }
        
        let tag = tagBuilder.build()
        
        do {
            try id3TagEditor.write(tag: tag, to: fileURL.path)
            print("[MetadataWriter] ✅ Wrote metadata to: \(fileURL.lastPathComponent)")
            print("[MetadataWriter]    Title: \(metadata.title)")
            print("[MetadataWriter]    Artist: \(metadata.artist)")
            print("[MetadataWriter]    Album: \(metadata.album)")
        } catch {
            print("[MetadataWriter] ❌ Failed: \(error)")
            throw WriterError.writeFailed(error)
        }
    }
    
    /// Writes metadata to an M4A/AAC file using AVFoundation
    private func writeM4AMetadata(_ metadata: MusicMetadata, to fileURL: URL) async throws {
        print("[MetadataWriter] Writing M4A to: \(fileURL.lastPathComponent)")
        
        // 1. Setup asset and export session
        let asset = AVURLAsset(url: fileURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw WriterError.writeFailed(NSError(domain: "MetadataWriter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"]))
        }
        
        // 2. Prepare metadata items
        var metadataItems: [AVMetadataItem] = []
        
        func addMetadataItem(key: AVMetadataKey, value: Any, keySpace: AVMetadataKeySpace = .common) {
            let item = AVMutableMetadataItem()
            item.key = key.rawValue as (NSCopying & NSObjectProtocol)
            item.keySpace = keySpace
            item.value = value as? (NSCopying & NSObjectProtocol)
            metadataItems.append(item)
        }
        
        // Core fields (Common KeySpace)
        addMetadataItem(key: .commonKeyTitle, value: metadata.title)
        addMetadataItem(key: .commonKeyArtist, value: metadata.artist)
        addMetadataItem(key: .commonKeyAlbumName, value: metadata.album)
        
        // iTunes specific fields
        if let albumArtist = metadata.albumArtist {
            addMetadataItem(key: .iTunesMetadataKeyAlbumArtist, value: albumArtist, keySpace: .iTunes)
        }
        
        if let year = metadata.year {
            addMetadataItem(key: .iTunesMetadataKeyReleaseDate, value: String(year), keySpace: .iTunes)
        }
        
        if let genre = metadata.genre {
            addMetadataItem(key: .iTunesMetadataKeyUserGenre, value: genre, keySpace: .iTunes)
        }
        
        // Track number (iTunes format)
        if let trackNumber = metadata.trackNumber {
            let total = metadata.totalTracks ?? 0
            var data = Data(count: 8)
            data[2] = UInt8((trackNumber >> 8) & 0xFF)
            data[3] = UInt8(trackNumber & 0xFF)
            data[4] = UInt8((total >> 8) & 0xFF)
            data[5] = UInt8(total & 0xFF)
            
            addMetadataItem(key: .iTunesMetadataKeyTrackNumber, value: data as NSData, keySpace: .iTunes)
        }
        
        // Artwork
        if let artworkURL = metadata.artworkURL {
            do {
                let artworkData = try await coverArtService.downloadArtwork(from: artworkURL)
                addMetadataItem(key: .commonKeyArtwork, value: artworkData as NSData)
                print("[MetadataWriter] ✅ Added M4A artwork (\(artworkData.count / 1024) KB)")
            } catch {
                print("[MetadataWriter] ⚠️ Could not download M4A artwork: \(error)")
            }
        }
        
        // 3. Set output URL (temporary)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .m4a
        exportSession.metadata = metadataItems
        
        // 4. Perform export
        await exportSession.export()
        
        if exportSession.status == .completed {
            // 5. Replace original file
            do {
                try FileManager.default.removeItem(at: fileURL)
                try FileManager.default.moveItem(at: tempURL, to: fileURL)
                print("[MetadataWriter] ✅ Successfully updated M4A: \(fileURL.lastPathComponent)")
            } catch {
                print("[MetadataWriter] ❌ File replacement failed: \(error)")
                throw WriterError.writeFailed(error)
            }
        } else {
            let error = exportSession.error ?? NSError(domain: "MetadataWriter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Export failed with status \(exportSession.status.rawValue)"])
            print("[MetadataWriter] ❌ Export failed: \(error)")
            throw WriterError.writeFailed(error)
        }
    }
    
    /// Writes metadata to a FLAC file using a hybrid approach:
    /// - AVFoundation for text metadata (fast, native)
    /// - metaflac CLI for artwork (reliable PICTURE block embedding)
    private func writeFLACMetadata(_ metadata: MusicMetadata, to fileURL: URL) async throws {
        print("[MetadataWriter] Writing FLAC to: \(fileURL.lastPathComponent)")
        
        let asset = AVURLAsset(url: fileURL)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw WriterError.writeFailed(NSError(domain: "MetadataWriter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create FLAC export session"]))
        }
        
        var metadataItems: [AVMetadataItem] = []
        
        func addMetadataItem(key: AVMetadataKey, value: Any, keySpace: AVMetadataKeySpace = .common) {
            let item = AVMutableMetadataItem()
            item.key = key.rawValue as (NSCopying & NSObjectProtocol)
            item.keySpace = keySpace
            item.value = value as? (NSCopying & NSObjectProtocol)
            metadataItems.append(item)
        }
        
        // Write text metadata via AVFoundation
        addMetadataItem(key: .commonKeyTitle, value: metadata.title)
        addMetadataItem(key: .commonKeyArtist, value: metadata.artist)
        addMetadataItem(key: .commonKeyAlbumName, value: metadata.album)
        
        if let year = metadata.year {
            addMetadataItem(key: .commonKeyCreationDate, value: String(year))
        }
        
        if let genre = metadata.genre {
            addMetadataItem(key: .commonKeyType, value: genre)
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".flac")
        exportSession.outputURL = tempURL
        exportSession.outputFileType = AVFileType("org.xiph.flac")
        exportSession.metadata = metadataItems
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            let error = exportSession.error ?? NSError(domain: "MetadataWriter", code: 4, userInfo: [NSLocalizedDescriptionKey: "FLAC Export failed with status \(exportSession.status.rawValue)"])
            print("[MetadataWriter] ❌ FLAC Export failed: \(error)")
            throw WriterError.writeFailed(error)
        }
        
        // Replace original file with updated version
        do {
            try FileManager.default.removeItem(at: fileURL)
            try FileManager.default.moveItem(at: tempURL, to: fileURL)
            print("[MetadataWriter] ✅ Text metadata written to FLAC")
        } catch {
            print("[MetadataWriter] ❌ FLAC File replacement failed: \(error)")
            throw WriterError.writeFailed(error)
        }
        
        // Now embed artwork using metaflac (more reliable for PICTURE blocks)
        if let artworkURL = metadata.artworkURL {
            do {
                let artworkData = try await coverArtService.downloadArtwork(from: artworkURL)
                try await embedFLACArtworkViaMetaflac(artworkData: artworkData, flacFileURL: fileURL)
                print("[MetadataWriter] ✅ Artwork embedded via metaflac (\(artworkData.count / 1024) KB)")
            } catch {
                print("[MetadataWriter] ⚠️ Could not embed FLAC artwork: \(error)")
                // Don't throw - text metadata is already written successfully
            }
        }
    }
    
    /// Embeds artwork into FLAC file using metaflac CLI tool
    /// This is more reliable than AVFoundation for FLAC PICTURE blocks
    private func embedFLACArtworkViaMetaflac(artworkData: Data, flacFileURL: URL) async throws {
        // Save artwork to temp file
        let tempArtworkURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        try artworkData.write(to: tempArtworkURL)
        
        defer {
            try? FileManager.default.removeItem(at: tempArtworkURL)
        }
        
        // Check if metaflac is available
        let checkProcess = Process()
        checkProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        checkProcess.arguments = ["which", "metaflac"]
        
        let checkPipe = Pipe()
        checkProcess.standardOutput = checkPipe
        checkProcess.standardError = Pipe()
        
        try checkProcess.run()
        checkProcess.waitUntilExit()
        
        guard checkProcess.terminationStatus == 0 else {
            throw WriterError.writeFailed(NSError(
                domain: "MetadataWriter",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "metaflac not found. Install via: brew install flac"]
            ))
        }
        
        // Remove existing artwork blocks
        let removeProcess = Process()
        removeProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        removeProcess.arguments = [
            "metaflac",
            "--remove",
            "--block-type=PICTURE",
            flacFileURL.path
        ]
        
        try removeProcess.run()
        removeProcess.waitUntilExit()
        
        // Import new artwork
        let importProcess = Process()
        importProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        importProcess.arguments = [
            "metaflac",
            "--import-picture-from=\(tempArtworkURL.path)",
            flacFileURL.path
        ]
        
        let errorPipe = Pipe()
        importProcess.standardError = errorPipe
        
        try importProcess.run()
        importProcess.waitUntilExit()
        
        guard importProcess.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw WriterError.writeFailed(NSError(
                domain: "MetadataWriter",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: "metaflac failed: \(errorMessage)"]
            ))
        }
    }
}
