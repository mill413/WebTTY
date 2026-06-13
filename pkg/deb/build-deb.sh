#!/usr/bin/env bash
#
# MebTTY - Build Debian package locally
#
# Usage:
#   ./pkg/deb/build-deb.sh [version]    # Build deb package with specified version
#   ./pkg/deb/build-deb.sh              # Build deb package with version from git tag or 0.0.0-dev
#   ./pkg/deb/build-deb.sh --clean      # Remove build artifacts
#   ./pkg/deb/build-deb.sh --help       # Show help
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEBIAN_META="$SCRIPT_DIR/DEBIAN"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[Deb]${NC} $*"; }
warn() { echo -e "${YELLOW}[Deb]${NC} $*"; }
err()  { echo -e "${RED}[Deb]${NC} $*" >&2; }

get_version() {
    # Try to get version from git tag
    if git -C "$PROJECT_ROOT" describe --tags --exact-match >/dev/null 2>&1; then
        VERSION=$(git -C "$PROJECT_ROOT" describe --tags --exact-match | sed 's/^v//')
    else
        VERSION="${1:-0.0.0-dev}"
    fi
    echo "$VERSION"
}

check_deps() {
    local missing=()
    command -v dpkg-deb >/dev/null 2>&1 || missing+=(dpkg-deb)
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        err "Missing required tools: ${missing[*]}"
        err "Install with: sudo apt-get install dpkg"
        exit 1
    fi
    
    log "Dependencies check passed"
}

build_deb() {
    local version="$1"
    
    log "Building MebTTY deb package v${version}..."
    
    # Check if executable exists
    if [[ ! -f "$PROJECT_ROOT/build/mebtty" ]]; then
        log "Executable not found, running build.sh first..."
        cd "$PROJECT_ROOT"
        ./build.sh
    fi
    
    # Create package directory
    local pkg_dir="mebtty_${version}_amd64"
    cd "$PROJECT_ROOT"
    rm -rf "$pkg_dir"
    
    log "Creating package structure: $pkg_dir/"
    mkdir -p "$pkg_dir/DEBIAN"
    mkdir -p "$pkg_dir/usr/local/bin"
    mkdir -p "$pkg_dir/lib/systemd/system"
    
    # Copy executable
    log "Copying executable..."
    cp "$PROJECT_ROOT/build/mebtty" "$pkg_dir/usr/local/bin/mebtty"
    chmod 755 "$pkg_dir/usr/local/bin/mebtty"
    
    # Copy systemd service
    log "Copying systemd service..."
    cp "$PROJECT_ROOT/mebtty.service" "$pkg_dir/lib/systemd/system/mebtty.service"
    chmod 644 "$pkg_dir/lib/systemd/system/mebtty.service"
    
    # Copy DEBIAN metadata
    log "Copying DEBIAN metadata..."
    sed "s/\${VERSION}/$version/g" "$DEBIAN_META/control" > "$pkg_dir/DEBIAN/control"
    cp "$DEBIAN_META/postinst" "$pkg_dir/DEBIAN/postinst"
    cp "$DEBIAN_META/prerm"    "$pkg_dir/DEBIAN/prerm"
    cp "$DEBIAN_META/postrm"   "$pkg_dir/DEBIAN/postrm"
    chmod 755 "$pkg_dir/DEBIAN/postinst" "$pkg_dir/DEBIAN/prerm" "$pkg_dir/DEBIAN/postrm"
    
    # Build deb package
    log "Building deb package..."
    dpkg-deb --build --root-owner-group "$pkg_dir"
    
    # Get file size
    local deb_file="${pkg_dir}.deb"
    local size=$(du -h "$deb_file" | cut -f1)
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  Debian package built successfully!${NC}"
    echo -e "${CYAN}${NC}"
    echo -e "${CYAN}  Package: $deb_file ($size)${NC}"
    echo -e "${CYAN}  Install: sudo dpkg -i $deb_file${NC}"
    echo -e "${CYAN}  Remove:  sudo dpkg -r mebtty${NC}"
    echo -e "${CYAN}  Purge:   sudo dpkg -P mebtty${NC}"
    echo -e "${CYAN}========================================${NC}"
}

clean() {
    log "Cleaning deb build artifacts..."
    cd "$PROJECT_ROOT"
    rm -rf mebtty_*_amd64
    rm -f mebtty_*_amd64.deb
    log "Done."
}

print_help() {
    echo "MebTTY - Build Debian package locally"
    echo ""
    echo "Usage: ./pkg/deb/build-deb.sh [command] [version]"
    echo ""
    echo "Commands:"
    echo "  (none) [version]  Build deb package (default: git tag or 0.0.0-dev)"
    echo "  --clean           Remove deb build artifacts"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./pkg/deb/build-deb.sh              # Use git tag or 0.0.0-dev"
    echo "  ./pkg/deb/build-deb.sh 1.2.3        # Build version 1.2.3"
    echo "  ./pkg/deb/build-deb.sh --clean      # Clean up"
    echo ""
    echo "Output:"
    echo "  mebtty_VERSION_amd64.deb    Debian package file"
}

# ── Main ─────────────────────────────────────────────────────────

case "${1:-}" in
    --clean)
        clean
        ;;
    --help|-h)
        print_help
        ;;
    *)
        check_deps
        VERSION=$(get_version "$@")
        build_deb "$VERSION"
        ;;
esac
