#!/bin/bash

# Script to set up and build OpenWrt for Philips HY3000
# Based on the GitHub Actions workflow in .github/workflows/hy3000-24.10-6.6.yml

set -e  # Exit on any error

echo "Setting up build environment for Philips HY3000..."

# Define variables based on the workflow
REPO_URL="https://github.com/padavanonly/immortalwrt-mt798x-24.10"
REPO_BRANCH="openwrt-24.10-6.6"
FEEDS_CONF="feeds.conf.default"
CONFIG_FILE="hy3000.config"
DIY_P1_SH="diy-part1.sh"
DIY_P2_SH="diy-part2.sh"

# Create workdir and clone the repository
echo "Creating workdir and cloning repository..."
mkdir -p /workdir
cd /workdir
git clone $REPO_URL -b $REPO_BRANCH openwrt
ln -sf /workdir/openwrt /workspace/openwrt

# Navigate to the OpenWrt directory
cd openwrt

# Load custom feeds (if any)
if [ -e "/workspace/$FEEDS_CONF" ]; then
    mv "/workspace/$FEEDS_CONF" feeds.conf.default
fi

# Run the first DIY script to set up feeds
if [ -e "/workspace/$DIY_P1_SH" ]; then
    chmod +x "/workspace/$DIY_P1_SH"
    "/workspace/$DIY_P1_SH"
fi

# Update and install feeds
echo "Updating feeds..."
./scripts/feeds update -a

echo "Installing feeds..."
./scripts/feeds install -a

# Run the second DIY script to customize the build
if [ -e "/workspace/$DIY_P2_SH" ]; then
    chmod +x "/workspace/$DIY_P2_SH"
    "/workspace/$DIY_P2_SH"
fi

# Copy the configuration file
if [ -e "/workspace/$CONFIG_FILE" ]; then
    cp "/workspace/$CONFIG_FILE" .config
fi

# If files directory exists, copy it
if [ -d "/workspace/files" ]; then
    cp -r "/workspace/files" ./
fi

# Run custom packages script if it exists
if [ -e "/workspace/Packages.sh" ]; then
    cd package/
    bash "/workspace/Packages.sh"
    cd ../
fi

# Generate defconfig to ensure all necessary packages are selected
echo "Generating defconfig..."
make defconfig

# Install the toolchain and system components
echo "Installing tools and toolchain..."
make -j$(nproc) tools/install V=s || make -j1 tools/install V=s
make -j$(nproc) toolchain/install V=s || make -j1 toolchain/install V=s

# Build opkg package which is required for the target installation step
echo "Building opkg package..."
make -j$(nproc) package/opkg/compile V=s || make -j1 package/opkg/compile V=s

# Now install packages and build the target
echo "Installing packages..."
make package/install V=s || make -j1 package/install V=s

echo "Building target..."
make -j$(nproc) target/compile V=s || make -j1 target/compile V=s

echo "Installing target..."
make -j$(nproc) target/install V=s || make -j1 target/install V=s

echo "Build completed successfully!"
echo "Check /workdir/openwrt/bin/targets/ for the firmware images."