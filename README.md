# FluxCloud iOS Client

A native, lightweight iOS client built with SwiftUI (iOS 16+) for the FluxCloud / FluxCDN personal cloud platform.

It allows you to connect directly to your self-hosted FluxCloud instance over HTTP or HTTPS, browse files and directories hierarchically, preview photos, view metadata, and open or download items via native iOS sharing.

---

## Key Features

### Server Connection & Authentication
- Connect to any self-hosted FluxCloud server via HTTP (local network / IP addresses) or HTTPS (public domains).
- API Key authentication with instant connection verification against the `/api/verify-key` endpoint.
- Secure local credential storage with session persistence.

### Native File Browser
- Hierarchical folder navigation with breadcrumb support and fluid transitions.
- Item metadata display including formatted file sizes and modified timestamps.
- Built-in category filtering for Quick Access (Folders, Images, Videos, Documents, Code).
- Live search bar for instant filtering within the current directory.
- Asynchronous image thumbnails with local memory caching.
- Pull-to-refresh support.

### File Preview & Actions
- Detailed file inspection sheet displaying full path, MIME type, file size, and timestamps.
- Native photo previews for images.
- System Share Sheet (`UIActivityViewController`) integration for exporting, saving to Files/Photos, or opening with third-party apps.
- Direct CDN download link copying to clipboard.

### In-App Auto-Updater
- Checks for newly published GitHub Releases on app launch via release timestamps.
- One-tap in-app download for `FluxCloud.ipa` with real-time download progress.
- Seamless installation handoff via iOS Share Sheet, TrollStore, AltStore, or Files app.

---

## Project Structure

```
FluxCloud_iOS/
├── FluxCloud.xcodeproj/          # Xcode project configuration
├── FluxCloud/
│   ├── FluxCloudApp.swift        # Main SwiftUI application entry point
│   ├── Info.plist                # App metadata and local network permissions
│   ├── Assets.xcassets/          # App icons and color catalog
│   ├── Models/                   # Data structures (FileItem, ServerConfig)
│   ├── Services/                 # Networking (APIService, AuthManager)
│   └── Views/                    # SwiftUI interface (LoginView, FileBrowserView, FileDetailView)
│       └── Components/           # Reusable UI elements (AuthenticatedAsyncImage, ShareSheet)
├── .github/
│   └── workflows/
│       └── build-ipa.yml         # Automated GitHub Actions workflow for IPA builds & releases
├── .gitignore
└── README.md
```

---

## Automated Releases & Installation

Each push to the `main` branch triggers the GitHub Actions workflow to build the unsigned `.ipa` binary and publish a new GitHub Release with a sequential version tag (`v1.0.<build_number>`).

### Downloading the App
1. Go to the [Releases](https://github.com/F1mmel/FluxCloud_iOS/releases) page of the repository.
2. Select the latest release.
3. Download `FluxCloud.ipa` under the **Assets** section.

### Sideloading onto iOS
The unsigned `.ipa` package can be installed on non-jailbroken and jailbroken devices using standard sideloading utilities:
- **AltStore / AltServer**: Sideload and auto-refresh using your personal Apple ID.
- **TrollStore**: Direct installation with permanent signing (iOS 14.0 – 17.0 on supported devices).
- **Sideloadly**: Install via macOS or Windows with automatic certificate management.
- **LiveContainer / Scarlet / Feather**: Direct on-device sideloading.

---

## Local Development in Xcode

### Requirements
- macOS 14.0 or newer
- Xcode 15.0 or newer
- iOS 16.0+ SDK

### Steps
1. Clone the repository:
   ```bash
   git clone https://github.com/F1mmel/FluxCloud_iOS.git
   cd FluxCloud_iOS
   ```
2. Open `FluxCloud.xcodeproj` in Xcode:
   ```bash
   open FluxCloud.xcodeproj
   ```
3. Select your development team in the project target settings (Signing & Capabilities).
4. Select a connected iOS device or iOS Simulator and press `Cmd + R` to build and run.

---

## License

This project is licensed under the MIT License.
