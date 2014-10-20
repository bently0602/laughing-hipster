#! /bin/bash

set -e

#
# SETUP SCRIPT
# - tested on ubuntu 14.04
# - required to be ran as root
#

if [ ! -e /usr/bin/dialog ]; then
	echo '--------------------------------'
	echo "Installing the dialog package"
	echo "before beginning..."
	echo '--------------------------------'
	apt-get -y install dialog
fi

exampleExternalIPAddress=`ifconfig 'eth0' | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`

dialog --clear --backtitle "Ubuntu 14.04 Setup Script" --title "Setup Values" --form "\nPlease fill in the following values:" 25 60 16 "ROOT password:" 1 1 "" 1 25 25 30 "INET Facing IP(eth0):" 2 1 $exampleExternalIPAddress 2 25 25 30 "External Interface:" 3 1 "eth0" 3 25 25 30 "SSH Pass( > 3 chars):" 4 1 "" 4 25 25 30 "SSH Key(y/n):" 5 1 "n" 5 25 25 30 "Cipher:" 6 1 "AES-256-CBC" 6 25 25 30 "TLS Cipher:" 7 1 "TLS-DHE-RSA-WITH-AES-256-CBC-SHA" 7 25 25 30 "Auth Digest:" 8 1 "SHA256" 8 25 25 30 "Key Size:" 9 1 "2048" 9 25 25 30 2>/tmp/form.$$

rootPassword=`sed -n '1,1p' /tmp/form.$$`
inetFacingIPaddress=`sed -n '2,2p' /tmp/form.$$`
externalInterface=`sed -n '3,3p' /tmp/form.$$`
sshPassphrase=`sed -n '4,4p' /tmp/form.$$`
createSSHKey=`sed -n '5,5p' /tmp/form.$$`
openvpnCIPHER=`sed -n '6,6p' /tmp/form.$$`
openvpnTLS=`sed -n '7,7p' /tmp/form.$$`
openvpnDIGEST=`sed -n '8,8p' /tmp/form.$$`
openvpnKEYSIZE=`sed -n '9,9p' /tmp/form.$$`

rm -f /tmp/form.$$

#-------------------------------------------------
# set root password
#-------------------------------------------------
echo "root:$rootPassword" | chpasswd
unset rootPassword

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
if  [ $createSSHKey == "y" ]; then
	echo "Creating Server SSH Key for user."
	ssh-keygen -t rsa -b 7680 -N $sshPassphrase -f "/root/.ssh/server_id_rsa" -C "$(whoami)@$(hostname)-$(date -I)"
	cat /root/.ssh/server_id_rsa.pub >> /root/.ssh/authorized_keys
	# Settings 
	find /etc/ssh/sshd_config -type f -exec sed -i 's/LoginGraceTime 120/LoginGraceTime 60/g' {} \;
	find /etc/ssh/sshd_config -type f -exec sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' {} \;
	find /etc/ssh/sshd_config -type f -exec sed -i 's/UsePAM yes/UsePAM no/g' {} \;
	find /etc/ssh/sshd_config -type f -exec sed -i 's/PermitRootLogin yes/PermitRootLogin without-password/g' {} \;
	unset sshPassphrase
fi

#-------------------------------------------------
# openvpn setup
#-------------------------------------------------

	# to run manually
	#openvpn --config server.conf
	# to revoke client certificate
	# at a later date run source ./vars & ./xtravars before adding or removing clients
	# then
	#/etc/openvpn/easy-rsa/revoke-full client1

# for tls-cipher
# openvpn --show-tls
# for cipher
# openvpn --show-ciphers
# for auth
# openvpn --show-digests
AUTHSECTION="
cipher $openvpnCIPHER
tls-cipher $openvpnTLS
auth $openvpnDIGEST
"
SHAREDSECTION="
comp-lzo
"
echo '
port 1132
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /etc/openvpn/ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
client-to-client
duplicate-cn
keepalive 10 120
tls-auth ta.key 0
user nobody
group nogroup
persist-key
persist-tun
status /etc/openvpn/openvpn-status.log
verb 3
# revoking support
# crl-verify /etc/openvpn/easy-rsa/keys/crl.pem
' >> /etc/openvpn/server.conf
echo "$AUTHSECTION" >> /etc/openvpn/server.conf
echo "$SHAREDSECTION" >> /etc/openvpn/server.conf

rm -fr /etc/openvpn/easy-rsa
mkdir /etc/openvpn/easy-rsa
cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa
mkdir -p /etc/openvpn/easy-rsa/keys
cd /etc/openvpn/easy-rsa

# setup directory to match CNs to static ips
mkdir /etc/openvpn/staticclients

# in case updating openssl messes with the version number
# easy-rsa expects for configuration
cp /etc/openvpn/easy-rsa/openssl-1.0.0.cnf /etc/openvpn/easy-rsa/openssl.cnf

echo "
export KEY_CONFIG=\"/etc/openvpn/easy-rsa/openssl.cnf\"
export KEY_SIZE=$openvpnKEYSIZE
export KEY_CN=\"DNS:www.private.server.com\"
export KEY_NAME=changeme
export KEY_COUNTRY=\"US\"
export KEY_PROVINCE=\"CA\"
export KEY_CITY=\"SanFrancisco\"
export KEY_ORG=\"LPWEF\"
export KEY_EMAIL=\"me@myhost.mydomain\"
" >> /etc/openvpn/easy-rsa/xtravars

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
echo '~~~~~Building DH Params~~~~~'
find /etc/openvpn/easy-rsa/build-dh -type f -exec sed -i 's/\$OPENSSL dhparam -out \${KEY_DIR}\/dh\${KEY_SIZE}.pem \${KEY_SIZE\}/\$OPENSSL dhparam -out \${KEY_DIR}\/dh.pem \${KEY_SIZE}/g' {} \;
./build-dh
echo '~~~~~Generate TLS~~~~~'
openvpn --genkey --secret /etc/openvpn/ta.key

# copy the server keys out and put them at the root of /etc/openvpn
# so the server.opvn can see them and client config creation can see them
cp -f /etc/openvpn/easy-rsa/keys/dh.pem /etc/openvpn/dh.pem
cp -f /etc/openvpn/easy-rsa/keys/ca.crt /etc/openvpn/ca.crt
cp -f /etc/openvpn/easy-rsa/keys/server.crt /etc/openvpn/server.crt
cp -f /etc/openvpn/easy-rsa/keys/server.key /etc/openvpn/server.key

#rm -rf "/etc/openvpn/easy-rsa/keys/server.crt"
#rm -rf "/etc/openvpn/easy-rsa/keys/server.key"
#rm -rf "/etc/openvpn/easy-rsa/keys/server.csr"
#rm -rf "/etc/openvpn/easy-rsa/keys/ca.crt"
#rm -rf "/etc/openvpn/easy-rsa/keys/dh.pem"

# BEGIN CLIENT CERT CREATE
# Create as many client keys as needed!
#
echo '~~~~~Create Client Certs~~~~~'
while true; do

	echo -n "Client Cert for OpenVPN Options: [add/remove/list/q] ('q' to finish): "; read clientCertInput;

	if [ "$clientCertInput" == "q" ]; then
		break
	elif [ "$clientCertInput" == "list" ]; then
		echo "List of Current Static Client Certs"
		echo "ls /etc/openvpn/staticclients"
		echo "-------------------------------------"
		ls /etc/openvpn/staticclients
		echo ""
		echo "index.txt Keys"
		echo "cat /etc/openvpn/easy-rsa/keys/index.txt"
		echo "-------------------------------------"
		cat /etc/openvpn/easy-rsa/keys/index.txt
		echo ""
		# openssl crl -in /etc/openvpn/easy-rsa/keys/crl.pem -text
	elif [ "$clientCertInput" == "remove" ]; then
		echo -n "Enter client name: "; read clientName;
		if [ "$clientName" == "server" ]; then
			echo "Cannot delete server."
			continue
		fi
		# this will throw an error which would normally stop the script
		# because of set -e. So turn it off temp.		
		set +e
		# That is what you want to see, as it indicates that a certificate verification of the revoked certificate failed.
		# It revocates it, and then tries to verify the revoked cert to make sure it is revoked.
		KEY_CN="DNS:www.""$clientName"".com" ./revoke-full "$clientName"
		set -e
		rm -f "/etc/openvpn/""$clientName"".ovpn"
		rm -f "/etc/openvpn/staticclients/""$clientName"
	elif [ "$clientCertInput" == "add" ]; then
		echo "Client name cannot contain spaces, special characters besides -, or be named server. "
		echo "(This will also become the CN in www.clientname.com format): ";
		echo -n "Enter client name: "; read clientName;
		if [ "$clientName" == "server" ]; then
			echo "A client cannot be named server."
			continue
		fi

		echo "Does this client need"/etc/openvpn/staticclients/""$clientName""/etc/openvpn/staticclients/""$clientName" a static ip address?"
		echo -n "[* is no; any other should be in 10.8.0.0/255.255.255.0 i.e. 10.8.0.5]: "; read clientStaticIP;
		# at a later date run source ./vars & ./xtravars before adding or removing clients
		echo "~~~~~Building Client Cert for $clientName~~~~~"
		# each client certificate needs a unique CommonName
		KEY_CN="DNS:www.""$clientName"".com" ./build-key "$clientName"

echo "# $clientName
client
dev tun
proto udp
remote $inetFacingIPaddress 1132
resolv-retry infinite
nobind
persist-key
persist-tun
ns-cert-type server
verb 3
redirect-gateway
key-direction 1
remote-cert-tls server" >> "/etc/openvpn/""$clientName"".ovpn"
echo "$AUTHSECTION" >> "/etc/openvpn/""$clientName"".ovpn"
echo "$SHAREDSECTION" >> "/etc/openvpn/""$clientName"".ovpn"

echo "<ca>" >> "/etc/openvpn/""$clientName"".ovpn"
cat /etc/openvpn/ca.crt >> "/etc/openvpn/""$clientName"".ovpn"
echo "</ca>" >> "/etc/openvpn/""$clientName"".ovpn"

echo "<cert>
-----BEGIN CERTIFICATE-----" >> "/etc/openvpn/""$clientName"".ovpn"
cat "/etc/openvpn/easy-rsa/keys/""$clientName"".crt" | sed -n "/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p" | head -n-1 | tail -n+2 >> "/etc/openvpn/""$clientName"".ovpn"
echo "-----END CERTIFICATE-----
</cert>" >> "/etc/openvpn/""$clientName"".ovpn"

echo '<key>' >> "/etc/openvpn/""$clientName"".ovpn"
cat "/etc/openvpn/easy-rsa/keys/""$clientName"".key" >> "/etc/openvpn/""$clientName"".ovpn"
echo '</key>' >> "/etc/openvpn/""$clientName"".ovpn"

echo '<tls-auth>' >> "/etc/openvpn/""$clientName"".ovpn"
cat /etc/openvpn/ta.key >> "/etc/openvpn/""$clientName"".ovpn"
echo '</tls-auth>' >> "/etc/openvpn/""$clientName"".ovpn"

		# make the file to put the static IP in
		if [ "$clientStaticIP" != "*" ]; then
			echo "ifconfig-push $clientStaticIP 255.255.255.0" >> "/etc/openvpn/staticclients/""$clientName"
		else
			echo "" >> "/etc/openvpn/staticclients/""$clientName"
		fi
		
		# delete the keys, etc.. we are not using anymore 
		# because it's embedded in the opvn file
		# we delete the ovpn file later when its spit
		# back out to the terminal
		rm -rf "/etc/openvpn/easy-rsa/keys/""$clientName"".crt"
		rm -rf "/etc/openvpn/easy-rsa/keys/""$clientName"".key"
		rm -rf "/etc/openvpn/easy-rsa/keys/""$clientName"".csr"
	# a value not allowed was inputed
	else
		echo "Not a valid input."
	fi
done

# END CLIENT CERT CREATE
echo '~~~~~Done Building Client Certs~~~~~'

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
echo ""
echo '----------------------------------'
echo "CLIENT OPENVPN CONFIGURATION FILES"
echo '----------------------------------'
cd /etc/openvpn
EXT=ovpn
for i in $(ls);do
    if [ "${i}" != "${i%.${EXT}}" ]; then
	if [ "$i" != "server.ovpn" ]; then
		echo ""
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		echo "Client Config File $i"
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
		cat "/etc/openvpn/""$i"
		rm -f "/etc/openvpn/""$i"
		echo ""
	fi
    fi
done

if [ -f /root/.ssh/server_id_rsa ]; then
	echo '----------------------------------'
	echo "SSH ID FILE"
	echo '----------------------------------'
	cat /root/.ssh/server_id_rsa
	rm -f /root/.ssh/server_id_rsa
fi
echo ""
echo '----------------------------------'
echo "IPTABLES RULES"
echo '----------------------------------'
#iptables -L -n
iptables -S
echo ""
echo '----------------------------------'
echo "IPTABLES IPv6 RULES"
echo '----------------------------------'
#ip6tables -v -nL | grep DROP
ip6tables -S
echo ""

echo -n "Cleanup and Turn ON / Restart Services? [y/n]: "; read cleanupAndRestart;

if [ "$cleanupAndRestart" == "y" ]; then
	#-------------------------------------------------
	# turn on services and cleanup
	#-------------------------------------------------
	service openvpn start

	echo " * Restarting and Reloading iptables-persistent..."
	service iptables-persistent reload
	service iptables-persistent restart

	if [ "$createSSHKey" == "y" ]; then
		service ssh restart
	fi
fi

echo ''
echo 'DONE!'
echo ''
