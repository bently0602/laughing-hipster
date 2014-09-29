laughing-hipster
================

Setup scripts for a fresh install on CentOS/RHEL 6.5 or Ubuntu 14.04.
The Ubuntu script has more options at them moment.

### Ubuntu
Steps

0. Asks questions for setup.. root pw, OpenVPN encryption settings, etc...
1. Changes root password
2. Updates system and installs tools
3. Sets proper date and time
4. SSH Setup
5. OpenVPN (client-to-client)
6. OpenVPN client certificate walkthrough
7. Firewall
8. Unattended Updates

### RHEL
Steps (split out into different scripts)

0. Asks questions for setup
1. Changes root password
2. Updates system and installs tools
3. Sets proper date and time
4. Firewall
5. Webdav and ssl cert setup
6. SSHD and cert setup (7680 RSA) with ssh passphrase from setup
7. OpenVPN Setup (from EPEL on RHEL, AES-128-CBC, 2048 RSA, uses TLS-AUTH)

### Notes
> RHEL - Creates a single OpenVPN client key called client.key in /etc/openvpn

> OpenVPN port is 1132. This is the only port open to outside.

> 10.8.0.1 is the server's address once your connected via VPN.. All ports are open when connected via VPN.
> Connected clients through VPN start at 10.8.0.2 unless you specify a static ip (Ubuntu script only).

