#!/bin/bash
# deliver-appstore — version.sh
# Version and build number bumping

# Bump version in xcconfig file
bump_version_xcconfig() {
    local file="$1"
    local new_version="$2"
    local new_build="$3"

    if [[ ! -f "$file" ]]; then
        abort "xcconfig file not found: $file"
    fi

    sed -i '' "s/MARKETING_VERSION = .*/MARKETING_VERSION = ${new_version}/" "$file"
    sed -i '' "s/CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = ${new_build}/" "$file"

    log_success "Updated $file: version=$new_version build=$new_build"
}

# Bump version in project.pbxproj
bump_version_pbxproj() {
    local file="$1"
    local new_version="$2"
    local new_build="$3"

    if [[ ! -f "$file" ]]; then
        abort "project.pbxproj not found: $file"
    fi

    sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = ${new_version};/g" "$file"
    sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = ${new_build};/g" "$file"

    log_success "Updated $file: version=$new_version build=$new_build"
}

# Bump version (auto-detects source type)
# Usage: bump_version "$SOURCE_TYPE" "$VERSION_FILE" "$NEW_VERSION" "$NEW_BUILD"
bump_version() {
    local source_type="$1"
    local file="$2"
    local new_version="$3"
    local new_build="$4"

    if [[ "$source_type" == "xcconfig" ]]; then
        bump_version_xcconfig "$file" "$new_version" "$new_build"
    else
        bump_version_pbxproj "$file" "$new_version" "$new_build"
    fi
}
