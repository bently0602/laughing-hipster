laughing-hipster
================

A collection of scripts for a Ubuntu 14.04 install.
Includes a script to automate the creation of a VPN server that allows inner 
connected client communication (connected client A can communicate directly over 
a secure channel to conencted client B), a remote devmachine, 
an easy backup script, and a port forwarding setup script.

Most of these scripts need root access to run, so look over the scripts before 
running. If it breaks you machine I dont assume any resonablilty for anything it
does. That said it works perfectly for me most every time.
I routinely white wash my machines with these scripts.

#### Server Setup Instructions (server-setup.sh):

1. Run server-setup.sh for basic setup.
##### server-setup.sh Steps

	> 0. Asks questions for setup. root pw, OpenVPN encryption settings, etc...
	> 1. Changes root password
	> 2. Updates system and installs tools
	> 3. Sets proper date and time
	> 4. SSH Setup
	> 5. OpenVPN (client-to-client)
	> 6. OpenVPN client certificate walkthrough
	> 7. Firewall
	> 8. Restarting services

2. Run autoupdates.sh if wanted. 
	update & upgrade every 15 mins except from 3 to 5.
	update & dist-upgrade every morning at 3:15am then after restart.

##### OpenVPN Server Setup Notes:

> OpenVPN port is 1132. This is the only port open to outside.
> 10.8.0.1 is the server's address once your connected via VPN.
> All ports are open on the server once connected via VPN.
> Connected clients through VPN start at 10.8.0.2 unless you 
	specify a static ip during setup.sh.
> openvpn server.conf is in etc/openvpn to be picked up by default openvpn 
	daemon.

#### Server Utilities (autoupdates.sh, backup.sh, ./portforwarder):
_**A basic remote development environment.**_

1. backup.sh is a shortcut for rsync -azP --no-p --no-o between two directories
	> Usage:
	> backup.sh /Files/ /mnt/target
2. portforwarder service - see directory's readme

#### Development Machine Setup Note (devmachine-setup.sh):
_**A basic remote development environment**_

Installs build-essential, git, python-dev, and nodejs from apt-get.
Setups up cloud9 IDE (from Github https://github.com/bently0602), 
tty.js (from Github https://github.com/bently0602), ipython notebook,
and gitr (Github https://github.com/bently0602).

SSH is also protected by google authenticator so make sure you have that setup 
on a phone or similar before running this without modification.
The script will prompt for specific IPs to allow access to the machine on ports
_22, 80, 443, 8080, 8888_.
If using in coordination with the included server VPN script you should 
probably include the IP of that machine along with any other IPs you want to directly
access it from.

Proxied Over Nginx:

	https://IP:8081 <- aux or tty.js
						PAM basic auth
		
	https://IP:(443) <- cloud9 ide (will be setup pointed to a made /software folder)
						PAM basic auth
						
	http://IP:(80) <- open pointed to nothing

Standalone (had problems with WS over basic auth proxy):

	https://IP:8888 <- ipython notebook with root at /software/notebooks
						Authentication is set when you run ./ipythonnotebook.py

Nothing is setup to run as a daemon on the development server.
I run everything inside of tmux. The devmachine-setup.sh script creates:

	/runcloud9.sh
	/runtty.sh
	/ipythonnotebook.py
	
for easy running. It also creates a /software/archive.sh script to easily archive
everything in /software as /software.tar.gz