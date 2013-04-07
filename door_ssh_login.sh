#! /bin/bash --

ping -c1 -t3  $(echo $SSH_CONNECTION | cut -d" " -f 1) >> /dev/null 2>&1
STATUS=$?
if [ $STATUS -ne 0 ]; then
	echo "come closer... ;-)"
	exit 1
fi

sudo $(dirname $0)/door.sh noverify
