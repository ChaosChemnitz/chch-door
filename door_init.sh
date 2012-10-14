#! /bin/sh

NAME=$1
SLOT=$2
if [ ! -n "$SLOT" ]; then
	echo "no slot defined -> using slot 1"
	SLOT=1
fi
KEYFILE=/etc/door_keys
DATE=$(date +%s)

rand20() {
openssl rand -hex 20
}

hmac() {
echo -n "$1" | openssl dgst -sha1 -mac HMAC -macopt "hexkey:$2" | cut -d= -f2 | grep -oe [0-9a-fA-F]\*
}

challenge() {
ykchalresp -$1 $2 2>/dev/null
}

configure() {
ykpersonalize -$1 -ochal-resp -ochal-hmac -ohmac-lt64 -y -a $2 >> /dev/null 2>&1
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

if [ ! -f $KEYFILE ]; then
	echo "creating key file under $KEYFILE"
	touch $KEYFILE
	chown root:root $KEYFILE
	chmod 600 $KEYFILE
	echo "# ID_RESP:SLOT:SECRET_KEY_ENC:NEXT_CHAL:DATE:NAME" >> $KEYFILE
fi

#generate global challenge to identify all keys
ID_CHAL=$(cat $KEYFILE | grep -e "^ID_CHAL=" | tail -n1 | cut -d= -f2)
if [ ! -n "$ID_CHAL" ]; then
	ID_CHAL=$(rand20)
	echo "ID_CHAL=$ID_CHAL" >> $KEYFILE
fi

#see if the key is already registered
ID_RESP=$(challenge $SLOT $ID_CHAL || (configure $SLOT $(rand20) && challenge $SLOT $ID_CHAL))
KEYFILE_ENTRY=$(grep -e "^$ID_RESP" $KEYFILE | tail -n1)
if [ -n "$KEYFILE_ENTRY" ]; then
	echo "key already registered"
	echo "rewriting secret key"
	
	#delete old key
	sed -i -e "/^${ID_RESP}:.*$/d" $KEYFILE
fi

echo "registering new key"

#configure secret key
SECRET_KEY=$(rand20)
configure $SLOT $SECRET_KEY

#precalculate next response
NEXT_CHAL=$(rand20)
NEXT_RESP=$(hmac $NEXT_CHAL $SECRET_KEY)
ID_RESP=$(hmac $ID_CHAL $SECRET_KEY)

#encrypt secret key
SECRET_KEY_ENC=$(aes_encrypt $SECRET_KEY $NEXT_RESP)

echo "$ID_RESP:$SLOT:$SECRET_KEY_ENC:$NEXT_CHAL:$DATE:$NAME" >> $KEYFILE
