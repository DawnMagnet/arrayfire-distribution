#!/usr/bin/env python3
"""
ArrayFire Docker Build Matrix Manager

Orchestrates building ArrayFire across multiple platforms, architectures, and backends.
Supports local builds, CI/CD integration, and artifact management.
"""

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

import yaml


@dataclass
class BuildTarget:
    """Represents a single build target"""

    distro: str
    version: int
    backend: str
    arch: str

    def __str__(self) -> str:
        return f"{self.distro}{self.version}-{self.backend}-{self.arch}"

    def get_image_name(self) -> str:
        """Generate Docker image name"""
        return (
            f"arrayfire:{self.distro}{self.version}-{self.backend}-{self.arch}"
        )

    def get_registry_image(self, registry: str = "ghcr.io/dawnmagnet") -> str:
        """Generate full registry image path"""
        version = "3.10"
        return f"{registry}/arrayfire-{self.backend}:{version}-{self.distro}{self.version}-{self.arch}"


class BuildMatrix:
    """Manages ArrayFire build matrix"""

    def __init__(self, config_file: str = "build-config.yaml"):
        """Initialize build matrix from config file"""
        self.config_path = Path(config_file)
        with open(self.config_path, "r") as f:
            self.config = yaml.safe_load(f)

        self.docker_dir = self.config_path.parent
        self.arrayfire_version = self.config["arrayfire"]["version"]
        self.arrayfire_release = self.config["arrayfire"]["release"]

    def get_dockerfile(self, distro: str) -> str:
        """Get Dockerfile path for distribution"""
        if distro.startswith("debian"):
            return "Dockerfile.debian"
        elif distro.startswith("rhel"):
            return "Dockerfile.rhel"
        else:
            raise ValueError(f"Unknown distro: {distro}")

    def get_version(self, distro_str: str) -> int:
        """Extract version from distro string"""
        import re

        match = re.search(r"(\d+)", distro_str)
        if match:
            return int(match.group(1))
        raise ValueError(f"Cannot extract version from {distro_str}")

    def get_mvp_targets(self) -> List[BuildTarget]:
        """Get MVP (Minimum Viable Product) build targets"""
        targets = []
        for item in self.config["mvp_matrix"]:
            distro = item["distro"]
            version = item["version"]
            backend = item["backend"]
            for arch in item["architectures"]:
                targets.append(
                    BuildTarget(
                        distro=distro,
                        version=version,
                        backend=backend,
                        arch=arch,
                    )
                )
        return targets

    def build_local(
        self, target: BuildTarget, output_dir: str = "output"
    ) -> bool:
        """Build target locally"""
        print(f"\n{'=' * 60}")
        print(f"Building: {target}")
        print(f"{'=' * 60}")

        # Determine Dockerfile and version arg name
        if target.distro == "debian":
            dockerfile = "Dockerfile.debian"
            version_arg = "DEBIAN_VERSION"
        else:
            dockerfile = "Dockerfile.rhel"
            version_arg = "RHEL_VERSION"

        dockerfile_path = self.docker_dir / dockerfile

        # Prepare build directory
        output_path = Path(output_dir) / str(target)
        output_path.mkdir(parents=True, exist_ok=True)

        # Build command
        cmd = [
            "docker",
            "build",
            "-f",
            str(dockerfile_path),
            "-t",
            target.get_image_name(),
            "--build-arg",
            f"{version_arg}={target.version}",
            "--build-arg",
            f"BACKEND={target.backend}",
            "--build-arg",
            f"ARCH={target.arch}",
            "--build-arg",
            f"ARRAYFIRE_VERSION={self.arrayfire_version}",
            "--build-arg",
            f"ARRAYFIRE_RELEASE={self.arrayfire_release}",
            "--output",
            f"type=local,dest={output_path}",
            str(self.docker_dir),
        ]

        print(f"Command: {' '.join(cmd)}")

        try:
            result = subprocess.run(cmd, check=True)
            print(f"✓ Build succeeded: {target}")
            return True
        except subprocess.CalledProcessError as e:
            print(f"✗ Build failed: {target}")
            print(f"Error: {e}")
            return False

    def build_with_buildx(
        self,
        target: BuildTarget,
        registry: str = "ghcr.io/dawnmagnet",
        push: bool = False,
    ) -> bool:
        """Build target with docker buildx (cross-platform)"""
        print(f"\n{'=' * 60}")
        print(f"Building with buildx: {target}")
        print(f"{'=' * 60}")

        # Determine Dockerfile and version arg name
        if target.distro == "debian":
            dockerfile = "Dockerfile.debian"
            version_arg = "DEBIAN_VERSION"
        else:
            dockerfile = "Dockerfile.rhel"
            version_arg = "RHEL_VERSION"

        dockerfile_path = self.docker_dir / dockerfile

        # Build command with buildx
        cmd = [
            "docker",
            "buildx",
            "build",
            "-f",
            str(dockerfile_path),
            "-t",
            target.get_registry_image(registry),
            "--platform",
            f"linux/{target.arch}",
            "--build-arg",
            f"{version_arg}={target.version}",
            "--build-arg",
            f"BACKEND={target.backend}",
            "--build-arg",
            f"ARCH={target.arch}",
            "--build-arg",
            f"ARRAYFIRE_VERSION={self.arrayfire_version}",
            "--build-arg",
            f"ARRAYFIRE_RELEASE={self.arrayfire_release}",
        ]

        if push:
            cmd.append("--push")

        cmd.append(str(self.docker_dir))

        print(f"Command: {' '.join(cmd)}")

        try:
            result = subprocess.run(cmd, check=True)
            print(f"✓ Build succeeded: {target}")
            if push:
                print(
                    f"✓ Pushed to registry: {target.get_registry_image(registry)}"
                )
            return True
        except subprocess.CalledProcessError as e:
            print(f"✗ Build failed: {target}")
            print(f"Error: {e}")
            return False

    def extract_packages(
        self, target: BuildTarget, source_dir: str, dest_dir: str = "packages"
    ) -> bool:
        """Extract .deb/.rpm packages from build output"""
        print(f"\nExtracting packages for: {target}")

        source_path = Path(source_dir)
        dest_path = Path(dest_dir)
        dest_path.mkdir(parents=True, exist_ok=True)

        # Find packages
        if target.distro == "debian":
            packages = list(source_path.glob("**/*.deb"))
        else:
            packages = list(source_path.glob("**/*.rpm"))

        if not packages:
            print(f"⚠ No packages found in {source_path}")
            return False

        for pkg in packages:
            import shutil

            dest_file = dest_path / f"{target}_{pkg.name}"
            shutil.copy2(pkg, dest_file)
            print(f"  Extracted: {dest_file.name}")

        return True


def main():
    parser = argparse.ArgumentParser(
        description="ArrayFire Docker Build Matrix Manager"
    )

    parser.add_argument(
        "action", choices=["build", "list", "extract"], help="Action to perform"
    )

    parser.add_argument(
        "--config",
        default="build-config.yaml",
        help="Build configuration file (default: build-config.yaml)",
    )

    parser.add_argument(
        "--mvp",
        action="store_true",
        help="Build only MVP (Minimum Viable Product) targets",
    )

    parser.add_argument(
        "--target", help="Specific target to build (format: debian12-all-amd64)"
    )

    parser.add_argument(
        "--output-dir",
        default="output",
        help="Output directory for local builds",
    )

    parser.add_argument(
        "--registry",
        default="ghcr.io/dawnmagnet",
        help="Container registry for buildx push",
    )

    parser.add_argument(
        "--push",
        action="store_true",
        help="Push images to registry (requires buildx)",
    )

    parser.add_argument(
        "--buildx",
        action="store_true",
        help="Use docker buildx for cross-platform builds",
    )

    args = parser.parse_args()

    # Load build matrix
    matrix = BuildMatrix(args.config)

    # List targets
    if args.action == "list":
        targets = (
            matrix.get_mvp_targets() if args.mvp else matrix.get_mvp_targets()
        )
        print(f"\n{'=' * 60}")
        print(f"Build Targets ({len(targets)} total)")
        print(f"{'=' * 60}")
        for target in targets:
            image = target.get_image_name()
            if args.buildx:
                image = target.get_registry_image(args.registry)
            print(f"  {target:<40} -> {image}")
        return 0

    # Determine targets to build
    if args.target:
        # Parse specific target
        parts = args.target.split("-")
        if len(parts) != 3:
            print(
                "Error: target format must be distro-backend-arch (e.g., debian12-all-amd64)"
            )
            return 1

        distro_version = parts[0]
        backend = parts[1]
        arch = parts[2]

        # Extract distro and version
        import re

        match = re.match(r"(\w+)(\d+)", distro_version)
        if not match:
            print(f"Error: invalid distro format: {distro_version}")
            return 1

        distro, version = match.group(1), int(match.group(2))
        targets = [BuildTarget(distro, version, backend, arch)]
    else:
        targets = matrix.get_mvp_targets()

    # Build
    if args.action == "build":
        results = {}
        for target in targets:
            if args.buildx:
                success = matrix.build_with_buildx(
                    target, args.registry, args.push
                )
            else:
                success = matrix.build_local(target, args.output_dir)
            results[str(target)] = success

        # Summary
        print(f"\n{'=' * 60}")
        print("Build Summary")
        print(f"{'=' * 60}")
        passed = sum(1 for v in results.values() if v)
        total = len(results)
        print(f"Passed: {passed}/{total}")
        for target, success in results.items():
            status = "✓" if success else "✗"
            print(f"  {status} {target}")

        return 0 if passed == total else 1

    # Extract packages
    if args.action == "extract":
        for target in targets:
            source = Path(args.output_dir) / str(target)
            matrix.extract_packages(target, str(source))
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
