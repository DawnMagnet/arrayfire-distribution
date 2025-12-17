#!/bin/bash
# ArrayFire Docker Build Script
# Provides convenient CLI for building ArrayFire packages

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
BUILD_CONFIG="${SCRIPT_DIR}/build-config.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Defaults
ACTION="build"
BACKEND="all"
DISTRO="debian"
VERSION="12"
ARCH="amd64"
OUTPUT_DIR="${PROJECT_ROOT}/docker/output"
REGISTRY="ghcr.io/dawnmagnet"
MVP_ONLY=false
DRY_RUN=false
PUSH=false

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [ACTION]

Actions:
  build       Build packages (default)
  list        List available targets
  extract     Extract built packages
  clean       Clean build outputs

Options:
  -b, --backend BACKEND    Backend to build: all, cpu, cuda, opencl, oneapi (default: all)
  -d, --distro DISTRO      Linux distribution: debian, rhel (default: debian)
  -v, --version VERSION    Distribution version: 11-13 for debian, 8-10 for rhel (default: 12)
  -a, --arch ARCH          Architecture: amd64, arm64 (default: amd64)
  -o, --output DIR         Output directory (default: ./output)
  -r, --registry REGISTRY   Container registry (default: ghcr.io/dawnmagnet)
  --mvp                    Build only MVP targets
  --push                   Push images to registry
  --dry-run                Show commands without running
  -h, --help               Show this help message

Examples:
  # Build CPU backend for Debian 12 amd64
  $0 -b cpu -d debian -v 12 -a amd64

  # List all MVP targets
  $0 list --mvp

  # Build all MVP targets locally
  $0 build --mvp

  # Build and push to registry
  $0 build -b cuda --push

EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--backend)
            BACKEND="$2"
            shift 2
            ;;
        -d|--distro)
            DISTRO="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -a|--arch)
            ARCH="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        --mvp)
            MVP_ONLY=true
            shift
            ;;
        --push)
            PUSH=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        build|list|extract|clean)
            ACTION="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Determine Dockerfile
if [ "$DISTRO" = "debian" ]; then
    DOCKERFILE="Dockerfile.debian"
    VERSION_ARG="DEBIAN_VERSION"
elif [ "$DISTRO" = "rhel" ]; then
    DOCKERFILE="Dockerfile.rhel"
    VERSION_ARG="RHEL_VERSION"
else
    echo -e "${RED}Error: Unknown distro: $DISTRO${NC}"
    exit 1
fi

DOCKERFILE_PATH="${SCRIPT_DIR}/${DOCKERFILE}"

# Read configuration for version
ARRAYFIRE_VERSION="3.10"
ARRAYFIRE_RELEASE="v3.10.0"

# Build target name
TARGET="${DISTRO}${VERSION}-${BACKEND}-${ARCH}"
IMAGE_NAME="arrayfire:${TARGET}"
REGISTRY_IMAGE="${REGISTRY}/arrayfire-${BACKEND}:${ARRAYFIRE_VERSION}-${DISTRO}${VERSION}-${ARCH}"

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Action: List targets
action_list() {
    print_info "Available targets:"
    echo ""

    # For now, just show the MVP
    echo "MVP (Minimum Viable Product):"
    echo "  debian12-all-amd64"
    echo "  debian12-all-arm64"
    echo "  debian12-cpu-amd64"
    echo "  debian12-cpu-arm64"
    echo "  debian12-cuda-amd64"
    echo "  debian12-opencl-amd64"
    echo "  debian12-opencl-arm64"
    echo "  rhel9-all-amd64"
    echo "  rhel9-cuda-amd64"
}

# Action: Build
action_build() {
    print_info "Building ArrayFire"
    print_info "Target: ${TARGET}"
    print_info "Dockerfile: ${DOCKERFILE_PATH}"
    echo ""

    mkdir -p "${OUTPUT_DIR}"

    # Prepare build command
    BUILD_CMD=(
        "docker" "build"
        "-f" "${DOCKERFILE_PATH}"
        "-t" "${IMAGE_NAME}"
        "--build-arg" "${VERSION_ARG}=${VERSION}"
        "--build-arg" "BACKEND=${BACKEND}"
        "--build-arg" "ARCH=${ARCH}"
        "--build-arg" "ARRAYFIRE_VERSION=${ARRAYFIRE_VERSION}"
        "--build-arg" "ARRAYFIRE_RELEASE=${ARRAYFIRE_RELEASE}"
        "--output" "type=local,dest=${OUTPUT_DIR}/${TARGET}"
        "${SCRIPT_DIR}"
    )

    if [ "$DRY_RUN" = true ]; then
        print_warn "DRY RUN MODE"
        echo "${BUILD_CMD[@]}"
        return 0
    fi

    print_info "Running build..."
    if "${BUILD_CMD[@]}"; then
        print_success "Build completed: ${TARGET}"
        print_info "Output: ${OUTPUT_DIR}/${TARGET}"

        # List generated packages
        echo ""
        print_info "Generated packages:"
        if [ "$DISTRO" = "debian" ]; then
            find "${OUTPUT_DIR}/${TARGET}" -name "*.deb" -type f 2>/dev/null | while read -r pkg; do
                echo "  - $(basename "$pkg")"
            done
        else
            find "${OUTPUT_DIR}/${TARGET}" -name "*.rpm" -type f 2>/dev/null | while read -r pkg; do
                echo "  - $(basename "$pkg")"
            done
        fi
    else
        print_error "Build failed"
        return 1
    fi
}

# Action: Extract
action_extract() {
    print_info "Extracting packages from ${OUTPUT_DIR}/${TARGET}"

    if [ ! -d "${OUTPUT_DIR}/${TARGET}" ]; then
        print_error "Build output directory not found: ${OUTPUT_DIR}/${TARGET}"
        return 1
    fi

    EXTRACT_DIR="${PROJECT_ROOT}/packages/${TARGET}"
    mkdir -p "${EXTRACT_DIR}"

    if [ "$DISTRO" = "debian" ]; then
        find "${OUTPUT_DIR}/${TARGET}" -name "*.deb" -type f -exec cp {} "${EXTRACT_DIR}/" \;
    else
        find "${OUTPUT_DIR}/${TARGET}" -name "*.rpm" -type f -exec cp {} "${EXTRACT_DIR}/" \;
    fi

    print_success "Packages extracted to ${EXTRACT_DIR}"
    ls -lh "${EXTRACT_DIR}/"
}

# Action: Clean
action_clean() {
    print_warn "Cleaning build outputs..."
    rm -rf "${OUTPUT_DIR}"
    print_success "Clean completed"
}

# Main
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   ArrayFire Docker Build System       ║${NC}"
echo -e "${BLUE}║   Version: 3.10                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

case "$ACTION" in
    list)
        action_list
        ;;
    build)
        action_build
        ;;
    extract)
        action_extract
        ;;
    clean)
        action_clean
        ;;
    *)
        print_error "Unknown action: $ACTION"
        usage
        ;;
esac
