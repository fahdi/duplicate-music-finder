import Foundation

class DuplicateEngine {
    
    func findDuplicates(in tracks: [TrackModel], criteria: DuplicateCriteria, fingerprintSettings: FingerprintSettings? = nil) async -> [DuplicateGroup] {
        guard tracks.count > 1 else { return [] }
        
        // Use fingerprint-based matching if enabled
        if criteria.matchFingerprint, let settings = fingerprintSettings {
            return await findDuplicatesByFingerprint(in: tracks, threshold: settings.similarityThreshold)
        }
        
        return await Task.detached(priority: .userInitiated) {
            var groups: [DuplicateGroup] = []
            
            // Dictionary to group tracks by a strict key first (usually Title + Artist is a good start)
            // If fuzzy matching is needed (like duration tolerance), we might need a more complex approach.
            // Approach:
            // 1. Group by strict string keys requested.
            // 2. Iterate groups and Refine by duration if requested.
            
            // Step 1: Group by String Keys
            let groupedFn = Dictionary(grouping: tracks) { track -> String in
                var key = ""
                if criteria.matchTitle { key += track.title.lowercased() + "|" }
                if criteria.matchArtist { key += track.artist.lowercased() + "|" }
                if criteria.matchAlbum { key += track.album.lowercased() + "|" }
                // We don't include duration in key if we want tolerance support
                return key
            }
            
            // Step 2: Process subgroups
            for (commonKey, subTracks) in groupedFn {
                if subTracks.count < 2 { continue }
                
                if criteria.matchDuration {
                    // Split subTracks into clusters based on duration tolerance
                    let durationClusters = self.clusterByDuration(tracks: subTracks, tolerance: criteria.durationTolerance)
                    for cluster in durationClusters {
                        if cluster.count > 1 {
                            groups.append(DuplicateGroup(commonKey: commonKey, tracks: cluster))
                        }
                    }
                } else {
                    // Just add the group
                    groups.append(DuplicateGroup(commonKey: commonKey, tracks: subTracks))
                }
            }
            
            return groups.sorted(by: { $0.tracks.first?.title ?? "" < $1.tracks.first?.title ?? "" })
        }.value
    }
    
    /// Finds duplicates by comparing audio fingerprints.
    /// Uses O(N²) comparison but with hash pre-filtering for performance.
    private func findDuplicatesByFingerprint(in tracks: [TrackModel], threshold: Float) async -> [DuplicateGroup] {
        return await Task.detached(priority: .userInitiated) {
            print("[DuplicateEngine] 🔍 Starting fingerprint-based duplicate detection")
            print("[DuplicateEngine]    Similarity threshold: \(Int(threshold * 100))%")
            
            // Filter to tracks that have fingerprints
            let fingerprintedTracks = tracks.filter { $0.fingerprint != nil }
            print("[DuplicateEngine]    Tracks with fingerprints: \(fingerprintedTracks.count)/\(tracks.count)")
            
            guard fingerprintedTracks.count > 1 else {
                print("[DuplicateEngine] ⚠️ Not enough fingerprinted tracks to compare")
                return []
            }
            
            var groups: [DuplicateGroup] = []
            var processedIds = Set<String>()
            
            // Group by hash first for fast pre-filtering
            let hashGroups = Dictionary(grouping: fingerprintedTracks) { track -> String in
                track.fingerprint?.hash ?? ""
            }
            print("[DuplicateEngine]    Unique hash buckets: \(hashGroups.count)")
            
            // For tracks with matching hashes, do detailed comparison
            print("[DuplicateEngine] 📊 Phase 1: Comparing tracks with matching hashes...")
            for (hash, samehashTracks) in hashGroups {
                if hash.isEmpty { continue }
                
                if samehashTracks.count >= 2 {
                    print("[DuplicateEngine]    Hash \(hash.prefix(8))... has \(samehashTracks.count) tracks")
                    // Same hash = likely duplicates, verify with detailed comparison
                    var verifiedGroup: [TrackModel] = []
                    
                    for track in samehashTracks {
                        if processedIds.contains(track.id) { continue }
                        
                        if verifiedGroup.isEmpty {
                            verifiedGroup.append(track)
                            processedIds.insert(track.id)
                        } else if let refFingerprint = verifiedGroup.first?.fingerprint,
                                  let trackFingerprint = track.fingerprint {
                            let similarity = refFingerprint.similarity(to: trackFingerprint)
                            print("[DuplicateEngine]      Comparing '\(track.title)' -> similarity: \(Int(similarity * 100))%")
                            if similarity >= threshold {
                                verifiedGroup.append(track)
                                processedIds.insert(track.id)
                                print("[DuplicateEngine]      ✅ MATCH!")
                            } else {
                                print("[DuplicateEngine]      ❌ Below threshold")
                            }
                        }
                    }
                    
                    if verifiedGroup.count > 1 {
                        print("[DuplicateEngine]    Found duplicate group: \(verifiedGroup.count) tracks")
                        groups.append(DuplicateGroup(commonKey: "fingerprint:\(hash)", tracks: verifiedGroup))
                    }
                }
            }
            
            // Also do cross-hash comparison for similar but not identical fingerprints
            // This catches cases where quantization put similar tracks in different hash buckets
            // Compare unprocessed tracks against ALL tracks (including those already matched in Phase 1)
            let unprocessed = fingerprintedTracks.filter { !processedIds.contains($0.id) }
            print("[DuplicateEngine] 📊 Phase 2: Cross-hash comparison for \(unprocessed.count) remaining tracks...")
            
            var crossHashComparisons = 0
            for track1 in unprocessed {
                if processedIds.contains(track1.id) { continue }
                
                // Compare against ALL tracks, not just unprocessed
                for track2 in fingerprintedTracks {
                    if track1.id == track2.id { continue }
                    
                    if let fp1 = track1.fingerprint, let fp2 = track2.fingerprint {
                        crossHashComparisons += 1
                        let similarity = fp1.similarity(to: fp2)
                        
                        // Debug: Show all comparisons with > 50% similarity
                        if similarity > 0.50 {
                            print("[DuplicateEngine]    '\(track1.title)' vs '\(track2.title)' = \(Int(similarity * 100))%")
                        }
                        
                        if similarity >= threshold {
                            print("[DuplicateEngine]    ✅ Cross-hash match: '\(track1.title)' <-> '\(track2.title)' (\(Int(similarity * 100))%)")
                            
                            // Add track1 to an existing group containing track2, or create new group
                            var foundGroup = false
                            for groupIndex in 0..<groups.count {
                                if groups[groupIndex].tracks.contains(where: { $0.id == track2.id }) {
                                    groups[groupIndex].tracks.append(track1)
                                    foundGroup = true
                                    break
                                }
                            }
                            
                            if !foundGroup {
                                groups.append(DuplicateGroup(commonKey: "fingerprint:\(track1.fingerprint?.hash ?? "unknown")", tracks: [track1, track2]))
                            }
                            
                            processedIds.insert(track1.id)
                            break // Found a match for track1, move to next track
                        }
                    }
                }
            }
            
            print("[DuplicateEngine]    Cross-hash comparisons performed: \(crossHashComparisons)")
            print("[DuplicateEngine] ✅ Found \(groups.count) duplicate groups via fingerprint matching")
            
            return groups.sorted(by: { $0.tracks.first?.title ?? "" < $1.tracks.first?.title ?? "" })
        }.value
    }
    
    private func clusterByDuration(tracks: [TrackModel], tolerance: TimeInterval) -> [[TrackModel]] {
        // Simple O(N^2) clustering or sorting approach. 
        // Since N (subTracks) is usually very small (2-10 duplicates), O(N^2) is fine.
        
        var clusters: [[TrackModel]] = []
        let sortedTracks = tracks.sorted(by: { $0.duration < $1.duration })
        
        var currentCluster: [TrackModel] = []
        
        for track in sortedTracks {
            if currentCluster.isEmpty {
                currentCluster.append(track)
                continue
            }
            
            // Compare with the first in cluster (or average). 
            // If within tolerance of the *first* item, add to cluster. 
            // Note: This matches "all in group are within tolerance of each other" roughly? 
            // Actually, usually we want "within tolerance of ANY in cluster" or "all within tolerance".
            // Let's assume absolute difference vs first element < tolerance.
            
            let reference = currentCluster[0]
            if abs(track.duration - reference.duration) <= tolerance {
                currentCluster.append(track)
            } else {
                clusters.append(currentCluster)
                currentCluster = [track]
            }
        }
        
        if !currentCluster.isEmpty {
            clusters.append(currentCluster)
        }
        
        return clusters
    }
}

