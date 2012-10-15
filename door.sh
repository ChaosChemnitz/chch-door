#! /bin/sh

cd /etc/door/
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

OPEN_INDICATOR=/tmp/door_status_open
CLOSED_INDICATOR=/tmp/door_status_closed

if [ -f $OPEN_INDICATOR ]; then
	LOCK_AGE=$(( $(date +%s)-$(stat -c %X $OPEN_INDICATOR) ))
elif [ -f $CLOSE_INDICATOR ]; then
	LOCK_AGE=$(( $(date +%s)-$(stat -c %X $CLOSED_INDICATOR) ))
else
	LOCK_AGE=15
fi

if [ $LOCK_AGE -lt 15 ]; then
	echo "please wait at least 15 seconds befor a second run of this script" >&2
	exit 1
fi

./door_verify.sh
STATUS=$?
if [ $STATUS -eq 0 ]; then
	echo "opening door"
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
	exit 0
else
	echo "the lock won't move" >&2
	exit 1
fi
