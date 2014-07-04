#!/bin/bash

echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo 'Please enter some configuration!'
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
read -s -p "root pw: " rootPassword
read -s -p 'ssh passphrase: ' sshPassphrase
echo ''
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo '          STARTING AUTOMATED SETUP SCRIPT'
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo ''

echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo '!!! Changing root Password !!!'
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo "$rootPassword" | passwd root --stdin
echo ''

# --------------------------
# STEP 1. PREREQS
# --------------------------
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo '!!! Updating System !!!'
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
yum -y upgrade
echo ''

echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo '!!! Installing nano, yum-utils, and ntp !!!'
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
# in case when adding extra repo sources something breaks
# package-cleanup --cleandupes
# rpm --rebuilddb
# from
# yum -y install yum-utils
yum -y install ntp ntpdate ntp-doc
echo ''

echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo '!!! Creating Software Dir !!!'
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
# -Create software directory
mkdir /software
mkdir /software/rpms
echo ''

echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo '!!! Updating Time and Starting ntpd !!!'
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
chkconfig ntpd on
ntpdate pool.ntp.org
service ntpd start
echo ''

# --------------------------
# STEP 2. IPTABLES
# --------------------------
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo '!!! IPTABLES Rules !!!'
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
#Remove all rules; Allow everything;
#Start from clean slate.
iptables -F
#Block NULL Packets
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
#Syn-flood block
iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
#XMAS block
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
#Accept all localhost/loopback incoming
iptables -A INPUT -i lo -j ACCEPT

# --------------------------
# Allow specific ports to the world
# on the first eth0 interface
# --------------------------
# iptables -A INPUT -i eth0 -p udp --dport 1132 -j ACCEPT
iptables -A INPUT -i eth0 -p tcp --dport 64 -j ACCEPT
#Allow ports from specifc IP Addresses
#iptables -A INPUT -p tcp -s 000.000.000.000 -m tcp --dport 22 -j ACCEPT

#allow any established outgoing connections to receive replies from the VPS on the other side of that connection
iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
#we will block everything else, and allow all outgoing connections
iptables -P OUTPUT ACCEPT
iptables -P INPUT DROP
iptables -P FORWARD DROP

#save and restart
iptables-save | sudo tee /etc/sysconfig/iptables
echo ''

# --------------------------
# STEP 3. Configure SSH and Users
# --------------------------
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo '!!! Configuring SSH for root !!!'
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
ssh-keygen -t rsa -b 7680 -N "$sshPassphrase" -f "/root/.ssh/server_id_rsa" -C "$(whoami)@$(hostname)-$(date -I)"
cat /root/.ssh/server_id_rsa.pub >> /root/.ssh/authorized_keys
# Settings
find /etc/ssh/sshd_config -type f -exec sed -i 's/Port 22/Port 64/g' {} \;
find /etc/ssh/sshd_config -type f -exec sed -i 's/#LoginGraceTime 2m/LoginGraceTime 1m/g' {} \;
find /etc/ssh/sshd_config -type f -exec sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' {} \;
find /etc/ssh/sshd_config -type f -exec sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' {} \;
find /etc/ssh/sshd_config -type f -exec sed -i 's/UsePAM yes/UsePAM no/g' {} \;
find /etc/ssh/sshd_config -type f -exec sed -i 's/#PermitRootLogin yes/PermitRootLogin without-password/g' {} \;

echo ''
echo ''
echo ''
echo '----------------------------------------------------'
echo 'PRIVATE KEY!!!'
echo 'SAVE THE FOLLOWING AS A KNOWN FILE'
echo 'CONNECT WITH:'
echo 'ssh -i /path/to/id_rsa root@0000.0000.0000.0000'
echo 'chown user key.isa'
echo 'chmod 700 key.isa'
echo '----------------------------------------------------'
cat /root/.ssh/server_id_rsa
rm -f /root/.ssh/server_id_rsa
echo ''
echo ''
echo ''
echo '----------------------------------------------------'
echo 'IPTABLES RULES'
echo '----------------------------------------------------'
iptables -S

service sshd restart
service iptables restart

