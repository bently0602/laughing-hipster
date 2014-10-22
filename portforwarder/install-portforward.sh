#!/bin/bash

cp portforward "/etc/init.d/portforward-""$1"
cp portforwardworker /usr/sbin/portforwardworker
chmod +x "/etc/init.d/portforward-""$1"
chmod +x /usr/sbin/portforwardworker

find "/etc/init.d/portforward-""$1" -type f -exec sed -i "s/DAEMONOPTS=\"\"/DAEMONOPTS=\"$2\"/g" {} \;
find "/etc/init.d/portforward-""$1" -type f -exec sed -i "s/NAME=\"\"/NAME=\"portforward-$1\"/g" {} \;

# ubuntu specific
update-rc.d "portforward-""$1" defaults

service "portforward-""$1" start