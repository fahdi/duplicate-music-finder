import Foundation
import ID3TagEditor

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
            // M4A writing would require different approach (MP4v2 or similar)
            throw WriterError.unsupportedFormat("M4A")
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
}
