#! /usr/bin/env bash

# Variables
APPENV='local'

DBHOST='localhost'
DBNAME='misp'
DBUSER_AMIN='root'
DBPASSWORD_AMIN='root'
DBUSER_MISP='misp'
DBPASSWORD_MISP='XXXXdbpasswordhereXXXXX'

PATH_TO_MISP='/var/www/MISP'
IP='127.0.0.1'
FQDN='localhost'



echo -e "\n--- Installing now... ---\n"

echo -e "\n--- Updating packages list ---\n"
apt-get -qq update

echo -e "\n--- Install base packages ---\n"
apt-get -y install vim git > /dev/null 2>&1

echo -e "\n--- Install Postfix ---\n"
# sudo apt-get install postfix
# # Postfix Configuration: Satellite system
# # change the relay server later with:
# sudo postconf -e 'relayhost = example.com'
# sudo postfix reload

echo -e "\n--- Updating packages list ---\n"
apt-get -qq update

#
# TODO: replace MySQL by MariaDB
#

echo -e "\n--- Install MySQL specific packages and settings ---\n"
echo "mysql-server mysql-server/root_password password $DBPASSWORD_AMIN" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $DBPASSWORD_AMIN" | debconf-set-selections
# echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
# echo "phpmyadmin phpmyadmin/app-password-confirm password $DBPASSWORD_AMIN" | debconf-set-selections
# echo "phpmyadmin phpmyadmin/mysql/admin-pass password $DBPASSWORD_AMIN" | debconf-set-selections
# echo "phpmyadmin phpmyadmin/mysql/app-pass password $DBPASSWORD_AMIN" | debconf-set-selections
# echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect none" | debconf-set-selections
apt-get -y install mysql-server phpmyadmin > /dev/null 2>&1

echo -e "\n--- Installing PHP-specific packages ---\n"
apt-get -y install php apache2 libapache2-mod-php php-curl php-gd php-mcrypt php-mysql php-pear php-apcu php-xml php-mbstring php-intl php-imagick > /dev/null 2>&1

echo -e "\n--- Enabling mod-rewrite and ssl ---\n"
a2enmod rewrite > /dev/null 2>&1
a2enmod ssl > /dev/null 2>&1

echo -e "\n--- Allowing Apache override to all ---\n"
sudo sed -i "s/AllowOverride None/AllowOverride All/g" /etc/apache2/apache2.conf

#echo -e "\n--- We want to see the PHP errors, turning them on ---\n"
#sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.0/apache2/php.ini
#sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.0/apache2/php.ini

echo -e "\n--- Setting up our MySQL user for MISP ---\n"
mysql -u root -p$DBPASSWORD_AMIN -e "CREATE USER '$DBUSER_MISP'@'localhost' IDENTIFIED BY '$DBPASSWORD_MISP';"
mysql -u root -p$DBPASSWORD_AMIN -e "GRANT ALL PRIVILEGES ON * . * TO '$DBUSER_MISP'@'localhost';"
mysql -u root -p$DBPASSWORD_AMIN -e "FLUSH PRIVILEGES;"


mkdir $PATH_TO_MISP
git clone https://github.com/MISP/MISP.git /var/www/MISP
# chown -R www-data $PATH_TO_MISP
# chgrp -R www-data $PATH_TO_MISP
# chmod -R 700 $PATH_TO_MISP



echo -e "\n--- Add a VirtualHost for MISP ---\n"
cat > /etc/apache2/sites-enabled/000-default.conf <<EOF
<VirtualHost $FQDN:80>
        ServerName $FQDN

        Redirect permanent / https://$FQDN
        
        LogLevel warn
        ErrorLog /var/log/apache2/misp.local_error.log
        CustomLog /var/log/apache2/misp.local_access.log combined
        ServerSignature Off
</VirtualHost>
        
<VirtualHost $FQDN:443>
        ServerAdmin admin@$FQDN
        ServerName $FQDN
        DocumentRoot $PATH_TO_MISP/app/webroot
        <Directory $PATH_TO_MISP/app/webroot>
            Options -Indexes
            AllowOverride all
            Order allow,deny
            allow from all
        </Directory>
        
        SSLEngine On
        SSLCertificateFile /etc/ssl/private/misp.local.crt
        SSLCertificateKeyFile /etc/ssl/private/misp.local.key
        #SSLCertificateChainFile /etc/ssl/private/misp-chain.crt
        
        LogLevel warn
        ErrorLog /var/log/apache2/misp.local_error.log
        CustomLog /var/log/apache2/misp.local_access.log combined
        ServerSignature Off
</VirtualHost>
EOF


echo -e "\n--- Restarting Apache ---\n"
service apache2 restart > /dev/null 2>&1


echo -e "\n--- MISP is ready! Point your Web browser to http://127.0.0.1:5000 ---\n"
