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
};
```

**Keyboard shortcuts:**
- `n` - Next preset
- `p` - Previous preset
- `r` - Random preset (hard cut)

**Technical notes:**
- Uses projectM 4.x API with separate playlist library
- OpenGL 3.2 Core Profile with high-DPI support (deprecated by Apple, but functional)
- 60 FPS when playing, 5 FPS when stopped
- Audio data is interleaved from dual channels before passing to projectM via `projectm_pcm_add_uint8()`
- Rendering via `projectm_opengl_render_frame()`
- Plugin runs in iTunes' main UI thread
- rpath set to `/usr/local/lib` for finding libprojectM at runtime

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
