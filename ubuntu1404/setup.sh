#! /bin/bash

set -e

#
# SETUP SCRIPT
# - tested on ubuntu 14.04
# - required to be ran as root
#

if [ ! -e /usr/bin/dialog ]
then
    echo '--------------------------------'
    echo "Installing the dialog package"
    echo "before beginning..."
    echo '--------------------------------'
    apt-get -y install dialog
fi

exampleExternalIPAddress=`ifconfig 'eth0' | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`

dialog --clear --backtitle "Ubuntu 14.04 Setup Script" --title "Setup Values" \
--form "\nPlease fill in the following values:" 25 60 16 \
"ROOT password:" 1 1 "" 1 25 25 30 \
"INET Facing IP(eth0):" 2 1 $exampleExternalIPAddress 2 25 25 30 \
"External Interface:" 3 1 "eth0" 3 25 25 30 \
"SSH Pass( > 3 chars):" 4 1 "" 4 25 25 30 \
2>/tmp/form.$$

rootPassword=`sed -n '1,1p' /tmp/form.$$`
inetFacingIPaddress=`sed -n '2,2p' /tmp/form.$$`
externalInterface=`sed -n '3,3p' /tmp/form.$$`
sshPassphrase=`sed -n '4,4p' /tmp/form.$$`

rm -f /tmp/form.$$

#-------------------------------------------------
# set root password
#-------------------------------------------------
echo "root:$rootPassword" | chpasswd

#-------------------------------------------------
# update and dependencies
#-------------------------------------------------
# update
apt-get -y update
apt-get -y upgrade

# install dependencies
apt-get -y install ntp ntpdate ntp-doc openvpn easy-rsa debconf-utils
apt-get -y remove ufw

# update time and install ntp
service ntp stop
ntpdate pool.ntp.org
service ntp start

#-------------------------------------------------
# sshd setup
#-------------------------------------------------
# Configure SSH and Users
rm -f /root/.ssh/server_id_rsa
ssh-keygen -t rsa -b 7680 -N $sshPassphrase -f "/root/.ssh/server_id_rsa" -C "$(whoami)@$(hostname)-$(date -I)"
cat /root/.ssh/server_id_rsa.pub >> /root/.ssh/authorized_keys
# Settings 
find /etc/ssh/sshd_config -type f -exec sed -i 's/LoginGraceTime 120/LoginGraceTime 60/g' {} \;
find /etc/ssh/sshd_config -type f -exec sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' {} \;
find /etc/ssh/sshd_config -type f -exec sed -i 's/UsePAM yes/UsePAM no/g' {} \;
find /etc/ssh/sshd_config -type f -exec sed -i 's/PermitRootLogin yes/PermitRootLogin without-password/g' {} \;

#-------------------------------------------------
# openvpn setup
#-------------------------------------------------
echo '
port 1132
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 208.67.222.222"
push "dhcp-option DNS 208.67.220.220"
client-to-client
duplicate-cn
keepalive 10 120
tls-auth ta.key 0
cipher AES-128-CBC
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
' >> /etc/openvpn/server.conf

rm -fr /etc/openvpn/easy-rsa
mkdir /etc/openvpn/easy-rsa
#find / -name easy-rsa
cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa
mkdir -p /etc/openvpn/easy-rsa/keys
cd /etc/openvpn/easy-rsa

# in case updating openssl messes with the version number
# easy-rsa expects for configuration
cp /etc/openvpn/easy-rsa/openssl-1.0.0.cnf /etc/openvpn/easy-rsa/openssl.cnf

echo '
export KEY_CONFIG="/etc/openvpn/easy-rsa/openssl.cnf"
export KEY_SIZE=2048
export KEY_CN="DNS:www.private.server.com"
export KEY_NAME=changeme
export KEY_COUNTRY="US"
export KEY_PROVINCE="CA"
export KEY_CITY="SanFrancisco"
export KEY_ORG="LPWEF"
export KEY_EMAIL="me@myhost.mydomain"
' >> /etc/openvpn/easy-rsa/xtravars

find /etc/openvpn/easy-rsa/build-ca -type f -exec sed -i 's/"\$EASY_RSA\/pkitool" --interact --initca \$\*/"\$EASY_RSA\/pkitool" --initca \$\*/g' {} \;
find /etc/openvpn/easy-rsa/build-key-server -type f -exec sed -i 's/"\$EASY_RSA\/pkitool" --interact --server \$\*/"\$EASY_RSA\/pkitool" --server \$\*/g' {} \;
find /etc/openvpn/easy-rsa/build-key -type f -exec sed -i 's/"\$EASY_RSA\/pkitool" --interact \$\*/"\$EASY_RSA\/pkitool" \$\*/g' {} \;

todaysDate=`date +"%Y%m%d000000Z"`
find /etc/openvpn/easy-rsa/pkitool -type f -exec sed -i "s/\$OPENSSL ca \$BATCH -days \$KEY_EXPIRE/\$OPENSSL ca \$BATCH -days \$KEY_EXPIRE -startdate $todaysDate /g" {} \;

cd /etc/openvpn/easy-rsa
. ./vars
. ./xtravars
./clean-all
echo '~~~~~Building CA~~~~~'
./build-ca
echo '~~~~~Building Server Cert~~~~~'
./build-key-server server
find /etc/openvpn/easy-rsa/build-dh -type f -exec sed -i 's/\$OPENSSL dhparam -out \${KEY_DIR}\/dh\${KEY_SIZE}.pem \${KEY_SIZE\}/\$OPENSSL dhparam -out \${KEY_DIR}\/dh.pem \${KEY_SIZE}/g' {} \;
echo '~~~~~Building DH Params~~~~~'
./build-dh
#--
# at a later date run source ./vars before adding new clients
echo '~~~~~Building Client Cert~~~~~'
# each client certificate needs a unique CommonName
KEY_CN=DNS:www.client.com ./build-key client
#--
echo '~~~~~Done building SSL~~~~~'
cd /etc/openvpn/easy-rsa/keys
cp -f dh.pem ca.crt server.crt server.key /etc/openvpn
echo '~~~~~Generate TLS~~~~~'
openvpn --genkey --secret /etc/openvpn/ta.key

echo "
client
dev tun
proto udp
remote $inetFacingIPaddress 1132
cipher AES-128-CBC
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

#-------------------------------------------------
# iptables rules
#-------------------------------------------------

echo "iptables-persistent iptables-persistent/autosave_v6 boolean false" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v4 boolean false" | debconf-set-selections
apt-get -y install iptables-persistent

# ************************************************
# Start from clean slate.
# for temporary set default policy to accept
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
# then flush all the rules
iptables -F
#iptables -X

# ************************************************
# allow any established outgoing connections to
# receive replies from the VPS on the other side 
# of that connection
#iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ************************************************
# block specials
#Block NULL Packets
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
#Syn-flood block
iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
#XMAS block
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

# ************************************************
# Allow specific ports to the world
#Allow ports from specifc IP Addresses
#iptables -A INPUT -p tcp -s 000.000.000.000 -m tcp --dport 22 -j ACCEPT
iptables -A INPUT -i $externalInterface -p udp --dport 1132 -j ACCEPT
#iptables -A INPUT -i $externalInterface -p tcp --dport 22 -j ACCEPT

# ************************************************
#Accept all localhost/loopback incoming
iptables -I INPUT 1 -i lo -j ACCEPT

# ************************************************
# Allow TUN interface connections to OpenVPN server
iptables -A OUTPUT -o tun+ -j ACCEPT
iptables -A INPUT -i tun+ -j ACCEPT

# ************************************************
# Allow TUN interface connections to be forwarded through other interfaces
iptables -A FORWARD -i tun+ -j ACCEPT
iptables -A FORWARD -i tun+ -o $externalInterface -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $externalInterface -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT

# ************************************************
# NAT the VPN client traffic to the internet
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE

# ************************************************
# Default rule to catch everything else
# we will block everything else, and allow all 
# outgoing connections
iptables -P OUTPUT ACCEPT
iptables -P INPUT DROP
iptables -P FORWARD DROP

#block all incoming IPv6
ip6tables -P INPUT ACCEPT
ip6tables -P OUTPUT ACCEPT
ip6tables -P FORWARD ACCEPT
ip6tables -F
ip6tables -P INPUT DROP
ip6tables -P OUTPUT DROP
ip6tables -P FORWARD DROP

iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6

# allow forwarding for openvpn in kernel
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

#-------------------------------------------------
# show information
#-------------------------------------------------
echo '----------------------------------'
echo "CLIENT OPENVPN CONFIGURATION FILE"
echo '----------------------------------'
cat /etc/openvpn/client.opvn
rm -f /etc/openvpn/client.opvn
echo '----------------------------------'
echo "SSH ID FILE"
echo '----------------------------------'
cat /root/.ssh/server_id_rsa
rm -f /root/.ssh/server_id_rsa
echo '----------------------------------'
echo "IPTABLES RULES"
echo '----------------------------------'
#iptables -L -n
iptables -S
echo '----------------------------------'
echo "IPTABLES IPv6 RULES"
echo '----------------------------------'
#ip6tables -v -nL | grep DROP
ip6tables -S

#-------------------------------------------------
# turn on services and cleanup
#-------------------------------------------------
service openvpn start
# to run manually
#openvpn --config server.conf
# to revoke client certificate
#/etc/openvpn/easy-rsa/vars
#/etc/openvpn/easy-rsa/revoke-full client1
service ssh restart
service iptables-persistent reload
service iptables-persistent restart

echo ''
echo 'DONE!'
echo ''

