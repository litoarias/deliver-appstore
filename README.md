# deliver-appstore

CD pipeline for delivering iOS apps to App Store Connect — works with any `.xcodeproj` and any AI agent (Claude Code, Codex, OpenCode) or directly from the terminal.

---

## No third-party tools. No API keys. Just your Xcode account.

Unlike fastlane or Bitrise, this requires **zero configuration** beyond what you already have. It uses `xcodebuild` directly and authenticates with the Apple Developer account you're already signed into in Xcode.

> If you can archive and upload manually from Xcode, this works out of the box.

No API keys · No certificates to export · No provisioning profiles · No `.env` files

---

## Requirements

| | |
|---|---|
| macOS + Xcode | Signed in to your Apple Developer account |
| `gh` CLI | Authenticated via `gh auth login` |
| Git | Repository with `main` and `develop` branches |
| Xcode project | `.xcodeproj` with automatic signing enabled |

---

## Installation

**Claude Code**
```bash
npx skills add litoarias/deliver-appstore
```

**Other agents / terminal**
```bash
git clone https://github.com/litoarias/deliver-appstore.git
# Add bin/ to your PATH or run scripts directly
```

---

## Workflow

### App Store Release

The release is split in two phases that match the App Store review cycle. Between them you keep working on `develop` as normal.

```
[feature/*] ──> [develop] ──> [release/X.X.X] ──> PR ──> [main]
                                     │                        │
                               bump version               tag X.X.X
                               archive + upload               │
                               App Store review...    [develop] <── merge
                                     │
                          /deliver-appstore-complete
```

### TestFlight Upload

A lightweight pipeline that archives and uploads the current project state to TestFlight. No branching, no version bumping, no git operations.

```
[any branch] ──> archive ──> upload ──> TestFlight
```

### Phase 1 — Build & Upload

Run from any branch in your iOS project directory.

| Step | What happens |
|------|-------------|
| Pre-flight | Verifies clean git tree, finds `.xcodeproj`, detects scheme and Team ID |
| Parameters | Asks for version (e.g. `1.4.0`) and build number (auto-suggests current + 1) |
| Branch | Merges feature branch into `develop` if needed, creates `release/X.X.X` |
| Version bump | Updates `MARKETING_VERSION` + `CURRENT_PROJECT_VERSION` in xcconfig or pbxproj, commits |
| Dependencies | Runs `xcodebuild -resolvePackageDependencies` |
| Archive | `xcodebuild clean archive` in Release with automatic signing |
| Upload | Exports and uploads to App Store Connect via your Xcode credentials |
| PR | Pushes `release/X.X.X` and opens a PR to `main` |

**Branch handling** is automatic depending on where you are:
- On a **feature branch** → offers to merge into `develop` first
- On **develop** → pulls latest and branches from there
- Anywhere else → checks out `develop`, pulls, then branches

After this you wait for Apple's review. You can keep working on `develop` in the meantime.

### Phase 2 — Post-Approval

Run after Apple approves your app. Auto-detects the release branch.

| Step | What happens |
|------|-------------|
| Detect | Reads version from branch name or lists available release branches |
| Merge | `release/X.X.X` → `main` (no-ff) |
| Tag | Annotated tag `X.X.X` on `main`, pushed to origin |
| Sync | `main` → `develop` to keep develop up to date |
| Cleanup | Deletes `release/X.X.X` locally and on origin |
| GitHub Release | Optional — creates a GitHub Release linked to the tag |

---

## Usage

**Claude Code**
```
/deliver-appstore
```
Claude detects your project, asks only for version and build number, and runs the full pipeline. At the end it reminds you to wait for App Store approval.

```
/deliver-appstore-complete
```
Run after approval. Claude finalizes the git-flow cycle, tags, syncs branches, and optionally creates the GitHub Release.

```
/deliver-testflight
```
Archives and uploads the current project state to TestFlight. No git operations — just build and upload.

**Terminal**
```bash
# Phase 1
deliver-appstore.sh
deliver-appstore.sh --version 1.2.0 --build 3 --scheme MyApp --no-confirm

# Phase 2
deliver-appstore-complete.sh
deliver-appstore-complete.sh --version 1.2.0 --no-confirm --github-release

# TestFlight
deliver-testflight.sh
```

**Options**

| Flag | Script | Description |
|------|--------|-------------|
| `--version X.X.X` | both | Set version (skip prompt) |
| `--build N` | phase 1 | Set build number (skip prompt) |
| `--scheme Name` | phase 1 | Set scheme (skip auto-detection) |
| `--no-confirm` | both | Skip all confirmation prompts |
| `--github-release` | phase 2 | Create GitHub Release automatically |

---

## Version Detection

Checked in this order:

1. **`.xcconfig`** — if any file contains `MARKETING_VERSION`, it's used as the version source
2. **`project.pbxproj`** — fallback for standard Xcode project setups

---

## Project Structure

```
deliver-appstore/
├── bin/
│   ├── deliver-appstore.sh          # Phase 1: build & upload
│   └── deliver-appstore-complete.sh # Phase 2: merge & tag
├── lib/
│   ├── utils.sh                     # Logging, colors, prompts
│   ├── detect.sh                    # Auto-detection
│   ├── version.sh                   # Version bumping
│   ├── build.sh                     # Archive, export, upload
│   └── git-flow.sh                  # Branch operations
├── claude-code/                     # Claude Code skill wrappers
├── codex/                           # Codex agent instructions
└── opencode/                        # OpenCode agent instructions
```

---

## License

MIT
