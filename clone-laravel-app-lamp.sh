#!/bin/bash

# Check if Git is installed
if ! command -v git &> /dev/null
then
    echo "Git not found. Installing Git..."
    sudo apt-get update
    sudo apt-get install git -y
fi

# Get user input for app name
read -p "Enter the app name: " APP_NAME

# Get user input for GitHub repo link and access token
read -p "Enter the GitHub repo link: " repo_link
read -p "Enter your access token for GitHub: " access_token

# Clone the repository
echo "Cloning the repository..."
git clone "$repo_link?access_token=$access_token" /var/www/html/$APP_NAME

# Install LAMP stack
echo "Installing LAMP stack..."
apt-get update
# Install PHP and required extensions
apt-get install apache2 mysql-server php libapache2-mod-php php-cli -y

# Get current PHP version
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")

# Install required PHP extensions for current PHP version
apt-get install php${PHP_VERSION}-bcmath php${PHP_VERSION}-bz2 php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-intl php${PHP_VERSION}-mbstring php${PHP_VERSION}-mysql php${PHP_VERSION}-zip -y

# Get user input for database name and database user
read -p "Enter database name: " db_name
read -p "Enter database user: " db_user

# Create a database and user for the Laravel app
echo "Creating database and user..."
mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE $db_name;
CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_password';
GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Copy .env.example to .env
echo "Copying .env.example to .env..."
cp /var/www/html/$APP_NAME/.env.example /var/www/html/$APP_NAME/.env

# Update .env file with user input
echo "Updating .env file..."
sed -i "s/APP_NAME=Laravel/APP_NAME=$APP_NAME/" /var/www/html/$APP_NAME/.env
sed -i "s/DB_DATABASE=laravel/DB_DATABASE=$db_name/" /var/www/html/$APP_NAME/.env
sed -i "s/DB_USERNAME=root/DB_USERNAME=$db_user/" /var/www/html/$APP_NAME/.env

# Install Composer and dependencies
echo "Installing Composer and dependencies..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
cd /var/www/html/$APP_NAME
composer install

# Set permissions
echo "Setting permissions..."
chown -R www-data:www-data /var/www/html/$APP_NAME
chmod -R 755 /var/www/html/$APP_NAME/storage

# Get user input for subdomain and port number
read -p "Enter the subdomain: " subdomain
read -p "Enter the port number: " port_number

# Create virtual host file for Apache
echo "Creating virtual host file for Apache..."
cat << EOF > /etc/apache2/sites-available/$subdomain.conf
<VirtualHost *:$port_number>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/$APP_NAME/public

    <Directory /var/www/html/$APP_NAME/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Enable the virtual host and restart Apache
echo "Enabling virtual host and restarting Apache..."
a2ensite $subdomain.conf
systemctl restart apache2

echo "Setup complete!"
