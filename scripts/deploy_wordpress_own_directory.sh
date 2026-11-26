#!/bin/bash
set -ex
source .env

# ---------- 1. Descargar WordPress y copiarlo a su propio directorio ----------
echo "Descargando WordPress..."
wget -q https://wordpress.org/latest.tar.gz -O /tmp/latest.tar.gz
tar -xzf /tmp/latest.tar.gz -C /tmp

echo "Copiando WordPress a /var/www/html/wordpress..."
mkdir -p /var/www/html/wordpress
cp -a /tmp/wordpress/. /var/www/html/wordpress/

# ---------- 2. Base de datos y usuario ----------
echo "Creando la base de datos..."
mysql -u root <<< "CREATE DATABASE IF NOT EXISTS $WORDPRESS_DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"

echo "Creando el usuario de la base de datos..."
set +x
mysql -u root <<< "CREATE USER IF NOT EXISTS '$WORDPRESS_DB_USER'@'$IP_CLIENTE_MYSQL' IDENTIFIED BY '$WORDPRESS_DB_PASSWORD'"
set -x

echo "Dando permisos al usuario sobre la base de datos..."
mysql -u root <<< "GRANT ALL PRIVILEGES ON $WORDPRESS_DB_NAME.* TO '$WORDPRESS_DB_USER'@'$IP_CLIENTE_MYSQL'"

# ---------- 3. wp-config.php ----------
echo "Creando wp-config.php..."
cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php
sed -i "s/database_name_here/$WORDPRESS_DB_NAME/" /var/www/html/wordpress/wp-config.php
sed -i "s/username_here/$WORDPRESS_DB_USER/" /var/www/html/wordpress/wp-config.php
set +x
sed -i "s/password_here/$WORDPRESS_DB_PASSWORD/" /var/www/html/wordpress/wp-config.php
set -x
sed -i "s/localhost/$WORDPRESS_DB_HOST/" /var/www/html/wordpress/wp-config.php

# ---------- 4. WP_SITEURL y WP_HOME ----------
echo "Añadiendo WP_SITEURL y WP_HOME..."
sed -i "/DB_COLLATE/a define('WP_SITEURL', 'https://$SERVER_NAME/wordpress');" /var/www/html/wordpress/wp-config.php
sed -i "/WP_SITEURL/a define('WP_HOME', 'https://$SERVER_NAME');" /var/www/html/wordpress/wp-config.php

# ---------- 5. index.php en la raíz ----------
echo "Copiando index.php a /var/www/html y apuntándolo a wordpress..."
cp /var/www/html/wordpress/index.php /var/www/html/index.php
sed -i "s#wp-blog-header.php#wordpress/wp-blog-header.php#" /var/www/html/index.php

# ---------- 6. Security keys nuevas ----------
echo "Borrando las security keys de ejemplo..."
sed -i "/AUTH_KEY/d" /var/www/html/wordpress/wp-config.php
sed -i "/LOGGED_IN_KEY/d" /var/www/html/wordpress/wp-config.php
sed -i "/NONCE_KEY/d" /var/www/html/wordpress/wp-config.php
sed -i "/AUTH_SALT/d" /var/www/html/wordpress/wp-config.php
sed -i "/LOGGED_IN_SALT/d" /var/www/html/wordpress/wp-config.php
sed -i "/NONCE_SALT/d" /var/www/html/wordpress/wp-config.php

echo "Descargando security keys nuevas..."
SECURITY_KEYS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
SECURITY_KEYS=$(echo "$SECURITY_KEYS" | tr '\n' ' ' | tr / _)
sed -i "/@-/a $SECURITY_KEYS" /var/www/html/wordpress/wp-config.php

# ---------- 7. .htaccess, propietario y permisos ----------
echo "Copiando los .htaccess..."
cp ../htaccess/.htaccess /var/www/html/.htaccess
sed -i "s/IP_ADMIN_HERE/$IP_ADMIN/" /var/www/html/.htaccess
cp ../htaccess/wp-admin.htaccess /var/www/html/wordpress/wp-admin/.htaccess
sed -i "s/IP_ADMIN_HERE/$IP_ADMIN/" /var/www/html/wordpress/wp-admin/.htaccess

echo "Poniendo propietario y permisos..."
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;
chmod 640 /var/www/html/wordpress/wp-config.php

# ---------- 8. Reiniciar Apache ----------
echo "Reiniciando Apache..."
systemctl restart apache2

# ---------- Comprobar que todo está bien ----------
if [ -f /var/www/html/wordpress/wp-config.php ]; then
    echo "OK: wp-config.php existe"
else
    echo "ERROR: wp-config.php NO existe"
    exit 1
fi

if grep -q "wordpress/wp-blog-header.php" /var/www/html/index.php; then
    echo "OK: index.php apunta a la carpeta wordpress"
else
    echo "ERROR: index.php NO apunta a la carpeta wordpress"
    exit 1
fi

if mysql -u root -e "USE $WORDPRESS_DB_NAME"; then
    echo "OK: la base de datos $WORDPRESS_DB_NAME existe"
else
    echo "ERROR: la base de datos $WORDPRESS_DB_NAME NO existe"
    exit 1
fi

if systemctl is-active --quiet apache2; then
    echo "OK: Apache está running"
else
    echo "ERROR: Apache NO está running"
    exit 1
fi

echo "WordPress desplegado en /var/www/html/wordpress"
