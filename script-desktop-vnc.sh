#!/bin/bash

# Script to automate desktop installation in centos 6.5
# root on 5901

yum -y groupinstall Desktop "Fonts" firefox

yum -y install tigervnc-server
chkconfig vncserver on

# this requires a prompt for now
vncpasswd

cp /etc/sysconfig/vncservers /etc/sysconfig/backup_vncservers.bak
rm -f /etc/sysconfig/vncservers
echo '
VNCSERVERS="1:root"
VNCSERVERARGS[1]=”-geometry 1024×768 -randr 1600x1200,1440x900,1024x768″
' >> /etc/sysconfig/vncservers

service vncserver restart
vncserver -kill :1
find /root/.vnc/xstartup -type f -exec sed -i 's/twm \&/exec gnome-session \&/g' {} \;
service vncserver restart

