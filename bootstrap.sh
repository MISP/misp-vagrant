#! /usr/bin/env bash

MISP_ENV=$1
if [ "$MISP_ENV" != "dev" ]; then
    echo "Deployment of a MISP demo environment..."
else
    echo "Deployment of a MISP development environment..."
fi

# Database configuration
DBHOST='localhost'
DBNAME='misp'
DBUSER_ADMIN='root'
DBPASSWORD_ADMIN="$(openssl rand -hex 32)"
DBUSER_MISP='misp'
DBPASSWORD_MISP="$(openssl rand -hex 32)"

# Webserver configuration
PATH_TO_MISP='/var/www/MISP'
MISP_BASEURL='http://127.0.0.1:5000'
MISP_LIVE='1'
FQDN='localhost'

# OpenSSL configuration
OPENSSL_C='LU'
OPENSSL_ST='State'
OPENSSL_L='Location'
OPENSSL_O='Organization'
OPENSSL_OU='Organizational Unit'
OPENSSL_CN='Common Name'
OPENSSL_EMAILADDRESS='info@localhost'

# GPG configuration
GPG_REAL_NAME='Real name'
GPG_EMAIL_ADDRESS='info@localhost'
GPG_KEY_LENGTH='2048'
GPG_PASSPHRASE=''

# Sane PHP defaults
upload_max_filesize=50M
post_max_size=50M
max_execution_time=300
max_input_time=223
memory_limit=512M
PHP_INI=/etc/php/7.2/apache2/php.ini

export DEBIAN_FRONTEND=noninteractive
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
locale-gen en_US.UTF-8
dpkg-reconfigure locales


echo "--- Installing MISP… ---"
echo "--- Updating packages list ---"
apt-get update


echo "--- Install base packages… ---"
apt-get -y install curl net-tools ifupdown gcc git gnupg-agent make python openssl redis-server sudo vim zip > /dev/null


echo "--- Installing and configuring Postfix… ---"
# # Postfix Configuration: Satellite system
# # change the relay server later with:
# postconf -e 'relayhost = example.com'
# postfix reload
echo "postfix postfix/mailname string `hostname`.misp.local" | debconf-set-selections
echo "postfix postfix/main_mailer_type string 'Satellite system'" | debconf-set-selections
apt-get install -y postfix > /dev/null


echo "--- Installing MariaDB specific packages and settings… ---"
apt-get install -y mariadb-client mariadb-server > /dev/null
# Secure the MariaDB installation (especially by setting a strong root password)
sleep 10 # give some time to the DB to launch...
systemctl restart mariadb.service
apt-get install -y expect > /dev/null
expect -f - <<-EOF
  set timeout 10
  spawn mysql_secure_installation
  expect "Enter current password for root (enter for none):"
  send -- "\r"
  expect "Set root password?"
  send -- "y\r"
  expect "New password:"
  send -- "${DBPASSWORD_ADMIN}\r"
  expect "Re-enter new password:"
  send -- "${DBPASSWORD_ADMIN}\r"
  expect "Remove anonymous users?"
  send -- "y\r"
  expect "Disallow root login remotely?"
  send -- "y\r"
  expect "Remove test database and access to it?"
  send -- "y\r"
  expect "Reload privilege tables now?"
  send -- "y\r"
  expect eof
EOF
apt-get purge -y expect > /dev/null


echo "--- Installing Apache2… ---"
apt-get install -y apache2 apache2-doc apache2-utils > /dev/null
a2dismod status > /dev/null
a2enmod ssl > /dev/null
a2enmod rewrite > /dev/null
a2dissite 000-default > /dev/null
a2ensite default-ssl > /dev/null


echo "--- Installing PHP-specific packages… ---"
apt-get install -y libapache2-mod-php php php-cli php-gnupg php-dev php-json php-mysql php-opcache php-readline php-redis php-xml php-mbstring php-gd > /dev/null



echo -e "\n--- Configuring PHP (sane PHP defaults)… ---\n"
for key in upload_max_filesize post_max_size max_execution_time max_input_time memory_limit
do
 sed -i "s/^\($key\).*/\1 = $(eval echo \${$key})/" $PHP_INI
done


echo "--- Restarting Apache… ---"
systemctl restart apache2 > /dev/null


echo "--- Retrieving MISP… ---"
if [ "$MISP_ENV" != "dev" ]; then
    mkdir $PATH_TO_MISP
    chown www-data:www-data $PATH_TO_MISP
    cd $PATH_TO_MISP
    sudo -u www-data -H git clone https://github.com/MISP/MISP.git $PATH_TO_MISP
else
    chown www-data:www-data $PATH_TO_MISP
    cd $PATH_TO_MISP
fi
#sudo -u www-data -H git checkout tags/$(git describe --tags `git rev-list --tags --max-count=1`)
sudo -u www-data -H git config core.filemode false
# chown -R www-data $PATH_TO_MISP
# chgrp -R www-data $PATH_TO_MISP
# chmod -R 700 $PATH_TO_MISP


echo "--- Installing Mitre's STIX… ---"
apt-get install -y python-dev python-pip libxml2-dev libxslt1-dev zlib1g-dev python-setuptools > /dev/null
cd $PATH_TO_MISP/app/files/scripts
sudo -u www-data -H git clone https://github.com/CybOXProject/python-cybox.git
sudo -u www-data -H git clone https://github.com/STIXProject/python-stix.git
cd $PATH_TO_MISP/app/files/scripts/python-cybox
sudo -u www-data -H git checkout v2.1.0.12
python setup.py install > /dev/null
cd $PATH_TO_MISP/app/files/scripts/python-stix
sudo -u www-data -H git checkout v1.1.1.4
python setup.py install > /dev/null
# install mixbox to accomodate the new STIX dependencies:
cd $PATH_TO_MISP/app/files/scripts/
sudo -u www-data -H git clone https://github.com/CybOXProject/mixbox.git
cd $PATH_TO_MISP/app/files/scripts/mixbox
sudo -u www-data -H git checkout v1.0.2
python setup.py install > /dev/null


echo "--- Retrieving CakePHP… ---"
# CakePHP is included as a submodule of MISP, execute the following commands to let git fetch it:
cd $PATH_TO_MISP
sudo -u www-data -H git submodule init
sudo -u www-data -H git submodule update
# Once done, install CakeResque along with its dependencies if you intend to use the built in background jobs:
cd $PATH_TO_MISP/app
sudo -u www-data -H php composer.phar require kamisama/cake-resque:4.1.2
sudo -u www-data -H php composer.phar config vendor-dir Vendor
sudo -u www-data -H php composer.phar install
# Enable CakeResque with php-redis
phpenmod redis
# To use the scheduler worker for scheduled tasks, do the following:
sudo -u www-data -H cp -fa $PATH_TO_MISP/INSTALL/setup/config.php $PATH_TO_MISP/app/Plugin/CakeResque/Config/config.php


echo "--- Setting the permissions… ---"
chown -R www-data:www-data $PATH_TO_MISP
chmod -R 750 $PATH_TO_MISP
chmod -R g+ws $PATH_TO_MISP/app/tmp
chmod -R g+ws $PATH_TO_MISP/app/files
chmod -R g+ws $PATH_TO_MISP/app/files/scripts/tmp


echo "--- Creating a database user… ---"
mysql -u $DBUSER_ADMIN -p$DBPASSWORD_ADMIN -e "create database $DBNAME;"
mysql -u $DBUSER_ADMIN -p$DBPASSWORD_ADMIN -e "grant usage on *.* to $DBNAME@localhost identified by '$DBPASSWORD_MISP';"
mysql -u $DBUSER_ADMIN -p$DBPASSWORD_ADMIN -e "grant all privileges on $DBNAME.* to '$DBUSER_MISP'@'localhost';"
mysql -u $DBUSER_ADMIN -p$DBPASSWORD_ADMIN -e "flush privileges;"
# Import the empty MISP database from MYSQL.sql
sudo -u www-data -H mysql -u $DBUSER_MISP -p$DBPASSWORD_MISP $DBNAME < /var/www/MISP/INSTALL/MYSQL.sql


echo "--- Configuring Apache… ---"
# !!! apache.24.misp.ssl seems to be missing
#cp $PATH_TO_MISP/INSTALL/apache.24.misp.ssl /etc/apache2/sites-available/misp-ssl.conf
# If a valid SSL certificate is not already created for the server, create a self-signed certificate:
openssl req -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=$OPENSSL_C/ST=$OPENSSL_ST/L=$OPENSSL_L/O=<$OPENSSL_O/OU=$OPENSSL_OU/CN=$OPENSSL_CN/emailAddress=$OPENSSL_EMAILADDRESS" -keyout /etc/ssl/private/misp.local.key -out /etc/ssl/private/misp.local.crt > /dev/null


echo "--- Add a VirtualHost for MISP ---"
cat > /etc/apache2/sites-available/misp-ssl.conf <<EOF
<VirtualHost *:80>
    ServerAdmin admin@misp.local
    ServerName misp.local
    DocumentRoot $PATH_TO_MISP/app/webroot

    <Directory $PATH_TO_MISP/app/webroot>
        Options -Indexes
        AllowOverride all
        Require all granted
    </Directory>

    LogLevel warn
    ErrorLog /var/log/apache2/misp.local_error.log
    CustomLog /var/log/apache2/misp.local_access.log combined
    ServerSignature Off
</VirtualHost>
EOF
# activate new vhost
a2dissite default-ssl
a2ensite misp-ssl


echo "--- Restarting Apache… ---"
systemctl restart apache2 > /dev/null


echo "--- Configuring log rotation… ---"
cp $PATH_TO_MISP/INSTALL/misp.logrotate /etc/logrotate.d/misp


echo "--- MISP configuration… ---"
# There are 4 sample configuration files in /var/www/MISP/app/Config that need to be copied
sudo -u www-data -H cp -a $PATH_TO_MISP/app/Config/bootstrap.default.php /var/www/MISP/app/Config/bootstrap.php
sudo -u www-data -H cp -a $PATH_TO_MISP/app/Config/database.default.php /var/www/MISP/app/Config/database.php
sudo -u www-data -H cp -a $PATH_TO_MISP/app/Config/core.default.php /var/www/MISP/app/Config/core.php
sudo -u www-data -H cp -a $PATH_TO_MISP/app/Config/config.default.php /var/www/MISP/app/Config/config.php
sudo -u www-data -H cat > $PATH_TO_MISP/app/Config/database.php <<EOF
<?php
class DATABASE_CONFIG {
        public \$default = array(
                'datasource' => 'Database/Mysql',
                //'datasource' => 'Database/Postgres',
                'persistent' => false,
                'host' => '$DBHOST',
                'login' => '$DBUSER_MISP',
                'port' => 3306, // MySQL & MariaDB
                //'port' => 5432, // PostgreSQL
                'password' => '$DBPASSWORD_MISP',
                'database' => '$DBNAME',
                'prefix' => '',
                'encoding' => 'utf8',
        );
}
EOF
# and make sure the file permissions are still OK
chown -R www-data:www-data $PATH_TO_MISP/app/Config
chmod -R 750 $PATH_TO_MISP/app/Config
# Set some MISP directives with the command line tool
$PATH_TO_MISP/app/Console/cake Baseurl $MISP_BASEURL
$PATH_TO_MISP/app/Console/cake Live $MISP_LIVE


echo "--- Generating a GPG encryption key… ---"
apt-get install -y rng-tools haveged
sudo -u www-data -H mkdir $PATH_TO_MISP/.gnupg
chmod 700 $PATH_TO_MISP/.gnupg
cat >gen-key-script <<EOF
    %echo Generating a default key
    Key-Type: default
    Key-Length: $GPG_KEY_LENGTH
    Subkey-Type: default
    Name-Real: $GPG_REAL_NAME
    Name-Comment: no comment
    Name-Email: $GPG_EMAIL_ADDRESS
    Expire-Date: 0
    Passphrase: '$GPG_PASSPHRASE'
    # Do a commit here, so that we can later print "done"
    %commit
    %echo done
EOF
sudo -u www-data -H gpg --homedir $PATH_TO_MISP/.gnupg --batch --gen-key gen-key-script
rm gen-key-script
# And export the public key to the webroot
sudo -u www-data -H gpg --homedir $PATH_TO_MISP/.gnupg --batch --gen-key gen-key-scriptgpg --homedir $PATH_TO_MISP/.gnupg --export --armor $EMAIL_ADDRESS > $PATH_TO_MISP/app/webroot/gpg.asc


echo "--- Making the background workers start on boot… ---"
chmod 755 $PATH_TO_MISP/app/Console/worker/start.sh
# With systemd:
# sudo cat > /etc/systemd/system/workers.service  <<EOF
# [Unit]
# Description=Start the background workers at boot
#
# [Service]
# Type=forking
# User=www-data
# ExecStart=$PATH_TO_MISP/app/Console/worker/start.sh
#
# [Install]
# WantedBy=multi-user.target
# EOF
# sudo systemctl enable workers.service > /dev/null
# sudo systemctl restart workers.service > /dev/null

# With initd:
if [ ! -e /etc/rc.local ]
then
    echo '#!/bin/sh -e' | sudo tee -a /etc/rc.local
    echo 'exit 0' | sudo tee -a /etc/rc.local
    chmod u+x /etc/rc.local
fi
sed -i -e '$i \sudo -u www-data -H bash /var/www/MISP/app/Console/worker/start.sh\n' /etc/rc.local


echo "--- Installing MISP modules… ---"
apt-get install -y python3-dev python3-pip libpq5 libjpeg-dev > /dev/null
cd /usr/local/src/
git clone https://github.com/MISP/misp-modules.git
cd misp-modules
pip3 install -I -r REQUIREMENTS > /dev/null
pip3 install -I . > /dev/null
# With systemd:
# sudo cat > /etc/systemd/system/misp-modules.service  <<EOF
# [Unit]
# Description=Start the misp modules server at boot
#
# [Service]
# Type=forking
# User=www-data
# ExecStart=/bin/sh -c 'misp-modules -l 0.0.0.0 -s &'
#
# [Install]
# WantedBy=multi-user.target
# EOF
# sudo systemctl enable misp-modules.service > /dev/null
# sudo systemctl restart misp-modules.service > /dev/null

# With initd:
sed -i -e '$i \sudo -u www-data -H misp-modules -l 0.0.0.0 -s &\n' /etc/rc.local


echo "--- Restarting Apache… ---"
systemctl restart apache2 > /dev/null
sleep 5


sudo -E $PATH_TO_MISP/app/Console/cake userInit -q > /dev/null
AUTH_KEY=$(mysql -u $DBUSER_MISP -p$DBPASSWORD_MISP misp -e "SELECT authkey FROM users;" | tail -1)
echo "--- Updating the galaxies… ---"
curl --header "Authorization: $AUTH_KEY" --header "Accept: application/json" --header "Content-Type: application/json" -o /dev/null -s -X POST http://127.0.0.1/galaxies/update

echo "--- Updating the taxonomies… ---"
curl --header "Authorization: $AUTH_KEY" --header "Accept: application/json" --header "Content-Type: application/json" -o /dev/null -s -X POST http://127.0.0.1/taxonomies/update

echo "--- Updating the warning lists… ---"
curl --header "Authorization: $AUTH_KEY" --header "Accept: application/json" --header "Content-Type: application/json" -o /dev/null -s -X POST http://127.0.0.1/warninglists/update

echo "--- Updating the object templates… ---"
curl --header "Authorization: $AUTH_KEY" --header "Accept: application/json" --header "Content-Type: application/json" -o /dev/null -s -X  POST http://127.0.0.1/objectTemplates/update


# echo "--- Enabling MISP new pub/sub feature (ZeroMQ)… ---"
# # ZeroMQ depends on the Python client for Redis
# pip install redis > /dev/null
# ## Install ZeroMQ and prerequisites
# apt-get install -y pkg-config > /dev/null
# cd /usr/local/src/
# git clone git://github.com/jedisct1/libsodium.git > /dev/null
# cd libsodium
# /autogen.sh > /dev/null
# ./configure > /dev/null
# make check > /dev/null
# make > /dev/null
# make install > /dev/null
# ldconfig > /dev/null
# cd /usr/local/src/
# wget https://archive.org/download/zeromq_4.1.5/zeromq-4.1.5.tar.gz > /dev/null
# tar -xvf zeromq-4.1.5.tar.gz > /dev/null
# cd zeromq-4.1.5/
# ./autogen.sh > /dev/null
# ./configure > /dev/null
# make check > /dev/null
# make > /dev/null
# make install > /dev/null
# ldconfig > /dev/null
# ## install pyzmq
# pip install pyzmq > /dev/null


echo "--- MISP is ready ---"
echo "Login and passwords for the MISP image are the following:"
echo "Web interface (default network settings): $MISP_BASEURL"
echo "MISP admin:  admin@admin.test/admin"
echo "Shell/SSH: misp/Password1234"
echo "MySQL:  $DBUSER_ADMIN/$DBPASSWORD_ADMIN - $DBUSER_MISP/$DBPASSWORD_MISP"
