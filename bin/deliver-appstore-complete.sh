#!/bin/bash
# deliver-appstore-complete.sh — Complete a release after App Store approval
# Usage: deliver-appstore-complete.sh [--version X.X.X] [--no-confirm] [--github-release]
#
# This script completes the release cycle:
#   1. Merges release/X.X.X into main
#   2. Creates a git tag on main
#   3. Merges main back into develop
#   4. Cleans up the release branch
#   5. Optionally creates a GitHub Release

set -euo pipefail

# Resolve script location to find lib/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# Source libraries
source "${LIB_DIR}/utils.sh"
source "${LIB_DIR}/detect.sh"
source "${LIB_DIR}/git-flow.sh"

# Parse arguments
ARG_VERSION=""
NO_CONFIRM="false"
CREATE_GITHUB_RELEASE="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)  ARG_VERSION="$2"; shift 2 ;;
        --no-confirm) NO_CONFIRM="true"; shift ;;
        --github-release) CREATE_GITHUB_RELEASE="true"; shift ;;
        -h|--help)
            echo "Usage: deliver-appstore-complete.sh [--version X.X.X] [--no-confirm] [--github-release]"
            exit 0 ;;
        *) abort "Unknown argument: $1" ;;
    esac
done

export NO_CONFIRM

# ─── Banner ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}  deliver-appstore-complete${NC} — Post-Approval Release Finalization"
separator

# ─── Step 1: Pre-flight checks ──────────────────────────
log_step "1/3" "Pre-flight checks"

require_command "git" "Install git via Xcode Command Line Tools"
require_git_repo
require_clean_worktree

# Detect version
if [[ -n "$ARG_VERSION" ]]; then
    VERSION="$ARG_VERSION"
else
    # Try to auto-detect from current branch
    CURRENT_BRANCH=$(detect_current_branch)
    if [[ "$CURRENT_BRANCH" == release/* ]]; then
        VERSION="${CURRENT_BRANCH#release/}"
        log_info "Detected version from current branch: $VERSION"
    else
        # List available release branches
        RELEASE_BRANCHES=()
        while IFS= read -r branch; do
            branch=$(echo "$branch" | xargs | sed 's|remotes/origin/||')
            [[ "$branch" == release/* ]] && RELEASE_BRANCHES+=("${branch#release/}")
        done < <(git branch -a 2>/dev/null | grep 'release/')

        # Remove duplicates
        RELEASE_BRANCHES=($(printf '%s\n' "${RELEASE_BRANCHES[@]}" | sort -u))

        if [[ ${#RELEASE_BRANCHES[@]} -eq 0 ]]; then
            VERSION=$(prompt_input "Version to complete" "")
            [[ -z "$VERSION" ]] && abort "No version specified."
        elif [[ ${#RELEASE_BRANCHES[@]} -eq 1 ]]; then
            VERSION="${RELEASE_BRANCHES[0]}"
            log_info "Found release branch: release/$VERSION"
        else
            VERSION=$(prompt_select "Select release to complete:" "${RELEASE_BRANCHES[@]}")
        fi
    fi
fi

RELEASE_BRANCH="release/${VERSION}"

# Verify release branch exists
if ! branch_exists "$RELEASE_BRANCH"; then
    abort "Branch '$RELEASE_BRANCH' does not exist."
fi

# Verify main and develop exist
if ! branch_exists "main"; then
    abort "Branch 'main' does not exist."
fi
if ! branch_exists "develop"; then
    abort "Branch 'develop' does not exist."
fi

# Detect app name
PROJECT=$(detect_xcodeproj 2>/dev/null || echo "")
APP_NAME=""
if [[ -n "$PROJECT" ]]; then
    APP_NAME=$(detect_app_name "$PROJECT")
fi

# ─── Confirmation ────────────────────────────────────────
summary_header "Release Completion"
[[ -n "$APP_NAME" ]] && summary_item "App" "$APP_NAME"
summary_item "Version" "$VERSION"
summary_item "Branch" "$RELEASE_BRANCH"
summary_item "Actions" "merge->main, tag, merge->develop, cleanup"
echo ""

confirm "Proceed?" || abort "Aborted by user."

# ─── Step 2: Finish release ─────────────────────────────
log_step "2/3" "Finishing release"

finish_release "$VERSION"

# ─── Step 3: GitHub Release ─────────────────────────────
log_step "3/3" "GitHub Release"

if [[ "$CREATE_GITHUB_RELEASE" == "true" ]]; then
    create_github_release "$VERSION"
elif [[ "$NO_CONFIRM" != "true" ]]; then
    if confirm "Create a GitHub Release for v${VERSION}?"; then
        create_github_release "$VERSION"
    else
        log_info "Skipped GitHub Release."
    fi
else
    log_info "Skipped GitHub Release (use --github-release to enable)."
fi

# ─── Done ────────────────────────────────────────────────
summary_header "Release ${VERSION} — COMPLETED"
[[ -n "$APP_NAME" ]] && summary_item "App" "$APP_NAME"
summary_item "Version" "$VERSION"
summary_item "Tag" "$VERSION (on main)"
summary_item "Branches" "main & develop updated"
summary_item "Cleanup" "release/$VERSION removed"
echo ""
log_success "Release cycle complete!"
echo ""
