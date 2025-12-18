import Foundation

class MusicAppBridge {
    
    enum MusicError: Error {
        case scriptError(String)
        case trackNotFound
        case deletionFailed
    }
    
    /// Deletes a track from the Music.app library using its Persistent ID.
    /// This removes the entry from the database. It does NOT typically delete the file from disk
    /// (unless Music.app is configured to do so, but we shouldn't rely on it).
    static func deleteTrack(persistentID: String) async throws {
        // AppleScript to find and delete the track by persistent ID
        let scriptSource = """
        tell application "Music"
            try
                set theTrack to (first track of library playlist 1 whose persistent ID is "\(persistentID)")
                delete theTrack
                return "OK"
            on error
                return "Error: Track not found or could not be deleted"
            end try
        end tell
        """
        
        return try await withCheckedThrowingContinuation { continuation in
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: scriptSource) {
                let output = scriptObject.executeAndReturnError(&error)
                
                if let error = error {
                    let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                    continuation.resume(throwing: MusicError.scriptError(errorMessage))
                } else {
                    let resultString = output.stringValue ?? ""
                    if resultString == "OK" {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: MusicError.deletionFailed)
                    }
                }
            } else {
                continuation.resume(throwing: MusicError.scriptError("Failed to initialize AppleScript"))
            }
        }
    }
}
