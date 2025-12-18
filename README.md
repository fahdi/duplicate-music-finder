# Duplicate Music Finder

A commercial-grade macOS desktop application built with SwiftUI to scan, detect, and manage duplicate audio tracks in your Apple Music library.

## Features

- **Music Library Scanning**: Reads from Music.app (iTunes Library) and supports direct folder scanning
- **Flexible Detection**: User-selectable criteria including:
  - Track Title
  - Artist
  - Album
  - Duration (with tolerance slider ±10 seconds)
- **Smart Auto-Selection**: Multiple strategies to keep the best copy:
  - Highest Bitrate
  - Longest Duration
  - Oldest/Latest Added
  - Preferred Format (MP3/M4A)
- **Safe Deletion**: Moves duplicates to Trash (reversible)
- **Modern UI**: Built with SwiftUI using NavigationSplitView

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
```

## Architecture

The app uses MVVM architecture with the following components:

- **Models**: `TrackModel`, `DuplicateGroup`, `DuplicateCriteria`, `AutoSelectionRule`
- **Services**: `MusicScanner`, `DuplicateEngine`, `SelectionManager`, `FileTrashHandler`
- **ViewModels**: `AppViewModel` (central state management)
- **Views**: SwiftUI-based UI layer

## Permissions

The app requires Music Library access permission (`NSAppleMusicUsageDescription` in Info.plist).

## License

TBD

## Roadmap

- [ ] Audio fingerprinting (Pro feature)
- [ ] Batch export reports (CSV/JSON)
- [ ] Missing artwork detection
- [ ] Music statistics dashboard
