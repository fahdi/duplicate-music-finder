import Foundation

/// User-configurable settings for audio fingerprint generation.
struct FingerprintSettings: Equatable {
    var sampleDuration: SampleDuration = .seconds30
    var similarityThreshold: Float = 0.85
    
    /// Sample duration options for fingerprint generation.
    enum SampleDuration: String, CaseIterable, Identifiable {
        case seconds10 = "10 seconds"
        case seconds30 = "30 seconds"
        case seconds60 = "60 seconds"
        case fullTrack = "Full Track"
        
        var id: String { rawValue }
        
        /// Returns the duration in seconds, or nil for full track.
        var seconds: Double? {
            switch self {
            case .seconds10: return 10
            case .seconds30: return 30
            case .seconds60: return 60
            case .fullTrack: return nil
            }
        }
    }
}
