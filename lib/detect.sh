#!/bin/bash
# deliver-appstore — detect.sh
# Auto-detection of Xcode project settings

# Detect .xcodeproj in current directory
# Returns the project path or exits if none found
detect_xcodeproj() {
    local projects=()
    while IFS= read -r -d '' proj; do
        projects+=("$proj")
    done < <(find . -maxdepth 1 -name "*.xcodeproj" -print0 2>/dev/null)

    if [[ ${#projects[@]} -eq 0 ]]; then
        abort "No .xcodeproj found in current directory."
    fi

    if [[ ${#projects[@]} -eq 1 ]]; then
        echo "${projects[0]}"
        return
    fi

    # Multiple projects — let user choose
    local names=()
    for p in "${projects[@]}"; do
        names+=("$(basename "$p")")
    done
    local selected
    selected=$(prompt_select "Multiple Xcode projects found. Select one:" "${names[@]}")
    echo "./${selected}"
}

# Detect available schemes for a project
# Usage: schemes=($(detect_schemes "$PROJECT"))
detect_schemes() {
    local project="$1"
    local schemes=()

    while IFS= read -r line; do
        line=$(echo "$line" | xargs) # trim whitespace
        [[ -n "$line" ]] && schemes+=("$line")
    done < <(xcodebuild -list -project "$project" 2>/dev/null | awk '/Schemes:/{found=1; next} found && /^$/{exit} found{print}')

    if [[ ${#schemes[@]} -eq 0 ]]; then
        abort "No schemes found in $project."
    fi

    printf '%s\n' "${schemes[@]}"
}

# Detect and select a scheme
# Usage: scheme=$(detect_scheme "$PROJECT")
detect_scheme() {
    local project="$1"
    local schemes=()

    while IFS= read -r s; do
        schemes+=("$s")
    done < <(detect_schemes "$project")

    if [[ ${#schemes[@]} -eq 1 ]]; then
        log_info "Detected scheme: ${schemes[0]}"
        echo "${schemes[0]}"
        return
    fi

    prompt_select "Multiple schemes found. Select one:" "${schemes[@]}"
}

# Detect DEVELOPMENT_TEAM from project.pbxproj
detect_team_id() {
    local project="$1"
    local pbxproj="${project}/project.pbxproj"

    if [[ ! -f "$pbxproj" ]]; then
        abort "Cannot find project.pbxproj at $pbxproj"
    fi

    local team_id
    team_id=$(grep -m1 'DEVELOPMENT_TEAM' "$pbxproj" | sed 's/.*= *"\{0,1\}\([A-Z0-9]*\)"\{0,1\} *;.*/\1/' | xargs)

    if [[ -z "$team_id" || "$team_id" == *"DEVELOPMENT_TEAM"* ]]; then
        abort "Could not detect DEVELOPMENT_TEAM from $pbxproj. Ensure automatic signing is configured."
    fi

    echo "$team_id"
}

# Detect bundle identifier via xcodebuild
detect_bundle_id() {
    local project="$1"
    local scheme="$2"

    local bundle_id
    bundle_id=$(xcodebuild -showBuildSettings -project "$project" -scheme "$scheme" -configuration Release 2>/dev/null \
        | grep 'PRODUCT_BUNDLE_IDENTIFIER' | head -1 | awk '{print $NF}')

    if [[ -z "$bundle_id" ]]; then
        log_warn "Could not detect bundle identifier automatically."
        bundle_id=$(prompt_input "Bundle Identifier" "")
    fi

    echo "$bundle_id"
}

# Detect where version is defined: "xcconfig" or "pbxproj"
# Also sets VERSION_FILE global variable
detect_version_source() {
    local project="$1"
    local project_dir
    project_dir=$(dirname "$project")/$(basename "$project" .xcodeproj)

    # Search for xcconfig files containing MARKETING_VERSION
    local xcconfig_file=""
    while IFS= read -r -d '' f; do
        if grep -q 'MARKETING_VERSION' "$f" 2>/dev/null; then
            xcconfig_file="$f"
            break
        fi
    done < <(find . -maxdepth 4 -name "*.xcconfig" -not -path "*/DerivedData/*" -not -path "*/.build/*" -not -path "*/Pods/*" -print0 2>/dev/null)

    if [[ -n "$xcconfig_file" ]]; then
        VERSION_FILE="$xcconfig_file"
        echo "xcconfig"
    else
        VERSION_FILE="${project}/project.pbxproj"
        echo "pbxproj"
    fi
}

# Detect current MARKETING_VERSION
detect_current_version() {
    local source_type="$1"

    if [[ "$source_type" == "xcconfig" ]]; then
        grep 'MARKETING_VERSION' "$VERSION_FILE" | head -1 | sed 's/.*= *\([^ ]*\).*/\1/' | xargs
    else
        grep 'MARKETING_VERSION' "$VERSION_FILE" | head -1 | sed 's/.*= *\([^;]*\);.*/\1/' | xargs
    fi
}

# Detect current CURRENT_PROJECT_VERSION (build number)
detect_current_build() {
    local source_type="$1"

    if [[ "$source_type" == "xcconfig" ]]; then
        grep 'CURRENT_PROJECT_VERSION' "$VERSION_FILE" | head -1 | sed 's/.*= *\([^ ]*\).*/\1/' | sed 's|//.*||' | xargs
    else
        grep 'CURRENT_PROJECT_VERSION' "$VERSION_FILE" | head -1 | sed 's/.*= *\([^;]*\);.*/\1/' | xargs
    fi
}

# Detect app name from project
detect_app_name() {
    local project="$1"
    basename "$project" .xcodeproj
}

# Detect current git branch
detect_current_branch() {
    git branch --show-current 2>/dev/null
}

# Check if a branch exists (local or remote)
branch_exists() {
    local branch="$1"
    git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null || \
    git show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null
}
