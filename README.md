# Overview

This document provides a comprehensive guide to the suite of backup scripts contained within this repository. These scripts are designed to offer flexible and robust solutions for both incremental and regular (full) data backup strategies, catering to various data protection needs.

# Scripts

The following sections describe the individual scripts available, categorized by their backup methodology (incremental or regular). Each script's purpose and basic operation are explained.

## Incremental Backups

This group of scripts is dedicated to performing incremental backups. This backup type is storage-efficient, as it only captures data that has changed since the last backup run, leading to faster backup operations and reduced disk space consumption.

### `incremental/backup_inc.sh`

The `incremental/backup_inc.sh` script is the core utility for creating incremental backups. It functions as an intelligent wrapper around the `gtar` (GNU tar) command.

#### Command-Line Options

The script accepts the following command-line options:

*   `-s SOURCE_PATH`: (Mandatory) Specifies the path to the directory or data to be archived (e.g., `/var/log`).
*   `-t TARGET_PATH`: (Mandatory) Defines the path to the directory where backup archives and associated files will be stored (e.g., `/mnt/backups`).
*   `-n BASE_NAME`: (Mandatory) Sets the base name for archive files (e.g., `my_app_backup`). This name is used to prefix generated files.
*   `-i ITERATIONS`: (Optional) The number of incremental backup cycles to perform before creating a new full backup. Default: `15`.
*   `-k KEEP_SEQUENCES`: (Optional) The number of additional full backup sequences to retain, besides the current active sequence. Default: `1`.
*   `-x EXCLUDE_LIST_FILE`: (Optional) Specifies the path to a file containing a list of file patterns to exclude from the backup (e.g., `/etc/backup_exclude.list`). Each pattern should be on a new line.
*   `-h`: (Optional) Displays a help message detailing usage and options.

#### Usage Example

Here's an example of how to run the `incremental/backup_inc.sh` script:

```bash
./incremental/backup_inc.sh -s /var/www/my_application -t /mnt/backups/my_app -n app_backup -i 10 -k 2 -x /etc/backup_excludes/my_app_exclude.list
```
This command would back up `/var/www/my_application` to `/mnt/backups/my_app`, naming archives like `app_backup-1.tar.gz`. It will perform a full backup every 10 increments and keep 2 older full sequences. Files matching patterns in `/etc/backup_excludes/my_app_exclude.list` will be excluded.

#### Key Files Created

The `incremental/backup_inc.sh` script creates and manages several important files within the specified `TARGET_PATH`. These include:

*   **Snapshot File (`${TARGET_PATH}/${BASE_NAME}.snap`)**:
    *   Example: `/mnt/backups/my_app/app_backup.snap`
    *   This is the GNU tar snapshot file, essential for `gtar` to track file changes since the last backup, enabling true incremental backups.
    *   If this file is missing (or is removed by the script), `incremental/backup_inc.sh` will perform a full backup.
    *   It is automatically removed according to the `ITERATIONS` setting to initiate a new full backup cycle.

*   **Increment File (`${TARGET_PATH}/${BASE_NAME}.inc`)**:
    *   Example: `/mnt/backups/my_app/app_backup.inc`
    *   A small text file storing the current increment number for the active backup sequence. This number is used to name the next archive and to determine when a new full backup is due based on `ITERATIONS`.

*   **Log File (`${TARGET_PATH}/${BASE_NAME}_backup.log`)**:
    *   Example: `/mnt/backups/my_app/app_backup_backup.log`
    *   A detailed log where the script records its operations, including start/end times, backup types (full/incremental), errors, and `gtar` messages (from stderr).

*   **Lock File (`${TARGET_PATH}/${BASE_NAME}.lock`)**:
    *   Example: `/mnt/backups/my_app/app_backup.lock`
    *   Contains the Process ID (PID) of the running `incremental/backup_inc.sh` instance. This prevents multiple instances for the same backup set from running concurrently, which could corrupt backup data.

*   **Archive Files (`${TARGET_PATH}/${BASE_NAME}-${increment_number}.tar.gz`)**:
    *   Example: `/mnt/backups/my_app/app_backup-1.tar.gz`, `/mnt/backups/my_app/app_backup-2.tar.gz`, etc.
    *   These are the compressed backup archives created by `gtar`. The `increment_number` in the filename corresponds to the value in the `INCREMENT_FILE`.

Its behavior is primarily controlled by two parameters that manage backup rotation and the retention of older backup sets:

*   **`ITERATIONS`** (default: `15`): This integer value specifies the number of incremental backup cycles that occur before a new full backup is automatically created.
*   **`KEEP_SEQUENCES`** (default: `1`): This parameter determines how many complete backup *sequences* (defined as a full backup along with all its associated incremental backups) are preserved, in addition to the currently active backup sequence.

**Example of Backup Rotation Logic:**

Consider `ITERATIONS=5` and `KEEP_SEQUENCES=1`. The numbers below represent sequential backup increment indices:

    1-full  2  3  4  5   (This is Sequence 1: Full backup #1 and its increments)
    6-full  7  8  9 10   (Sequence 2 is created. Sequence 1 is still kept.)
   11-full 12 13 14 15   (Sequence 3 is created. Now, Sequence 1 (backups 1-5) is removed due to the KEEP_SEQUENCES setting.)
   16-full 17 18 19 20   (Sequence 4 is created. Sequence 2 (backups 6-10) is removed.)
   21-full 22 23 24 25   (Sequence 5 is created. Sequence 3 (backups 11-15) is removed.)
   26-full 27 ...         (Sequence 6 begins. Sequence 4 (backups 16-20) is removed.)

    --------------------------------------------------------------------------------------> Time progression

This configuration ensures that `ITERATIONS * KEEP_SEQUENCES` older backups are always available, plus all backups from the most recent, active sequence.

### `incremental/backup_users.sh` and `incremental/extract_user.sh`

This section details two utility scripts: `incremental/backup_users.sh` for automating backups of multiple user directories, and `incremental/extract_user.sh` for restoring data from these backups.

#### `incremental/backup_users.sh`

**Purpose:**
The `incremental/backup_users.sh` script serves as a wrapper around `incremental/backup_inc.sh`. Its primary function is to iterate through all user directories within a specified parent directory (e.g., `/home`) and execute `incremental/backup_inc.sh` for each user, creating individual incremental backups for them. This is particularly useful for system administrators managing multiple user accounts on a server.

**Command-Line Arguments:**

*   `SOURCE_PARENT_DIR`: (Mandatory) The first argument to the script. This is the parent directory that contains the individual user home directories to be backed up (e.g., `/home`). The script will look for subdirectories within this path.
*   `MAIN_BACKUP_DEST_DIR`: (Mandatory) The second argument. This specifies the main directory where backups for all users will be stored (e.g., `/backups/incremental`). The script will create user-specific subdirectories within this location (e.g., `/backups/incremental/user1`, `/backups/incremental/user2`).

**Usage Example:**

```bash
./incremental/backup_users.sh /home /var/local_backups/incremental_users
```
This command will:
1.  Scan the `/home` directory for user subdirectories (e.g., `/home/user1`, `/home/user2`).
2.  For each user directory found, it will invoke `incremental/backup_inc.sh`.
    *   The source for `incremental/backup_inc.sh` will be the user's home directory (e.g., `/home/user1`).
    *   The target for `incremental/backup_inc.sh` will be a user-specific subdirectory in the main backup destination (e.g., `/var/local_backups/incremental_users/user1`).
    *   The base name for `incremental/backup_inc.sh` will be the username (e.g., `user1`).

**Exclusion List:**
The `incremental/backup_users.sh` script utilizes a global exclusion list named `exclude.list`, which must be located in the same directory as the `incremental/backup_users.sh` script itself. The patterns in this `exclude.list` are passed to `incremental/backup_inc.sh` for every user backup, ensuring consistent exclusions across all users.

#### `incremental/extract_user.sh`

**Purpose:**
The `incremental/extract_user.sh` script is used to restore files and directories from a specific user's incremental backup sequence created by `incremental/backup_inc.sh` (potentially via `incremental/backup_users.sh`). It reconstructs the user's data up to a specified backup increment.

**Internal Script Configuration (Mandatory):**

Before using `extract_user.sh` for the first time, you **must** open the script in a text editor and configure the following variables, typically found near the top of the file:

*   **`BACKUPS_ROOT`**:
    *   **Purpose**: This variable must be set to the main directory where backups for all users are stored (e.g., the `MAIN_BACKUP_DEST_DIR` used with `incremental/backup_users.sh`).
    *   **Example**: `BACKUPS_ROOT=/var/local_backups/incremental_users`

*   **`INCREMENT_COUNT`**:
    *   **Purpose**: This variable specifies the number of increments per full backup cycle. **Crucially, this value MUST match the `ITERATIONS` parameter that was used with `incremental/backup_inc.sh` (or `incremental/backup_users.sh`) when the backups were originally created.** If these values do not match, the script may attempt to restore from an incorrect full backup, leading to incomplete or incorrect data restoration.
    *   **Example**: If backups were made with `incremental/backup_inc.sh -i 10 ...`, then `INCREMENT_COUNT` in `incremental/extract_user.sh` should be set to `15` (if `ITERATIONS` was defaulted to 15 for `incremental/backup_inc.sh`) or `10` (if `-i 10` was explicitly used). The script's default is `INCREMENT_COUNT=15`.

**Command-Line Options:**

*   `-n USER_NAME`: (Mandatory) The username of the user whose backups are to be extracted. This corresponds to the subdirectory name within `BACKUPS_ROOT` and the base name used for the backup files (e.g., `jsmith`).
*   `-t TARGET_PATH`: (Mandatory) The path to an empty or non-existent directory where the extracted files will be restored (e.g., `/tmp/jsmith_restore`). The script will create this directory if it doesn't exist.
*   `-c INCREMENT_TO_RESTORE`: (Mandatory) The specific increment number up to which the data should be restored (e.g., `5`). This means the script will restore the relevant full backup and all subsequent incremental backups up to and including this specified increment number.

**Step-by-Step Guide to Extracting User Backups:**

1.  **Internal Configuration (One-Time Setup):**
    *   Open the `incremental/extract_user.sh` script in a text editor.
    *   Verify and set the `BACKUPS_ROOT` variable to point to your main backup storage location (e.g., `/var/local_backups/incremental_users`).
    *   Verify and set the `INCREMENT_COUNT` variable to match the `ITERATIONS` value used during backup creation (default is 15).
    *   Save the changes to `extract_user.sh`.

2.  **Identify User and Target Directory:**
    *   Determine the `USER_NAME` of the user whose data you need to restore (e.g., `jsmith`).
    *   Choose a `TARGET_PATH` for the restored files (e.g., `/tmp/jsmith_restored_files`). Ensure this directory is empty or can be safely created.

3.  **List Available Backup Increments:**
    *   To view the available backup points for the user, list the contents of their backup directory. This directory is typically `BACKUPS_ROOT/USER_NAME/`.
    *   Example for user `jsmith`, assuming `BACKUPS_ROOT` is `/var/local_backups/incremental_users`:
      ```bash
      ls -lh /var/local_backups/incremental_users/jsmith/
      ```
    *   This command will display files such as:
      ```
      jsmith.inc              (Tracks the latest increment number)
      jsmith.snap             (The snapshot file for current incrementals)
      jsmith-1.tar.gz         (Initial full backup or first in a sequence)
      jsmith-2.tar.gz         (First incremental backup after jsmith-1)
      jsmith-3.tar.gz         (Second incremental backup)
      ...
      jsmith-N.tar.gz         (The Nth backup file in the sequence)
      jsmith_backup.log       (Log file for this user's backups)
      ```
    *   Examine the timestamps and increment numbers (`-1`, `-2`, etc.) to decide which backup point you need. For example, if `jsmith-5.tar.gz` represents the desired state, then `5` is your `INCREMENT_TO_RESTORE`.

4.  **Run the Extraction Script:**
    *   Execute `extract_user.sh` with the determined parameters.
    *   Example:
      ```bash
      ./incremental/extract_user.sh -n jsmith -t /tmp/jsmith_restored_files -c 5
      ```

5.  **Access Restored Files:**
    *   Once the script completes, the restored files and directories for `jsmith`, up to the state of increment `5`, will be available in `/tmp/jsmith_restored_files`. The script will also attempt to `chown` the restored files to the original user.

This provides a comprehensive guide to using `backup_users.sh` for creating backups and `extract_user.sh` for restoring them, emphasizing necessary configurations and clear steps.

## Regular Backups

This group of scripts is intended for performing regular, non-incremental (typically full) backups of specified data sets.

### `regular/backup.sh`

The `regular/backup.sh` script provides a straightforward method for creating regular, full (non-incremental) backups. It archives specified files and directories into a compressed `tar.gz` file. A key feature of this script is its ability to automatically manage backup retention by removing old backup directories from the target location based on a defined period.

#### Command-Line Arguments

The script requires the following command-line arguments:

1.  **`SOURCES_LIST`** (Mandatory, first argument)
    *   **Description**: Path to a plain text file. Each line in this file must be an absolute path to a file or directory that needs to be included in the backup.
    *   **Example**: `/etc/backup_config/my_app_sources.list`

2.  **`BACKUP_TARGET_DIR`** (Mandatory, second argument)
    *   **Description**: The primary directory where backup archives will be stored. The script will automatically create a subdirectory named after the current year (e.g., `2023`) within this directory to organize backups.
    *   **Example**: `/mnt/server_backups/full_archives`
    *   **Safety Checks**: This script implements several safety checks for the `BACKUP_TARGET_DIR` to prevent accidental data loss:
        *   It cannot be the root directory (`/`).
        *   It cannot be or be within critical system paths (e.g., `/etc`, `/usr`, `/var`).
        *   It must have a reasonable path depth (not too shallow, e.g., requires at least 3 path components like `/mnt/backups/data`).

3.  **`RETENTION_DAYS`** (Optional, third argument)
    *   **Description**: The number of days for which to keep backups. The script searches for directories (`-type d`) directly within `BACKUP_TARGET_DIR` and removes those whose modification time (`-mtime`) is older than the specified `RETENTION_DAYS`.
    *   **Default**: `1825` days (approximately 5 years) if not specified.
    *   **Example**: `365` (to keep backups for one year).

#### `SOURCES_LIST` File Format

The `SOURCES_LIST` file must be a plain text file. Each line in this file should specify a single absolute path to a file or directory that is to be included in the backup.

**Example `SOURCES_LIST` content:**
```
/etc/my_application/config.xml
/var/log/my_application/
/opt/important_data_service/data_files/
```

#### Usage Example

```bash
./regular/backup.sh /root/config/production_sources.list /srv/backups/production_server 365
```
**Explanation of the example:**
*   This command instructs the `regular/backup.sh` script to read the list of paths from `/root/config/production_sources.list`.
*   All files and directories listed therein will be archived into a single compressed `.tar.gz` file.
*   The resulting archive will be stored in a subdirectory named after the current year, located under `/srv/backups/production_server` (e.g., `/srv/backups/production_server/2023/`).
*   The script will also remove any directories found directly under `/srv/backups/production_server` (this does not typically affect the yearly subdirectories unless they are very old and directly named in a way that `find` matches) that are older than 365 days.

#### Archive Naming and Location

Backup archives are created with a name incorporating the current date and a Unix timestamp, and are placed within a year-specific subdirectory of the `BACKUP_TARGET_DIR`.

*   **Location**: `BACKUP_TARGET_DIR/YYYY/` (where `YYYY` is the current year, e.g., `2023`).
*   **Naming Scheme**: `logs-YYYY.MM.DD.timestamp.tar.gz` (e.g., `logs-2023.10.27.1698412800.tar.gz`, where `1698412800` is a Unix timestamp).

This structure helps organize backups chronologically.

# General Usage Notes

This section provides important general information regarding the usage of these backup scripts, covering dependencies, permissions, best practices, and more.

*   **Script Dependencies:**
    *   The `incremental/backup_inc.sh` script specifically requires `gtar` (GNU tar) to be installed and accessible in the system's `PATH`. This is because it relies on `gtar`'s `--listed-incremental` feature.
    *   Other scripts in this suite generally rely on standard Unix/Linux shell utilities such as `tar` (which may or may not be GNU tar, depending on the system), `find`, `mkdir`, `rm`, `ps`, `awk`, `sed`, etc. These utilities are typically available on most Linux and Unix-like systems.

*   **Permissions:**
    *   These backup scripts generally require sufficient privileges to perform their operations effectively. This includes the ability to:
        *   Read all source files and directories intended for backup. This might involve accessing restricted user directories or system files.
        *   Write to the specified target backup directories. This includes creating new subdirectories (e.g., year-specific folders, user-specific folders) and writing backup archives and metadata files (logs, snapshot files, increment files, lock files).
        *   Execute `gtar` or `tar` commands with appropriate options.
        *   Remove old backup files or directories, which is a core part of the retention policy in `regular/backup.sh` and the rotation mechanism in `incremental/backup_inc.sh`.
    *   Due to these requirements, it is common to run these scripts as the `root` user or via `sudo`. If doing so, ensure you fully understand the security implications and have configured the scripts with correct, safe target paths to prevent accidental data loss.

*   **Path Specificity:**
    *   To avoid ambiguity and ensure scripts behave predictably regardless of the directory from which they are executed, it is **strongly recommended to use absolute paths** for all source and target directory arguments provided to the scripts.
    *   Similarly, paths listed within the `SOURCES_LIST` file for `regular/backup.sh` should also be absolute.

*   **Exclusion Lists:**
    *   **`incremental/backup_users.sh`**: This script utilizes a global exclusion list named `exclude.list`, which must be located in the same directory as the `incremental/backup_users.sh` script itself. The patterns defined in this file are applied to all user backups performed by this script.
    *   **`incremental/backup_inc.sh`**: This script supports more granular exclusion rules through its `-x EXCLUDE_LIST_FILE` command-line option. This allows different exclusion criteria to be applied to different backup tasks.
    *   **Format**: Exclusion patterns specified in these files should follow the format supported by GNU tar's `--exclude-from` option (typically, one pattern per line; standard shell globbing patterns like `*.log` or `temp/` are usually supported).

*   **Testing and Validation:**
    *   **Crucial First Step**: Before relying on these scripts for protecting critical data, it is **highly recommended** to conduct thorough testing in a safe, non-production environment.
    *   **Verification**: Ensure that backups are created as expected and, most importantly, that they can be successfully restored. Perform test restorations to confirm data integrity.
    *   **Log Review**: Carefully examine the log files generated by the scripts for any errors, warnings, or unexpected messages.
    *   **Understand Logic**: Familiarize yourself with the backup rotation (for `incremental/backup_inc.sh`) and retention logic (for `regular/backup.sh`) to confirm that it aligns with your data retention policies and storage capacity.

*   **Customization:**
    *   **Review Before Use**: Always review the script contents before deploying them in a production environment.
    *   **Internal Configuration**: Pay special attention to scripts like `incremental/extract_user.sh`, which explicitly require internal variables (e.g., `BACKUPS_ROOT`, `INCREMENT_COUNT`) to be configured before use.
    *   **Adaptation**: You may need to adjust paths, default parameters, or specific commands within the scripts if your system environment has unique requirements not directly addressed by the provided command-line arguments.
