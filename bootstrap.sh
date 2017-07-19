#! /usr/bin/env bash

# Database configuration
DBHOST='localhost'
DBNAME='misp'
DBUSER_AMIN='root'
DBPASSWORD_AMIN='aStrongRo0TPaSSWorD'
DBUSER_MISP='misp'
DBPASSWORD_MISP='XXXXdbpasswordhereXXXXX'

# Webserver configuration
PATH_TO_MISP='/var/www/MISP'
IP='127.0.0.1'
FQDN='localhost'

# OpenSSL configuration
OPENSSL_C='Luxembourg'
OPENSSL_ST='Luxembourg'
OPENSSL_L='Luxembourg'
OPENSSL_O='SMILE'
OPENSSL_OU='CIRCL'
OPENSSL_CN='circl.lu'
OPENSSL_EMAILADDRESS='info@circl.lu'

# GPG configuration
GPG_REAL_NAME='Cedric'
GPG_EMAIL_ADDRESS='info@circl.lu'
GPG_KEY_LENGTH='2048'
GPG_PASSPHRASE=''




echo -e "\n--- Installing MISP... ---\n"


echo -e "\n--- Updating packages list ---\n"
apt-get -qq update


echo -e "\n--- Install base packages ---\n"
apt-get -y install curl gcc git gnupg-agent make python openssl redis-server sudo vim zip > /dev/null 2>&1

# To prevent a random error when cloning with Git: 'RPC failed; curl 56 GnuTLS recv error (-54): Error in the pull function.'
git config --global http.postBuffer 1048576000
git config --global https.postBuffer 1048576000

echo -e "\n--- Installing and configuring Postfix ---\n"
# # Postfix Configuration: Satellite system
# # change the relay server later with:
# sudo postconf -e 'relayhost = example.com'
# sudo postfix reload
echo "postfix postfix/mailname string `hostname`.ourdomain.org" | debconf-set-selections
echo "postfix postfix/main_mailer_type string 'Satellite system'" | debconf-set-selections
apt-get install -y postfix > /dev/null 2>&1


echo -e "\n--- Installing MariaDB specific packages and settings ---\n"
apt-get install -y mariadb-client mariadb-server > /dev/null 2>&1
# Secure the MariaDB installation (especially by setting a strong root password)
sleep 7 # give some time to the DB to launch...
apt-get install -y expect > /dev/null 2>&1
expect -f - <<-EOF
  set timeout 10
  spawn mysql_secure_installation
  expect "Enter current password for root (enter for none):"
  send -- "\r"
  expect "Set root password?"
  send -- "y\r"
  expect "New password:"
  send -- "${DBPASSWORD_AMIN}\r"
  expect "Re-enter new password:"
  send -- "${DBPASSWORD_AMIN}\r"
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
apt-get purge -y expect > /dev/null 2>&1


echo -e "\n--- Installing Apache2 ---\n"
apt-get install -y apache2 apache2-doc apache2-utils > /dev/null 2>&1
a2dismod status > /dev/null 2>&1
a2enmod ssl > /dev/null 2>&1
a2enmod rewrite > /dev/null 2>&1
a2dissite 000-default > /dev/null 2>&1
a2ensite default-ssl > /dev/null 2>&1


echo -e "\n--- Installing PHP-specific packages ---\n"
apt-get install -y libapache2-mod-php php php-cli php-crypt-gpg php-dev php-json php-mysql php-opcache php-readline php-redis php-xml > /dev/null 2>&1


echo -e "\n--- Restarting Apache ---\n"
systemctl restart apache2 > /dev/null 2>&1


echo -e "\n--- Retrieving MISP ---\n"
mkdir $PATH_TO_MISP
chown www-data:www-data $PATH_TO_MISP
cd $PATH_TO_MISP
git clone https://github.com/MISP/MISP.git $PATH_TO_MISP
git checkout tags/$(git describe --tags `git rev-list --tags --max-count=1`)
git config core.filemode false
# chown -R www-data $PATH_TO_MISP
# chgrp -R www-data $PATH_TO_MISP
# chmod -R 700 $PATH_TO_MISP


echo -e "\n--- Installing Mitre's STIX ---\n"
apt-get install -y python-dev python-pip libxml2-dev libxslt1-dev zlib1g-dev python-setuptools > /dev/null 2>&1
cd $PATH_TO_MISP/app/files/scripts
git clone https://github.com/CybOXProject/python-cybox.git
git clone https://github.com/STIXProject/python-stix.git
cd $PATH_TO_MISP/app/files/scripts/python-cybox
git checkout v2.1.0.12
python setup.py install > /dev/null 2>&1
cd $PATH_TO_MISP/app/files/scripts/python-stix
git checkout v1.1.1.4
python setup.py install > /dev/null 2>&1
# install mixbox to accomodate the new STIX dependencies:
cd $PATH_TO_MISP/app/files/scripts/
git clone https://github.com/CybOXProject/mixbox.git
cd $PATH_TO_MISP/app/files/scripts/mixbox
git checkout v1.0.2
python setup.py install > /dev/null 2>&1


echo -e "\n--- Retrieving CakePHP... ---\n"
# CakePHP is included as a submodule of MISP, execute the following commands to let git fetch it:
cd $PATH_TO_MISP
git submodule init
git submodule update
# Once done, install CakeResque along with its dependencies if you intend to use the built in background jobs:
cd $PATH_TO_MISP/app
php composer.phar require kamisama/cake-resque:4.1.2
php composer.phar config vendor-dir Vendor
php composer.phar install
# Enable CakeResque with php-redis
phpenmod redis
# To use the scheduler worker for scheduled tasks, do the following:
cp -fa $PATH_TO_MISP/INSTALL/setup/config.php $PATH_TO_MISP/app/Plugin/CakeResque/Config/config.php


echo -e "\n--- Setting the permissions... ---\n"
chown -R www-data:www-data $PATH_TO_MISP
chmod -R 750 $PATH_TO_MISP
chmod -R g+ws $PATH_TO_MISP/app/tmp
chmod -R g+ws $PATH_TO_MISP/app/files
chmod -R g+ws $PATH_TO_MISP/app/files/scripts/tmp


echo -e "\n--- Creating a database user... ---\n"
mysql -u $DBUSER_AMIN -p$DBPASSWORD_AMIN -e "create database $DBNAME;"
mysql -u $DBUSER_AMIN -p$DBPASSWORD_AMIN -e "grant usage on *.* to $DBNAME@localhost identified by '$DBPASSWORD_MISP';"
mysql -u $DBUSER_AMIN -p$DBPASSWORD_AMIN -e "grant all privileges on $DBNAME.* to '$DBUSER_MISP'@'localhost';"
mysql -u $DBUSER_AMIN -p$DBPASSWORD_AMIN -e "flush privileges;"
# Import the empty MISP database from MYSQL.sql
mysql -u $DBUSER_MISP -p$DBPASSWORD_MISP $DBNAME < /var/www/MISP/INSTALL/MYSQL.sql


echo -e "\n--- Configuring Apache... ---\n"
# !!! apache.24.misp.ssl seems to be missing
#cp $PATH_TO_MISP/INSTALL/apache.24.misp.ssl /etc/apache2/sites-available/misp-ssl.conf
# If a valid SSL certificate is not already created for the server, create a self-signed certificate:
sudo openssl req -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=$OPENSSL_C/ST=$OPENSSL_ST/L=$OPENSSL_L/O=<$OPENSSL_O/OU=$OPENSSL_OU/CN=$OPENSSL_CN/emailAddress=$OPENSSL_EMAILADDRESS" -keyout /etc/ssl/private/misp.local.key -out /etc/ssl/private/misp.local.crt


echo -e "\n--- Add a VirtualHost for MISP ---\n"
cat > /etc/apache2/sites-available/misp-ssl.conf <<EOF
<VirtualHost *:80>
        ServerAdmin me@me.local
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
# cat > /etc/apache2/sites-available/misp-ssl.conf <<EOF
# <VirtualHost *:80>
#         ServerName misp.local
#
#         Redirect permanent / https://$FQDN
#
#         LogLevel warn
#         ErrorLog /var/log/apache2/misp.local_error.log
#         CustomLog /var/log/apache2/misp.local_access.log combined
#         ServerSignature Off
# </VirtualHost>
#
# <VirtualHost *:443>
#         ServerAdmin me@me.local
#         ServerName misp.local
#         DocumentRoot $PATH_TO_MISP/app/webroot
#
#         <Directory $PATH_TO_MISP/app/webroot>
#             Options -Indexes
#             AllowOverride all
#             Require all granted
#         </Directory>
#
#         SSLEngine On
#         SSLCertificateFile /etc/ssl/private/misp.local.crt
#         SSLCertificateKeyFile /etc/ssl/private/misp.local.key
#         #SSLCertificateChainFile /etc/ssl/private/misp-chain.crt
#
#         LogLevel warn
#         ErrorLog /var/log/apache2/misp.local_error.log
#         CustomLog /var/log/apache2/misp.local_access.log combined
#         ServerSignature Off
# </VirtualHost>
# EOF
# activate new vhost
a2dissite default-ssl
a2ensite misp-ssl


echo -e "\n--- Restarting Apache ---\n"
systemctl restart apache2 > /dev/null 2>&1


echo -e "\n--- Configuring log rotation ---\n"
cp $PATH_TO_MISP/INSTALL/misp.logrotate /etc/logrotate.d/misp


echo -e "\n--- MISP configuration ---\n"
# There are 4 sample configuration files in /var/www/MISP/app/Config that need to be copied
cp -a $PATH_TO_MISP/app/Config/bootstrap.default.php /var/www/MISP/app/Config/bootstrap.php
cp -a $PATH_TO_MISP/app/Config/database.default.php /var/www/MISP/app/Config/database.php
cp -a $PATH_TO_MISP/app/Config/core.default.php /var/www/MISP/app/Config/core.php
cp -a $PATH_TO_MISP/app/Config/config.default.php /var/www/MISP/app/Config/config.php
cat > $PATH_TO_MISP/app/Config/database.php <<EOF
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


echo -e "\n--- Generating a GPG encryption key... ---\n"
apt-get install -y rng-tools haveged
mkdir $PATH_TO_MISP/.gnupg
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
gpg --homedir $PATH_TO_MISP/.gnupg --batch --gen-key gen-key-script
rm gen-key-script
# And export the public key to the webroot
gpg --homedir $PATH_TO_MISP/.gnupg --export --armor $EMAIL_ADDRESS > $PATH_TO_MISP/app/webroot/gpg.asc


echo -e "\n--- Making the background workers start on boot... ---\n"
chmod +x $PATH_TO_MISP/app/Console/worker/start.sh
cat > /etc/systemd/system/workers.service  <<EOF
[Unit]
Description=Start the background workers at boot

[Service]
Type=oneshot
RemainAfterExit=yes
User=www-data
ExecStart=/bin/sh -c 'bash $PATH_TO_MISP/app/Console/worker/start.sh'

[Install]
WantedBy=multi-user.target
EOF
systemctl enable workers.service > /dev/null
systemctl restart workers.service > /dev/null


echo -e "\n--- Restarting Apache ---\n"
systemctl restart apache2 > /dev/null 2>&1
sleep 5

echo -e "\n--- Updating the galaxies... ---\n"
sudo -E $PATH_TO_MISP/app/Console/cake userInit -q > /dev/null
AUTH_KEY=$(mysql -u $DBUSER_MISP -p$DBPASSWORD_MISP misp -e "SELECT authkey FROM users;" | tail -1)
curl -k -X POST -H "Authorization: $AUTH_KEY" -H "Accept: application/xml" -v http://127.0.0.1/galaxies/update > /dev/null


echo -e "\n--- Updating the taxonomies... ---\n"
curl -k -X POST -H "Authorization: $AUTH_KEY" -H "Accept: application/xml" -v http://127.0.0.1/taxonomies/update


# echo -e "\n--- Enabling MISP new pub/sub feature (ZeroMQ)... ---\n"
# # ZeroMQ depends on the Python client for Redis
# pip install redis > /dev/null 2>&1
# ## Install ZeroMQ and prerequisites
# apt-get install -y pkg-config > /dev/null 2>&1
# cd /usr/local/src/
# git clone git://github.com/jedisct1/libsodium.git > /dev/null 2>&1
# cd libsodium
# /autogen.sh > /dev/null 2>&1
# ./configure > /dev/null 2>&1
# make check > /dev/null 2>&1
# make > /dev/null 2>&1
# make install > /dev/null 2>&1
# ldconfig > /dev/null 2>&1
# cd /usr/local/src/
# wget https://archive.org/download/zeromq_4.1.5/zeromq-4.1.5.tar.gz > /dev/null 2>&1
# tar -xvf zeromq-4.1.5.tar.gz > /dev/null 2>&1
# cd zeromq-4.1.5/
# ./autogen.sh > /dev/null 2>&1
# ./configure > /dev/null 2>&1
# make check > /dev/null 2>&1
# make > /dev/null 2>&1
# make install > /dev/null 2>&1
# ldconfig > /dev/null 2>&1
# ## install pyzmq
# pip install pyzmq > /dev/null 2>&1


echo -e "\n--- MISP is ready! ---\n"
echo -e "\n--- Point your Web browser to http://127.0.0.1:5000 ---\n"
echo -e "\n--- Default user/pass = admin@admin.test/admin ---\n"
