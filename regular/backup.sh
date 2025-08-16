#!/usr/bin/env bash

# Usage: backup.sh <sourcelist> <target> [retention_days]
# <sourcelist>: File containing a list of paths to back up.
# <target>: Directory where backups will be stored.
# [retention_days]: Optional. Number of days to keep backups. Defaults to 1825 (5 years).

set -e

if [ -z "$1" ]; then
    echo "Error: Specify source list file." >&2
    echo "Usage: $0 <sourcelist> <target> [retention_days]" >&2
    exit 1
fi

if [ -z "$2" ]; then
    echo "Error: Specify backups target directory." >&2
    echo "Usage: $0 <sourcelist> <target> [retention_days]" >&2
    exit 1
fi

SOURCES_LIST=$1
BACKUP_TARGET_DIR=$2

# Configure OLD_THAN_DAYS (retention period)
DEFAULT_OLD_THAN_DAYS=$(( 365 * 5 )) # 5 years
if [ -n "$3" ]; then
    if [[ "$3" =~ ^[0-9]+$ ]]; then # Basic check for integer
        OLD_THAN_DAYS=$3
    else
        echo "Warning: Invalid retention period '$3' provided. Using default: ${DEFAULT_OLD_THAN_DAYS} days." >&2
        OLD_THAN_DAYS=$DEFAULT_OLD_THAN_DAYS
    fi
else
    OLD_THAN_DAYS=$DEFAULT_OLD_THAN_DAYS
fi
echo "Backups older than ${OLD_THAN_DAYS} days will be removed from ${BACKUP_TARGET_DIR}."

# Validate BACKUP_TARGET_DIR for safety before find command
if [ -z "${BACKUP_TARGET_DIR}" ]; then
    echo "Critical Error: BACKUP_TARGET_DIR is empty. Aborting." >&2
    exit 1
fi

if [ "${BACKUP_TARGET_DIR}" = "/" ]; then
    echo "Critical Error: BACKUP_TARGET_DIR is set to '/'. This is extremely dangerous. Aborting." >&2
    exit 1
fi

# Check against critical system paths
CRITICAL_PATHS=( "/bin" "/etc" "/usr" "/var" "/opt" "/lib" "/sbin" "/sys" "/proc" "/dev" "/boot" "/home" "/root" "/run" "/srv" )
for critical_path in "${CRITICAL_PATHS[@]}"; do
    # Check if BACKUP_TARGET_DIR is exactly a critical path or a subdirectory of it
    if [[ "${BACKUP_TARGET_DIR}" == "${critical_path}" || "${BACKUP_TARGET_DIR}" == "${critical_path}/"* ]]; then
        echo "Critical Error: BACKUP_TARGET_DIR '${BACKUP_TARGET_DIR}' is within or is a critical system path '${critical_path}'. Aborting." >&2
        exit 1
    fi
done

# Check for minimum path depth (e.g., at least 3 components like /mnt/backups/daily)
# Count slashes, excluding a trailing slash
normalized_target_dir=$(echo "${BACKUP_TARGET_DIR}" | sed 's:/*$::') # Remove trailing slashes
path_depth=$(echo "${normalized_target_dir}" | awk -F'/' '{print NF-1}')
MIN_PATH_DEPTH=2 # e.g., /mnt/backups (2 slashes, 3 components)
if [ "${path_depth}" -lt "${MIN_PATH_DEPTH}" ]; then
    echo "Critical Error: BACKUP_TARGET_DIR '${BACKUP_TARGET_DIR}' is too shallow (depth ${path_depth}, requires at least ${MIN_PATH_DEPTH}). Aborting." >&2
    exit 1
fi

echo "Attempting to remove old backups older than ${OLD_THAN_DAYS} days from ${BACKUP_TARGET_DIR}"
# The actual find command will only run if the above checks pass due to set -e
/bin/find "${BACKUP_TARGET_DIR}" -type d -mtime "+${OLD_THAN_DAYS}" -exec rm -rf {} \;
echo "Old backups removal process completed."


# Validate SOURCES_LIST before tar command
if [ ! -f "${SOURCES_LIST}" ]; then
    echo "Error: Sources list file '${SOURCES_LIST}' is not a valid file or does not exist." >&2
    exit 1
fi

mkdir -p "${BACKUP_TARGET_DIR}/$(date +%Y)"
target_file="${BACKUP_TARGET_DIR}/$(date +%Y)/logs-$(date +%Y.%m.%d.%s).tar.gz"
echo "Backing up sources from list '${SOURCES_LIST}' to '${target_file}'"
tar -T "${SOURCES_LIST}" -czf "${target_file}"
echo "Backup completed successfully to ${target_file}"

exit 0
