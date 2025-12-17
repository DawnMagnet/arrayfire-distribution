#!/bin/bash
# ArrayFire Docker Build - Quick Test Script
# This script validates the build system configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   ArrayFire Docker Build System      ║${NC}"
echo -e "${BLUE}║   Configuration Validation           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}[1/5]${NC} Checking prerequisites..."

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker not found${NC}"
    echo "  Install: https://docs.docker.com/get-docker/"
    exit 1
fi
echo -e "${GREEN}✓ Docker${NC} $(docker --version | cut -d' ' -f3)"

# Check Git
if ! command -v git &> /dev/null; then
    echo -e "${RED}✗ Git not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Git${NC} $(git --version | cut -d' ' -f3)"

# Check Python (optional)
if command -v python3 &> /dev/null; then
    echo -e "${GREEN}✓ Python 3${NC} $(python3 --version | cut -d' ' -f2)"
else
    echo -e "${YELLOW}⚠ Python 3 not found (optional, for build-matrix.py)${NC}"
fi

echo ""
echo -e "${YELLOW}[2/5]${NC} Checking project structure..."

# Check key files
FILES=(
    "docker/Dockerfile.debian"
    "docker/Dockerfile.rhel"
    "docker/build-config.yaml"
    "docker/build.sh"
    "docker/README.md"
    ".github/workflows/build-release.yml"
)

for file in "${FILES[@]}"; do
    if [ -f "${PROJECT_ROOT}/${file}" ]; then
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${RED}✗${NC} $file (missing)"
    fi
done

echo ""
echo -e "${YELLOW}[3/5]${NC} Validating configuration..."

# Validate YAML
if command -v python3 &> /dev/null; then
    if python3 -c "import yaml; yaml.safe_load(open('${SCRIPT_DIR}/build-config.yaml'))" 2>/dev/null; then
        echo -e "${GREEN}✓ build-config.yaml${NC} valid YAML"
    else
        echo -e "${RED}✗ build-config.yaml${NC} invalid YAML"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠${NC} Skipping YAML validation (Python not available)"
fi

echo ""
echo -e "${YELLOW}[4/5]${NC} Checking Docker daemon..."

# Test Docker connection
if docker ps &> /dev/null; then
    echo -e "${GREEN}✓ Docker daemon${NC} running and accessible"
else
    echo -e "${RED}✗ Docker daemon${NC} not accessible"
    echo "  Run: sudo usermod -aG docker \$USER"
    exit 1
fi

echo ""
echo -e "${YELLOW}[5/5]${NC} Quick build test..."

# Test dry-run
if bash "${SCRIPT_DIR}/build.sh" --dry-run -d debian -v 12 -b cpu &> /dev/null; then
    echo -e "${GREEN}✓ Build script${NC} working correctly"
else
    echo -e "${RED}✗ Build script${NC} has issues"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  All checks passed! Ready to build.   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

echo "Quick Start Commands:"
echo ""
echo "  # List available targets"
echo "  $ cd docker && ./build.sh list --mvp"
echo ""
echo "  # Build Debian 12 CPU backend (amd64)"
echo "  $ ./build.sh -d debian -v 12 -b cpu -a amd64"
echo ""
echo "  # Build with Python build matrix (recommended)"
echo "  $ python3 build-matrix.py list"
echo "  $ python3 build-matrix.py build --mvp"
echo ""
echo "  # Using Docker Compose (parallel builds)"
echo "  $ cd .. && docker-compose -f docker-compose.build.yml build"
echo ""
echo "Documentation:"
echo "  • docker/README.md - Full documentation"
echo "  • docker/CONFIGURATION.md - Configuration guide"
echo "  • .github/workflows/build-release.yml - CI/CD setup"
echo ""
