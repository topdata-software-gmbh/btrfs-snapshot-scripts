#!/usr/bin/env bash
#
#
# Description:
#   Creates a BTRFS snapshot of a directory. The directory must be a BTRFS subvolume.
#   Stores snapshots in /srv/snapshots with timestamp-based naming.
#
# Usage:
#   ./backup-shop.sh [-h|--help]
#   ./backup-shop.sh /path/to/shop/directory
#
# Arguments:
#   /path/to/shop/directory - Full path to the shop directory containing docker-compose.yaml
#
# Example:
#   ./backup-shop.sh /srv/sites/os24-sw64
#   Creates snapshot: /srv/snapshots/os24-sw64__2024-10-23-121033
#
# Requirements:
#   - BTRFS filesystem on /srv
#   - Docker and docker-compose installed
#   - Shop directory must contain docker-compose.yaml
#   - Write permissions on /srv/snapshots
#
# Author: Marc Christenfeldt / claude.ai
# Date: October 2024

usage() {
    echo "Usage: $(basename "$0") [-h|--help] /path/to/shop/directory"
    echo
    echo "Creates a BTRFS snapshot of a shop's Docker volumes."
    echo
    echo "Options:"
    echo "    -h, --help    Show this help message and exit"
    echo
    echo "Arguments:"
    echo "    /path/to/shop/directory    Full path to shop directory containing docker-compose.yaml"
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
    local shop_name=$(basename "$shop_dir")
    local timestamp=$(date '+%Y-%m-%d-%H%M%S')
    local snapshot_name="${shop_name}__${timestamp}"
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
if [ "$#" -ne 1 ]; then
    usage
    exit 1
fi

create_snapshot "$1"

