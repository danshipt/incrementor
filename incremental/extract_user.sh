#!/bin/bash

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

function usage {
    echo "Extract incremental backup for the user."
    echo ""
    echo "extract_user.sh -n USER_NAME -t EXTRACT_TO -c NEEDED_BACKUP_INDEX"
    echo "  -t: extract to path"
    echo "  -n: archive base name"
    echo "  -c: index of the backup of interest"
}


BACKUPS_ROOT=/backups/incremental
INCREMENT_COUNT=15

while getopts "c:i:s:t:n:h" OPTION
do
    case ${OPTION} in
    h)
        usage
        exit 1
        ;;
    c)
        NEEDED_BACKUP_INDEX=$OPTARG
        ;;
    t)
        TARGET_PATH=$OPTARG
        ;;
    n)
        USER_NAME=$OPTARG
        ;;
    ?)
        usage
        exit
        ;;
    esac
done

INCREMENT_FILE=${BACKUPS_ROOT}/${USER_NAME}/${USER_NAME}.inc
USER_BACKUPS_ROOT=${BACKUPS_ROOT}/${USER_NAME}

if [ ! -d ${TARGET_PATH} ]
then
    mkdir -p ${TARGET_PATH}
fi

if [ -z ${USER_NAME} ]
then
    usage
    exit 1
fi

if [ -z ${NEEDED_BACKUP_INDEX} ]
then
    NEEDED_BACKUP_INDEX=`cat ${INCREMENT_FILE}`
fi

idx_mod=$(( NEEDED_BACKUP_INDEX % INCREMENT_COUNT ))
if (( idx_mod == 0 ))
then
    idx_mod=${INCREMENT_COUNT}
fi

FULL_BACKUP_INDEX=$(( NEEDED_BACKUP_INDEX - idx_mod + 1 ))


echo "*** Extracting backup of user " ${USER_NAME}
echo "    backup source: " ${BACKUPS_ROOT}
echo "    full backup index: " ${FULL_BACKUP_INDEX}
echo "    need backup index: " ${NEEDED_BACKUP_INDEX}

./extract_inc.sh -s ${USER_BACKUPS_ROOT} -t ${TARGET_PATH} -n ${USER_NAME} -i ${FULL_BACKUP_INDEX} -c ${NEEDED_BACKUP_INDEX}

echo "changing owner"
chown -R ${USER_NAME}:${USER_NAME} ${TARGET_PATH}

