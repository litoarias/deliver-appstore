#!/bin/bash
# deliver-appstore — utils.sh
# Common utilities: colors, logging, confirmations, validations

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Logging
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()    { echo -e "\n${BOLD}${CYAN}[$1]${NC} ${BOLD}$2${NC}"; }

# Confirm action (returns 0 for yes, 1 for no)
# Usage: confirm "Do you want to continue?" && do_something
confirm() {
    local message="${1:-Continue?}"
    if [[ "${NO_CONFIRM:-}" == "true" ]]; then
        return 0
    fi
    echo -en "${YELLOW}$message [Y/n]: ${NC}"
    read -r response
    case "$response" in
        [nN][oO]|[nN]) return 1 ;;
        *) return 0 ;;
    esac
}

# Prompt for input with optional default
# Usage: value=$(prompt_input "Version" "1.0.0")
prompt_input() {
    local label="$1"
    local default="$2"
    if [[ -n "$default" ]]; then
        echo -en "${CYAN}$label${NC} [${default}]: "
    else
        echo -en "${CYAN}$label${NC}: "
    fi
    read -r input
    echo "${input:-$default}"
}

# Prompt user to select from a list
# Usage: selected=$(prompt_select "Choose a scheme:" "Scheme1" "Scheme2" "Scheme3")
prompt_select() {
    local prompt="$1"
    shift
    local options=("$@")

    if [[ ${#options[@]} -eq 1 ]]; then
        echo "${options[0]}"
        return
    fi

    echo -e "${CYAN}$prompt${NC}" >&2
    local i=1
    for opt in "${options[@]}"; do
        echo -e "  ${BOLD}$i)${NC} $opt" >&2
        ((i++))
    done

    while true; do
        echo -en "${YELLOW}Select [1-${#options[@]}]: ${NC}" >&2
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
            echo "${options[$((choice-1))]}"
            return
        fi
        echo -e "${RED}Invalid selection. Try again.${NC}" >&2
    done
}

# Require a command to be available
require_command() {
    local cmd="$1"
    local hint="${2:-}"
    if ! command -v "$cmd" &>/dev/null; then
        log_error "'$cmd' is not installed."
        [[ -n "$hint" ]] && log_info "Install hint: $hint"
        exit 1
    fi
}

# Require clean git working tree
require_clean_worktree() {
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        log_error "Working tree is not clean. Commit or stash your changes first."
        git status --short
        exit 1
    fi
}

# Require being inside a git repository
require_git_repo() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        log_error "Not inside a git repository."
        exit 1
    fi
}

# Abort with error message
abort() {
    log_error "$1"
    exit 1
}

# Print a separator line
separator() {
    echo -e "${BLUE}──────────────────────────────────────────────${NC}"
}

# Print summary header
summary_header() {
    echo ""
    separator
    echo -e "${BOLD}${GREEN}  $1${NC}"
    separator
}

# Print a key-value pair in summary
summary_item() {
    printf "  ${BOLD}%-18s${NC} %s\n" "$1:" "$2"
}
