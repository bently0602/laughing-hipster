#!/bin/bash

yum -y install httpd
yum -y install mod_ssl
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
mkdir /software/webdav-cert
mkdir /webdav
mkdir /webdavguest

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

