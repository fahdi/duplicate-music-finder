# Duplicate Music Finder

A commercial-grade macOS desktop application built with SwiftUI to scan, detect, and manage duplicate audio tracks in your Apple Music library.

## Features

### Core Detection
- **Music Library Scanning**: Reads from Music.app (iTunes Library) and supports direct folder scanning
- **Flexible Metadata Detection**: User-selectable criteria including:
  - Track Title
  - Artist
  - Album
  - Duration (with tolerance slider ±10 seconds)

### Audio Fingerprinting (NEW)
Detect duplicates regardless of file format, bitrate, or metadata differences using perceptual audio analysis.

- **FFT Spectral Analysis**: Uses Apple's Accelerate framework for efficient frequency analysis
- **Encoding Agnostic**: Detects duplicates even when:
  - Different bitrates (128kbps vs 320kbps)
  - Different formats (MP3 vs M4A)
  - Trimmed/edited versions (handles up to ~10 seconds offset)
- **Configurable Settings**:
  - **Sample Duration**: Choose 10s, 30s, 60s, or Full Track analysis
  - **Similarity Threshold**: Adjustable slider (50% - 100%)
- **Parallel Processing**: Fingerprints generated concurrently for speed

### Audio Preview (NEW)
Listen to tracks directly in the app to verify duplicates before deletion.

- **Auto-Play on Select**: Click any track to instantly play it (enabled by default)
- **Visual Indicator**: Speaker icon shows which track is currently playing
- **Stop Control**: Stop button appears in sidebar during playback
- **Seamless Switching**: Click another track to switch playback instantly

### Smart Auto-Selection
Multiple strategies to automatically select which copy to keep:
- Highest Bitrate
- Longest Duration
- Oldest/Latest Added
- Preferred Format (MP3/M4A)

### Safe Deletion
- Moves duplicates to Trash (reversible via Finder)
- Removes entries from Music.app library

## Usage

### Basic Workflow
1. Launch the app
2. Select detection criteria in the sidebar:
   - **Metadata matching**: Title, Artist, Album, Duration
   - **Audio Fingerprint**: Enable for encoding-agnostic detection
3. Click **Scan Library**
4. Review detected duplicates in the main view
5. Click tracks to preview audio (if Auto-Play enabled)
6. Select tracks to remove (click the circle icon)
7. Click **Remove Selected** to move to Trash

### Fingerprint Matching Tips
- **Lower threshold (70-80%)**: Catches more duplicates, but may have false positives
- **Higher threshold (90-100%)**: Stricter matching, fewer false positives
- **Sample Duration**: Longer samples = more accurate but slower
- Best for finding same songs encoded at different bitrates

## Requirements

- macOS 13.0+
- Swift 5.9+
- Xcode 15.0+ (for development)

## Building

```bash
# Build the project
swift build

# Create macOS app bundle
./bundle_app.sh

# Launch the app
open DuplicateMusicFinder.app

# Run with debug output visible in terminal
./DuplicateMusicFinder.app/Contents/MacOS/DuplicateMusicFinder
```

## Architecture

The app uses MVVM architecture with the following components:

### Models
- `TrackModel` - Audio track metadata and fingerprint
- `DuplicateGroup` - Group of duplicate tracks
- `DuplicateCriteria` - User-selected matching criteria
- `AutoSelectionRule` - Auto-selection strategy
- `AudioFingerprint` - Spectral peak data for perceptual matching
- `FingerprintSettings` - User-configurable fingerprint parameters

### Services
- `MusicScanner` - Reads Music.app library
- `DuplicateEngine` - Duplicate detection logic
- `SelectionManager` - Auto-selection rules
- `FileTrashHandler` - Safe file deletion
- `AudioFingerprintService` - FFT spectral analysis using AVFoundation + Accelerate
- `AudioPlayerService` - Audio preview playback

### ViewModels
- `AppViewModel` - Central state management

### Views
- SwiftUI-based UI with NavigationSplitView

## Permissions

The app requires:
- Music Library access (`NSAppleMusicUsageDescription` in Info.plist)
- File system access for audio playback

## Technical Details

### Fingerprinting Algorithm
1. **Audio Decoding**: Uses AVAudioFile to decode any supported format to PCM
2. **Mono Conversion**: Mixes stereo channels for consistent analysis
3. **FFT Analysis**: 2048-sample windows with 50% overlap using vDSP
4. **Peak Extraction**: Extracts top 5 frequencies (300Hz - 3000Hz) per window
5. **Hash Generation**: Creates condensed hash for fast pre-filtering
6. **Similarity Comparison**: Sliding window comparison with ±50Hz tolerance

### Performance Optimizations
- Parallel fingerprint generation using Swift TaskGroup
- Hash-based pre-filtering before detailed comparison
- Sampled window comparison (every 10th window)
- Early exit on high-confidence matches

## License

TBD

## Roadmap

- [x] Audio fingerprinting
- [x] Audio preview playback
- [ ] Batch export reports (CSV/JSON)
- [ ] Missing artwork detection
- [ ] Music statistics dashboard
- [ ] Folder scanning support in UI
