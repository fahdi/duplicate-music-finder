import Foundation

/// Service for querying the AcoustID API to identify songs via audio fingerprint.
/// Requires a free API key from https://acoustid.org/my-applications
class AcoustIDService {
    
    private let apiKey: String
    private let baseURL = "https://api.acoustid.org/v2/lookup"
    
    enum AcoustIDError: Error, LocalizedError {
        case noApiKey
        case networkError(Error)
        case noMatches
        case invalidResponse
        
        var errorDescription: String? {
            switch self {
            case .noApiKey:
                return "AcoustID API key not configured"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .noMatches:
                return "No matches found in AcoustID database"
            case .invalidResponse:
                return "Invalid response from AcoustID"
            }
        }
    }
    
    struct AcoustIDResult {
        let score: Float
        let recordingId: String
        let title: String
        let artists: [String]
        let releaseId: String?
        let album: String?
    }
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    /// Look up a fingerprint in the AcoustID database
    /// - Parameters:
    ///   - fingerprint: Chromaprint fingerprint string
    ///   - duration: Duration of the audio in seconds
    /// - Returns: Array of possible matches, sorted by confidence
    func lookup(fingerprint: String, duration: Int) async throws -> [AcoustIDResult] {
        print("[AcoustID] Looking up fingerprint...")
        
        guard !apiKey.isEmpty else {
            throw AcoustIDError.noApiKey
        }
        
        // Rate limiting: max 3 requests per second
        await enforceRateLimit()
        
        // Use POST method for long fingerprints (AcoustID guideline)
        guard let url = URL(string: baseURL) else {
            throw AcoustIDError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Build POST body - meta should be space-separated per AcoustID docs
        let params = [
            "client": apiKey,
            "fingerprint": fingerprint,
            "duration": String(duration),
            "meta": "recordings releases"  // Space-separated, gets recordings with release info
        ]
        let bodyString = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            lastRequestTime = Date()
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw AcoustIDError.invalidResponse
            }
            
            return try parseResponse(data)
            
        } catch let error as AcoustIDError {
            throw error
        } catch {
            throw AcoustIDError.networkError(error)
        }
    }
    
    // Rate limiting
    private var lastRequestTime: Date?
    private let minRequestInterval: TimeInterval = 0.35 // ~3 requests per second
    
    private func enforceRateLimit() async {
        if let lastTime = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minRequestInterval {
                let delay = minRequestInterval - elapsed
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
    
    private func parseResponse(_ data: Data) throws -> [AcoustIDResult] {
        // Debug: print raw response
        if let rawString = String(data: data, encoding: .utf8) {
            print("[AcoustID] Raw response: \(String(rawString.prefix(500)))...")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? String,
              status == "ok",
              let results = json["results"] as? [[String: Any]] else {
            throw AcoustIDError.invalidResponse
        }
        
        var matches: [AcoustIDResult] = []
        
        for result in results {
            // Score can be Float or Double depending on JSON parsing
            let scoreValue: Float
            if let s = result["score"] as? Float {
                scoreValue = s
            } else if let s = result["score"] as? Double {
                scoreValue = Float(s)
            } else if let s = result["score"] as? NSNumber {
                scoreValue = s.floatValue
            } else {
                continue
            }
            
            guard let recordings = result["recordings"] as? [[String: Any]] else {
                print("[AcoustID] No recordings in result with score \(scoreValue)")
                continue
            }
            
            print("[AcoustID] Found \(recordings.count) recordings with score \(String(format: "%.0f%%", scoreValue * 100))")
            
            for recording in recordings {
                guard let recordingId = recording["id"] as? String else {
                    continue
                }
                
                // Extract artists from recording
                var artistNames: [String] = []
                if let artists = recording["artists"] as? [[String: Any]] {
                    artistNames = artists.compactMap { $0["name"] as? String }
                }
                
                // The title might not be in recording - we'll get it from MusicBrainz if needed
                // For now, try to get it from releases
                var title = "Unknown"
                var releaseId: String?
                var album: String?
                
                // Try releases first (from "recordings releases" meta)
                if let releases = recording["releases"] as? [[String: Any]], let firstRelease = releases.first {
                    releaseId = firstRelease["id"] as? String
                    album = firstRelease["title"] as? String
                    // For singles, the release title IS the song title
                    if title == "Unknown" {
                        title = album ?? "Unknown"
                    }
                }
                
                // Try releasegroups as fallback
                if releaseId == nil, let releaseGroups = recording["releasegroups"] as? [[String: Any]],
                   let firstRelease = releaseGroups.first {
                    releaseId = firstRelease["id"] as? String
                    album = firstRelease["title"] as? String
                }
                
                matches.append(AcoustIDResult(
                    score: scoreValue,
                    recordingId: recordingId,
                    title: title,
                    artists: artistNames,
                    releaseId: releaseId,
                    album: album
                ))
            }
        }
        
        if matches.isEmpty {
            throw AcoustIDError.noMatches
        }
        
        // Sort by score descending
        let sorted = matches.sorted { $0.score > $1.score }
        print("[AcoustID] ✅ Found \(sorted.count) matches, best score: \(String(format: "%.0f%%", (sorted.first?.score ?? 0) * 100))")
        return sorted
    }
}
