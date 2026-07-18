# Wallpaper Manager

Wallpaper Manager is a local-first wallpaper application built with Flutter. It organizes local folders and remote feeds into collections, combines collections into playback pools, and automatically rotates the Windows desktop background.

The long-term target is Windows, macOS, Android, and iOS. Windows is the currently implemented and tested desktop platform; the shared application and domain layers are structured for the remaining platforms.

## Run
Extract the following folder on your device:

                \apps\wallpaper_app\build\windows\x64\runner\Release
                
then click **wallpaper_app.exe**.
## Features

- Local album sources with recursive image and video discovery
- RSS and Atom image feeds, including NASA Image of the Day
- JSON feed source definitions
- Google Photos source placeholder for future Picker API integration
- One Library collection per source
- Rename, remove, merge, refresh, and edit source operations
- Favorites pool combining media from multiple collections
- Full-screen image inspection with zoom and available metadata
- Ordered, reverse-ordered, and randomized playback pools
- Automatic wallpaper rotation with configurable intervals
- Fill, fit, stretch, center, tile, and multi-display span modes
- Native Windows wallpaper application
- Large remote-image streaming and automatic 8K optimization
- Light, dark, and system themes with persistent accent colors
- Minimize-to-tray behavior and a tray menu with Open, Settings, and Quit
- Optional launch at desktop startup
- Persistent libraries, favorites, sources, and playback configuration

## Screens and Navigation

The application currently exposes:

- **Library** — source collections and the Favorites pool
- **Sources** — source configuration and management
- **Now Playing** — collection pooling, ordering, display behavior, and wallpaper controls
- **Schedules** — reserved for expanded scheduling rules
- **Favorites** — reserved navigation entry; favorites currently live in Library
- **Downloads** — reserved for download and cache management
- **Devices** — reserved for cross-device synchronization
- **Settings** — theme, accent, startup, tray, and platform behavior

## Repository Structure

```text
Wallpaper/
├── apps/
│   └── wallpaper_app/       Flutter UI and Windows runner
├── packages/
│   └── wallpaper_core/      Shared models, capabilities, providers, and rotation logic
├── docs/
│   └── architecture.md      Architecture and platform boundaries
└── README.md
```

## Requirements

For Windows development:

- Flutter 3.44 or newer
- Dart 3.12 or newer
- Visual Studio 2022 with **Desktop development with C++**
- Windows 10 or newer

Android development additionally requires Android Studio and its Android SDK. macOS and iOS builds require a Mac with Xcode.

## Run on Windows

From the repository root:

```powershell
cd apps\wallpaper_app
flutter pub get
flutter run -d windows
```

Check the local toolchain if the build does not start:

```powershell
flutter doctor -v
flutter devices
```

## Build a Windows Release

```powershell
cd apps\wallpaper_app
flutter build windows --release
```

The output is created at:

```text
apps/wallpaper_app/build/windows/x64/runner/Release/
```

Distribute the complete `Release` directory, not only the executable, because Flutter requires the adjacent DLL and data files.

## Build the Windows MSI Installer

Install the supported WiX Toolset version once:

```powershell
dotnet tool install --global wix --version 5.0.2
```

Then build the Flutter release and MSI from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\installer\windows\build-msi.ps1
```

The version is read from `apps/wallpaper_app/pubspec.yaml`. The resulting installer is written to:

```text
dist/Wallpaper-Manager-<version>-x64.msi
```

The MSI installs Wallpaper Manager for all users, creates desktop and Start Menu shortcuts, registers the application in Windows Apps & Features, and supports in-place upgrades and clean uninstallation. Administrator approval is required during installation.

## Build the Windows Setup Executable

Install Inno Setup 6 once:

```powershell
winget install --id JRSoftware.InnoSetup --exact
```

Then build the Flutter release and Setup executable from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\installer\windows\build-exe.ps1
```

The resulting installer is written to:

```text
dist/Wallpaper-Manager-<version>-x64-Setup.exe
```

The Setup executable installs Wallpaper Manager for all users, bundles the required Visual C++ runtime DLLs, creates Start Menu and optional desktop shortcuts, and supports upgrades and clean uninstallation. Administrator approval is required during installation.

## Testing

Run the Flutter application checks:

```powershell
cd apps\wallpaper_app
flutter analyze
flutter test
```

Run the platform-neutral core tests:

```powershell
cd packages\wallpaper_core
dart pub get
dart analyze
dart test
```

## Data and Privacy

Wallpaper Manager is local-first and does not require an account. Local album files remain in their original folders and are never uploaded by the current application. Source definitions, media references, favorites, playback choices, and appearance settings are stored locally so they survive restarts.

Remote feeds are restricted to HTTPS and have response limits and validation. Large wallpaper images are streamed to temporary storage and optimized locally when necessary.

Removing a local source removes only its application collection; it does not delete the original files.

## Current Limitations

- Windows is the only platform with a completed native wallpaper bridge.
- Video files can be discovered, but Windows live-video wallpaper playback is not implemented yet.
- Google Photos authorization and selection are not implemented yet.
- Mobile background execution and iOS Shortcuts integration require native runner work.
- Schedules, downloads, devices, and cloud synchronization remain future modules.
- Persistence is local to the computer and is not currently cloud-synchronized.

## Architecture

The Flutter client owns the responsive interface and application orchestration. `wallpaper_core` contains platform-neutral media models, source/provider contracts, rotation behavior, and platform capability definitions. Native bridges own operating-system wallpaper operations.

See [docs/architecture.md](docs/architecture.md) for component, privacy, and delivery details.


## Suggested RSS Feeds
NASA Image of the Day

        https://www.nasa.gov/feeds/iotd-feed/
        
NASA Earth Observatory

        https://science.nasa.gov/feed/earth-observatory/image-of-the-day
        
Wikimedia Commons Picture of the Day

        https://commons.wikimedia.org/w/api.php?action=featuredfeed&feed=potd&feedformat=rss&language=en
        
        https://commons.wikimedia.org/w/api.php?action=featuredfeed&feed=potd&feedformat=atom&language=en
        
NASA Astronomy Picture of the Day—APOD

        https://antwrp.gsfc.nasa.gov/apod.rss
        
        https://apod.com/feed.rss
        

## Author

Developed with ❤️ by [Mohammad Movahedi](https://m-movahedi.com).
