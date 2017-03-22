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
#
#
# Description:
# This script is a wrapper for the gtar. Used to extract incremental backups.
#
# For this script to work properly, you must always specify the full backup index.

function usage {
    echo "Extract incremental backup. Starting from full backup index to the backup of interest."
    echo ""
    echo "extract_inc.sh -s BACKUPS_SOURCE -t EXTRACT_TO -n BASE_NAME -i FULL_BACKUP_INDEX -c NEEDED_BACKUP_INDEX"
    echo "  -s: path where backups are stored"
    echo "  -t: extract to path"
    echo "  -n: archive base name"
    echo "  -i: index of the full backup"
    echo "  -c: index of the backup of interest"
}

FROM_ITERATION=
NEEDED_BACKUP_INDEX=
SOURCE_PATH=
TARGET_PATH=
BASE_NAME=
LOG_FILE=


while getopts "c:i:s:t:n:h" OPTION
do
    case ${OPTION} in
    h)
        usage
        exit 1
        ;;
    i)
        FROM_ITERATION=$OPTARG
        ;;
    c)
        NEEDED_BACKUP_INDEX=$OPTARG
        ;;
    s)
        SOURCE_PATH=$OPTARG
        ;;
    t)
        TARGET_PATH=$OPTARG
        ;;
    n)
        BASE_NAME=$OPTARG
        ;;
    ?)
        usage
        exit
        ;;
    esac
done


if [ ! -d ${SOURCE_PATH} ]
then
    echo "${SOURCE_PATH} must exist!"
    exit 1
fi

if [ ! -d ${TARGET_PATH} ]
then
    echo "${TARGET_PATH} must exist!"
    exit 1
fi

if [ -z ${BASE_NAME} ]
then
    usage
    exit 1
fi

if [ -z ${FROM_ITERATION} ]
then
    usage
    exit 1
fi

if [ -z ${NEEDED_BACKUP_INDEX} ]
then
    usage
    exit 1
fi


LOG_FILE=${TARGET_PATH}/${BASE_NAME}_extract.log

echo "Using data:"
echo "    full backup index: ${FROM_ITERATION}"
echo "    needed backup index: ${NEEDED_BACKUP_INDEX}"
echo "    source: ${SOURCE_PATH}"
echo "    target: ${TARGET_PATH}"
echo "    base name: ${BASE_NAME}"

PRE_PATH=`pwd`
cd ${TARGET_PATH}

for (( inc=FROM_ITERATION; inc<=NEEDED_BACKUP_INDEX; inc++ ))
do
    echo "Extracting: ${SOURCE_PATH}/${BASE_NAME}-${inc}.tar.gz"
    gtar --listed-incremental=/dev/null -xzpf ${SOURCE_PATH}/${BASE_NAME}-${inc}.tar.gz
done

cd ${PRE_PATH}
