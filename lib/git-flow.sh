#!/bin/bash
# deliver-appstore — git-flow.sh
# Git branching operations for release management

# Ensure develop is up to date and switch to it
checkout_develop() {
    log_info "Switching to develop branch..."

    if ! branch_exists "develop"; then
        abort "Branch 'develop' does not exist. This tool requires a develop branch."
    fi

    git checkout develop || abort "Failed to checkout develop."
    git pull origin develop || abort "Failed to pull develop from origin."

    log_success "On develop branch (up to date)."
}

# Merge a feature branch into develop
# Usage: merge_feature_to_develop "$FEATURE_BRANCH"
merge_feature_to_develop() {
    local feature_branch="$1"

    log_info "Merging '$feature_branch' into develop..."

    checkout_develop
    git merge --no-ff "$feature_branch" -m "Merge $feature_branch into develop" \
        || abort "Merge failed. Resolve conflicts manually and re-run."
    git push origin develop || abort "Failed to push develop."

    log_success "Merged '$feature_branch' into develop."
}

# Create a release branch from develop
# Usage: create_release_branch "$VERSION"
create_release_branch() {
    local version="$1"
    local release_branch="release/${version}"

    if branch_exists "$release_branch"; then
        abort "Branch '$release_branch' already exists."
    fi

    git checkout -b "$release_branch" || abort "Failed to create $release_branch."

    log_success "Created branch '$release_branch'."
}

# Push the release branch to origin
push_release_branch() {
    local version="$1"
    local release_branch="release/${version}"

    git push -u origin "$release_branch" || abort "Failed to push $release_branch."

    log_success "Pushed '$release_branch' to origin."
}

# Create a GitHub PR for the release
# Usage: create_release_pr "$VERSION" "$BUILD" "$APP_NAME"
create_release_pr() {
    local version="$1"
    local build="$2"
    local app_name="$3"
    local release_branch="release/${version}"

    if ! command -v gh &>/dev/null; then
        log_warn "gh CLI not installed. Skipping PR creation."
        log_info "Create a PR manually: $release_branch -> main"
        return
    fi

    log_info "Creating PR: $release_branch -> main..."

    local pr_url
    pr_url=$(gh pr create \
        --base main \
        --head "$release_branch" \
        --title "Release ${version}" \
        --body "$(cat <<EOF
## Release ${version} (build ${build})

**App:** ${app_name}

### Checklist
- [ ] App Store review approved
- [ ] Run \`/deliver-appstore-complete\` or \`deliver-appstore-complete.sh\` after approval
EOF
)" 2>&1)

    if [[ $? -eq 0 ]]; then
        log_success "PR created: $pr_url"
    else
        log_warn "Could not create PR: $pr_url"
    fi
}

# Finish release: merge to main, tag, merge back to develop, cleanup
# Usage: finish_release "$VERSION"
finish_release() {
    local version="$1"
    local release_branch="release/${version}"

    # Merge release into main
    log_step "MERGE" "Merging $release_branch into main..."
    git checkout main || abort "Failed to checkout main."
    git pull origin main || abort "Failed to pull main."
    git merge --no-ff "$release_branch" -m "Merge $release_branch into main" \
        || abort "Merge into main failed. Resolve conflicts manually."
    git push origin main || abort "Failed to push main."
    log_success "Merged $release_branch into main."

    # Tag on main
    log_step "TAG" "Creating tag $version on main..."
    git tag -a "$version" -m "Release $version" \
        || abort "Failed to create tag $version."
    git push origin "$version" || abort "Failed to push tag $version."
    log_success "Tag $version created and pushed."

    # Merge main back into develop
    log_step "SYNC" "Merging main back into develop..."
    git checkout develop || abort "Failed to checkout develop."
    git pull origin develop || abort "Failed to pull develop."
    git merge --no-ff main -m "Merge main into develop after release $version" \
        || abort "Merge into develop failed. Resolve conflicts manually."
    git push origin develop || abort "Failed to push develop."
    log_success "Main merged back into develop."

    # Cleanup release branch
    log_step "CLEANUP" "Removing release branch..."
    git branch -d "$release_branch" 2>/dev/null
    git push origin --delete "$release_branch" 2>/dev/null
    log_success "Release branch $release_branch removed."
}

# Create a GitHub Release
# Usage: create_github_release "$VERSION"
create_github_release() {
    local version="$1"

    if ! command -v gh &>/dev/null; then
        log_warn "gh CLI not installed. Skipping GitHub Release."
        return
    fi

    local release_url
    release_url=$(gh release create "$version" \
        --title "v${version}" \
        --notes "Release ${version}" \
        --target main 2>&1)

    if [[ $? -eq 0 ]]; then
        log_success "GitHub Release created: $release_url"
    else
        log_warn "Could not create GitHub Release: $release_url"
    fi
}
