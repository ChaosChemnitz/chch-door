#! /bin/bash

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

OPEN_INDICATOR=/tmp/door_status_open
CLOSED_INDICATOR=/tmp/door_status_closed

DELAY=10
DATE_STRING="$(date +%s)#$(date +"%F %X")"
TIMEOUT=30
LOCKDIR="/var/lock"

lock_file() {
        OUTFILE=$1
        OUTFILE_LOCK="${LOCKDIR}/$(readlink -f $OUTFILE | sed -e "s/\//\!/g").lock"
        TIMEOUT_LOCK=$TIMEOUT
        while [ $(mkdir "$OUTFILE_LOCK" 2> /dev/null; echo $? ) -ne 0 -a $TIMEOUT_LOCK -gt 0 ]; do
                TIMEOUT_LOCK=$(($TIMEOUT_LOCK-1))
                if [ -f "$OUTFILE_LOCK/lastaction" -a ! -d "$OUTFILE_LOCK/timeout"  ] >> /dev/null 2>&1; then
                        FILEAGE=$(($(date +%s) - $(stat -c '%Y' "$OUTFILE_LOCK/lastaction" || echo $(date +%s) 2> /dev/null )))
                        TIMEOUT_LOCK=$(($TIMEOUT-$FILEAGE))
                fi
                if [ $TIMEOUT_LOCK -le 0 ]; then
                        if [ $(mkdir "$OUTFILE_LOCK/timeout" >> /dev/null 2>&1; echo $? ) -ne 0 ]; then
                                TIMEOUTAGE_LOCK=$(($(date +%s) - $(stat -c '%Y' "$OUTFILE_LOCK/timeout")))
                                if [ $TIMEOUTAGE_LOCK -gt $TIMEOUT ]; then
                                        if [ $(rm -rf "$OUTFILE_LOCK/timeout" >> /dev/null 2>&1; echo $? ) -ne 0 ]; then
                                                TIMEOUT_LOCK=$TIMEOUT
                                        else
                                                TIMEOUT_LOCK=1
                                        fi
                                else
                                        TIMEOUT_LOCK=$(($TIMEOUT-$TIMEOUTAGE_LOCK))
                                fi
                        fi
                fi
                sleep 1
        done
        if [ $TIMEOUT_LOCK -le 0 ]; then
                echo "Timeout! Ignoring old \"$OUTFILE_LOCK\"." >&2
        fi
        touch "$OUTFILE_LOCK/lastaction"
}

unlock_file() {
        OUTFILE=${1}
        OUTFILE_LOCK="${LOCKDIR}/$(readlink -f $OUTFILE | sed -e "s/\//\!/g").lock"
        rm -rf "$OUTFILE_LOCK"
}

cd $(dirname $0) || {
    echo "konnte verzeichniss nicht wechseln"
    exit 1
}

lock_file $OPEN_INDICATOR
lock_file $CLOSED_INDICATOR
if [ -f $OPEN_INDICATOR ]; then
	LOCK_AGE=$(( $(date +%s)-$(stat -c %X $OPEN_INDICATOR) ))
elif [ -f $CLOSED_INDICATOR ]; then
	LOCK_AGE=$(( $(date +%s)-$(stat -c %X $CLOSED_INDICATOR) ))
else
	LOCK_AGE=$DELAY
fi

if [ $LOCK_AGE -lt $DELAY ]; then
	echo "please wait at least $DELAY seconds before a second run of this script" >&2
	unlock_file $OPEN_INDICATOR
	unlock_file $CLOSED_INDICATOR
	exit 1
fi

if [ "$1" == "noverify" ]; then
	STATUS=0
else
	./door_verify.sh
	STATUS=$?
fi
if [ $STATUS -eq 0 ]; then
	if [ -f $OPEN_INDICATOR ]; then
		echo "closing door"
		./door_lock.sh close
		rm $OPEN_INDICATOR
		touch $CLOSED_INDICATOR
	else
		echo "opening door"
		./door_lock.sh open
		rm $CLOSED_INDICATOR
		touch $OPEN_INDICATOR	
	fi
	unlock_file $OPEN_INDICATOR
	unlock_file $CLOSED_INDICATOR
	exit 0
else
	echo "the lock won't move" >&2
	if [ -f $OPEN_INDICATOR ]; then
		touch $OPEN_INDICATOR
	else
		touch $CLOSED_INDICATOR
	fi
	unlock_file $OPEN_INDICATOR
	unlock_file $CLOSED_INDICATOR
	exit 1
fi
