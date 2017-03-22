#!/usr/bin/env bash

# Usage: backup.sh <sourcelist> <target>

set -e

if [ -z $1 ]; then
    echo "Specify  source list"
    exit 1
fi

if [ -z $2 ]; then
    echo "Specify  backups target"
    exit 1
fi

SOURCES_LIST=$1
BACKUP_TARGET_DIR=$2
OLD_THAN_DAYS=$(( 365 * 5 ))

echo "Remove old backups"
/bin/find ${BACKUP_TARGET_DIR} -type d -mtime +${OLD_THAN_DAYS} -exec rm -rf {} \;

mkdir -p ${BACKUP_TARGET_DIR}/$(date +%Y)
target_file=${BACKUP_TARGET_DIR}/$(date +%Y)/logs-$(date +%Y.%m.%d.%s).tar.gz
echo "Backing up list" ${SOURCES_LIST} "to" ${target_file}
tar -T ${SOURCES_LIST} -czf ${target_file}

exit 0
