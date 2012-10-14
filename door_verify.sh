#! /bin/sh

KEYFILE=/etc/door_keys
LOGFILE=/var/log/door.log
DATE=$(date +%s)

rand20() {
openssl rand -hex 20
}

hmac() {
echo -n "$1" | openssl dgst -sha1 -mac HMAC -macopt "hexkey:$2" | cut -d= -f2 | grep -oe [0-9a-fA-F]\*
}

aes_encrypt() {
echo "$1" | openssl enc -aes256 -e -k "$2" | xxd -ps -c 256
}

aes_decrypt() {
echo "$1" | xxd -ps -r | openssl enc -aes256 -d -k "$2" >> /dev/null 2>&1
DECRYPT_OK=$?
DECRYPTED_TEXT="$(echo "$1" | xxd -ps -r | openssl enc -aes256 -d -k "$2" 2>&1)"
if [ $DECRYPT_OK -ne 0 ]; then
	DECRYPTED_TEXT="DEADBEEF"
fi
echo $DECRYPTED_TEXT
}

challenge() {
ykchalresp -$1 $2 2>/dev/null
}

if [ ! -f $KEYFILE ]; then
	echo "no keyfile found" >&2
	exit 1
fi

if [ ! -f $LOGFILE ]; then
        echo "generating new logfile" >&2
	echo "# DATE:ID:SIGNED_DATE:STATUS" > $LOGFILE
	chmod 600 $LOGFILE
fi

ID_CHAL=$(cat $KEYFILE | grep -e "^ID_CHAL=" | tail -n1 | cut -d= -f2)
if [ ! -n "$ID_CHAL" ]; then
	echo "no global challenge defined (can't identify keys)" >&2
	exit 1
fi


ID_RESP_1=$(challenge 1 $ID_CHAL)
ID_RESP_2=$(challenge 2 $ID_CHAL)
KEYFILE_ENTRY_1=$(grep -e "^$ID_RESP_1" $KEYFILE | tail -n1)
KEYFILE_ENTRY_2=$(grep -e "^$ID_RESP_2" $KEYFILE | tail -n1)
if [ -n "$KEYFILE_ENTRY_1" ]; then
	KEYFILE_ENTRY=$KEYFILE_ENTRY_1
	SLOT=1
elif [ -n "$KEYFILE_ENTRY_2" ]; then
	KEYFILE_ENTRY=$KEYFILE_ENTRY_2
	SLOT=2
else
	echo "key couldn't be identified" >&2	
	echo "$DATE:::ERROR_UNKNOWN_ID" >> $LOGFILE
	exit 1
fi

ID=$(echo $KEYFILE_ENTRY | cut -d: -f1)
SLOT=$(echo $KEYFILE_ENTRY | cut -d: -f2)
SECRET_KEY_ENC=$(echo $KEYFILE_ENTRY | cut -d: -f3)
CHALLENGE=$(echo $KEYFILE_ENTRY | cut -d: -f4)

#challenge key
RESPONSE=$(challenge $SLOT $CHALLENGE)
SECRET_KEY="$(aes_decrypt $SECRET_KEY_ENC $RESPONSE)"
if test "$(hmac $CHALLENGE $SECRET_KEY)" = "$RESPONSE"; then
	echo "$DATE:$ID:$(hmac $DATE $SECRET_KEY):OK" >> $LOGFILE
	echo "OK"

	#precalculate next response
	NEXT_CHALLENGE=$(rand20)
	NEXT_RESP=$(hmac $NEXT_CHALLENGE $SECRET_KEY)

	#encrypt secret key
	SECRET_KEY_ENC=$(aes_encrypt $SECRET_KEY $NEXT_RESP)
	SECRET_KEY=""

	export ID=$ID SLOT=$SLOT SECRET_KEY_ENC=$SECRET_KEY_ENC NEXT_CHALLENGE=$NEXT_CHALLENGE
	sed -i -e "s/^${ID}:[^:]*:[^:]*:[^:]*:/$ID:$SLOT:$SECRET_KEY_ENC:$NEXT_CHALLENGE:/" $KEYFILE
	export ID="" SLOT="" SECRET_KEY_ENC="" NEXT_CHALLENGE="" CREATION_DATE="" KEY_NAME=""
	exit 0
else 
	echo "$DATE:$ID::ERROR_FAILED_ON_CHALLENGE" >> $LOGFILE
	echo "not identified"
	exit 1
fi
