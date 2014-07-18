#!/bin/bash

# --------------------------
# STEP 1. Installing Prereqs
# --------------------------
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo '!!! Installing Prereqs !!!'
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
yum -y install wget
yum -y install postgresql postgresql-server

# --------------------------
# STEP 2. Get Mirth & Java
# --------------------------
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
echo '!!! Get Mirth & Java !!!'
echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'

echo ''
echo 'Downloading from Staging...'
echo ''

mkdir -p /software
cd /software
rm -f mirthconnect-2.2.3.6825.b80-linux.rpm
wget http://downloads.mirthcorp.com/connect/2.2.3.6825.b80/mirthconnect-2.2.3.6825.b80-linux.rpm

echo ''
echo 'Installing Java...'
echo ''

# NOTE: uncomment if using openjdk
yum -y install java-1.7.0-openjdk-devel

# NOTE: using oracle jdk
#rm -f jdk-7u65-linux-x64.tar.gz
#wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/7u60-b19/jdk-7u65-linux-x64.tar.gz
#tar zxvf jdk-7u65-linux-x64.tar.gz
#mkdir /usr/java
#mv /software/jdk1.7.0_65/ /usr/java/
#alternatives --install /usr/bin/java java /usr/java/jdk1.7.0_65/jre/bin/java 2000
#alternatives --install /usr/bin/javaws javaws /usr/java/jdk1.7.0_65/jre/bin/javaws 2000

echo ''
echo 'Installing Mirth...'
echo ''

cd /software
rpm -ivh mirthconnect-2.2.3.6825.b80-linux.rpm

echo '
#!/bin/sh
#
# /etc/init.d/mirthconnect
#
# chkconfig:         2345 75 15
# description:       mirthconnect
#

RETVAL=0
prog="mirthconnect"

start() {
        echo -n -e $"Sending start to mcservice...\n"
        /opt/mirthconnect/mcservice start
        RETVAL=$?
        [ "$RETVAL" = 0 ] && touch /var/lock/subsys/$prog
        echo
}

stop() {
        echo -n -e $"Sending stop to mcservice...\n"
        /opt/mirthconnect/mcservice stop
        #killproc $prog -TERM
        RETVAL=$?
        [ "$RETVAL" = 0 ] && rm -f /var/lock/subsys/$prog
        echo
}

case "$1" in
        start)
                start
                ;;
        stop)
                stop
                ;;
        restart)
                stop
                start
                ;;
        condrestart)
                if [ -f /var/lock/subsys/$prog ] ; then
                        stop
                        # avoid race
                        sleep 5
                        start
                fi
                ;;
        status)
                # status mcservice
                /opt/mirthconnect/mcservice status
                RETVAL=$?
                ;;
        *)
                echo $"Usage: $0 {start|stop|restart|condrestart|status}"
                RETVAL=1
esac
exit $RETVAL
' >> /etc/init.d/mirthconnect
chmod +x /etc/init.d/mirthconnect
chkconfig mirthconnect on

rm -f /opt/mirthconnect/mcserver.vmoptions
rm -f /opt/mirthconnect/mcservice.vmoptions

# Settings to tune
#-Xmx5120m
#-XX:+UseConcMarkSweepGC
#-XX:MaxPermSize=1024m
#-XX:PermSize=1024m

echo '
-server
-Xmx256m
-Djava.awt.headless=true
'  >> /opt/mirthconnect/mcserver.vmoptions

echo '
-server
-Xmx256m
-Djava.awt.headless=true
'  >> /opt/mirthconnect/mcservice.vmoptions

rm -f /opt/mirthconnect/conf/mirth.properties

echo '
dir.appdata = appdata
dir.tempdata = temp
http.port = 8080
https.port = 8443
jmx.port = 1099
password.minlength = 0
password.minupper = 0
password.minlower = 0
password.minnumeric = 0
password.minspecial = 0
password.retrylimit = 0
password.lockoutperiod = 0
password.expiration = 0
password.graceperiod = 0
password.reuseperiod = 0
password.reuselimit = 0
keystore.path = ${dir.appdata}/keystore.jks
keystore.storepass = 81uWxplDtB
keystore.keypass = 81uWxplDtB
keystore.type = JCEKS
truststore.path = ${dir.appdata}/truststore.jks
truststore.storepass = 81uWxplDtB
http.contextpath = /
server.url =
jmx.password = admin
http.host = 0.0.0.0
https.host = 0.0.0.0
jmx.host = localhost
#database = derby
#database.url = jdbc:derby:${dir.base}/mirthdb;create=true
database = postgres
database.url = jdbc:postgresql://127.0.0.1:5432/mirthdb
database.username = mirthdb
database.password = mirthdb
' >> /opt/mirthconnect/conf/mirth.properties

echo ''
echo 'Configuring Postgresql...'
echo ''

chkconfig postgresql on
service postgresql initdb

find /var/lib/pgsql/data/postgresql.conf -type f -exec sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" {} \;
rm -f /var/lib/pgsql/data/pg_hba.conf
#local   all         all                               ident
echo '
local   all         postgres                          ident
local   all         all                               ident
host    all         all         127.0.0.1/32          md5
host    all         all         ::1/128               md5
host    all         all         0.0.0.0/0             md5
' >> /var/lib/pgsql/data/pg_hba.conf

service postgresql start

sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"
sudo -u postgres psql -c "CREATE USER mirthdb WITH PASSWORD 'mirthdb';"
sudo -u postgres psql -c "create database mirthdb;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE mirthdb to mirthdb;"

service mirthconnect start
service iptables restart

echo '~~~~~~~~~~~~'
echo ''
echo 'DONE!'
echo ''
echo '~~~~~~~~~~~~'
