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
# This script wraps backup_inc.sh to backup all users from /home. It is recommended
# to run this script on a backup node.
#
# To backup all users from /home, use this command:
# $ /path/to/script/backup_users.sh /home /backups/incremental
#
# If you run this command daily (i.e. in Cron), you will get incremental backups.
#
# For example, backups for user user1 appears here: /backups/incremental/user1

# Global config
USERDATA_PATH=

function usage {
	echo "Usage: backup_users.sh path_with_users path_with_backups"
	echo "       backup_users.sh /home /share/user_backups_incremental"
}

if [ -z $1 ]
then
    usage
    exit 1
fi

if [ -z $2 ]
then
    usage
    exit 1
fi

LOCK_FILE=/tmp/users_backup.lock
if [[ -f ${LOCK_FILE} ]]
then
    echo "! archive is in progress"
    exit 100
fi

trap "{ echo '!!! Clean up'; rm -f ${LOCK_FILE} ; exit 0; }" EXIT
echo "progress" > ${LOCK_FILE}

# target dir containing all the backups
USERDATA_PATH=$1
TARGET_BACKUPS_DIR=$2
SCRIPT_DIR=`dirname "$0"`
EXCLUDE_FILES=${SCRIPT_DIR}/exclude.list

echo "Data"
echo "	  script dir: ${SCRIPT_DIR}"
echo "    source: ${USERDATA_PATH}"
echo "    target: ${TARGET_BACKUPS_DIR}"
echo "	  exclude: ${EXCLUDE_FILES}"

PRE_PATH=`pwd`

cd ${SCRIPT_DIR}

for user in `ls ${USERDATA_PATH}`; do
{
	SOURCE_DIR=${USERDATA_PATH}/${user}

	mkdir -p ${TARGET_BACKUPS_DIR}/${user}
	./backup_inc.sh -i 15 -k 1 -x ${EXCLUDE_FILES} -t ${TARGET_BACKUPS_DIR}/${user} -n ${user} ${SOURCE_DIR}
}
done

cd ${PRE_PATH}
