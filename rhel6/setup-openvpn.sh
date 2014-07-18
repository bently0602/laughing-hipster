#!/bin/bash

# install OpenVPN AS
#mkdir /software/openvpn-as
#wget http://swupdate.openvpn.org/as/openvpn-as-2.0.3-CentOS6.x86_64.rpm
#rpm -Uvh openvpn-as-2.0.3-CentOS6.x86_64.rpm
#passwd openvpn

read -p 'inet facing ipaddress (maybe eth0?): ' inetFacingIPaddress 
echo ''

# --------------------------
# STEP 5. OPENVPN
# --------------------------
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
group nobody
persist-key
persist-tun
status openvpn-status.log
verb 3
' >> /etc/openvpn/server.conf

mkdir -p /etc/openvpn/easy-rsa/keys
cp -rf /usr/share/easy-rsa/2.0 /etc/openvpn/easy-rsa

echo '
export KEY_SIZE=2048
export KEY_CN="CommonName"
export KEY_NAME=changeme
export KEY_COUNTRY="US"
export KEY_PROVINCE="CA"
export KEY_CITY="SanFrancisco"
export KEY_ORG="LPWEF"
export KEY_EMAIL="me@myhost.mydomain"
' >> /etc/openvpn/easy-rsa/2.0/xtravars

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
source ./xtravars
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

