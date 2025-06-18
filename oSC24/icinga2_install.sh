#!/bin/sh

# Run this script as root
# This script uses MariaDB database
#
ICINGA_REL=15.5
MARIADB_PASSWD=""
DIRECTOR_DB_PASSWD="myverysecretdirector"
ICINGAWEB_DB_PASSWD="myverysecreticingaweb"
ICINGAIDO_DB_PASSWD="myverysecreticingaido"
IP_ADDRESS=$(hostname -i)

clear


cat <<ET
 ___     _                       ___           _        _ _ 
|_ _|___(_)_ __   __ _  __ _    |_ _|_ __  ___| |_ __ _| | |
 | |/ __| | '_ \ / _\` |/ _\` |    | || '_ \/ __| __/ _\` | | |
 | | (__| | | | | (_| | (_| |    | || | | \__ \ || (_| | | |
|___\___|_|_| |_|\__, |\__,_|   |___|_| |_|___/\__\__,_|_|_|
                 |___/                                      

Installing icinga2.  Please be patient ....
ET


sleep 9


# Prepare Repositories
# Icinga
rpm --import https://packages.icinga.com/icinga.key
zypper -n ar https://packages.icinga.com/openSUSE/ICINGA-release.repo
sed -i "s:\$releasever:$ICINGA_REL:g" /etc/zypp/repos.d/icinga-stable-release.repo
# MariaDB
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --os-type=sles --os-version=15 --skip-maxscale
#
zypper -n ref

# Install MariaDB
zypper -n install --recommends MariaDB-server galera-4 MariaDB-client MariaDB-shared MariaDB-backup MariaDB-common

# Install Icinga2
zypper -n install --recommends icinga2 icinga2-ido-mysql monitoring-plugins-all

# Install Icinga Director
zypper -n install icinga-director

# Install missing php modules
zypper -n install php8-imagick

# Enable and start mariadb
systemctl enable --now mariadb.service

clear
cat <<ET

#######################################################################
WARNING: You are about delete the following databases if they exist !!!

director
icingaweb2
icingaido

Press Enter to proceed or Ctrl +C to cancel
########################################################################

ET
read s

# Drop dbs
for DB in director icingaweb2 icingaido
do

case "${DB}" in
	director)
		USER=director
		PASS=${DIRECTOR_DB_PASSWD}
		;;
	icingaweb2)
		USER=icingaweb
		PASS=${ICINGAWEB_DB_PASSWD}
		;;
	icingaido)
		USER=icinga
		PASS=${ICINGAIDO_DB_PASSWD}
esac

# Drop old database
mariadb-admin drop $DB

# Setup databases
mariadb -p${MARIADB_PASSWD} -e "CREATE DATABASE ${DB} CHARACTER SET 'utf8';
GRANT ALL PRIVILEGES ON ${DB}.* TO '${USER}'@'localhost' IDENTIFIED BY '${PASS}';"
done

# Setup IDO schema for Icinga IDP database
echo "Please be patient while I setup the Icinga IDO database schema ... "
time mariadb -u icinga -p${ICINGAIDO_DB_PASSWD} icingaido < /usr/share/icinga2-ido-mysql/schema/mysql.sql

# Update ido-mysql.conf file
cat > /etc/icinga2/features-available/ido-mysql.conf <<ET
object IdoMysqlConnection "ido-mysql" {
  user = "icinga"
  password = "${ICINGAIDO_DB_PASSWD}"
  host = "localhost"
  database = "icingaido"
}
ET

# Setup api
icinga2 api setup
API_USER=$(awk -F'"' '/object ApiUser/ {print $2}'  /etc/icinga2/conf.d/api-users.conf)
API_PASSWD=$(awk -F'"' '/password/ {print $2}'  /etc/icinga2/conf.d/api-users.conf)
export API_USER API_PASSWD

# Enable extra features
icinga2 feature enable ido-mysql

# Check icinga configuration syntax
icinga2 daemon -C
icinga2 daemon -C --dump-objects

# Enable and start icinga
systemctl enable --now icinga2.service

# Configure apache webserver to support rewrite
a2enmod rewrite

# Enable and start apache
systemctl enable --now apache2.service
ET


clear
cat <<ET

#################################################################
Installation of Icinga2 is complete!

Now run Icinga Web 2 Setup using the following Informationn:

http://${IP_ADDRESS}/icingaweb2/setup

Access using the following:

Username: 
Password:

Setup token is: 

API Credentials
---------------
API Username:	${API_USER}
API Password:	${API_PASSWD}


#################################################################

ET

# Setup token
# Add credentials for DB
# Admin user & password
