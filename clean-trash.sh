#!/usr/bin/env bash
#
# Description:
#   Deletes all BTRFS subvolumes found in the /srv/trash directory
#
# Usage:
#   ./clean-trash.sh [-h|--help]
#
# Options:
#   -h, --help            Show help message and exit
#
# Requirements:
#   - BTRFS filesystem
#   - sudo privileges for btrfs commands
#
# Author: Marc Christenfeldt (claude.ai)
# Date: October 2024

usage() {
    echo "Usage: $(basename "$0") [-h|--help]"
    echo
    echo "Deletes all BTRFS subvolumes found in the /srv/trash directory"
    echo
    echo "Options:"
    echo "    -h, --help    Show this help message and exit"
}

clean_trash() {
    local trash_dir="/srv/trash"

    # Check if trash directory exists
    if [ ! -d "$trash_dir" ]; then
        echo "Error: Trash directory does not exist: $trash_dir"
        exit 1
    fi

    # Get list of subvolumes in trash
    echo "Scanning for subvolumes in $trash_dir..."
    local subvolumes
    subvolumes=$(find "$trash_dir" -maxdepth 1 -type d -not -path "$trash_dir")

    if [ -z "$subvolumes" ]; then
        echo "No subvolumes found in $trash_dir"
        exit 0
    fi

    # Show subvolumes to be deleted and ask for confirmation
    echo "The following subvolumes will be deleted:"
    while IFS= read -r subvol; do
        echo "  $subvol"
    done <<< "$subvolumes"
    
    read -p "Do you want to proceed with deletion? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled"
        exit 0
    fi

    # Delete each subvolume
    echo "Deleting subvolumes..."
    while IFS= read -r subvol; do
        if [ -d "$subvol" ]; then
            echo "Deleting: $subvol"
            if ! sudo btrfs subvolume delete "$subvol" 2>/dev/null; then
                echo "Warning: Failed to delete subvolume: $subvol"
            fi
        fi
    done <<< "$subvolumes"

    echo "Trash cleanup complete"
}

# ==== MAIN ====

# Parse command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

clean_trash
