import Foundation

/// Service for fetching detailed metadata from MusicBrainz API.
/// Rate limited to 1 request per second.
class MusicBrainzService {
    
    private let baseURL = "https://musicbrainz.org/ws/2"
    private let userAgent = "DuplicateMusicFinder/1.0 (https://github.com/shakir1311/duplicate-music-finder)"
    
    // Rate limiting
    private var lastRequestTime: Date?
    private let minRequestInterval: TimeInterval = 1.1 // Slightly over 1 second to be safe
    
    enum MusicBrainzError: Error, LocalizedError {
        case networkError(Error)
        case notFound
        case rateLimited
        case invalidResponse
        
        var errorDescription: String? {
            switch self {
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .notFound:
                return "Recording not found in MusicBrainz"
            case .rateLimited:
                return "Rate limited by MusicBrainz API"
            case .invalidResponse:
                return "Invalid response from MusicBrainz"
            }
        }
    }
    
    /// Fetches detailed metadata for a recording
    /// - Parameter recordingId: MusicBrainz recording ID
    /// - Returns: MusicMetadata with detailed info
    func getRecording(id recordingId: String) async throws -> MusicMetadata {
        print("[MusicBrainz] Fetching recording: \(recordingId)")
        
        // Rate limiting
        await enforceRateLimit()
        
        let urlString = "\(baseURL)/recording/\(recordingId)?inc=artists+releases+tags&fmt=json"
        guard let url = URL(string: urlString) else {
            throw MusicBrainzError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            lastRequestTime = Date()
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MusicBrainzError.invalidResponse
            }
            
            if httpResponse.statusCode == 404 {
                throw MusicBrainzError.notFound
            }
            
            if httpResponse.statusCode == 503 {
                throw MusicBrainzError.rateLimited
            }
            
            guard httpResponse.statusCode == 200 else {
                throw MusicBrainzError.invalidResponse
            }
            
            return try parseRecording(data, recordingId: recordingId)
            
        } catch let error as MusicBrainzError {
            throw error
        } catch {
            throw MusicBrainzError.networkError(error)
        }
    }
    
    private func enforceRateLimit() async {
        if let lastTime = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minRequestInterval {
                let delay = minRequestInterval - elapsed
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
    
    private func parseRecording(_ data: Data, recordingId: String) throws -> MusicMetadata {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MusicBrainzError.invalidResponse
        }
        
        let title = json["title"] as? String ?? "Unknown"
        
        // Parse artists
        var artistName = "Unknown Artist"
        if let artistCredit = json["artist-credit"] as? [[String: Any]] {
            let names = artistCredit.compactMap { $0["name"] as? String }
            artistName = names.joined(separator: ", ")
        }
        
        // Parse first release for album info
        var album = "Unknown Album"
        var releaseId: String?
        var year: Int?
        var trackNumber: Int?
        
        if let releases = json["releases"] as? [[String: Any]], let firstRelease = releases.first {
            album = firstRelease["title"] as? String ?? album
            releaseId = firstRelease["id"] as? String
            
            if let date = firstRelease["date"] as? String, date.count >= 4 {
                year = Int(date.prefix(4))
            }
            
            // Get track number from media
            if let media = firstRelease["media"] as? [[String: Any]], let firstMedia = media.first,
               let tracks = firstMedia["tracks"] as? [[String: Any]], let firstTrack = tracks.first {
                trackNumber = firstTrack["position"] as? Int
            }
        }
        
        // Parse tags/genre
        var genre: String?
        if let tags = json["tags"] as? [[String: Any]] {
            let tagNames = tags.compactMap { $0["name"] as? String }
            genre = tagNames.first
        }
        
        print("[MusicBrainz] ✅ Found: \(title) by \(artistName)")
        
        return MusicMetadata(
            recordingId: recordingId,
            releaseId: releaseId,
            artistId: nil,
            title: title,
            artist: artistName,
            album: album,
            albumArtist: nil,
            trackNumber: trackNumber,
            discNumber: nil,
            totalTracks: nil,
            year: year,
            genre: genre,
            artworkURL: nil,
            confidence: 1.0
        )
    }
}
