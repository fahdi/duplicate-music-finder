import Foundation

/// Represents a perceptual audio fingerprint extracted from spectral analysis.
/// Fingerprints can be compared to detect duplicate audio even across different encodings.
struct AudioFingerprint: Equatable, Hashable {
    /// Spectral peaks for each time window. Each inner array contains peak frequencies.
    let peaks: [[Float]]
    
    /// Condensed hash for fast pre-filtering before detailed comparison.
    let hash: String
    
    /// Duration of audio that was analyzed (in seconds).
    let analyzedDuration: Double
    
    /// Compares this fingerprint to another and returns similarity score (0.0 - 1.0).
    /// Uses sliding window approach to handle trimmed/offset audio.
    func similarity(to other: AudioFingerprint) -> Float {
        guard !peaks.isEmpty && !other.peaks.isEmpty else { return 0.0 }
        
        // First try direct comparison (offset 0) - fastest path
        let directSim = compareAtOffset(selfOffset: 0, otherOffset: 0, other: other)
        if directSim >= 0.85 {
            return directSim
        }
        
        // If direct comparison fails, try sliding window with larger steps
        // Check up to ~10 seconds of offset (about 400 windows at 44.1kHz)
        let maxOffset = min(400, min(peaks.count, other.peaks.count) / 3)
        let stepSize = 20 // Skip 20 windows (~0.5 seconds) between checks for speed
        var bestSimilarity = directSim
        
        // Try offsetting in both directions
        for offset in stride(from: stepSize, to: maxOffset, by: stepSize) {
            let sim1 = compareAtOffset(selfOffset: offset, otherOffset: 0, other: other)
            let sim2 = compareAtOffset(selfOffset: 0, otherOffset: offset, other: other)
            bestSimilarity = max(bestSimilarity, sim1, sim2)
            
            // Early exit if we found a good match
            if bestSimilarity >= 0.85 {
                return bestSimilarity
            }
        }
        
        return bestSimilarity
    }
    
    /// Compare fingerprints at a specific offset - samples every Nth window for speed
    private func compareAtOffset(selfOffset: Int, otherOffset: Int, other: AudioFingerprint) -> Float {
        let selfStart = selfOffset
        let otherStart = otherOffset
        let selfEnd = peaks.count
        let otherEnd = other.peaks.count
        
        let compareLength = min(selfEnd - selfStart, otherEnd - otherStart)
        guard compareLength > 0 else { return 0.0 }
        
        // Sample every 10th window for speed (compare ~130 windows instead of 1290)
        let sampleStep = 10
        var matchingWindows: Float = 0
        var sampledWindows: Float = 0
        
        for i in stride(from: 0, to: compareLength, by: sampleStep) {
            let selfPeaks = peaks[selfStart + i]
            let otherPeaks = other.peaks[otherStart + i]
            
            guard !selfPeaks.isEmpty && !otherPeaks.isEmpty else { continue }
            sampledWindows += 1
            
            // Count how many peaks in this window match (within tolerance)
            var windowMatches = 0
            for selfPeak in selfPeaks {
                for otherPeak in otherPeaks {
                    // Allow ±50 Hz tolerance for frequency matching
                    if abs(selfPeak - otherPeak) <= 50.0 {
                        windowMatches += 1
                        break
                    }
                }
            }
            
            // If at least half the peaks match, count this window as matching
            let matchRatio = Float(windowMatches) / Float(selfPeaks.count)
            if matchRatio >= 0.5 {
                matchingWindows += 1
            }
        }
        
        return sampledWindows > 0 ? matchingWindows / sampledWindows : 0.0
    }
    
    /// Creates a condensed hash from the peaks for fast comparison.
    static func generateHash(from peaks: [[Float]]) -> String {
        // Take top peaks from evenly distributed windows and create a hash
        var hashComponents: [UInt32] = []
        
        let step = max(1, peaks.count / 10) // Sample ~10 windows
        for i in stride(from: 0, to: peaks.count, by: step) {
            if let topPeak = peaks[i].first {
                // Quantize frequency to 50Hz bands
                let quantized = UInt32(topPeak / 50.0)
                hashComponents.append(quantized)
            }
        }
        
        // Convert to hex string
        return hashComponents.map { String(format: "%02x", $0) }.joined()
    }
}
