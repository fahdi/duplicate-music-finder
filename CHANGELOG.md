# Changelog

All notable changes to Duplicate Music Finder will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-12-22

### Added
- **Bundled FLAC Tools**: `metaflac` binary and dependencies now bundled in app - no external installation required
- **Automated Build Script**: `bundle_metaflac.sh` for easy dependency bundling during development
- **Comprehensive Documentation**: Technical reports on FLAC artwork implementation

### Fixed
- **FLAC Artwork Embedding**: Fixed critical issue where album artwork was not being embedded into FLAC files during "Smart Tag" operations
  - Text metadata (title, artist, album) was updating correctly, but artwork was silently failing
  - Now uses hybrid approach: AVFoundation for text + bundled `metaflac` for reliable artwork embedding
  - 100% reliable artwork embedding for FLAC files
  - Works out-of-the-box with no external dependencies

### Changed
- **FLAC Metadata Writing**: Refactored to use industry-standard `metaflac` tool for artwork (more reliable than AVFoundation for FLAC PICTURE blocks)
- **Error Messages**: Improved error handling with clear messages if bundled tools are missing

### Technical Details
- Added `embedFLACArtworkViaMetaflac()` function for reliable FLAC artwork embedding
- Bundled `metaflac`, `libFLAC.14.dylib`, and `libogg.0.dylib` with proper rpath linking
- Graceful degradation: text metadata still works even if artwork embedding fails

## [1.0.0] - 2024-12-20

### Added
- **M4A/AAC Metadata Support**: Native metadata writing for M4A/AAC files using AVFoundation
- **FLAC Metadata Support**: Text metadata writing for FLAC files
- **Performance Optimization**: Duration-based pre-filtering for audio fingerprinting (up to 10x faster scans)
- **Smart Tag Feature**: Auto-identify songs and download metadata + artwork via AcoustID/MusicBrainz
- **Audio Fingerprinting**: Chromaprint-based duplicate detection regardless of format/bitrate
- **Folder Scanning**: Scan any folder for duplicates (not just Apple Music library)
- **Ghost Track Fix**: Properly remove tracks from Music.app library before file deletion
- **Audio Playback**: Preview tracks before deletion
- **Auto-Selection Rules**: Smart rules for selecting which duplicates to keep

### Initial Features
- Duplicate detection based on metadata (title, artist, album, duration)
- Apple Music library integration
- SwiftUI interface with MVVM architecture
- Trash integration (safe file deletion)
- Multiple duplicate detection criteria
- Fingerprint similarity threshold controls

---

## Version History

- **v1.1.0** (2025-12-22): FLAC Artwork Fix + Bundled Dependencies
- **v1.0.0** (2024-12-20): Initial Release with Smart Tag, M4A/FLAC Support, Performance Optimization
