#!/bin/bash
# Build status checker

DOCKER_OUTPUT_DIR="/home/sgct/Project/arrayfire-distribution/docker/output"

echo "ArrayFire Build Status Monitor"
echo "=============================="
echo ""

# Check docker build status
echo "[1] Docker Build Status:"
RUNNING=$(docker ps --filter "ancestor=debian:12-slim" -q 2>/dev/null | wc -l)
if [ $RUNNING -gt 0 ]; then
    echo "✓ Build container is running (PID: $(docker ps --filter "ancestor=debian:12-slim" -q 2>/dev/null))"
else
    echo "⚠ No active build containers"
fi
echo ""

# Check output directory
echo "[2] Output Directory:"
if [ -d "$DOCKER_OUTPUT_DIR" ]; then
    SIZE=$(du -sh "$DOCKER_OUTPUT_DIR" 2>/dev/null | cut -f1)
    FILES=$(find "$DOCKER_OUTPUT_DIR" -type f | wc -l)
    echo "✓ Output directory exists"
    echo "  Size: $SIZE"
    echo "  Files: $FILES"
else
    echo "⚠ Output directory not yet created"
fi
echo ""

# Check system resource usage
echo "[3] System Resource Usage:"
LOAD=$(uptime | awk -F'load average:' '{print $2}')
MEM=$(free -h | awk '/^Mem:/ {print $3 " / " $2}')
DISK=$(df -h / | awk 'NR==2 {print $4 " free"}')

echo "  Load average: $LOAD"
echo "  Memory: $MEM"
echo "  Disk: $DISK"
echo ""

# Expected timeline
echo "[4] Expected Timeline:"
echo "  Phase 1: Dependencies - ✓ Completed"
echo "  Phase 2: CMake Config - ✓ Completed"
echo "  Phase 3: Compilation - ⏳ In Progress"
echo "    - Estimated time: 20-60 minutes"
echo "    - With ccache: Faster on subsequent builds"
echo "  Phase 4: Packaging - ⏳ Pending"
echo ""

echo "To check full build logs:"
echo "  tail -f /path/to/build/log"
echo ""
echo "To check if build succeeded:"
echo "  ls -lh $DOCKER_OUTPUT_DIR/debian12-cpu-amd64/"
