#!/bin/bash

# Script to automate setup of centos 6.5

# modify these accordingly
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo 'Please enter some configuration!'
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
read -s -p "root pw: " rootPassword
echo ''
read -s -p 'ssh passphrase: ' sshPassphrase
echo ''
read -p 'personal webdav username: ' webdavUsername
echo ''
read -s -p 'personal webdav password: ' webdavPassword
echo ''
read -p 'guest/ master webdav username: ' guestMasterWebdavUsername
echo ''
read -s -p 'guest/ master webdav password: ' guestMasterWebdavPassword
echo ''
read -p 'guest/ guest webdav username: ' guestWebdavUsername
echo ''
read -s -p 'guest/ guest webdav password: ' guestWebdavPassword
echo ''
read -p 'inet facing ipaddress (maybe eth0?): ' inetFacingIPaddress 
echo ''
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
echo '!!! Installing wget, nano, yum-utils !!!'
echo '!!! apache, mod_ssl, ntp, and "Dev. Tools" !!!'
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
yum -y install wget
yum -y install nano
# in case when adding extra repo sources something breaks
# https://ask.fedoraproject.org/en/question/9807/yum-will-not-update-errno-12-cannot-allocate-memory/
# package-cleanup --cleandupes
# rpm --rebuilddb
yum -y install yum-utils
yum -y install httpd
yum -y install mod_ssl
yum -y install ntp ntpdate ntp-doc
yum groupinstall "Development Tools" -y
echo ''

echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo '!!! Creating Software Dir !!!'
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
# -Create software directory
mkdir /software
mkdir /software/rpms
mkdir /software/webdav-cert
mkdir /webdav
mkdir /webdavguest
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
#https://www.digitalocean.com/community/articles/how-to-setup-a-basic-ip-tables-configuration-on-centos-6
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
#Allow specific ports to the world
# port for openvpn to the WORLD!!!!!!
# on the first eth0 interface
iptables -A INPUT -i eth0 -p udp --dport 1132 -j ACCEPT
#Allow ports from specifc IP Addresses
#iptables -A INPUT -p tcp -s 000.000.000.000 -m tcp --dport 22 -j ACCEPT
#allow any established outgoing connections to receive replies from the VPS on the other side of that connection
iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
#we will block everything else, and allow all outgoing connections
iptables -P OUTPUT ACCEPT
iptables -P INPUT DROP
#save and restart
iptables-save | sudo tee /etc/sysconfig/iptables
service iptables restart
#to look and see what rules are active
#iptables -L -n
echo ''

# --------------------------
# STEP 3. WEBDAV
# --------------------------
# check http://www.onlamp.com/pub/a/onlamp/2008/03/04/step-by-step-configuring-ssl-under-apache.html
# check http://ubuntuguide.org/wiki/WebDAV
# https://www.sslshopper.com/article-how-to-disable-weak-ciphers-and-ssl-2.0-in-apache.html
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo '!!! Configuring WEBDAV !!!'
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'

htpasswd -b -c /etc/httpd/webdav.password "$webdavUsername" "$webdavPassword"
htpasswd -b -c /etc/httpd/gueststore.password "$guestWebdavUsername" "$guestWebdavPassword"
htpasswd -b -c /etc/httpd/gueststore.password "$guestMasterWebdavUsername" "$guestMasterWebdavPassword"

chown apache:apache /webdav
openssl req -x509 -nodes -days 1024 -newkey rsa:4096 -keyout /software/webdav-cert/webdavcert.key -out /software/webdav-cert/webdavcert.crt -subj "/C=US/ST=FART/L=FART/O=Dis/CN=www.crap.co"

echo "
#NameVirtualHost *:443

LoadModule ssl_module modules/mod_ssl.so

<VirtualHost *:443>
    Alias /webdav /webdav
    Alias /webdavguest /webdavguest

    SSLEngine on
    SSLProtocol -ALL +SSLv3 +TLSv1
    SSLCipherSuite ALL:!ADH:RC4+RSA:+HIGH:+MEDIUM:!LOW:!SSLv2:!EXPORT
    SSLOptions +StrictRequire
    SSLCertificateFile /software/webdav-cert/webdavcert.crt
    SSLCertificateKeyFile /software/webdav-cert/webdavcert.key

    <Directory />
        SSLRequireSSL
    </Directory>

    <Location /webdav>
        Options Indexes
        DAV On
        AuthType Basic
        AuthName 'webdav'
        AuthUserFile /etc/httpd/webdav.password
        Require valid-user
    </Location>

    <Location /webdavguest>
        Options Indexes
        DAV On
        AuthType Basic
        AuthName 'webdavguest'
        AuthUserFile /etc/httpd/gueststore.password
        Require valid-user
    </Location>
    
</VirtualHost>" >> /etc/httpd/conf/httpd.conf

find /etc/httpd/conf/httpd.conf -type f -exec sed -i 's/Listen 80/Listen 443/g' {} \;

cp /etc/httpd/conf.d/welcome.conf /etc/httpd/conf.d/welcome.bak
cp /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.bak

rm -f /etc/httpd/conf.d/welcome.conf
rm -f /etc/httpd/conf.d/ssl.conf

service httpd restart
echo ''

# --------------------------
# STEP 4. Configure SSH and Users
# --------------------------
# Setup SSH with keys
# !!! Super not good way, private key should be generated on the client that is connceting to the server...
# !!! Should not be allowing login for root!!!
# https://wiki.archlinux.org/index.php/SSH_Keys
# Using RSA for compat
# other users would use ~/.ssh but root uses /root/
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo '!!! Configuring SSH for root !!!'
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
ssh-keygen -t rsa -b 7680 -N "$sshPassphrase" -f "/root/.ssh/server_id_rsa" -C "$(whoami)@$(hostname)-$(date -I)"
echo '----------------------------------------------------'
echo 'PRIVATE KEY!!!'
echo 'SAVE THE FOLLOWING AS A KNOWN FILE'
echo 'CONNECT WITH:'
echo 'ssh -i /path/to/id_rsa user@server.nixcraft.com'
echo 'chown user key.isa'
echo 'chmod 700 key.isa'
echo '----------------------------------------------------'
cat /root/.ssh/server_id_rsa
cat /root/.ssh/server_id_rsa.pub >> /root/.ssh/authorized_keys
rm -f /root/.ssh/server_id_rsa

# Settings (made for default CENTOS config file, will not work if modified)
find /etc/ssh/sshd_config -type f -exec sed -i 's/#LoginGraceTime 2m/LoginGraceTime 1m/g' {} \;
find /etc/ssh/sshd_config -type f -exec sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' {} \;
find /etc/ssh/sshd_config -type f -exec sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' {} \;
find /etc/ssh/sshd_config -type f -exec sed -i 's/UsePAM yes/UsePAM no/g' {} \;
find /etc/ssh/sshd_config -type f -exec sed -i 's/#PermitRootLogin yes/PermitRootLogin without-password/g' {} \;

echo ''

# --------------------------
# STEP 5. OPENVPN
# --------------------------
# https://www.digitalocean.com/community/articles/how-to-setup-and-configure-an-openvpn-server-on-centos-6
# http://www.garron.me/en/linux/openvpn-server-client-linux-how-to.html
# http://tipupdate.com/how-to-install-openvpn-on-centos-vps/
# http://www.openlogic.com/wazi/bid/188052/From-Zero-to-OpenVPN-in-30-Minutes
# https://community.openvpn.net/openvpn/wiki/Openvpn23ManPage @ INLINE FILE SUPPORT
# http://allanmcrae.com/2013/09/routing-traffic-with-openvpn/

echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo '!!! Installing and Configuring OpenVPN !!!'
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
# maybe compile from source later on???
cd /software/rpms
wget http://dl.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
rpm -Uvh epel-release-6-8.noarch.rpm
# disable pulling from these repos by default
sed --in-place "s/\\(.*enabled.*=\\).*/\1 0/" /etc/yum.repos.d/epel.repo
sed --in-place "s/\\(.*enabled.*=\\).*/\1 0/" /etc/yum.repos.d/epel-testing.repo

# to extract inside and see the layout of everything in RPM
#rpm2cpio openvpn-2.3.2-2.el6.i686.rpm | cpio -idmv

yum -y  --enablerepo epel install openvpn easy-rsa

useradd openvpn

cp /usr/share/doc/openvpn-2.3.2/sample/sample-config-files/server.conf /etc/openvpn
find /etc/openvpn/server.conf -type f -exec sed -i 's/;push "redirect-gateway def1 bypass-dhcp"/push "redirect-gateway def1 bypass-dhcp"/g' {} \;
find /etc/openvpn/server.conf -type f -exec sed -i 's/;push "dhcp-option DNS 208.67.222.222"/push "dhcp-option DNS 208.67.222.222"/g' {} \;
find /etc/openvpn/server.conf -type f -exec sed -i 's/;push "dhcp-option DNS 208.67.220.220"/push "dhcp-option DNS 208.67.220.220"/g' {} \;
find /etc/openvpn/server.conf -type f -exec sed -i 's/;user nobody/user nobody/g' {} \;
find /etc/openvpn/server.conf -type f -exec sed -i 's/;group nobody/group nobody/g' {} \;
find /etc/openvpn/server.conf -type f -exec sed -i 's/dh dh1024.pem/dh dh.pem/g' {} \;
find /etc/openvpn/server.conf -type f -exec sed -i 's/;tls-auth ta.key 0 # This file is secret/tls-auth ta.key 0/g' {} \;
find /etc/openvpn/server.conf -type f -exec sed -i 's/port 1194/port 1132/g' {} \;
find /etc/openvpn/server.conf -type f -exec sed -i 's/;client-to-client/client-to-client/g' {} \;

mkdir -p /etc/openvpn/easy-rsa/keys
cp -rf /usr/share/easy-rsa/2.0 /etc/openvpn/easy-rsa

find /etc/openvpn/easy-rsa/2.0/vars -type f -exec sed -i 's/export KEY_COUNTRY="US"/export KEY_COUNTRY="US"/g' {} \;
find /etc/openvpn/easy-rsa/2.0/vars -type f -exec sed -i 's/export KEY_PROVINCE="CA"/export KEY_PROVINCE="CA"/g' {} \;
find /etc/openvpn/easy-rsa/2.0/vars -type f -exec sed -i 's/export KEY_CITY="SanFrancisco"/export KEY_CITY="SanFrancisco"/g' {} \;
find /etc/openvpn/easy-rsa/2.0/vars -type f -exec sed -i 's/export KEY_ORG="Fort-Funston"/export KEY_ORG="Fort-Funston"/g' {} \;
find /etc/openvpn/easy-rsa/2.0/vars -type f -exec sed -i 's/export KEY_EMAIL="me@myhost.mydomain"/export KEY_EMAIL="me@myhost.mydomain"/g' {} \;
find /etc/openvpn/easy-rsa/2.0/vars -type f -exec sed -i 's/export KEY_EMAIL=mail@host.domain/export KEY_EMAIL=mail@host.domain/g' {} \;
find /etc/openvpn/easy-rsa/2.0/vars -type f -exec sed -i 's/export KEY_CN=changeme/export KEY_CN=changeme/g' {} \;
find /etc/openvpn/easy-rsa/2.0/vars -type f -exec sed -i 's/export KEY_NAME=changeme/export KEY_NAME=changeme/g' {} \;
find /etc/openvpn/easy-rsa/2.0/vars -type f -exec sed -i 's/export KEY_OU=changeme/export KEY_OU=changeme/g' {} \;
find /etc/openvpn/easy-rsa/2.0/vars -type f -exec sed -i 's/export PKCS11_MODULE_PATH=changeme/export PKCS11_MODULE_PATH=changeme/g' {} \;
find /etc/openvpn/easy-rsa/2.0/vars -type f -exec sed -i 's/export PKCS11_PIN=1234/export PKCS11_PIN=1234/g' {} \;
find /etc/openvpn/easy-rsa/2.0/vars -type f -exec sed -i 's/export KEY_SIZE=1024/export KEY_SIZE=1024/g' {} \;

#OpenVPN might fail to properly detect the OpenSSL version on CentOS 6. As a precaution, manually copy the required OpenSSL configuration file.
cp /etc/openvpn/easy-rsa/2.0/openssl-1.0.0.cnf /etc/openvpn/easy-rsa/2.0/openssl.cnf

# Disable interaction
find /etc/openvpn/easy-rsa/2.0/build-ca -type f -exec sed -i 's/"\$EASY_RSA\/pkitool" --interact --initca \$\*/"\$EASY_RSA\/pkitool" --initca \$\*/g' {} \;
find /etc/openvpn/easy-rsa/2.0/build-key-server -type f -exec sed -i 's/"\$EASY_RSA\/pkitool" --interact --server \$\*/"\$EASY_RSA\/pkitool" --server \$\*/g' {} \;
find /etc/openvpn/easy-rsa/2.0/build-key -type f -exec sed -i 's/"\$EASY_RSA\/pkitool" --interact \$\*/"\$EASY_RSA\/pkitool" \$\*/g' {} \;

todaysDate=`date +"%Y%m%d000000Z"`
find /etc/openvpn/easy-rsa/2.0/pkitool -type f -exec sed -i "s/\$OPENSSL ca \$BATCH -days \$KEY_EXPIRE/\$OPENSSL ca \$BATCH -days \$KEY_EXPIRE -startdate $todaysDate /g" {} \;

cd /etc/openvpn/easy-rsa/2.0
source ./vars
./clean-all
echo '~~~~~Building CA~~~~~'
./build-ca
#--
echo '~~~~~Building Server Cert~~~~~'
./build-key-server server
#--
find /etc/openvpn/easy-rsa/2.0/build-dh -type f -exec sed -i 's/\$OPENSSL dhparam -out \${KEY_DIR}\/dh\${KEY_SIZE}.pem \${KEY_SIZE\}/\$OPENSSL dhparam -out \${KEY_DIR}\/dh.pem \${KEY_SIZE}/g' {} \;
echo '~~~~~Building DH Params~~~~~'
./build-dh
#--
# at a later date run source ./vars before adding new clients
echo '~~~~~Building Client Cert~~~~~'
KEY_CN=client ./build-key client
#--
echo '~~~~~Done building SSL~~~~~'
cd keys
cp -f dh.pem ca.crt server.crt server.key /etc/openvpn

# new here
echo '~~~~~Generate TLS~~~~~'
openvpn --genkey --secret /etc/openvpn/ta.key

echo "
client
dev tun
proto udp
remote $inetFacingIPaddress 1132
resolv-retry infinite
nobind
persist-key
persist-tun
ns-cert-type server
comp-lzo
verb 3
redirect-gateway
key-direction 1
<ca>" >> /etc/openvpn/client.opvn
cat ca.crt >> /etc/openvpn/client.opvn
echo '</ca>
<cert>
-----BEGIN CERTIFICATE-----' >> /etc/openvpn/client.opvn
cat client.crt | sed -n "/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p" | head -n-1 | tail -n+2 >> /etc/openvpn/client.opvn
echo '-----END CERTIFICATE-----
</cert>
<key>' >> /etc/openvpn/client.opvn
cat client.key >> /etc/openvpn/client.opvn
echo '</key>' >> /etc/openvpn/client.opvn
echo '<tls-auth>' >> /etc/openvpn/client.opvn
cat /etc/openvpn/ta.key >> /etc/openvpn/client.opvn
echo '</tls-auth>' >> /etc/openvpn/client.opvn

echo '----------------------------------------------------'
echo 'CLIENT.OPVN - CONTAINS KEYS!!!'
echo 'SAVE THE FOLLOWING AS A KNOWN FILE'
echo '----------------------------------------------------'
cat  /etc/openvpn/client.opvn

iptables -A OUTPUT -o tun+ -j ACCEPT
# Allow TUN interface connections to OpenVPN server
iptables -A INPUT -i tun+ -j ACCEPT
# Allow TUN interface connections to be forwarded through other interfaces
iptables -A FORWARD -i tun+ -j ACCEPT
iptables -A FORWARD -i tun+ -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth0 -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT
# NAT the VPN client traffic to the internet
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE

service iptables save

find /etc/sysctl.conf -type f -exec sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/g' {} \;

sysctl -p
chkconfig openvpn on
service openvpn start

service sshd restart
service iptables restart

# install OpenVPN AS
#mkdir /software/openvpn-as
#wget http://swupdate.openvpn.org/as/openvpn-as-2.0.3-CentOS6.x86_64.rpm
#rpm -Uvh openvpn-as-2.0.3-CentOS6.x86_64.rpm
#passwd openvpn

# --------------------------
# STEP 6. CLEANUP AS NEEDED
# --------------------------
