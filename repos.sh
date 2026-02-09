#!/usr/bin/env bash
# repos.sh — Clone, pull, and manage Capitec service repositories.
#
# Usage:
#   ./repos.sh clone          Clone all repos via SSH
#   ./repos.sh clone_https    Clone all repos via HTTPS
#   ./repos.sh pull           Pull latest for all repos
#   ./repos.sh status         Show git status of all repos
#   ./repos.sh reset          Reset all repos to default branch

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

if [[ -z "${CAPITEC_DEVSTACK_WORKSPACE:-}" ]]; then
    echo "ERROR: CAPITEC_DEVSTACK_WORKSPACE is not set."
    echo "Set it in devstack/.env or export it in your shell."
    exit 1
fi

WORKSPACE="$(cd "${CAPITEC_DEVSTACK_WORKSPACE}" 2>/dev/null && pwd || echo "${CAPITEC_DEVSTACK_WORKSPACE}")"

if [[ ! -d "${WORKSPACE}" ]]; then
    echo "ERROR: CAPITEC_DEVSTACK_WORKSPACE directory does not exist: ${WORKSPACE}"
    exit 1
fi

# Default branch for all repos
DEFAULT_BRANCH="${CAPITEC_DEFAULT_BRANCH:-main}"

# Repository definitions: <directory-name> <ssh-url> <https-url>
REPOS=(
    "core-banking git@github.com:capitec/core-banking.git https://github.com/capitec/core-banking.git"
    "core-fraud-detection git@github.com:capitec/core-fraud-detection.git https://github.com/capitec/core-fraud-detection.git"
    "fraud-ops-portal git@github.com:capitec/fraud-ops-portal.git https://github.com/capitec/fraud-ops-portal.git"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_repo_name() { echo "$1" | awk '{print $1}'; }
_repo_ssh()  { echo "$1" | awk '{print $2}'; }
_repo_https(){ echo "$1" | awk '{print $3}'; }

_for_each_repo() {
    local callback="$1"
    for entry in "${REPOS[@]}"; do
        local name=$(_repo_name "$entry")
        local ssh=$(_repo_ssh "$entry")
        local https=$(_repo_https "$entry")
        local dir="${WORKSPACE}/${name}"
        $callback "$name" "$dir" "$ssh" "$https"
    done
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

_clone_repo() {
    local name="$1" dir="$2" url="$3"
    if [[ -d "${dir}/.git" ]]; then
        echo "  ${name}: already cloned — skipping"
    elif [[ -d "${dir}" ]]; then
        echo "  ${name}: directory exists but is not a git repo — skipping (remove it manually to re-clone)"
    else
        echo "  ${name}: cloning..."
        git clone "${url}" "${dir}"
    fi
}

clone() {
    echo "Cloning service repos (SSH) into ${WORKSPACE}..."
    _for_each_repo _clone_ssh_entry
}

_clone_ssh_entry() {
    _clone_repo "$1" "$2" "$3"
}

clone_https() {
    echo "Cloning service repos (HTTPS) into ${WORKSPACE}..."
    _for_each_repo _clone_https_entry
}

_clone_https_entry() {
    _clone_repo "$1" "$2" "$4"
}

pull() {
    echo "Pulling latest for all service repos..."
    _for_each_repo _pull_entry
}

_pull_entry() {
    local name="$1" dir="$2"
    if [[ -d "${dir}/.git" ]]; then
        echo "  ${name}: pulling..."
        (cd "${dir}" && git pull --ff-only)
    else
        echo "  ${name}: not a git repo — skipping (run 'make repos.clone' first)"
    fi
}

status() {
    echo "Status of service repos in ${WORKSPACE}:"
    echo ""
    _for_each_repo _status_entry
}

_status_entry() {
    local name="$1" dir="$2"
    if [[ -d "${dir}/.git" ]]; then
        echo "--- ${name} ---"
        (cd "${dir}" && echo "  branch: $(git branch --show-current)" && git status --short)
        echo ""
    else
        echo "--- ${name} ---"
        echo "  not a git repo"
        echo ""
    fi
}

reset() {
    echo "This will reset all service repos to '${DEFAULT_BRANCH}' and discard local changes."
    read -p "Are you sure? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    _for_each_repo _reset_entry
}

_reset_entry() {
    local name="$1" dir="$2"
    if [[ -d "${dir}/.git" ]]; then
        echo "  ${name}: resetting to ${DEFAULT_BRANCH}..."
        (cd "${dir}" && git checkout "${DEFAULT_BRANCH}" && git reset --hard "origin/${DEFAULT_BRANCH}" && git clean -fd)
    else
        echo "  ${name}: not a git repo — skipping"
    fi
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

case "${1:-}" in
    clone)       clone ;;
    clone_https) clone_https ;;
    pull)        pull ;;
    status)      status ;;
    reset)       reset ;;
    *)
        echo "Usage: $0 {clone|clone_https|pull|status|reset}"
        exit 1
        ;;
esac
