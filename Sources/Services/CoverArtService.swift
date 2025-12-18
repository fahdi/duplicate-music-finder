import Foundation

/// Service for fetching album artwork from the Cover Art Archive.
class CoverArtService {
    
    private let baseURL = "https://coverartarchive.org"
    
    enum CoverArtError: Error, LocalizedError {
        case noArtwork
        case networkError(Error)
        case invalidResponse
        
        var errorDescription: String? {
            switch self {
            case .noArtwork:
                return "No artwork found for this release"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Invalid response from Cover Art Archive"
            }
        }
    }
    
    /// Gets the URL for the front cover artwork
    /// - Parameter releaseId: MusicBrainz release ID
    /// - Returns: URL to the front cover image
    func getArtworkURL(releaseId: String) async throws -> URL {
        print("[CoverArt] Fetching artwork for release: \(releaseId)")
        
        // The Cover Art Archive automatically redirects to the actual image
        let urlString = "\(baseURL)/release/\(releaseId)/front"
        guard let url = URL(string: urlString) else {
            throw CoverArtError.invalidResponse
        }
        
        // Make a HEAD request to check if artwork exists and get final URL
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CoverArtError.invalidResponse
            }
            
            if httpResponse.statusCode == 404 {
                throw CoverArtError.noArtwork
            }
            
            // Return the redirect URL or original URL
            if let finalURL = httpResponse.url {
                print("[CoverArt] ✅ Found artwork: \(finalURL.lastPathComponent)")
                return finalURL
            }
            
            return url
            
        } catch let error as CoverArtError {
            throw error
        } catch {
            throw CoverArtError.networkError(error)
        }
    }
    
    /// Downloads artwork image data
    /// - Parameter url: URL to the artwork image
    /// - Returns: Image data
    func downloadArtwork(from url: URL) async throws -> Data {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw CoverArtError.invalidResponse
            }
            
            print("[CoverArt] ✅ Downloaded \(data.count / 1024) KB")
            return data
            
        } catch let error as CoverArtError {
            throw error
        } catch {
            throw CoverArtError.networkError(error)
        }
    }
}
