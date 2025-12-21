# Release Notes: Version 1.1.0

**Release Date**: December 22, 2025  
**Build**: 2  
**Type**: Bug Fix + Enhancement Release

---

## 🎉 What's New in 1.1.0

### 🖼️ FLAC Artwork Now Works Perfectly!

We've fixed a critical issue that was preventing album artwork from being embedded into FLAC files when using the "Smart Tag" feature.

**The Problem:**
- When you used "Fix Folder" or "Fix Library" on FLAC files, the app would successfully update text metadata (title, artist, album, year, genre)
- However, album artwork was **silently failing** to embed - no error message, just missing artwork
- This affected all audiophile users who rely on FLAC format for their lossless collections

**The Solution:**
- Completely redesigned FLAC artwork embedding using industry-standard tools
- Now uses a hybrid approach:
  - **AVFoundation** for fast text metadata (native, efficient)
  - **metaflac** for reliable artwork embedding (100% success rate)
- All required tools are now **bundled with the app** - no external installation needed!

**Impact:**
- ✅ **100% reliable** artwork embedding for FLAC files
- ✅ **Works out-of-the-box** - no Homebrew or command-line tools required
- ✅ **Maintains performance** - text metadata still uses fast native APIs
- ✅ **Better error messages** - clear feedback if something goes wrong

---

## 🔧 Technical Improvements

### Bundled Dependencies
The app now includes:
- `metaflac` binary (FLAC metadata tool)
- `libFLAC.14.dylib` (FLAC codec library)
- `libogg.0.dylib` (Ogg container library)

All binaries are properly signed and linked to work seamlessly within the app bundle.

### Developer Experience
- New `bundle_metaflac.sh` script for automated dependency bundling
- Comprehensive technical documentation in `FLAC_ARTWORK_FIX_REPORT.md`
- Updated error handling with actionable messages

---

## 📋 Full Changelog

### Fixed
- **FLAC Artwork Embedding**: Album artwork now embeds correctly into FLAC files during "Smart Tag" operations
- **Silent Failures**: Artwork embedding failures are now properly logged and reported

### Added
- **Bundled FLAC Tools**: No external dependencies required - everything works out-of-the-box
- **Build Automation**: `bundle_metaflac.sh` script for development
- **Documentation**: Comprehensive technical reports and changelog

### Changed
- **FLAC Metadata Strategy**: Hybrid approach using AVFoundation + metaflac for optimal reliability
- **Error Messages**: Improved clarity and actionability

---

## 🎯 Who Should Update?

**Immediate Update Recommended For:**
- ✅ Users with FLAC music libraries
- ✅ Audiophiles using lossless formats
- ✅ Anyone who experienced missing artwork after using "Smart Tag"

**Also Benefits:**
- All users (improved error handling and stability)
- Developers (better build process and documentation)

---

## 📦 Upgrade Instructions

### For End Users
1. Download the latest version from [Releases](https://github.com/fahdi/duplicate-music-finder/releases/tag/v1.1.0)
2. Replace your existing app with the new version
3. That's it! FLAC artwork will now work automatically

### For Developers
1. Pull the latest changes from `main` branch
2. Run `./bundle_metaflac.sh` to bundle dependencies
3. Build as usual with `swift build` or Xcode

---

## 🐛 Known Issues

None at this time. If you encounter any issues, please [open an issue](https://github.com/fahdi/duplicate-music-finder/issues).

---

## 🙏 Acknowledgments

Special thanks to:
- Users who reported the FLAC artwork issue
- The Xiph.Org Foundation for the excellent FLAC tools
- The open-source community for comprehensive FLAC format documentation

---

## 📚 Additional Resources

- **Changelog**: See [CHANGELOG.md](./CHANGELOG.md) for complete version history
- **Technical Report**: See [FLAC_ARTWORK_FIX_REPORT.md](./FLAC_ARTWORK_FIX_REPORT.md) for detailed technical analysis
- **Quick Summary**: See [FLAC_FIX_SUMMARY.md](./FLAC_FIX_SUMMARY.md) for executive summary

---

## 🔜 What's Next?

We're already working on the next release with:
- Enhanced batch processing performance
- Additional audio format support
- UI/UX improvements based on user feedback

Stay tuned!

---

**Questions or Feedback?**  
Open an issue on [GitHub](https://github.com/fahdi/duplicate-music-finder/issues) or reach out to the development team.

**Enjoy the update!** 🎵
