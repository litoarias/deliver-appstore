# deliver-appstore

Generic, reusable CD pipeline for delivering iOS apps to App Store Connect. Works with **any `.xcodeproj`** project and **any AI coding agent** (Claude Code, Codex, OpenCode) or directly from the terminal.

## Features

- **Auto-detection**: Automatically detects Xcode project, scheme, team ID, version source, and current version/build
- **Git-flow**: Manages branching (`develop` -> `release/X.X.X` -> `main`), tagging, and cleanup
- **Version bumping**: Supports both `.xcconfig` and `project.pbxproj` version sources
- **Build & Upload**: Archives, signs, and uploads directly to App Store Connect via Xcode credentials
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

## Usage

### Phase 1: Build & Upload (`deliver-appstore`)

Run from your iOS project directory:

```bash
# Interactive mode
deliver-appstore.sh

# Non-interactive mode (for CI)
deliver-appstore.sh --version 1.2.0 --build 3 --scheme MyApp --no-confirm
```

**What it does:**
1. Detects your Xcode project settings automatically
2. Asks for version and build number
3. Merges feature branch into `develop` (if applicable)
4. Creates `release/X.X.X` branch
5. Bumps version and build number
6. Archives and uploads to App Store Connect
7. Pushes release branch and creates a PR to `main`

### Phase 2: Post-Approval (`deliver-appstore-complete`)

Run after your app has been approved on the App Store:

```bash
# Interactive mode (auto-detects release branch)
deliver-appstore-complete.sh

# Non-interactive mode
deliver-appstore-complete.sh --version 1.2.0 --no-confirm --github-release
```

**What it does:**
1. Merges `release/X.X.X` into `main`
2. Creates git tag `X.X.X` on `main`
3. Merges `main` back into `develop`
4. Removes the release branch
5. Optionally creates a GitHub Release

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

## How Version Detection Works

The tool checks for version numbers in this order:

1. **`.xcconfig` files**: If any `.xcconfig` in the project contains `MARKETING_VERSION`, it uses that file
2. **`project.pbxproj`**: Falls back to reading `MARKETING_VERSION` from the Xcode project file

This supports both xcconfig-based setups (common in modular projects) and standard Xcode project configurations.

## Git Flow

```
feature/* ──merge──> develop ──branch──> release/X.X.X ──PR──> main
                                                                  │
                         develop <──merge── main <──merge─────────┘
                                             │
                                          tag X.X.X
```

## License

MIT
