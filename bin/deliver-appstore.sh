#!/bin/bash
# deliver-appstore.sh — Build, sign, and upload an iOS app to App Store Connect
# Usage: deliver-appstore.sh [--version X.X.X] [--build N] [--scheme Name] [--no-confirm]
#
# This script automates the full release pipeline:
#   1. Merges feature branch to develop (if needed)
#   2. Creates a release/X.X.X branch
#   3. Bumps version and build number
#   4. Archives and uploads to App Store Connect
#   5. Pushes and creates a PR to main

set -euo pipefail

# Resolve script location to find lib/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# Source libraries
source "${LIB_DIR}/utils.sh"
source "${LIB_DIR}/detect.sh"
source "${LIB_DIR}/version.sh"
source "${LIB_DIR}/build.sh"
source "${LIB_DIR}/git-flow.sh"

# Parse arguments
ARG_VERSION=""
ARG_BUILD=""
ARG_SCHEME=""
NO_CONFIRM="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)  ARG_VERSION="$2"; shift 2 ;;
        --build)    ARG_BUILD="$2"; shift 2 ;;
        --scheme)   ARG_SCHEME="$2"; shift 2 ;;
        --no-confirm) NO_CONFIRM="true"; shift ;;
        -h|--help)
            echo "Usage: deliver-appstore.sh [--version X.X.X] [--build N] [--scheme Name] [--no-confirm]"
            exit 0 ;;
        *) abort "Unknown argument: $1" ;;
    esac
done

export NO_CONFIRM

# ─── Banner ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}  deliver-appstore${NC} — iOS App Store Release Pipeline"
separator

# ─── Step 1: Pre-flight checks ──────────────────────────
log_step "1/8" "Pre-flight checks"

require_command "xcodebuild" "Install Xcode from the Mac App Store"
require_command "git" "Install git via Xcode Command Line Tools"
require_git_repo
require_clean_worktree

# Detect project
PROJECT=$(detect_xcodeproj)
APP_NAME=$(detect_app_name "$PROJECT")
log_success "Project: $APP_NAME ($PROJECT)"

# Detect scheme
if [[ -n "$ARG_SCHEME" ]]; then
    SCHEME="$ARG_SCHEME"
else
    SCHEME=$(detect_scheme "$PROJECT")
fi
log_success "Scheme: $SCHEME"

# Detect team ID
TEAM_ID=$(detect_team_id "$PROJECT")
log_success "Team ID: $TEAM_ID"

# Detect version source
VERSION_SOURCE=$(detect_version_source "$PROJECT")
CURRENT_VERSION=$(detect_current_version "$VERSION_SOURCE")
CURRENT_BUILD=$(detect_current_build "$VERSION_SOURCE")
log_success "Version source: $VERSION_SOURCE ($VERSION_FILE)"
log_success "Current version: $CURRENT_VERSION ($CURRENT_BUILD)"

# Check develop branch exists
if ! branch_exists "develop"; then
    abort "Branch 'develop' not found. This tool requires git-flow with main/develop branches."
fi

# ─── Step 2: Gather parameters ──────────────────────────
log_step "2/8" "Release parameters"

if [[ -n "$ARG_VERSION" ]]; then
    NEW_VERSION="$ARG_VERSION"
else
    NEW_VERSION=$(prompt_input "New version" "$CURRENT_VERSION")
fi

if [[ -n "$ARG_BUILD" ]]; then
    NEW_BUILD="$ARG_BUILD"
else
    NEW_BUILD=$(prompt_input "Build number" "$((CURRENT_BUILD + 1))")
fi

RELEASE_BRANCH="release/${NEW_VERSION}"

# Check release branch doesn't already exist
if branch_exists "$RELEASE_BRANCH"; then
    abort "Branch '$RELEASE_BRANCH' already exists. Delete it first or choose a different version."
fi

# ─── Confirmation ────────────────────────────────────────
summary_header "Release Summary"
summary_item "App" "$APP_NAME"
summary_item "Scheme" "$SCHEME"
summary_item "Version" "$NEW_VERSION (build $NEW_BUILD)"
summary_item "Release branch" "$RELEASE_BRANCH"
summary_item "Team ID" "$TEAM_ID"
echo ""

confirm "Proceed with release?" || abort "Aborted by user."

# ─── Step 3: Branch management ──────────────────────────
log_step "3/8" "Branch management"

CURRENT_BRANCH=$(detect_current_branch)

if [[ "$CURRENT_BRANCH" != "develop" ]]; then
    log_info "Currently on branch: $CURRENT_BRANCH"
    if confirm "Merge '$CURRENT_BRANCH' into develop first?"; then
        merge_feature_to_develop "$CURRENT_BRANCH"
    else
        checkout_develop
    fi
else
    log_info "Already on develop. Pulling latest..."
    git pull origin develop || abort "Failed to pull develop."
    log_success "Develop is up to date."
fi

create_release_branch "$NEW_VERSION"

# ─── Step 4: Version bump ───────────────────────────────
log_step "4/8" "Version bump"

bump_version "$VERSION_SOURCE" "$VERSION_FILE" "$NEW_VERSION" "$NEW_BUILD"

git add -A
git commit -m "Bump version to ${NEW_VERSION} (${NEW_BUILD})"
log_success "Version bump committed."

# ─── Step 5: Resolve dependencies ───────────────────────
log_step "5/8" "Resolving dependencies"

xcodebuild -resolvePackageDependencies -project "$PROJECT" -scheme "$SCHEME" 2>&1 | tail -5
log_success "Dependencies resolved."

# ─── Step 6: Archive ────────────────────────────────────
log_step "6/8" "Archive"

ARCHIVE_PATH=$(archive_app "$PROJECT" "$SCHEME" "$TEAM_ID" "$APP_NAME")

# ─── Step 7: Export & Upload ─────────────────────────────
log_step "7/8" "Export & Upload to App Store Connect"

PLIST_PATH=$(generate_export_options "$TEAM_ID")
EXPORT_PATH=$(export_and_upload "$APP_NAME" "$ARCHIVE_PATH" "$PLIST_PATH")

# ─── Step 8: Push & PR ──────────────────────────────────
log_step "8/8" "Push release branch & create PR"

push_release_branch "$NEW_VERSION"
create_release_pr "$NEW_VERSION" "$NEW_BUILD" "$APP_NAME"

# ─── Done ────────────────────────────────────────────────
summary_header "Release ${NEW_VERSION} (${NEW_BUILD}) — DONE"
summary_item "App" "$APP_NAME"
summary_item "Version" "${NEW_VERSION} (build ${NEW_BUILD})"
summary_item "Branch" "$RELEASE_BRANCH"
summary_item "Status" "Uploaded to App Store Connect"
echo ""
log_info "Next steps:"
echo -e "  1. Wait for App Store review approval"
echo -e "  2. Run ${BOLD}deliver-appstore-complete.sh --version ${NEW_VERSION}${NC}"
echo -e "     (or ${BOLD}/deliver-appstore-complete${NC} in Claude Code)"
echo ""
