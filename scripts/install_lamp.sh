#!/bin/bash

# Control de errores y muestra de comandos antes de ejecutar
set -ex

# Carga las variables del .env en el script
source .env

# Actualizar la lista de paquetes y sistema
echo "Actualizando el sistema..."
apt update
apt upgrade -y

# ---------- Apache ----------
if dpkg -s apache2 > /dev/null 2>&1; then
    echo "Apache ya está instalado"
else
    echo "Instalando Apache..."
    apt install -y apache2
fi

# ---------- PHP ----------
if dpkg -s php > /dev/null 2>&1; then
    echo "PHP ya está instalado"
else
    echo "Instalando PHP y sus extensiones..."
    apt install -y php libapache2-mod-php php-mysql php-xml php-mbstring php-curl php-zip php-gd php-intl
fi

# ---------- MySQL ----------
if dpkg -s mysql-server > /dev/null 2>&1; then
    echo "MySQL ya está instalado"
else
    echo "Instalando MySQL..."
    apt install -y mysql-server
fi

# ---------- Configuración de Apache ----------
echo "Copiando la configuración de Apache..."
cp ../conf/000-default.conf /etc/apache2/sites-available/000-default.conf

echo "Activando mod_rewrite..."
a2enmod rewrite

echo "Borrando index.html por defecto..."
rm -f /var/www/html/index.html

echo "Reiniciando Apache..."
systemctl restart apache2

# ---------- Comprobar que todo funciona ----------
if systemctl is-active --quiet apache2; then
    echo "OK: Apache está running"
else
    echo "ERROR: Apache NO está running"
    exit 1
fi

if systemctl is-active --quiet mysql; then
    echo "OK: MySQL está running"
else
    echo "ERROR: MySQL NO está running"
    exit 1
fi

if php -v > /dev/null 2>&1; then
    echo "OK: PHP funciona"
else
    echo "ERROR: PHP NO funciona"
    exit 1
fi






