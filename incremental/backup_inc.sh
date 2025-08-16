#!/bin/bash

set -e

# Copyright (C) 2015 JustHost.ru, Dmitry Shilyaev
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#
# Description:
# This script is a wrapper for the gtar. Used to create incremental backups.
#

ITERATIONS=15
KEEP_SEQUENCES=1
SOURCE_PATH=
TARGET_PATH=
BASE_NAME=
LOG_FILE=
EXCLUDE_FILE=

function usage {
    echo "Create incremental backup. Full/incremental iterations are tracked automagically."
    echo ""
    echo "backup_inc.sh -t TARGET_ARCHIVE_PATH -n BASE_NAME -s PATH_WITH_DATA_TO_ARCHIVE [ -i ITERATIONS ] [ -k KEEP_SEQUENCES ] [ -x EXCLUDE_LIST_FILE ]"
    echo "  -t: path to store archived data"
    echo "  -n: archive base name. BASE_NAME-1.tar.gz, BASE_NAME-2.tar.gz, ..."
    echo "  -s: data to archive (source path)"
    echo "  -i: number of iterations until new full backup. Default: 15"
    echo "  -k: keep sequences. How many additional incremental backup sequences to keep. Default: 1 (current + previous)"
    echo "  -x: path to a file containing a list of patterns to exclude"
    echo "  -h: display this help message"
}

while getopts "i:k:t:n:x:s:h" OPTION
do
    case ${OPTION} in
    h)
        usage
        exit 1
        ;;
    i)
        ITERATIONS=$OPTARG
        ;;
    k)
        KEEP_SEQUENCES=$OPTARG
        ;;
    t)
        TARGET_PATH=$OPTARG
        ;;
    n)
        BASE_NAME=$OPTARG
        ;;
    x)
        EXCLUDE_FILE=$OPTARG
        ;;
    s)
        SOURCE_PATH=$OPTARG
        ;;
    ?)
        usage
        exit 1
        ;;
    esac
done

if [ -z "${SOURCE_PATH}" ]
then
    echo "Error: Source path (-s) must be provided."
    usage
    exit 1
fi

if [ ! -d "${SOURCE_PATH}" ]
then
    echo "Error: Source path \"${SOURCE_PATH}\" must exist and be a directory!"
    exit 1
fi

if [ -z "${TARGET_PATH}" ] 
then
    echo "Error: Target path (-t) must be provided."
    usage
    exit 1
fi

if [ ! -d "${TARGET_PATH}" ]
then
    echo "Error: Target path \"${TARGET_PATH}\" must exist and be a directory!"
    exit 1
fi

if [ -z "${BASE_NAME}" ]
then
    echo "Error: Base name (-n) must be provided."
    usage
    exit 1
fi


SNAPSHOT_FILE=${TARGET_PATH}/${BASE_NAME}.snap
INCREMENT_FILE=${TARGET_PATH}/${BASE_NAME}.inc
LOG_FILE=${TARGET_PATH}/${BASE_NAME}_backup.log
LOCK_FILE=${TARGET_PATH}/${BASE_NAME}.lock

echo "*** " $(date +"%d.%m.%Y %H:%M:%S") "BACKUP STARTED ${BASE_NAME} ***"
echo "*** " $(date +"%d.%m.%Y %H:%M:%S") "BACKUP STARTED ${BASE_NAME} ***" >> ${LOG_FILE} # Added to log file
echo "Using data:"
echo "    iterations: ${ITERATIONS}"
echo "    keep seq: ${KEEP_SEQUENCES}"
echo "    source: ${SOURCE_PATH}"
echo "    target: ${TARGET_PATH}"
echo "    base name: ${BASE_NAME}"
echo "    snapshot: ${SNAPSHOT_FILE}"
echo "    exclude: ${EXCLUDE_FILE}"

function logBackup {
    if [[ ! -f ${LOG_FILE} ]]
    then
        echo "*** JustHost.ru Backups log ***" > ${LOG_FILE}
        echo "date - iterations - keep sequences - source - target - base name - increment - snapshot" >> ${LOG_FILE}
    fi

    LOGSNAPSHOT=
    if [[ -f ${SNAPSHOT_FILE} ]]
    then
        LOGSNAPSHOT=${SNAPSHOT_FILE}
    else
        LOGSNAPSHOT='last incremental'
    fi

    increment=
    if [[ -f ${INCREMENT_FILE} ]]
    then
        increment=`cat ${INCREMENT_FILE}`
    fi

    echo $(date +"%d.%m.%Y %H:%M:%S") "-" ${ITERATIONS} "-" ${KEEP_SEQUENCES} "-" ${SOURCE_PATH} "-" ${TARGET_PATH} "-" ${BASE_NAME} "-" ${increment} "-" ${LOGSNAPSHOT} >> ${LOG_FILE}
}

function createIncrementalBackup {

    if [[ -f ${LOCK_FILE} ]]
    then
        locked_pid=$(cat ${LOCK_FILE})
        if ps -p "${locked_pid}" > /dev/null 2>&1; then
            echo "! archive is in progress (PID: ${locked_pid})"
            exit 100
        else
            echo "Warning: Stale lock file found for PID ${locked_pid}. Removing it."
            echo "$(date +"%d.%m.%Y %H:%M:%S") - Warning: Stale lock file found for PID ${locked_pid}. Removing it." >> ${LOG_FILE}
            rm -f ${LOCK_FILE}
        fi
    fi

    trap "{ echo '!!! Clean up'; rm -f ${LOCK_FILE} ; exit 0; }" EXIT # Restored original trap
    echo $$ > ${LOCK_FILE}


    if [[ ! -f ${INCREMENT_FILE} ]]
    then
        echo 0 > ${INCREMENT_FILE}
    fi

    increment=`cat ${INCREMENT_FILE}`
    increment=$(( ++increment ))

    # set -e # This is now at the top of the script

    if [[ ! -f ${SNAPSHOT_FILE} ]]; then
        echo "$(date +"%d.%m.%Y %H:%M:%S") - Starting full backup for ${BASE_NAME} (snapshot file ${SNAPSHOT_FILE} not found or was removed)." >> ${LOG_FILE}
    else
        echo "$(date +"%d.%m.%Y %H:%M:%S") - Starting incremental backup for ${BASE_NAME} using snapshot ${SNAPSHOT_FILE}." >> ${LOG_FILE}
    fi

    GTAR_ERRORS_LOG=${TARGET_PATH}/gtar_errors.log
    rm -f ${GTAR_ERRORS_LOG} # Ensure it's clean before use

    if  [[ -f ${EXCLUDE_FILE} ]]
    then
        gtar --no-check-device --ignore-failed-read --listed-incremental=${SNAPSHOT_FILE} -X ${EXCLUDE_FILE} -czpf ${TARGET_PATH}/${BASE_NAME}-${increment}.tar.gz -C ${SOURCE_PATH} ./ 2> ${GTAR_ERRORS_LOG}
    else
        gtar --no-check-device --ignore-failed-read --listed-incremental=${SNAPSHOT_FILE} -czpf ${TARGET_PATH}/${BASE_NAME}-${increment}.tar.gz ${SOURCE_PATH} -C ${SOURCE_PATH} ./ 2> ${GTAR_ERRORS_LOG}
    fi

    if [ -s ${GTAR_ERRORS_LOG} ] # Check if file is not empty
    then
        echo "gtar stderr: " >> ${LOG_FILE} # Restored gtar log message
        cat ${GTAR_ERRORS_LOG} >> ${LOG_FILE}
    fi
    rm -f ${GTAR_ERRORS_LOG}

    echo ${increment} > ${INCREMENT_FILE}

    mod=$(( increment % ITERATIONS ))

    if [[ ${mod} == 0 ]]
    then
        echo "! refresh snapshot ${SNAPSHOT_FILE}. Next full backup: ${increment}"
        echo "$(date +"%d.%m.%Y %H:%M:%S") - Snapshot file ${SNAPSHOT_FILE} removed for ${BASE_NAME}. Next backup (increment ${increment}) will be a full backup." >> ${LOG_FILE}
        if ! rm -f ${SNAPSHOT_FILE}; then # Added error check for rm
            echo "Error: Failed to remove snapshot file ${SNAPSHOT_FILE}" >> ${LOG_FILE}
        fi
    fi

    # set +e # This is now at the top of the script
}

function removeExpiredBackups {
    if [[ ! -f ${INCREMENT_FILE} ]]
    then
        echo 0 > ${INCREMENT_FILE}
    fi

    increment=`cat ${INCREMENT_FILE}`

    end=$(( increment - (increment % ITERATIONS) - (ITERATIONS * KEEP_SEQUENCES) + 1 ))
    start=$((end - ITERATIONS))

    if (( start >= 0 ))
    then
        echo "Current: ${increment}. Obsolete indexes: [${start} - ${end}]"

        for (( inc=start; inc<end; inc++ ))
        do
            backup_file=${TARGET_PATH}/${BASE_NAME}-${inc}.tar.gz

            if [[ -f ${backup_file} ]]
            then
                echo "! remove ${inc}"
                rm -f ${TARGET_PATH}/${BASE_NAME}-${inc}.tar.gz
            fi
        done
    fi
}

removeExpiredBackups
createIncrementalBackup
logBackup

echo "*** " $(date +"%d.%m.%Y %H:%M:%S") "BACKUP ENDED ${BASE_NAME} ***"
echo "*** " $(date +"%d.%m.%Y %H:%M:%S") "BACKUP ENDED ${BASE_NAME} ***" >> ${LOG_FILE} # Added to log file

exit 0