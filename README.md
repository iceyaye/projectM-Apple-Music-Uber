projectM-Apple-Music-Uber
=========================

A high-performance fork of the projectM visualization plug-in for macOS Apple Music.

## About This Fork

This is a fork of [kblaschke/frontend-music-plug-in](https://github.com/kblaschke/frontend-music-plug-in) with the following enhancements:

- **Updated to projectM 4.1** - Latest visualization engine
- **Adaptive mesh quality** - Automatically adjusts rendering quality based on performance
- **Options menu** - User-friendly settings panel accessible via View → Visualizer → Options
- **Performance optimizations** - VSync support, ProMotion display handling (up to 120Hz), reduced idle power consumption
- **FPS overlay** - Real-time performance monitoring with preset name display

## Acknowledgments

Thanks to [kblaschke](https://github.com/kblaschke) for the original plugin and for maintaining the [projectM](https://github.com/projectM-visualizer) visualization library. This project wouldn't exist without his work keeping the MilkDrop legacy alive.

## Requirements

- macOS 10.14+
- projectM 4.x library installed at `/usr/local/lib`
- Presets and textures (see below)

## Installing projectM 4.x

Build from source:

```bash
git clone https://github.com/projectM-visualizer/projectm.git
cd projectm
cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"
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
projectM-Apple-Music-Uber/
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
cp -R build/src/ProjectM-Uber.bundle ~/Library/iTunes/iTunes\ Plug-ins/
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

## Settings

Access settings via **View → Visualizer → Options** in the menu bar.

**Note:** A song must be playing with the visualizer open for the Options menu item to be enabled.

Available settings:
- **VSync** - Enable for smoother playback (caps FPS to display refresh rate)
- **Shuffle** - Randomize preset order vs sequential playback
- **Hard Cuts** - Enable sudden beat-triggered preset transitions
- **Show FPS & Preset Name** - Display overlay with FPS, mesh quality, and current preset name
- **Mesh Quality** - Auto (adaptive), High, Medium, or Low
- **Preset Duration** - Time before switching to next preset (5-120s)
- **Beat Sensitivity** - How reactive to music beats (0.5-5.0)
- **Hard Cut Sensitivity** - Threshold for beat-triggered cuts (0.5-4.0)
- **Soft Cut Duration** - Transition blend time between presets (0.5-10s)

Settings are saved automatically and persist across sessions.

## Uninstalling

If installed via the `.pkg` installer, use the uninstaller at:
```
/Applications/Utilities/Uninstall projectM-Uber.app
```

Or manually delete:
```bash
rm -rf ~/Library/iTunes/iTunes\ Plug-ins/ProjectM-Uber.bundle
rm -rf /Library/iTunes/iTunes\ Plug-ins/ProjectM-Uber.bundle
```

## Troubleshooting

### Plugin not showing in Visualizer menu after a crash

If the plugin crashed, Music.app may have blacklisted it. Remove the blacklist file and restart Music:

```bash
rm ~/Library/iTunes/iTunes\ Plug-ins/DisabledPlugins.plist
```

Then quit and reopen Music.app.

## License

LGPL 2.1 - See [LICENSE.md](LICENSE.md)
