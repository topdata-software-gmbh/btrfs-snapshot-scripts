#!/usr/bin/env bash
#
#
# Description:
#   Creates a BTRFS snapshot of a directory. The directory must be a BTRFS subvolume.
#   Stores snapshots in /srv/snapshots with timestamp-based naming.
#
# Usage:
#   ./make-snapshot.sh [-h|--help]
#   ./make-snapshot.sh /path/to/shop/directory [snapshot-name]
#
# Arguments:
#   /path/to/shop/directory - Full path to the shop directory containing docker-compose.yaml
#   snapshot-name          - Optional name to append to the snapshot (will be slugified)
#
# Examples:
#   ./make-snapshot.sh /srv/sites/os24-sw64
#   Creates snapshot: /srv/snapshots/os24-sw64__2024-10-23-121033
#
#   ./make-snapshot.sh /srv/sites/os24-sw64 "before backup to sw65"
#   Creates snapshot: /srv/snapshots/os24-sw64__2024-10-23-121033__before-backup-to-sw65
#
# Requirements:
#   - BTRFS filesystem on /srv
#   - Docker and docker-compose installed
#   - Shop directory must contain docker-compose.yaml
#   - Write permissions on /srv/snapshots
#
# Author: Marc Christenfeldt / claude.ai
# Date: October 2024

slugify() {
    echo "$1" | iconv -t ascii//TRANSLIT | sed -E 's/[^a-zA-Z0-9]+/-/g' | sed -E 's/^-+|-+$//g' | tr '[:upper:]' '[:lower:]'
}

usage() {
    echo "Usage: $(basename "$0") [-h|--help] /path/to/shop/directory [snapshot-name]"
    echo
    echo "Creates a BTRFS snapshot of a shop's Docker volumes."
    echo
    echo "Options:"
    echo "    -h, --help    Show this help message and exit"
    echo
    echo "Arguments:"
    echo "    /path/to/shop/directory    Full path to shop directory containing docker-compose.yaml"
    echo "    snapshot-name              Optional name to append to the snapshot (will be slugified)"
    echo
    echo "The script will:"
    echo "1. Stop running containers"
    echo "2. Create a read-only snapshot in /srv/snapshots"
    echo "3. Restart the containers"
    echo "4. Name format: shopname__YYYY-MM-DD-HHMMSS"
    echo
    echo "Example:"
    echo "    $(basename "$0") /srv/sites/os24-sw64"
}
# Parse command line options
case "$1" in
    -h|--help)
        usage
        exit 0
        ;;
esac

create_snapshot() {
    local shop_dir="$1"
    local custom_name="$2"
    local shop_name=$(basename "$shop_dir")
    local timestamp=$(date '+%Y-%m-%d-%H%M%S')
    local snapshot_name="${shop_name}__${timestamp}"
    
    if [ -n "$custom_name" ]; then
        local slugified_name=$(slugify "$custom_name")
        snapshot_name="${snapshot_name}__${slugified_name}"
    fi
    local snapshot_path="/srv/snapshots/${snapshot_name}"

    # Ensure /srv/snapshots exists
    mkdir -p /srv/snapshots


    # Create the snapshot
    echo "Creating snapshot ${snapshot_name}..."
    if btrfs subvolume snapshot -r "${shop_dir}" "${snapshot_path}"; then
        echo "Snapshot created successfully at ${snapshot_path}"
    else
        echo "Error creating snapshot"
        exit 2
    fi

    echo "Backup complete: ${snapshot_name}"
}

# Check arguments
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
    exit 1
fi

create_snapshot "$1" "$2"

