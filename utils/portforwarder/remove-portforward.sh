#!/bin/bash

service "portforward-""$1" stop

# ubuntu specific
update-rc.d -f "portforward-""$1" remove

rm -f "/etc/init.d/portforward-""$1"

echo "Remove portforwardworker? [Y][ENTER]:"
read removeportforwardworker
if [ "removeportforwardworker" == "Y" ]; then
	rm -f /usr/sbin/portforwardworker
fi