# deliver-appstore

Generic, reusable CD pipeline for delivering iOS apps to App Store Connect. Works with **any `.xcodeproj`** project and **any AI coding agent** (Claude Code, Codex, OpenCode) or directly from the terminal.

## No third-party tools. No API keys. Just your Xcode account.

Unlike fastlane, Bitrise, or other CI/CD tools, `deliver-appstore` requires **zero configuration** beyond what you already have:

- No App Store Connect API keys to generate or store
- No certificates to export or manage
- No provisioning profiles to download
- No `.env` files or secrets

It uses `xcodebuild` directly — the same tool Xcode uses internally — and authenticates with the Apple Developer account you're already signed into in Xcode. If you can archive and upload manually from Xcode, this tool works out of the box.

## Features

- **Auto-detection**: Automatically detects Xcode project, scheme, team ID, version source, and current version/build
- **Git-flow**: Manages branching (`develop` -> `release/X.X.X` -> `main`), tagging, and cleanup
- **Version bumping**: Supports both `.xcconfig` and `project.pbxproj` version sources
- **Build & Upload**: Archives, signs, and uploads directly to App Store Connect via `xcodebuild` — no API keys needed
- **GitHub integration**: Creates PRs and GitHub Releases via `gh` CLI
- **Agent-agnostic**: Shell scripts as core logic + wrappers for Claude Code, Codex, and OpenCode

## Requirements

- **macOS** with Xcode installed and **signed in** to your Apple Developer account
- **gh** CLI installed and authenticated (`gh auth login`)
- **Git** repository with `main` and `develop` branches
- iOS project with `.xcodeproj` and **automatic signing** configured

## Installation

### Claude Code (as a skill)

```bash
npx skills add litoarias/deliver-appstore
```

Then use `/deliver-appstore` and `/deliver-appstore-complete` in Claude Code.

### Manual / Other agents

Clone the repository:

```bash
git clone https://github.com/litoarias/deliver-appstore.git
```

Add `bin/` to your PATH or run scripts directly:

```bash
/path/to/deliver-appstore/bin/deliver-appstore.sh
```

## Workflow

The release process is split into two phases that match how the App Store review cycle actually works: you submit first, wait for approval, then finalize. Between those two phases you can keep working normally on `develop`.

```
[feature/*] ──merge──> [develop] ──branch──> [release/X.X.X] ──────────────────────> PR ──> [main]
                                                    │                                              │
                                              bump version                                    tag X.X.X
                                              archive + upload                                     │
                                              App Store review...                         [develop] <──merge──┘
                                                    │
                                            /deliver-appstore-complete
```

### Phase 1 — Build & Upload (`/deliver-appstore`)

Run this from your iOS project directory, **from any branch** (feature branch, develop, or directly from develop).

**What happens step by step:**

1. **Pre-flight**: verifies git is clean, finds the `.xcodeproj`, detects scheme and Team ID automatically
2. **Parameters**: asks for the new version (e.g. `1.4.0`) and build number (auto-suggests current + 1)
3. **Branch management** — three scenarios handled automatically:
   - If you're on a **feature branch**: offers to merge it into `develop` first, then creates the release branch
   - If you're already on **develop**: pulls latest and branches from there
   - If you're anywhere else: checks out `develop`, pulls, and branches from there
4. **Version bump**: updates `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in your xcconfig or `project.pbxproj`, commits the change
5. **Resolve dependencies**: runs `xcodebuild -resolvePackageDependencies` to sync SPM packages
6. **Archive**: runs `xcodebuild clean archive` in Release configuration with automatic signing
7. **Upload**: exports the archive and uploads directly to App Store Connect using your Xcode credentials (no API keys needed)
8. **PR**: pushes `release/X.X.X` and opens a pull request to `main` via `gh`

At this point you wait for App Store review. You can keep working on `develop` as normal.

### Phase 2 — Post-Approval (`/deliver-appstore-complete`)

Run this **after Apple approves your app**. It auto-detects the release branch (or asks if multiple exist).

**What happens step by step:**

1. **Detect version**: reads from current branch name (`release/X.X.X`), or lists available release branches if needed
2. **Merge release → main**: `git merge --no-ff` to preserve merge history, then pushes
3. **Tag**: creates an annotated tag `X.X.X` on `main` and pushes it
4. **Sync back**: merges `main` into `develop` so develop stays up to date with any release-time changes
5. **Cleanup**: deletes `release/X.X.X` both locally and on origin
6. **GitHub Release** (optional): creates a GitHub Release linked to the tag

### Usage from Claude Code

```
/deliver-appstore
```

Claude guides you through the whole Phase 1 interactively — detects your project, asks only what it needs (version, build), and runs every step. At the end it tells you to wait for App Store approval.

```
/deliver-appstore-complete
```

Run this after approval. Claude finalizes the git-flow cycle, creates the tag, syncs branches, and optionally creates the GitHub Release.

### Usage from the terminal

```bash
# Phase 1 — interactive
deliver-appstore.sh

# Phase 1 — non-interactive (CI)
deliver-appstore.sh --version 1.2.0 --build 3 --scheme MyApp --no-confirm

# Phase 2 — interactive (auto-detects release branch)
deliver-appstore-complete.sh

# Phase 2 — non-interactive
deliver-appstore-complete.sh --version 1.2.0 --no-confirm --github-release
```

## Options

### `deliver-appstore.sh`

| Flag | Description |
|------|-------------|
| `--version X.X.X` | Set version (skip prompt) |
| `--build N` | Set build number (skip prompt) |
| `--scheme Name` | Set scheme (skip auto-detection) |
| `--no-confirm` | Skip all confirmation prompts |

### `deliver-appstore-complete.sh`

| Flag | Description |
|------|-------------|
| `--version X.X.X` | Set version (skip prompt) |
| `--no-confirm` | Skip all confirmation prompts |
| `--github-release` | Create GitHub Release automatically |

## How Version Detection Works

The tool checks for version numbers in this order:

1. **`.xcconfig` files**: If any `.xcconfig` in the project contains `MARKETING_VERSION`, it uses that file
2. **`project.pbxproj`**: Falls back to reading `MARKETING_VERSION` from the Xcode project file

This supports both xcconfig-based setups (common in modular projects) and standard Xcode project configurations.

## Project Structure

```
deliver-appstore/
├── bin/
│   ├── deliver-appstore.sh            # Main script: build & upload
│   └── deliver-appstore-complete.sh   # Post-approval: merge & tag
├── lib/
│   ├── utils.sh                       # Colors, logging, prompts
│   ├── detect.sh                      # Auto-detection (project, scheme, version...)
│   ├── version.sh                     # Version bumping
│   ├── build.sh                       # Archive + export + upload
│   └── git-flow.sh                    # Git branching operations
├── claude-code/                       # Claude Code skill wrappers
├── codex/                             # Codex agent instructions
└── opencode/                          # OpenCode agent instructions
```

## License

MIT
