# deliver-appstore — OpenCode Agent Instructions

## Overview

This repository contains shell scripts for automating iOS app releases to App Store Connect. The scripts handle the full git-flow release cycle: branching, version bumping, archiving, uploading, and post-approval merging.

## Available Commands

### `deliver-appstore` — Build & Upload

Run from an iOS project directory (containing a `.xcodeproj`):

```bash
/path/to/deliver-appstore/bin/deliver-appstore.sh
```

Or with arguments for non-interactive mode:

```bash
/path/to/deliver-appstore/bin/deliver-appstore.sh --version 1.2.0 --build 3 --no-confirm
```

**What it does:**
1. Auto-detects Xcode project, scheme, team ID, and current version
2. Merges current feature branch into `develop` (if applicable)
3. Creates `release/X.X.X` branch from `develop`
4. Bumps `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`
5. Archives the app with `xcodebuild`
6. Exports and uploads to App Store Connect
7. Pushes the release branch and creates a GitHub PR to `main`

### `deliver-appstore-complete` — Post-Approval

Run after the app has been approved on the App Store:

```bash
/path/to/deliver-appstore/bin/deliver-appstore-complete.sh --version 1.2.0
```

**What it does:**
1. Merges `release/X.X.X` into `main`
2. Creates git tag `X.X.X` on `main`
3. Merges `main` back into `develop`
4. Removes the `release/X.X.X` branch
5. Optionally creates a GitHub Release

## Requirements

- macOS with Xcode installed and signed in to App Store Connect
- `gh` CLI installed and authenticated
- Git repository with `main` and `develop` branches
- `.xcodeproj` with automatic signing configured

## Manual Execution Steps

If you cannot run the scripts directly, follow the steps documented in the scripts. The core flow is:

### Build & Upload
1. Detect project: `find . -maxdepth 1 -name "*.xcodeproj"`
2. List schemes: `xcodebuild -list -project <project>`
3. Detect team: `grep DEVELOPMENT_TEAM <project>/project.pbxproj`
4. Create release branch from develop
5. Bump version in `.xcconfig` or `project.pbxproj`
6. Archive: `xcodebuild clean archive -scheme <scheme> -configuration Release ...`
7. Export+Upload: `xcodebuild -exportArchive` with `destination=upload`
8. Push and create PR with `gh pr create`

### Post-Approval
1. Merge `release/<version>` into `main`, push
2. Tag `<version>` on main, push tag
3. Merge `main` into `develop`, push
4. Delete `release/<version>` branch

### `deliver-testflight` — TestFlight Upload

Run from an iOS project directory (containing a `.xcodeproj`):

```bash
/path/to/deliver-appstore/bin/deliver-testflight.sh
```

**What it does:**
1. Auto-detects Xcode project, scheme, team ID, current version, and build number
2. Archives the app with `xcodebuild`
3. Exports and uploads to App Store Connect (TestFlight)

**No git operations** — does not commit, branch, tag, or push. Just builds and uploads the current state.

### Manual Execution Steps (TestFlight)

1. Detect project: `find . -maxdepth 1 -name "*.xcodeproj"`
2. List schemes: `xcodebuild -list -project <project>`
3. Detect team: `grep DEVELOPMENT_TEAM <project>/project.pbxproj`
4. Archive: `xcodebuild clean archive -scheme <scheme> -configuration Release ...`
5. Export+Upload: `xcodebuild -exportArchive` with `destination=upload`
