# Automated Backup Script

## A. Project Overview

### What Does This Script Do?

This Bash script automatically creates **compressed backups** (`.tar.gz`) of specified folders.  
It also generates checksum files to ensure data integrity, manages retention (daily, weekly, monthly), and includes options to restore or list backups — all from a single command.

### Why Is It Useful?

Manual backups are time-consuming and error-prone. This script simplifies the process by:

* Running automatically with one command  
* Verifying backup integrity using checksums  
* Deleting old backups automatically (rotation)  
* Preventing multiple simultaneous runs via a lock file  
* Supporting **dry-run mode** for safe testing  

---

## B. How to Use It

### Installation Steps

1. Clone or copy the script to your local machine.  
2. Make it executable:
   ```bash
   chmod +x backup.sh
Create a configuration file named backup.config in the same directory:

bash
Copy code
BACKUP_DESTINATION="/home/user/backups"
EXCLUDE_PATTERNS="*.tmp,*.log"
DAILY_KEEP=3
WEEKLY_KEEP=2
MONTHLY_KEEP=2
CHECKSUM_CMD="sha256sum"
Basic Usage Examples
Create a new backup

bash
Copy code
./backup.sh --backup /home/user/data
Restore a backup

bash
Copy code
./backup.sh --restore /home/user/backups/backup-2025-11-05-1130.tar.gz /tmp/restore
List all backups

bash
Copy code
./backup.sh --list
Dry-run mode (no actual backup created)

bash
Copy code
./backup.sh --dry-run --backup /home/user/data
Command Options
Command	Description
--backup <src_dir>	Create a new compressed backup
--restore <archive> <target_dir>	Restore files from a backup archive
--list	List available backups
--dry-run	Simulate the backup process without performing actions

C. How It Works
Backup Rotation Logic
The script lists all available backups chronologically.

It retains only the most recent:

DAILY_KEEP backups (daily)

WEEKLY_KEEP backups (weekly)

MONTHLY_KEEP backups (monthly)

Older backups are deleted automatically (unless --dry-run is used).

Checksum Verification
After each backup, a checksum file is created and verified:

bash
Copy code
sha256sum backup.tar.gz > backup.tar.gz.md5
If the checksum does not match, the script logs an error and exits safely.

Folder Structure Example
Copy code
/home/user/backups/
├── backup-2025-11-01-0900.tar.gz
├── backup-2025-11-01-0900.tar.gz.md5
├── backup-2025-11-02-0900.tar.gz
├── backup-2025-11-02-0900.tar.gz.md5
└── backup.log
D. Design Decisions
Why This Approach?
Bash is available by default on most Linux systems — no dependencies required.

tar and sha256sum are efficient and widely supported.

The configuration file allows easy customization without modifying the script.

Challenges Solved
Preventing parallel backups → Implemented a lock file (/tmp/backup.lock).

Error handling → Used set -euo pipefail and structured logging.

Backup rotation → Designed simple retention logic for daily/weekly/monthly cleanup.

E. Testing
Testing Process
Create a sample folder:

bash
Copy code
mkdir test_data && echo "hello" > test_data/file1.txt
Run the following tests:

bash
Copy code
./backup.sh --backup test_data
./backup.sh --list
./backup.sh --dry-run --backup test_data
./backup.sh --restore /home/user/backups/backup-2025-11-05-1130.tar.gz /tmp/restore
Example Output
Creating Backup

yaml
Copy code
[2025-11-05 11:30:00] INFO: Starting backup of test_data -> backup-2025-11-05-1130.tar.gz
[2025-11-05 11:30:10] SUCCESS: Backup created: backup-2025-11-05-1130.tar.gz
[2025-11-05 11:30:11] INFO: Checksum verified successfully
[2025-11-05 11:30:12] INFO: Archive extraction test succeeded
Dry-Run Example

yaml
Copy code
[2025-11-05 11:32:00] DRY: Would run: tar -czf backup.tar.gz -C /test_data
Error Example (invalid folder)

javascript
Copy code
Error: Source folder not found: /fake/folder
Automatic Cleanup Example

yaml
Copy code
[2025-11-05 11:33:00] INFO: Deleted old backup backup-2025-10-15-0900.tar.gz
F. Known Limitations
Currently supports only one source folder per run.

Rotation depends on file naming timestamps, not creation time.

No built-in support for remote uploads (e.g., AWS S3, SCP).

Does not send success/failure notifications yet.

Future Enhancements
Add cloud/remote backup support (AWS, Google Drive, etc.)

Integrate with cron or systemd timers for scheduled runs

Add colorized or formatted log output for better readability

Optional email or Slack notifications for job completion

