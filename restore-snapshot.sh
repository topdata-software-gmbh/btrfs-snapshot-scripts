#!/usr/bin/env bash
#
# Description:
#   Restores a BTRFS snapshot of a directory which is a BTRFS subvolume.
#   Automatically handles container shutdown and startup during restore.
#   Optionally deletes the source snapshot after successful restore.
#
# Usage:
#   ./restore-snapshot.sh [-h|--help] [-d|--delete-snapshot] /path/to/snapshot /path/to/shop/directory
#
# Arguments:
#   /path/to/snapshot       - Full path to the snapshot to restore
#   /path/to/shop/directory - Full path to the target shop directory
#
# Options:
#   -d, --delete-snapshot  Delete the source snapshot after successful restore
#   -h, --help            Show help message and exit
#
# Example:
#   ./restore-snapshot.sh -d /srv/snapshots/os24-sw64__2024-10-23-121033 /srv/sites/os24-sw64
#
# Requirements:
#   - BTRFS filesystem on /srv
#   - Docker and docker-compose installed
#   - Write permissions on shop directory
#
# Author: Marc Christenfeldt (claude.ai)
# Date: October 2024

usage() {
    echo "Usage: $(basename "$0") [-h|--help] [-d|--delete-snapshot] /path/to/snapshot /path/to/shop/directory"
    echo
    echo "Restores a BTRFS snapshot of a directory which is a BTRFS subvolume."
    echo
    echo "Options:"
    echo "    -h, --help            Show this help message and exit"
    echo "    -d, --delete-snapshot Delete the source snapshot after successful restore"
    echo
    echo "Arguments:"
    echo "    /path/to/snapshot          Full path to the snapshot to restore"
    echo "    /path/to/shop/directory    Full path to target shop directory"
    echo
    echo "The script will:"
    echo "1. Stop running containers (if docker-compose.yaml exists)"
    echo "2. Restore the specified snapshot"
    echo "3. Restart the containers (if docker-compose.yaml exists)"
    echo "4. Optionally delete the source snapshot if -d flag is used"
    echo
    echo "Example:"
    echo "    $(basename "$0") -d /srv/snapshots/os24-sw64__2024-10-23-121033 /srv/sites/os24-sw64"
}


restore_snapshot() {
    local snapshot_path="$1"
    local shop_dir="$2"
    local delete_snapshot="$3"

    # Verify inputs
    if [ ! -d "$snapshot_path" ]; then
        echo "Error: Snapshot path does not exist: $snapshot_path"
        exit 1
    fi
    if [ ! -d "$shop_dir" ]; then
        echo "Error: Shop directory does not exist: $shop_dir"
        exit 1
    fi

    # Handle docker-compose operations if yaml exists
    local docker_compose_exists=false
    if [ -f "${shop_dir}/docker-compose.yaml" ]; then
        docker_compose_exists=true
        echo "Found docker-compose.yaml, will manage containers"
    else
        echo "Warning: No docker-compose.yaml found in ${shop_dir}, skipping container management"
    fi

    # Stop the containers if docker-compose exists
    if [ "$docker_compose_exists" = true ]; then
        echo "Stopping containers..."
        if ! cd "${shop_dir}" || ! docker compose down; then
            echo "Warning: Failed to stop containers, continuing anyway..."
        fi
    fi

    # Move existing subvolume to trash
    local trash_dir="/srv/trash"
    local timestamp=$(date +%Y-%m-%d-%H%M%S)
    local trash_path="${trash_dir}/$(basename "${shop_dir}")__${timestamp}"

    echo "Moving existing directory to trash..."
    if [ -d "${shop_dir}" ]; then
        # Create trash directory if it doesn't exist
        if [ ! -d "$trash_dir" ]; then
            if ! mkdir -p "$trash_dir"; then
                echo "Error: Could not create trash directory: $trash_dir"
                exit 1
            fi
        fi

        # Move the subvolume to trash
        if ! mv "${shop_dir}" "${trash_path}"; then
            echo "Error: Could not move existing directory to trash"
            exit 1
        fi
        echo "Moved existing directory to: ${trash_path}"
    fi

    # Restore the snapshot
    echo "Restoring snapshot from ${snapshot_path} to ${shop_dir}"

    if ! sudo btrfs subvolume snapshot "${snapshot_path}" "${shop_dir}"; then
        echo "Error creating writable snapshot"
        exit 2
    fi

    echo "Snapshot restored successfully"

    # Delete source snapshot if requested
    if [ "$delete_snapshot" = true ]; then
        echo "Deleting source snapshot..."
        if ! sudo btrfs subvolume delete "${snapshot_path}"; then
            echo "Warning: Failed to delete source snapshot: ${snapshot_path}"
        fi
    fi

    # Start the containers if docker-compose exists
    if [ "$docker_compose_exists" = true ]; then
        echo "Starting containers..."
        if ! cd "${shop_dir}" || ! docker compose up -d; then
            echo "Warning: Failed to start containers"
        fi
    fi

    echo "Restore complete"
}


# ==== MAIN ====

# Parse command line options
delete_snapshot=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -d|--delete-snapshot)
            delete_snapshot=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

# Check remaining arguments
if [ "$#" -ne 2 ]; then
    usage
    exit 1
fi

restore_snapshot "$1" "$2" "$delete_snapshot"
