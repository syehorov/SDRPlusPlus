#!/bin/sh

URL=https://www.etsi.org/deliver/etsi_en/300300_300399/30039502/01.03.02_20/en_30039502v010302a0.zip
MD5_EXP=903c94be747d9ad1185485fdc7b6b0a6
LOCAL_FILE=etsi_tetra_codec.zip

PATCHDIR=`pwd`
CODECDIR=`pwd`/../codec

echo Deleting $CODECDIR ...
[ -e $CODECDIR ] && rm -rf $CODECDIR

echo Creating $CODECDIR ...
mkdir $CODECDIR

if [ ! -f $LOCAL_FILE ]; then
	echo Downloading $URL ...
# 	wget -O $LOCAL_FILE $URL
	curl -kLSs $URL -o $LOCAL_FILE
else
	echo Skipping download, file $LOCAL_FILE exists
fi
MD5=`md5sum $LOCAL_FILE | awk '{ print $1 }'`

echo Checking MD5SUM ...
if [ $MD5 != $MD5_EXP ]; then
	print "MD5sum of ETSI reference codec file doesn't match"
	exit 1
fi

echo Unpacking ZIP ...
cd $CODECDIR
unzip -L $PATCHDIR/etsi_tetra_codec.zip
echo Contents of $CODECDIR:
ls -lah

echo Applying Patches ...
ls -lah $PATCHDIR
cat $PATCHDIR/series
for p in `cat "$PATCHDIR/series"`; do
	echo "=> Applying patch '$PATCHDIR/$p'..."
	patch -p1 < "$PATCHDIR/$p"
done

echo Remove documentation ...
rm -rf ${CODECDIR}/c-word

echo Done!
