import Foundation

/// Service for generating Chromaprint audio fingerprints using the fpcalc CLI tool.
/// These fingerprints are compatible with the AcoustID database for song identification.
class ChromaprintService {
    
    enum ChromaprintError: Error, LocalizedError {
        case fpcalcNotFound
        case executionFailed(String)
        case invalidOutput
        case fileNotFound
        
        var errorDescription: String? {
            switch self {
            case .fpcalcNotFound:
                return "fpcalc not found. Install with: brew install chromaprint"
            case .executionFailed(let message):
                return "fpcalc failed: \(message)"
            case .invalidOutput:
                return "Could not parse fpcalc output"
            case .fileNotFound:
                return "Audio file not found"
            }
        }
    }
    
    /// Path to fpcalc binary
    private let fpcalcPath: String
    
    init() {
        // Priority: 1) Bundled in app, 2) Homebrew Intel, 3) Homebrew ARM, 4) PATH
        let possiblePaths = [
            Bundle.main.resourcePath.map { $0 + "/fpcalc" },
            "/usr/local/bin/fpcalc",          // Homebrew on Intel
            "/opt/homebrew/bin/fpcalc"        // Homebrew on Apple Silicon
        ].compactMap { $0 }
        
        self.fpcalcPath = possiblePaths.first { FileManager.default.fileExists(atPath: $0) } ?? "fpcalc"
        print("[Chromaprint] Using fpcalc at: \(fpcalcPath)")
    }
    
    /// Generates a Chromaprint fingerprint for an audio file
    /// - Parameter url: URL of the audio file
    /// - Returns: Tuple of (fingerprint string, duration in seconds)
    func generateFingerprint(for url: URL) async throws -> (fingerprint: String, duration: Int) {
        print("[Chromaprint] Generating fingerprint for: \(url.lastPathComponent)")
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ChromaprintError.fileNotFound
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                
                process.executableURL = URL(fileURLWithPath: self.fpcalcPath)
                process.arguments = ["-json", url.path]
                process.standardOutput = pipe
                process.standardError = pipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    
                    if process.terminationStatus != 0 {
                        let errorOutput = String(data: data, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: ChromaprintError.executionFailed(errorOutput))
                        return
                    }
                    
                    // Parse JSON output
                    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let fingerprint = json["fingerprint"] as? String,
                          let duration = json["duration"] as? Double else {
                        continuation.resume(throwing: ChromaprintError.invalidOutput)
                        return
                    }
                    
                    print("[Chromaprint] ✅ Generated fingerprint, duration: \(Int(duration))s")
                    continuation.resume(returning: (fingerprint, Int(duration)))
                    
                } catch {
                    if (error as NSError).domain == NSCocoaErrorDomain && (error as NSError).code == 4 {
                        continuation.resume(throwing: ChromaprintError.fpcalcNotFound)
                    } else {
                        continuation.resume(throwing: ChromaprintError.executionFailed(error.localizedDescription))
                    }
                }
            }
        }
    }
}
