#!/bin/bash

# Script to make read-only btrfs snapshots writeable and then delete them
# Targets the oldest snapshots first

# Configuration - adjust these variables as needed
SNAPSHOT_PATH="/srv/snapshots"
NUMBER_TO_DELETE=5  # Number of oldest snapshots to delete
DRY_RUN=false  # Set to false to actually perform deletions

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== BTRFS Snapshot Cleanup Script ===${NC}"
echo -e "${YELLOW}This script will identify the oldest btrfs snapshots, make them writeable, and delete them${NC}"

# Get snapshot list ordered by ID (roughly chronological)
echo -e "\n${BLUE}Listing all snapshots, sorted by ID (oldest first):${NC}"
SNAPSHOTS=$(sudo btrfs subvolume list /srv | grep "snapshots/" | sort -k2 -n)
echo "$SNAPSHOTS"

# Count total snapshots
TOTAL_SNAPSHOTS=$(echo "$SNAPSHOTS" | wc -l)
echo -e "\n${BLUE}Total snapshots found: ${TOTAL_SNAPSHOTS}${NC}"

# Select the oldest N snapshots
echo -e "\n${BLUE}Selecting the ${NUMBER_TO_DELETE} oldest snapshots:${NC}"
OLDEST_SNAPSHOTS=$(echo "$SNAPSHOTS" | head -n $NUMBER_TO_DELETE)
echo "$OLDEST_SNAPSHOTS"

# Function to extract full path from snapshot line
get_snapshot_path() {
    local line="$1"
    local rel_path=$(echo "$line" | awk '{print $9}')
    echo "/srv/$rel_path"
}

# Confirm with user
echo -e "\n${YELLOW}The following snapshots will be made writeable and then deleted:${NC}"
while IFS= read -r line; do
    FULL_PATH=$(get_snapshot_path "$line")
    echo -e "${RED}$FULL_PATH${NC}"
done <<< "$OLDEST_SNAPSHOTS"

echo -e "\n${YELLOW}Are you sure you want to make these snapshots writeable and delete them?${NC}"
echo -e "${RED}WARNING: This operation cannot be undone!${NC}"
read -p "Type 'yes' to confirm: " CONFIRMATION

if [ "$CONFIRMATION" != "yes" ]; then
    echo -e "\n${YELLOW}Operation cancelled.${NC}"
    exit 0
fi

# Process snapshots
echo -e "\n${BLUE}Processing snapshots...${NC}"

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}DRY RUN MODE: No changes will be made.${NC}"
    echo -e "${YELLOW}To perform actual deletions, set DRY_RUN=false in the script.${NC}"
fi

while IFS= read -r line; do
    FULL_PATH=$(get_snapshot_path "$line")
    
    # Extract snapshot ID for reference
    SNAP_ID=$(echo "$line" | awk '{print $2}')
    
    echo -e "\n${BLUE}Processing snapshot ID ${SNAP_ID}: ${FULL_PATH}${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo "  Would make the snapshot writeable with: sudo btrfs property set ${FULL_PATH} ro false"
        echo "  Would delete the snapshot with: sudo btrfs subvolume delete ${FULL_PATH}"
    else
        echo "  Making snapshot writeable..."
        sudo btrfs property set "${FULL_PATH}" ro false
        
        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}Successfully made snapshot writeable${NC}"
            
            echo "  Deleting snapshot..."
            sudo btrfs subvolume delete "${FULL_PATH}"
            
            if [ $? -eq 0 ]; then
                echo -e "  ${GREEN}Successfully deleted snapshot${NC}"
            else
                echo -e "  ${RED}Failed to delete snapshot${NC}"
            fi
        else
            echo -e "  ${RED}Failed to make snapshot writeable${NC}"
        fi
    fi
done <<< "$OLDEST_SNAPSHOTS"

echo -e "\n${BLUE}Operation completed.${NC}"

if [ "$DRY_RUN" = true ]; then
    echo -e "\n${YELLOW}This was a dry run. No changes were made.${NC}"
    echo -e "${YELLOW}To perform actual deletions, set DRY_RUN=false in the script.${NC}"
fi

