#!/bin/bash

echo "To see CRON logs use:"
echo "grep CRON /var/log/syslog"
echo "To manually edit (or remove jobs):"
echo "crontab -u root -e"

echo "Installing cron if needed."
apt-get -y -qq install cron

echo "Creating update cron task at /update.sh"
rm -f /update.sh
echo "
#!/bin/bash

t=\`date +%Y%m%d%H%M%S\`
echo \"update.sh Starting update \$t\" >> /updates.log
apt-get -qq -y update
echo \"update.sh Starting upgrade\" >> /updates.log
apt-get upgrade -q -y >> /updates.log

t=\`date +%Y%m%d%H%M%S\`
echo \"update.sh Finishing \$t\" >> /updates.log
" >> /update.sh
chmod +x /update.sh

echo "Creating dist-update cron task at /dist-update.sh"
rm -f /dist-update.sh
echo "
#!/bin/bash

t=\`date +%Y%m%d%H%M%S\`
echo \"dist-update.sh Starting update \$t\" >> /updates.log
apt-get -qq -y update
echo \"dist-update.sh Starting dist-upgrade\" >> /updates.log
apt-get dist-upgrade -q -y >> /updates.log

t=\`date +%Y%m%d%H%M%S\`
echo \"dist-update.sh Finishing \$t\" >> /updates.log
echo 'dist-update.sh Restarting...' >> /updates.log
/sbin/shutdown -r now 
" >> /dist-update.sh
chmod +x /dist-update.sh

echo "Adding update.sh task every 15mins besides 3 or 4 AM."
line="*/15 0-2,5-23 * * * /update.sh"
(crontab -u root -l; echo "$line" ) | crontab -u root -

echo "Adding dist-update.sh task every day at 3:15 AM."
line="15 3 * * * /dist-update.sh"
(crontab -u root -l; echo "$line" ) | crontab -u root -

echo "Restarting cron."
service cron restart
