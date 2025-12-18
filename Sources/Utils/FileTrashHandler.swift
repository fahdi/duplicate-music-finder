import Foundation

class FileTrashHandler {
    
    enum TrashError: Error {
        case fileNotFound
        case fileAccessDenied
        case unknown
    }
    
    func moveTracksToTrash(_ tracks: [TrackModel]) async throws -> Int {
        var successCount = 0
        let fileManager = FileManager.default
        
        for track in tracks {
            guard let url = track.fileURL else { continue }
            
            do {
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.trashItem(at: url, resultingItemURL: nil)
                    successCount += 1
                    print("Moved to trash: \(url.path)")
                } else {
                    print("File not found: \(url.path)")
                }
            } catch {
                print("Failed to trash file \(url.path): \(error)")
                // Depending on requirements, we might want to throw or just continue
                // For a bulk operation, continuing and reporting count is often better
            }
        }
        
        return successCount
    }
}
