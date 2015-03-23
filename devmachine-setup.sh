#! /bin/bash

apt-get -y update
apt-get -y upgrade
apt-get -y install libpam-google-authenticator git nodejs npm nodejs-legacy nginx nginx-extras openssl tmux
apt-get -y install build-essential python-dev

# -------------------------------------------------
# setup firewall and google authenticator for ssh
# -------------------------------------------------

google-authenticator -f -t -d -r 3 -R 30 -w 17

find /etc/ssh/sshd_config -type f -exec sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' {} \;
find /etc/ssh/sshd_config -type f -exec sed -i 's/Port 22/Port 22/g' {} \;

echo "auth required pam_google_authenticator.so" | sudo tee -a /etc/pam.d/sshd

ufw default deny incoming
ufw default allow outgoing

#
# EDIT YOUR IPS TO ALLOW HERE
#
#ufw allow from 111.111.111.111 proto tcp to any port 22
echo '~~~~~Allow IPS~~~~~'
while true; do
	echo -n "Client IP to allow: [xxx.xxx.xxx.xxx/list/q] ('q' to finish): "; read clientIPInput;

	if [ "$clientIPInput" == "q" ]; then
		break
	elif [ "$clientIPInput" == "list" ]; then
	    ufw status
	else
	        ufw allow from "$clientIPInput" proto tcp to any port 443
	        ufw allow from "$clientIPInput" proto tcp to any port 8080
	        ufw allow from "$clientIPInput" proto tcp to any port 8888
	        ufw allow from "$clientIPInput" proto tcp to any port 80
	        ufw allow from "$clientIPInput" proto tcp to any port 22
    	fi
    
service ssh restart

ufw enable
ufw status

# -------------------------------------------------
# setup cloud 9 and gitr and tty.js
# -------------------------------------------------
cd /
mkdir /software
cd /software
git clone https://github.com/bently0602/core.git
git clone https://github.com/bently0602/gitr.git
git clone https://github.com/bently0602/tty.js.git

ln -s /software/gitr/gitr /usr/bin/gitr

cd core
./scripts/install-sdk.sh

mkdir /software/notebooks
pip install "ipython[notebook]"

# -------------------------------------------------
# setup nginx proxy
# -------------------------------------------------
usermod -a -G shadow www-data

# store all the certs here
mkdir -p /etc/nginx/ssl
cd /etc/nginx/ssl

# for nginx
openssl genrsa -des3 -out server.key 2048
openssl req -new -key server.key -out server.csr
cp server.key server.key.bak
openssl rsa -in server.key.bak -out server.key
openssl x509 -req -in server.csr -signkey server.key -out server.crt

# for ipython notebook
openssl req -x509 -nodes -newkey rsa:2048 -keyout ipython.pem -out ipython.pem

echo '
server {
	listen 443;
	ssl on;

	### SSL log files ###
	access_log      /var/log/nginx/ssl-access.log;
	error_log       /var/log/nginx/ssl-error.log;

	### SSL cert files ###
	ssl_certificate      /etc/nginx/ssl/server.crt;
	ssl_certificate_key  /etc/nginx/ssl/server.key;

	### Add SSL specific settings here ###

	# ssl_protocols        SSLv3 TLSv1 TLSv1.1 TLSv1.2;
	# ssl_ciphers RC4:HIGH:!aNULL:!MD5;
	# ssl_prefer_server_ciphers on;
	# keepalive_timeout    60;
	# ssl_session_cache    shared:SSL:10m;
	# ssl_session_timeout  10m;	
	
	error_page 497  https://$host:$server_port$request_uri;
	
	location / {
		auth_pam "Secure Zone";
		auth_pam_service_name "nginx";
		
		client_max_body_size 20M;

		proxy_set_header        X-Forwarded-Proto $scheme;
		add_header              Front-End-Https   on;
		proxy_set_header        Accept-Encoding   "";
		proxy_set_header        Host            $host;
		proxy_set_header        X-Real-IP       $remote_addr;
		proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;

		proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;

		proxy_http_version 1.1;
		proxy_set_header Upgrade $http_upgrade;
		proxy_set_header Connection "upgrade";

		proxy_pass http://127.0.0.1:8181;
	}
}
' >> /etc/nginx/conf.d/cloud9.conf

# for aux
echo '
server {
	listen 8080;
	ssl on;

	### SSL log files ###
	access_log      /var/log/nginx/ssl-access.log;
	error_log       /var/log/nginx/ssl-error.log;

	### SSL cert files ###
	ssl_certificate      /etc/nginx/ssl/server.crt;
	ssl_certificate_key  /etc/nginx/ssl/server.key;

	### Add SSL specific settings here ###

	# ssl_protocols        SSLv3 TLSv1 TLSv1.1 TLSv1.2;
	# ssl_ciphers RC4:HIGH:!aNULL:!MD5;
	# ssl_prefer_server_ciphers on;
	# keepalive_timeout    60;
	# ssl_session_cache    shared:SSL:10m;
	# ssl_session_timeout  10m;	
	
	error_page 497  https://$host:$server_port$request_uri;
	
	location / {
		auth_pam "Secure Zone";
		auth_pam_service_name "nginx";
		
		client_max_body_size 20M;

		proxy_set_header        X-Forwarded-Proto $scheme;
		add_header              Front-End-Https   on;
		proxy_set_header        Accept-Encoding   "";
		proxy_set_header        Host            $host;
		proxy_set_header        X-Real-IP       $remote_addr;
		proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;

		proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;

		proxy_http_version 1.1;
		proxy_set_header Upgrade $http_upgrade;
		proxy_set_header Connection "upgrade";

		proxy_pass http://127.0.0.1:8081;
	}
}
' >> /etc/nginx/conf.d/aux.conf

echo '
# more /etc/pam.d/nginx
@include common-auth
' >> /etc/pam.d/nginx

echo '
#! /bin/bash
node /software/core/server.js --listen 127.0.0.1 --port 8181 -w /software
' >> /runcloud9.sh
chmod +x /runcloud9.sh

echo '
#! /bin/bash
node /software/tty.js/bin/tty.js --port 8081
' >> /runtty.sh
chmod +x /runtty.sh

echo '
from IPython.lib import passwd
import os
print "Enter the password for access to notebooks."
x = passwd()
os.system("cd /software/notebooks && ipython notebook --port 8888 --certfile=/etc/nginx/ssl/ipython.pem --NotebookApp.password="+ x + " --Notebook.App.notebook_dir=/software/notebooks --NotebookApp.ip=\"*\"")
' >> /ipythonnotebook.py

echo '
#!/bin/bash

tar -zcvf /software.tar.gz ./
' >> /software/archive.sh

echo 'shutdown -r now recommended'
echo '/runcloud9.sh runs cloud 9 on https://:443'
echo 'an auxillary http proxy is on port 8080 pointed to 8081'
echo 'ipython notebook server is running on https://:8888'

service nginx restart
service ssh restart