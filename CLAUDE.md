# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Notes

- Use `rg` (ripgrep) instead of `grep` for all searches

## Project Overview

macOS Apple Music visualization plugin using projectM 4.x. Transforms audio waveforms and spectrum data into real-time visualizations. Follows the iTunes Visual Plugin SDK pattern.

## Build Commands

```bash
# Configure (PRESET_DIRS is required, CMAKE_PREFIX_PATH for projectM)
cmake -B build -S . \
  -DPRESET_DIRS="$(pwd)/presets;$(pwd)/textures" \
  -DCMAKE_PREFIX_PATH=/usr/local

# Build
cmake --build build

# Install plugin manually
mkdir -p ~/Library/iTunes/iTunes\ Plug-ins/
cp -R _CPack_Packages/Darwin/productbuild/ProjectM-MusicPlugin-*/MusicPlugin/Library/iTunes/iTunes\ Plug-ins/ProjectM.bundle ~/Library/iTunes/iTunes\ Plug-ins/

# Create installer package
cpack --config build/CPackConfig.cmake
```

**Building universal binary with Developer ID signing:**
```bash
cmake -B build -S . \
  -DPRESET_DIRS="$(pwd)/presets;$(pwd)/textures" \
  -DCMAKE_PREFIX_PATH=/usr/local \
  -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -DCODESIGN_IDENTITY_BUNDLE="Developer ID Application: Your Name (TEAM_ID)" \
  -DCODESIGN_IDENTITY_INSTALLER="Developer ID Installer: Your Name (TEAM_ID)"

cmake --build build
cpack --config build/CPackConfig.cmake
```

**Required dependencies:**
- CMake 3.21+
- projectM 4.x with playlist library (build from source as universal binary)
- macOS with Xcode toolchain
- Developer ID certificates (for distribution)

**Installing projectM 4.x from source (universal binary):**
```bash
git clone https://github.com/projectM-visualizer/projectm.git
cd projectm
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr/local -DBUILD_SHARED_LIBS=ON -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"
cmake --build build
sudo cmake --install build
```

**CMake options:**
- `PRESET_DIRS` (required): Paths to projectM presets and textures
- `CMAKE_PREFIX_PATH`: Path to projectM installation (default: /usr/local)
- `CMAKE_OSX_ARCHITECTURES`: Set to `"arm64;x86_64"` for universal binary
- `CODESIGN_IDENTITY_BUNDLE`: Developer ID Application certificate name
- `CODESIGN_IDENTITY_INSTALLER`: Developer ID Installer certificate name

**Required certificates for distribution (create in Xcode → Settings → Accounts → Manage Certificates):**
- Developer ID Application - signs the plugin bundle
- Developer ID Installer - signs the .pkg installer

## Architecture

**Plugin message flow:**
```
iTunes → VisualPluginHandler() → Message dispatcher
                                    ├─ Init/Cleanup
                                    ├─ Activate/Deactivate (resource management)
                                    ├─ Pulse (receive audio data)
                                    ├─ Draw (render frame via OpenGL)
                                    └─ Play/Stop/TrackInfo/Artwork
```

**Key source files:**
- `src/iprojectM.hpp` - Main struct definitions, version info
- `src/iprojectM.mm` - Audio processing, projectM initialization, `ProcessRenderData()`
- `src/iprojectM_mac.mm` - macOS rendering, `VisualView` NSOpenGLView, `DrawVisual()`, keyboard handling
- `src/macos/iTunesAPI.h` - iTunes plugin SDK types and callbacks
- `src/macos/iTunesVisualAPI.h` - Visual plugin message types, `RenderVisualData` struct
- `packaging.cmake` - CPack configuration for .pkg installer
- `src/Resources/postinstall` - Creates uninstaller app after installation

**Core data structure:**
```cpp
struct VisualPluginData {
    projectm_handle pm;               // projectM visualization handle
    projectm_playlist_handle playlist; // Playlist manager for presets
    NSOpenGLView *destView;           // iTunes-provided view
    VisualView *subview;              // Custom NSView wrapper
    RenderVisualData renderData;      // Audio waveform & spectrum
    ITTrackInfo trackInfo;            // Song metadata
    bool playing;                     // Playback state
    UInt32 cachedRefreshRate;         // Display refresh rate (cached)
    int meshQualityLevel;             // Adaptive quality: 0=high, 1=medium, 2=low
};
```

**Keyboard shortcuts:**
- `n` - Next preset
- `p` - Previous preset
- `r` - Random preset (hard cut)
- `l` - Lock/unlock current preset (prevents auto-advancement)
- `f` - Toggle FPS/mesh quality overlay
- `0` - Enable adaptive mesh quality (auto)
- `1` - Force high quality mesh (140×110, disables adaptive)
- `2` - Force medium quality mesh (96×72, disables adaptive)
- `3` - Force low quality mesh (64×48, disables adaptive)

**Technical notes:**
- Uses projectM 4.x API with separate playlist library
- OpenGL 3.2 Core Profile with high-DPI support and VSync enabled
- Dynamic refresh rate detection for high-refresh displays (capped at 120Hz, falls back to 60Hz on older macOS)
- Adaptive mesh quality: automatically reduces mesh resolution when FPS drops, recovers when performance improves
- 5 FPS when stopped to conserve power
- Audio data is interleaved from dual channels before passing to projectM via `projectm_pcm_add_uint8()`
- Rendering via `projectm_opengl_render_frame()`
- Plugin runs in iTunes' main UI thread
- rpath set to `/usr/local/lib` for finding libprojectM at runtime

**Adaptive mesh quality levels:**
| Level | Resolution | Vertices | Trigger |
|-------|------------|----------|---------|
| High | 140×110 | 15,400 | Default, FPS > 95% target |
| Medium | 96×72 | 6,912 | FPS < 80% target |
| Low | 64×48 | 3,072 | FPS still < 80% |

## Installer

The `.pkg` installer:
- Installs plugin to `~/Library/iTunes/iTunes Plug-ins/` or `/Library/iTunes/iTunes Plug-ins/`
- Creates uninstaller at `/Applications/Utilities/Uninstall projectM.app`
- Signed with Developer ID for Gatekeeper approval

**Verify signatures:**
```bash
# Check bundle signature
codesign -dv --verbose=2 ~/Library/iTunes/iTunes\ Plug-ins/ProjectM.bundle

# Check package signature
pkgutil --check-signature ProjectM-MusicPlugin-4.1.pkg
```
