import Foundation

enum AutoSelectionRule: String, CaseIterable, Identifiable {
    case manual = "Manual Selection"
    case highestBitrate = "Keep Highest Bitrate"
    case longestDuration = "Keep Longest Duration"
    case oldesetAdded = "Keep Oldest Added"
    case latestAdded = "Keep Latest Added"
    case preferM4A = "Prefer AAC/M4A"
    case preferMP3 = "Prefer MP3"
    
    var id: String { rawValue }
}
