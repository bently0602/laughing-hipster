laughing-hipster
================

Setup scripts for a fresh install on Ubuntu 14.04.

#### Server Setup Instructions:

1. Run setup.sh for basic setup. (See setup.sh Steps)
2. Run autoupdates.sh if wanted. 
	update & upgrade every 15 mins except from 3 to 5.
	update & dist-upgrade every morning at 3:15am then after restart.


#### setup.sh Steps

0. Asks questions for setup.. root pw, OpenVPN encryption settings, etc...
1. Changes root password
2. Updates system and installs tools
3. Sets proper date and time
4. SSH Setup
5. OpenVPN (client-to-client)
6. OpenVPN client certificate walkthrough
7. Firewall
8. Restarting services

#### Server Utilities
1. backup.sh is a shortcut for rsync -azP --no-p --no-o between two directories
2. portforwarder service - see directories readme

#### Notes

> OpenVPN port is 1132. This is the only port open to outside.

> 10.8.0.1 is the server's address once your connected via VPN.. All ports are open when connected via VPN.
> Connected clients through VPN start at 10.8.0.2 unless you specify a static ip during setup.sh.

