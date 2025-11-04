# Automated Backup System

## Overview
This Bash script automatically creates and verifies compressed backups, manages retention (daily, weekly, monthly), and provides restore, listing, and dry-run features.

## Features
- Configurable backup location and exclude patterns
- MD5 checksum verification
- Log file tracking all operations
- Retention policy (delete old backups)
- Dry-run simulation mode
- Prevents multiple runs via lock file
- Optional restore and listing modes

## Usage
### Create a Backup
```bash
./backup.sh /path/to/folder
