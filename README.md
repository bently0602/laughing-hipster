laughing-hipster
================

A collection of setup scripts (one per role) for Ubuntu 16.04.
Includes a script to automate the creation of a VPN server that allows inner 
connected client communication (connected client A can communicate directly over 
a secure channel to conencted client B) and a script to install a web browser 
based development IDE (Cloud9) running a self signed SSL and token and password
protected.

Most of these scripts need root access to run, so look over the scripts before 
running. If it breaks you machine I dont assume any responsibility for anything 
it does. It works perfectly for me most every time though. I routinely white 
wash my machines with these scripts.

#### Development Machine Setup Note (devmachine.sh):
_**A basic remote development environment**_

A Cloud9 development environment setup automatically from Cloud9 trunk.

Automatically installs Cloud9 from trunk and setups up a Nginx forward proxy
with self signed SSL and token and password based SSO for all the sites it 
serves.

Installs build-essential, git, python-dev, and nodejs from apt-get.
Setups up cloud9 IDE (from Github https://github.com/bently0602)
and gitr (Github https://github.com/bently0602).

Proxied Over Nginx:
		
	https://IP:(443) <- cloud9 ide (will be setup pointed to a made /software folder)
	https://IP:443/aux8080 <- internal proxied port 8080 access
	https://IP:443/aux8081 <- internal proxied port 8081 access
	
It also creates a /software/archive.sh script to easily archive everything in 
/software as /software.tar.gz.


#### Server Setup Instructions (vpn-server-setup.sh):

> 
> Notes:
> - no IPV6, need to disable and force only IPV4 to route all the traffic through the VPN currently
> - iOS needs to have force AES-CBC enabled through Settings/OpenVPN

1. Run vpn-server-setup.sh for basic setup.
##### vpn-server-setup.sh Steps

	> 0. Asks questions for setup. root pw, OpenVPN encryption settings, etc...
	> 1. Changes root password
	> 2. Updates system and installs tools
	> 3. Sets proper date and time
	> 4. SSH Setup
	> 5. OpenVPN (client-to-client)
	> 6. OpenVPN client certificate walkthrough
	> 7. Firewall
	> 8. Restarting services

###### OpenVPN Server Setup Notes:

> OpenVPN port is 1132. This is the only port open to outside.
> 10.8.0.1 is the server's address once your connected via VPN.
> All ports are open on the server once connected via VPN.
> Connected clients through VPN start at 10.8.0.2 unless you 
	specify a static ip during setup.sh.
> openvpn server.conf is in etc/openvpn to be picked up by default openvpn 
	daemon.

#### Server Utilities (./utils/backup.sh, ./utils/portforwarder):

1. backup.sh is a shortcut for rsync -azP --no-p --no-o between two directories
	> Usage:
	> backup.sh /Files/ /mnt/target
2. portforwarder service - see directory's readme
