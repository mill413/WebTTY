#!/usr/bin/env bash
#
# MebTTY - Build Arch Linux package locally
#
# Usage:
#   ./pkg/aur/build-aur.sh [version]    # Build AUR package with specified version
#   ./pkg/aur/build-aur.sh              # Build AUR package with version from git tag or 0.0.0dev
#   ./pkg/aur/build-aur.sh --clean      # Remove build artifacts
#   ./pkg/aur/build-aur.sh --help       # Show help
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[AUR]${NC} $*"; }
warn() { echo -e "${YELLOW}[AUR]${NC} $*"; }
err()  { echo -e "${RED}[AUR]${NC} $*" >&2; }

get_version() {
    if git -C "$PROJECT_ROOT" describe --tags --exact-match >/dev/null 2>&1; then
        VERSION=$(git -C "$PROJECT_ROOT" describe --tags --exact-match | sed 's/^v//')
    else
        VERSION="${1:-0.0.0dev}"
    fi
    # Sanitize: replace hyphens with dots (Arch pkgver cannot contain hyphens)
    VERSION=$(echo "$VERSION" | tr '-' '.')
    echo "$VERSION"
}

check_deps() {
    local missing=()
    command -v makepkg >/dev/null 2>&1 || missing+=(makepkg)
    command -v fakeroot >/dev/null 2>&1 || missing+=(fakeroot)

    if [[ ${#missing[@]} -gt 0 ]]; then
        err "Missing required tools: ${missing[*]}"
        err "Install with: sudo pacman -S base-devel fakeroot"
        exit 1
    fi

    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        err "makepkg cannot be run as root. Please run as a normal user."
        exit 1
    fi

    log "Dependencies check passed"
}

build_aur() {
    local version="$1"

    log "Building MebTTY AUR package v${version}..."

    # Check if executable exists
    if [[ ! -f "$PROJECT_ROOT/build/mebtty" ]]; then
        log "Executable not found, running build.sh first..."
        cd "$PROJECT_ROOT"
        ./build.sh
    fi

    # Create build directory
    local build_dir="$PROJECT_ROOT/aur-build"
    rm -rf "$build_dir"
    mkdir -p "$build_dir"

    log "Creating package structure..."

    # Copy executable
    cp "$PROJECT_ROOT/build/mebtty" "$build_dir/mebtty-${version}-linux-amd64"
    chmod +x "$build_dir/mebtty-${version}-linux-amd64"

    # Copy service file
    cp "$PROJECT_ROOT/mebtty.service" "$build_dir/mebtty.service"

    # Copy install script
    cp "$SCRIPT_DIR/mebtty.install" "$build_dir/mebtty.install"

    # Generate PKGBUILD for local build (without source array, reference local files)
    cat > "$build_dir/PKGBUILD" <<EOF
# Maintainer: MebTTY Contributors
pkgname=mebtty
pkgver=$version
pkgrel=1
pkgdesc="A self-hosted web terminal that runs in your browser"
arch=('x86_64')
url="https://github.com/mill413/mebtty"
license=('MIT')
depends=('glibc' 'gcc-libs')
install=mebtty.install
source=()

package() {
    cd "\$srcdir/.."
    install -Dm755 "mebtty-${version}-linux-amd64" "\$pkgdir/usr/bin/mebtty"
    install -Dm644 "mebtty.service" "\$pkgdir/usr/lib/systemd/system/mebtty.service"
}
EOF

    # Build package
    log "Running makepkg..."
    cd "$build_dir"
    makepkg -f --noconfirm

    # Move output to project root
    local pkg_file=$(ls mebtty-*.pkg.tar.zst 2>/dev/null | head -1)
    if [[ -n "$pkg_file" ]]; then
        cp "$pkg_file" "$PROJECT_ROOT/"
        local size=$(du -h "$PROJECT_ROOT/$pkg_file" | cut -f1)

        echo ""
        echo -e "${CYAN}========================================${NC}"
        echo -e "${CYAN}  AUR package built successfully!${NC}"
        echo -e "${CYAN}${NC}"
        echo -e "${CYAN}  Package: $pkg_file ($size)${NC}"
        echo -e "${CYAN}  Install: sudo pacman -U $pkg_file${NC}"
        echo -e "${CYAN}  Remove:  sudo pacman -R mebtty${NC}"
        echo -e "${CYAN}========================================${NC}"
    else
        err "Package build failed"
        exit 1
    fi
}

clean() {
    log "Cleaning AUR build artifacts..."
    cd "$PROJECT_ROOT"
    rm -rf aur-build
    rm -f mebtty-*.pkg.tar.zst
    log "Done."
}

print_help() {
    echo "MebTTY - Build Arch Linux package locally"
    echo ""
    echo "Usage: ./pkg/aur/build-aur.sh [command] [version]"
    echo ""
    echo "Commands:"
    echo "  (none) [version]  Build AUR package (default: git tag or 0.0.0dev)"
    echo "  --clean           Remove AUR build artifacts"
    echo "  --help            Show this help message"
    echo ""
    echo "Requirements:"
    echo "  - base-devel (makepkg, fakeroot)"
    echo "  - Cannot run as root"
    echo ""
    echo "Examples:"
    echo "  ./pkg/aur/build-aur.sh              # Use git tag or 0.0.0dev"
    echo "  ./pkg/aur/build-aur.sh 1.2.3        # Build version 1.2.3"
    echo "  ./pkg/aur/build-aur.sh --clean      # Clean up"
    echo ""
    echo "Output:"
    echo "  mebtty-VERSION-1-x86_64.pkg.tar.zst  Arch Linux package"
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
        build_aur "$VERSION"
        ;;
esac
