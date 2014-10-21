#! /bin/bash

set -e

if [ $# -eq 0 ]; then
    echo 'backup uses rsync to backup(sync) one directory'
    echo 'to another.'
    exit 1
fi   

if [ ! -e /usr/bin/rsync ]; then
	echo '--------------------------------'
	echo "Installing the rsync package"
	echo "before beginning..."
	echo '--------------------------------'
	apt-get -y install rsync
fi

src="$1"
if [[ "$1" != */ ]]
then
	src="$1""/"
fi

echo "rsync -azP --no-p --no-o \"$src\" \"$2\""
rsync -azP --no-p --no-o "$src" "$2"