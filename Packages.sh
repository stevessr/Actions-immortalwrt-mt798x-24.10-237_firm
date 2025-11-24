#!/bin/bash

# Define the package update function
update_package() {
    local pkg_name=$1
    local repo_url=$2
    local delete_dir=$3
    local target_dir=$4
    local branch=$5

    echo " "
    echo "Search directory: $pkg_name"
    
    # If a directory to delete is specified, remove it
    if [ -n "$delete_dir" ] && [ -d "$delete_dir" ]; then
        echo "Delete directory: $delete_dir"
        rm -rf "$delete_dir"
    elif [ ! -d "$delete_dir" ]; then
        echo "Not fonud directory: $pkg_name"
    fi

    # Clone the repository
    if [ -n "$branch" ]; then
        git clone --depth=1 --single-branch -b "$branch" "$repo_url" "$target_dir"
    else
        git clone --depth=1 "$repo_url" "$target_dir"
    fi

    # Auto-update Makefile version (if applicable)
    local makefile_path="./$target_dir/Makefile"
    if [ -f "$makefile_path" ]; then
        echo " "
        echo "luci-app-$pkg_name version update has started!"
        
        local old_ver=$(grep -o 'PKG_VERSION:=.*' "$makefile_path" | sed 's/PKG_VERSION:=//')
        
        # Robust API call
        local api_response=$(curl -sL "https://api.github.com/repos/$repo_url/releases/latest")
        local new_ver=$(echo "$api_response" | jq -r '.tag_name // empty' | sed 's/v//')

        if [ -z "$new_ver" ] || echo "$api_response" | grep -q "API rate limit exceeded"; then
            echo "Error: Failed to fetch new version for $pkg_name. Skipping update."
            return
        fi

        echo "old version: $old_ver "
        echo "new version: $new_ver"
        
        if [ "$old_ver" != "$new_ver" ]; then
            sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$new_ver/g" "$makefile_path"
            local new_hash=$(curl -sL "https://api.github.com/repos/$repo_url/tarball/$new_ver" | sha256sum | awk '{print $1}')
            sed -i "s/PKG_HASH:=.*/PKG_HASH:=$new_hash/g" "$makefile_path"
            echo "$makefile_path version has been updated!"
        else
            echo "$makefile_path version is already the latest!"
        fi
    else
        echo "$pkg_name not found!"
    fi
}

# Clone and update packages
update_package "openclash" "https://github.com/vernesong/OpenClash" "../feeds/luci/applications/luci-app-openclash" "OpenClash" "master"
update_package "passwall" "https://github.com/xiaorouji/openwrt-passwall" "../feeds/luci/applications/luci-app-passwall" "openwrt-passwall" "main"
update_package "passwall2" "https://github.com/xiaorouji/openwrt-passwall2" "" "openwrt-passwall2" "main"
update_package "luci-app-tailscale" "https://github.com/asvow/luci-app-tailscale" "" "luci-app-tailscale" "main"
update_package "ssr-plus" "https://github.com/fw876/helloworld" "" "helloworld" "master"
update_package "mosdns" "https://github.com/sbwml/luci-app-mosdns" "../feeds/packages/net/mosdns" "luci-app-mosdns" "v5" "v2dat"
update_package "luci-app-store" "https://github.com/linkease/istore" "" "openwrt-package" "main"
update_package "luci-app-quickstart" "https://github.com/linkease/nas-packages" "" "openwrt-package" "master"
update_package "lucky" "https://github.com/gdy666/luci-app-lucky" "" "openwrt-package" "main"
update_package "luci-app-lucky" "https://github.com/gdy666/luci-app-lucky" "" "openwrt-package" "main"
update_package "luci-app-npc" "https://github.com/fullcone-nat/fullcone-nat-nftables-or-iptables" "" "kwrt-packages" "main"
update_package "luci-app-frpc" "https://github.com/kuoruan/luci-app-frpc" "../feeds/luci/applications/luci-app-frpc" "kwrt-packages" "master"
update_package "luci-app-zerotier" "https://github.com/kuoruan/luci-app-zerotier" "../feeds/luci/applications/luci-app-zerotier" "kwrt-packages" "master"
update_package "luci-theme-argon" "https://github.com/jerrykuku/luci-theme-argon" "../feeds/luci/themes/luci-theme-argon" "kwrt-packages" "master"
update_package "quickstart" "https://github.com/linkease/nas-packages-luci" "" "kwrt-packages" "main"
update_package "luci-app-quickstart" "https://github.com/linkease/nas-packages-luci" "" "kwrt-packages" "main"

# Update OpenClash core
echo " "
echo "预置OpenClash内核和数据!"
CRASH_URL=$(curl -sL https://api.github.com/repos/vernesong/OpenClash/releases/tags/Clash | jq -r ".assets[].browser_download_url" | grep -E "clash-linux-arm64-v3-.tar.gz$")
GEO_URL="https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest"
mkdir -p ../feeds/luci/applications/luci-app-openclash/root/etc/openclash
cd ../feeds/luci/applications/luci-app-openclash/root/etc/openclash || exit
curl -sL "$CRASH_URL" | tar xz && mv clash clash_main
curl -sL "$GEO_URL/Country.mmdb" -o Country.mmdb && echo "Country.mmdb done!"
curl -sL "$GEO_URL/GeoSite.dat" -o GeoSite.dat && echo "GeoSite.dat done!"
curl -sL https://github.com/MetaCubeX/Clash.Meta/releases/download/v1.18.0/clash.meta-linux-arm64-v1.18.0.gz | gzip -d > meta && chmod +x meta && echo "meta done!"
echo "openclash date has been updated!"