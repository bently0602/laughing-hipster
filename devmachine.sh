#! /bin/bash

apt-get -y update
apt-get -y upgrade
apt-get -y install libpam-google-authenticator git nodejs npm nodejs-legacy nginx nginx-extras openssl tmux pwgen qrencode
apt-get -y install build-essential python-dev
apt-get -y install ntp ntpdate ntp-doc fail2ban unattended-upgrades update-notifier-common

# update time and install ntp
service ntp stop
ntpdate pool.ntp.org
service ntp start

echo "About to configure unattended-upgrades. Select yes to the prompts."
read -n1 -r -p "Press any key to continue..." key
dpkg-reconfigure unattended-upgrades # select yes
echo 'APT::Periodic::Update-Package-Lists "1";' >> /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Download-Upgradeable-Packages "1";' >> /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::AutocleanInterval "7";' >> /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Unattended-Upgrade "1";' >> /etc/apt/apt.conf.d/20auto-upgrades
echo 'Unattended-Upgrade::Automatic-Reboot "true";' >> /etc/apt/apt.conf.d/50unattended-upgrades

# -------------------------------------------------
# setup firewall and google authenticator for ssh
# -------------------------------------------------

#google-authenticator -f -t -d -r 3 -R 30 -w 17

#find /etc/ssh/sshd_config -type f -exec sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' {} \;
#find /etc/ssh/sshd_config -type f -exec sed -i 's/Port 22/Port 22/g' {} \;

#echo "auth required pam_google_authenticator.so" | sudo tee -a /etc/pam.d/sshd

ufw default deny incoming
ufw default allow outgoing

#
# EDIT YOUR IPS TO ALLOW HERE
#
#ufw allow from 111.111.111.111 proto tcp to any port 22
echo '~~~~~Allow IPS~~~~~'
echo '-include the one your accessing from-'
while true; do
	echo -n "Client IP to allow for port 22: [xxx.xxx.xxx.xxx/list/q] ('q' to finish): "; read clientIPInput;

	if [ "$clientIPInput" == "q" ]; then
		break
	elif [ "$clientIPInput" == "list" ]; then
	    ufw status
	else
        # ufw allow from "$clientIPInput" proto tcp to any port 443
        # ufw allow from "$clientIPInput" proto tcp to any port 8080
        # ufw allow from "$clientIPInput" proto tcp to any port 8888
        # ufw allow from "$clientIPInput" proto tcp to any port 80
        ufw allow from "$clientIPInput" proto tcp to any port 22
	fi
done

ufw allow 443/tcp

# -------------------------------------------------
# setup cloud 9 and gitr and tty.js
# -------------------------------------------------
cd /
mkdir /software
cd /software
git clone git://github.com/c9/core.git
git clone https://github.com/bently0602/gitr.git

ln -s /software/gitr/gitr /usr/bin/gitr

cd core
./scripts/install-sdk.sh

# -------------------------------------------------
# setup nginx proxy
# -------------------------------------------------
usermod -a -G shadow www-data

# store all the certs here
mkdir -p /etc/nginx/ssl
cd /etc/nginx/ssl

echo 'Setting up self signed cert.'
echo 'Youll be asked for a passphrase. The rest just press enter.'
# for nginx
openssl genrsa -des3 -out server.key 2048
openssl req -new -key server.key -out server.csr
cp server.key server.key.bak
openssl rsa -in server.key.bak -out server.key
openssl x509 -req -in server.csr -signkey server.key -out server.crt

rm -f /etc/nginx/nginx.conf
echo '
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
	worker_connections 768;
	# multi_accept on;
}

http {
	limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;

	##
	# Basic Settings
	##

	sendfile on;
	tcp_nopush on;
	tcp_nodelay on;
	keepalive_timeout 65;
	types_hash_max_size 2048;
	# server_tokens off;

	# server_names_hash_bucket_size 64;
	# server_name_in_redirect off;

	include /etc/nginx/mime.types;
	default_type application/octet-stream;

	##
	# SSL Settings
	##

	ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # Dropping SSLv3, ref: POODLE
	ssl_prefer_server_ciphers on;

	##
	# Logging Settings
	##

	access_log /var/log/nginx/access.log;
	error_log /var/log/nginx/error.log;

	##
	# Gzip Settings
	##

	gzip on;
	gzip_disable "msie6";

	# gzip_vary on;
	# gzip_proxied any;
	# gzip_comp_level 6;
	# gzip_buffers 16 8k;
	# gzip_http_version 1.1;
	# gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

	lua_code_cache on;
	lua_package_path "/etc/nginx/conf.d/src/?.lua;;";
	lua_shared_dict     access_tokens    1M;
	
	##
	# Virtual Host Configs
	##
	include /etc/nginx/conf.d/*.conf;
	include /etc/nginx/sites-enabled/*;
}
' >> /etc/nginx/nginx.conf

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
	
	location /login {
	    limit_req zone=login burst=1;
        content_by_lua_block {
            require("login")()
        }
    }
    
    location /xxxtestsecured {
        access_by_lua_block {
            require("secured")()
        }
        echo -n "hello from secured";
    }

	location / {
        access_by_lua_block {
            require("secured")()
        }
		# auth_pam "Secure Zone";
		# auth_pam_service_name "nginx";
		
		client_max_body_size 20M;
    	proxy_redirect    off;

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

		proxy_pass http://127.0.0.1:8888;
	}

	location /aux8080/ {
        access_by_lua_block {
            require("secured")()
        }		
		# auth_pam "Secure Zone";
		# auth_pam_service_name "nginx";
		
		client_max_body_size 20M;

		proxy_set_header X-Forwarded-Proto https;
    	proxy_redirect    off;

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

		proxy_pass http://127.0.0.1:8080/;
	}

	location /aux8081/ {
        access_by_lua_block {
            require("secured")()
        }		
		# auth_pam "Secure Zone";
		# auth_pam_service_name "nginx";
		
		client_max_body_size 20M;

		proxy_set_header X-Forwarded-Proto https;
    	proxy_redirect    off;

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

		proxy_pass http://127.0.0.1:8081/;
	}		
}
' >> /etc/nginx/conf.d/main.conf

mkdir -p /etc/nginx/conf.d/src
mkdir -p /etc/nginx/conf.d/src/libs

echo '
local Settings = {}

Settings["max_invalid_attempts"] = 4
Settings["max_invalid_accesses"] = 4
Settings["invalid_timeout"] = 21600 -- seconds -- 6 hours
Settings["token_size"] = 300

' >> /etc/nginx/conf.d/src/settings.lua

secureRandomAuthCodeGen=`python -c "import os; import base64; string = base64.b32encode(os.urandom(20)); print string.lower();"`

echo "Enter the web credentials:"
echo "Enter username: "
read input_username
echo "Enter password: "
read input_password
echo 'Settings["username_check"] = "'"$input_username"'"' >> /etc/nginx/conf.d/src/settings.lua
echo 'Settings["password_check"] = "'"$input_password"'"' >> /etc/nginx/conf.d/src/settings.lua
echo 'Settings["auth_code_check"] = "'"$secureRandomAuthCodeGen"'"' >> /etc/nginx/conf.d/src/settings.lua
echo 'return Settings' >> /etc/nginx/conf.d/src/settings.lua

echo ""
echo 'USE THIS FOR GOOGLE AUTHENTICATOR (sepearte every 4 chars)'
echo $secureRandomAuthCodeGen
ex=`python -c "string = '$secureRandomAuthCodeGen'; length = 4; print ' '.join(string[i:i+length] for i in xrange(0,len(string),length))"`
echo $ex
# echo -n $secureRandomAuthCodeGen | qrencode -t ANSI -o-
# echo -n $ex | awk -v ORS="" '{ print toupper($0) }' | qrencode -t ANSI -o-
echo ""
read -n1 -r -p "Press any key to continue..." key

cd /etc/nginx/conf.d/src
wget https://raw.githubusercontent.com/bently0602/laughing-hipster/master/src/login.lua
wget https://raw.githubusercontent.com/bently0602/laughing-hipster/master/src/secured.lua
cd /etc/nginx/conf.d/src/libs
wget https://raw.githubusercontent.com/bently0602/laughing-hipster/master/src/libs/basexx.lua
wget https://raw.githubusercontent.com/bently0602/laughing-hipster/master/src/libs/bit32.lua
wget https://raw.githubusercontent.com/bently0602/laughing-hipster/master/src/libs/cookie.lua
wget https://raw.githubusercontent.com/bently0602/laughing-hipster/master/src/libs/gauth.lua
wget https://raw.githubusercontent.com/bently0602/laughing-hipster/master/src/libs/random.lua
wget https://raw.githubusercontent.com/bently0602/laughing-hipster/master/src/libs/sha1.lua
wget https://raw.githubusercontent.com/bently0602/laughing-hipster/master/src/libs/sha1_bit32.lua

echo '#! /bin/bash
node /software/core/server.js --listen 127.0.0.1 --port 8888 -w /software
' >> /runcloud9.sh
chmod +x /runcloud9.sh

echo '#!/bin/bash

tar -zcvf /software.tar.gz /software
' >> /software/archive.sh

cd /software
echo '[Unit]
Description=cloud9 ide

[Service]
ExecStart=/bin/sh /runcloud9.sh
Restart=always
Type=simple
User=root

[Install]
WantedBy=multi-user.target
' >> /etc/systemd/system/cloud9.service

systemctl daemon-reload
systemctl enable cloud9.service
systemctl start cloud9.service

systemctl restart nginx.service

ufw enable
ufw status

echo 'now finished!!!'
echo 'shutdown -r now recommended'
echo '---------------------------'
echo '/runcloud9.sh runs cloud 9 but this is'
echo 'already started for you as a daemon.'
echo '---------------------------'
echo ''
echo 'open ports 8080(/aux8080) and 8081(/aux8081)'
echo '---------------------------'
echo 'Ex. an auxillary http proxy /aux8080 pointed to 8080'
echo 'in your apps bind to 0.0.0.0 and 8080. you can then access'
echo 'it through https://domain/aux8080'

service ssh restart
