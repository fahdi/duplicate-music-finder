import Foundation
import AVFoundation
import Accelerate

/// Service for generating perceptual audio fingerprints using FFT spectral analysis.
/// Uses AVFoundation for audio decoding and Accelerate/vDSP for efficient FFT computation.
class AudioFingerprintService {
    
    enum FingerprintError: Error, LocalizedError {
        case fileNotFound
        case audioLoadFailed
        case insufficientAudio
        case processingFailed
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound: return "Audio file not found"
            case .audioLoadFailed: return "Failed to load audio file"
            case .insufficientAudio: return "Audio file too short for fingerprinting"
            case .processingFailed: return "Failed to process audio data"
            }
        }
    }
    
    // FFT Configuration
    private let fftSize: Int = 2048           // ~46ms window at 44.1kHz
    private let hopSize: Int = 1024           // 50% overlap
    private let peaksPerWindow: Int = 5       // Top N peaks to keep
    private let minFrequency: Float = 300     // Hz - ignore very low frequencies
    private let maxFrequency: Float = 3000    // Hz - focus on vocal/instrument range
    
    /// Generates a fingerprint for the audio file at the given URL.
    func generateFingerprint(for url: URL, settings: FingerprintSettings) async throws -> AudioFingerprint {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                do {
                    let fingerprint = try self.processAudioFile(at: url, settings: settings)
                    continuation.resume(returning: fingerprint)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func processAudioFile(at url: URL, settings: FingerprintSettings) throws -> AudioFingerprint {
        print("[Fingerprint] 🎵 Processing: \(url.lastPathComponent)")
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("[Fingerprint] ❌ File not found: \(url.path)")
            throw FingerprintError.fileNotFound
        }
        
        // Load audio file
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            print("[Fingerprint] ❌ Failed to load audio: \(error)")
            throw FingerprintError.audioLoadFailed
        }
        
        let sampleRate = Float(audioFile.processingFormat.sampleRate)
        let totalFrames = AVAudioFrameCount(audioFile.length)
        let totalDuration = Double(totalFrames) / Double(sampleRate)
        
        print("[Fingerprint]    Sample rate: \(Int(sampleRate)) Hz, Duration: \(String(format: "%.1f", totalDuration))s")
        
        // Determine sample range based on settings
        let (startFrame, frameCount) = calculateSampleRange(
            totalFrames: totalFrames,
            sampleRate: sampleRate,
            totalDuration: totalDuration,
            settings: settings
        )
        
        let analyzeDuration = Double(frameCount) / Double(sampleRate)
        print("[Fingerprint]    Analyzing \(String(format: "%.1f", analyzeDuration))s (\(settings.sampleDuration.rawValue))")
        
        guard frameCount > UInt32(fftSize) else {
            print("[Fingerprint] ❌ Audio too short for FFT analysis")
            throw FingerprintError.insufficientAudio
        }
        
        // Create buffer and read audio
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: frameCount
        ) else {
            throw FingerprintError.processingFailed
        }
        
        audioFile.framePosition = Int64(startFrame)
        try audioFile.read(into: buffer, frameCount: frameCount)
        
        // Convert to mono if stereo
        let monoSamples = convertToMono(buffer: buffer)
        
        // Extract spectral peaks using FFT
        print("[Fingerprint]    Running FFT spectral analysis...")
        let peaks = extractSpectralPeaks(from: monoSamples, sampleRate: sampleRate)
        
        // Generate hash
        let hash = AudioFingerprint.generateHash(from: peaks)
        
        let analyzedDuration = Double(frameCount) / Double(sampleRate)
        
        print("[Fingerprint] ✅ Generated fingerprint: \(peaks.count) windows, hash=\(hash.prefix(16))...")
        
        return AudioFingerprint(peaks: peaks, hash: hash, analyzedDuration: analyzedDuration)
    }
    
    private func calculateSampleRange(
        totalFrames: AVAudioFrameCount,
        sampleRate: Float,
        totalDuration: Double,
        settings: FingerprintSettings
    ) -> (startFrame: AVAudioFramePosition, frameCount: AVAudioFrameCount) {
        
        guard let targetDuration = settings.sampleDuration.seconds else {
            // Full track
            return (0, totalFrames)
        }
        
        let targetFrames = AVAudioFrameCount(targetDuration * Double(sampleRate))
        
        if targetFrames >= totalFrames {
            // Track is shorter than target, use entire track
            return (0, totalFrames)
        }
        
        // Start from beginning of track (skip first 5 seconds to avoid intros)
        // This works better with sliding window for trimmed tracks
        let skipSeconds: Double = 5.0
        let skipFrames = AVAudioFramePosition(skipSeconds * Double(sampleRate))
        let startFrame = min(skipFrames, Int64(totalFrames) - Int64(targetFrames))
        
        return (max(0, startFrame), targetFrames)
    }
    
    private func convertToMono(buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }
        
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        if channelCount == 1 {
            return Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        }
        
        // Mix channels to mono
        var monoSamples = [Float](repeating: 0, count: frameCount)
        for channel in 0..<channelCount {
            let samples = UnsafeBufferPointer(start: channelData[channel], count: frameCount)
            for i in 0..<frameCount {
                monoSamples[i] += samples[i] / Float(channelCount)
            }
        }
        
        return monoSamples
    }
    
    private func extractSpectralPeaks(from samples: [Float], sampleRate: Float) -> [[Float]] {
        var allPeaks: [[Float]] = []
        
        // Setup FFT
        let log2n = vDSP_Length(log2(Float(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return []
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        // Process in sliding windows
        var windowStart = 0
        while windowStart + fftSize <= samples.count {
            let windowSamples = Array(samples[windowStart..<(windowStart + fftSize)])
            
            // Apply Hann window
            var windowedSamples = [Float](repeating: 0, count: fftSize)
            var window = [Float](repeating: 0, count: fftSize)
            vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
            vDSP_vmul(windowSamples, 1, window, 1, &windowedSamples, 1, vDSP_Length(fftSize))
            
            // Perform FFT
            var realPart = [Float](repeating: 0, count: fftSize / 2)
            var imagPart = [Float](repeating: 0, count: fftSize / 2)
            
            windowedSamples.withUnsafeBufferPointer { windowedPtr in
                realPart.withUnsafeMutableBufferPointer { realPtr in
                    imagPart.withUnsafeMutableBufferPointer { imagPtr in
                        var splitComplex = DSPSplitComplex(
                            realp: realPtr.baseAddress!,
                            imagp: imagPtr.baseAddress!
                        )
                        
                        windowedPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                            vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                        }
                        
                        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                    }
                }
            }
            
            // Calculate magnitudes
            var magnitudes = [Float](repeating: 0, count: fftSize / 2)
            realPart.withUnsafeBufferPointer { realPtr in
                imagPart.withUnsafeBufferPointer { imagPtr in
                    var splitComplex = DSPSplitComplex(
                        realp: UnsafeMutablePointer(mutating: realPtr.baseAddress!),
                        imagp: UnsafeMutablePointer(mutating: imagPtr.baseAddress!)
                    )
                    vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
                }
            }
            
            // Find peak frequencies within our frequency range
            let peaks = findPeakFrequencies(magnitudes: magnitudes, sampleRate: sampleRate)
            allPeaks.append(peaks)
            
            windowStart += hopSize
        }
        
        return allPeaks
    }
    
    private func findPeakFrequencies(magnitudes: [Float], sampleRate: Float) -> [Float] {
        let binWidth = sampleRate / Float(fftSize)
        let minBin = Int(minFrequency / binWidth)
        let maxBin = min(Int(maxFrequency / binWidth), magnitudes.count - 1)
        
        guard minBin < maxBin else { return [] }
        
        // Find local maxima
        var peaks: [(frequency: Float, magnitude: Float)] = []
        
        for i in (minBin + 1)..<maxBin {
            if magnitudes[i] > magnitudes[i - 1] && magnitudes[i] > magnitudes[i + 1] {
                let frequency = Float(i) * binWidth
                peaks.append((frequency, magnitudes[i]))
            }
        }
        
        // Sort by magnitude and take top N
        peaks.sort { $0.magnitude > $1.magnitude }
        let topPeaks = peaks.prefix(peaksPerWindow)
        
        // Return frequencies only, sorted for consistent comparison
        return topPeaks.map { $0.frequency }.sorted()
    }
}
