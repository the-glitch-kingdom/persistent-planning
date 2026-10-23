#!/bin/bash
# ensure-python.sh — Check for Python >=3.8, install if missing
# Supports: Linux (apt/yum/dnf/pacman), macOS (brew), WSL2

set -e

MIN_MAJOR=3
MIN_MINOR=8

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; RESET='\033[0m'

# All logging goes to stderr so stdout is clean for the command name
log()  { printf '%b\n' "${CYAN}[python]${RESET} $*" >&2; }
ok()   { printf '%b\n' "${GREEN}[python]${RESET} $*" >&2; }
warn() { printf '%b\n' "${YELLOW}[python]${RESET} $*" >&2; }
fail() { printf '%b\n' "${RED}[python]${RESET} $*" >&2; exit 1; }

version_ok() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then return 1; fi
    local ver
    ver=$("$cmd" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    local major minor
    major=$(echo "$ver" | cut -d. -f1)
    minor=$(echo "$ver" | cut -d. -f2)
    [ "$major" -gt "$MIN_MAJOR" ] || { [ "$major" -eq "$MIN_MAJOR" ] && [ "$minor" -ge "$MIN_MINOR" ]; }
}

find_python() {
    for cmd in python3 python python3.12 python3.11 python3.10 python3.9 python3.8; do
        if version_ok "$cmd"; then
            echo "$cmd"
            return 0
        fi
    done
    return 1
}

install_linux() {
    log "Detecting Linux package manager..."
    if command -v apt-get &>/dev/null; then
        log "Installing via apt..."
        sudo apt-get update -qq && sudo apt-get install -y python3 python3-pip
    elif command -v dnf &>/dev/null; then
        log "Installing via dnf..."
        sudo dnf install -y python3 python3-pip
    elif command -v yum &>/dev/null; then
        log "Installing via yum..."
        sudo yum install -y python3 python3-pip
    elif command -v pacman &>/dev/null; then
        log "Installing via pacman..."
        sudo pacman -Sy --noconfirm python python-pip
    elif command -v zypper &>/dev/null; then
        log "Installing via zypper..."
        sudo zypper install -y python3 python3-pip
    else
        fail "No supported package manager found (tried apt, dnf, yum, pacman, zypper). Please install Python ${MIN_MAJOR}.${MIN_MINOR}+ manually."
    fi
}

install_macos() {
    if command -v brew &>/dev/null; then
        log "Installing via Homebrew..."
        brew install python3
    else
        warn "Homebrew not found. Attempting to install Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        brew install python3
    fi
}

main() {
    log "Checking for Python >= ${MIN_MAJOR}.${MIN_MINOR}..."

    if PYTHON_CMD=$(find_python); then
        ver=$("$PYTHON_CMD" --version 2>&1)
        ok "Found: $PYTHON_CMD ($ver)"
        echo "$PYTHON_CMD"
        exit 0
    fi

    warn "Python >= ${MIN_MAJOR}.${MIN_MINOR} not found. Attempting installation..."

    OS="$(uname -s)"
    case "$OS" in
        Linux*)  install_linux ;;
        Darwin*) install_macos ;;
        *)       fail "Unsupported OS: $OS. Please install Python ${MIN_MAJOR}.${MIN_MINOR}+ manually." ;;
    esac

    if PYTHON_CMD=$(find_python); then
        ver=$("$PYTHON_CMD" --version 2>&1)
        ok "Installed successfully: $PYTHON_CMD ($ver)"
        echo "$PYTHON_CMD"
    else
        fail "Installation appeared to succeed but Python ${MIN_MAJOR}.${MIN_MINOR}+ is still not accessible. Please check your PATH."
    fi
}

main
