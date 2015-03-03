laughing-hipster
================

A collection of scripts for a Ubuntu 14.04 install.
Includes a script to automate the creation of a  VPN server that allows inter 
connected client communication (connected
client A can communicate directly over a secure channel to conencted client B),
a remote devmachine (cloud9 web ide, gitr - my own workaround for dealing with
specifying keys, and a modified tty.js project all setup up proxied over SSL 
with nginx), a easy backup script, and a port forwarding setup script.

It should go without saying that these scripts need root access to run, so 
look over the scripts before running. If it breaks you machine I dont assume
any resonablilty for anything it does. That said it works perfectly for me 
every time. I routinely white wash my machines with these scripts.

#### Server Setup Instructions:

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

#### Server Utilities:
1. backup.sh is a shortcut for rsync -azP --no-p --no-o between two directories
	> Usage:
	> backup.sh /Files/ /mnt/target
2. portforwarder service - see directory's readme

#### Server Setup Notes:

> OpenVPN port is 1132. This is the only port open to outside.

> 10.8.0.1 is the server's address once your connected via VPN.

> All ports are open when connected via VPN.

> Connected clients through VPN start at 10.8.0.2 unless you 
	specify a static ip during setup.sh.
	
> openvpn server.conf is in etc/openvpn to be picked up by default openvpn 
	daemon.

#### Development Machine Setup Note:
The script will prompt for IPs to allow access to the machine.
If using in coordination with the server VPN script included you should 
probably include the IP of that machine along with any home or work IPs.

	https://IP:8081 <- aux or tty.js
	https://IP <- cloud9 ide (will be setup pointed to a made /software folder)
	