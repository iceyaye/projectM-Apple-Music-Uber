projectM Plug-In for Apple Music
================================

This repository contains the sources for the macOS Apple Music app projectM visualization plug-in that turns your music into awesome visuals while you listen.

## Requirements

- macOS 10.14+
- projectM 4.x library installed at `/usr/local/lib`
- Presets and textures (see below)

## Installing projectM 4.x

Build from source:

```bash
git clone https://github.com/projectM-visualizer/projectm.git
cd projectm
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr/local -DBUILD_SHARED_LIBS=ON -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"
cmake --build build
sudo cmake --install build
```

## Downloading Presets and Textures

Presets and textures are not included in this repository. Download them separately:

**Presets:**
- [Cream of the Crop](https://github.com/projectM-visualizer/presets-cream-of-the-crop) - Curated collection of the best presets
- [Classic MilkDrop Presets](https://github.com/projectM-visualizer/presets-milkdrop-original) - Original MilkDrop presets
- [En D Presets](https://github.com/projectM-visualizer/presets-en-d) - Additional preset collection

**Textures:**
- [projectM Textures](https://github.com/projectM-visualizer/textures) - Default texture pack

Place them in the project root:
```
frontend-music-plug-in/
├── presets/
│   └── *.milk files
└── textures/
    └── *.jpg files
```

## Building

```bash
# Configure
cmake -B build -S . \
  -DCMAKE_BUILD_TYPE=Release \
  -DPRESET_DIRS="$(pwd)/presets;$(pwd)/textures" \
  -DCMAKE_PREFIX_PATH=/usr/local

# Build
cmake --build build

# Create installer package (optional)
cpack --config build/CPackConfig.cmake
```

### Building Universal Binary with Signing

For distribution, build a universal binary with Developer ID signing:

```bash
cmake -B build -S . \
  -DCMAKE_BUILD_TYPE=Release \
  -DPRESET_DIRS="$(pwd)/presets;$(pwd)/textures" \
  -DCMAKE_PREFIX_PATH=/usr/local \
  -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -DCODESIGN_IDENTITY_BUNDLE="Developer ID Application: Your Name (TEAM_ID)" \
  -DCODESIGN_IDENTITY_INSTALLER="Developer ID Installer: Your Name (TEAM_ID)"

cmake --build build
cpack --config build/CPackConfig.cmake
```

## Installation

Either run the generated `.pkg` installer, or manually copy:

```bash
mkdir -p ~/Library/iTunes/iTunes\ Plug-ins/
cp -R build/src/ProjectM.bundle ~/Library/iTunes/iTunes\ Plug-ins/
```

Then restart the Music app and select **View → Visualizer → projectM**.

## Keyboard Shortcuts

While the visualizer is running:
- `n` - Next preset
- `p` - Previous preset
- `r` - Random preset (hard cut)
- `l` - Lock/unlock current preset
- `f` - Toggle FPS display
- `0` - Auto mesh quality (adaptive)
- `1` / `2` / `3` - Force mesh quality (high/medium/low, disables adaptive)

## Uninstalling

If installed via the `.pkg` installer, use the uninstaller at:
```
/Applications/Utilities/Uninstall projectM.app
```

Or manually delete:
```bash
rm -rf ~/Library/iTunes/iTunes\ Plug-ins/ProjectM.bundle
rm -rf /Library/iTunes/iTunes\ Plug-ins/ProjectM.bundle
```

## License

LGPL 2.1 - See [LICENSE.md](LICENSE.md)
