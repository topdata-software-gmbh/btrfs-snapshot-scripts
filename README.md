# btrfs-snapshot-scripts

A collection of shell scripts for managing BTRFS snapshots of Docker-based applications.

## Requirements

- BTRFS filesystem mounted on `/srv`
- Docker and docker-compose installed
- sudo privileges for BTRFS operations
- Write permissions on relevant directories

## Scripts

### make-snapshot.sh

Creates a read-only BTRFS snapshot of a directory. Snapshots are stored in `/srv/snapshots` with timestamp-based naming.

```bash
./make-snapshot.sh /path/to/shop/directory [snapshot-name]
```

Example:
```bash
# Basic snapshot
./make-snapshot.sh /srv/sites/os24-sw64

# Snapshot with custom name
./make-snapshot.sh /srv/sites/os24-sw64 "before backup to sw65"
```

### restore-snapshot.sh

Restores a BTRFS snapshot to a target directory. Handles Docker container management automatically.

```bash
./restore-snapshot.sh [-d] /path/to/snapshot /path/to/shop/directory
```

Options:
- `-d, --delete-snapshot`: Delete the source snapshot after successful restore

Example:
```bash
./restore-snapshot.sh -d /srv/snapshots/os24-sw64__2024-10-23-121033 /srv/sites/os24-sw64
```

### clean-trash.sh

Deletes all BTRFS subvolumes from the `/srv/trash` directory. Includes interactive confirmation.

```bash
./clean-trash.sh
```

## Workflow Example

1. Create a snapshot before making changes:
   ```bash
   ./make-snapshot.sh /srv/sites/shop1 "before-update"
   ```

2. If something goes wrong, restore from snapshot:
   ```bash
   ./restore-snapshot.sh /srv/snapshots/shop1__2024-12-19-143022__before-update /srv/sites/shop1
   ```

3. Clean up old backups in trash:
   ```bash
   ./clean-trash.sh
   ```

## License

MIT License - See LICENSE file for details.
