#!/bin/bash
set -ex
source .env

# ---------- 1. Certificado autofirmado ----------
# Lo creamos solo si no existe ya uno con nuestra IP
if [ -f /etc/ssl/certs/wordpress.crt ] && openssl x509 -in /etc/ssl/certs/wordpress.crt -noout -text | grep -qF "$SERVER_NAME"; then
    echo "Ya existe un certificado para $SERVER_NAME, no se crea otro"
else
    echo "Creando el certificado autofirmado para $SERVER_NAME..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/wordpress.key \
        -out /etc/ssl/certs/wordpress.crt \
        -subj "/C=ES/O=$CERT_ORGANIZATION/CN=$SERVER_NAME" \
        -addext "subjectAltName=IP:$SERVER_NAME"
    chmod 600 /etc/ssl/private/wordpress.key
fi

# ---------- 2. Virtual host del puerto 443 ----------
echo "Copiando default-ssl.conf..."
cp ../conf/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf
sed -i "s/PUT_YOUR_SERVER_NAME_HERE/$SERVER_NAME/" /etc/apache2/sites-available/default-ssl.conf

# ---------- 3. Redirección de HTTP a HTTPS ----------
echo "Activando la redirección de HTTP a HTTPS..."
sed -i "s|#Redirect permanent / https://PUT_YOUR_SERVER_NAME_HERE/|Redirect permanent / https://$SERVER_NAME/|" /etc/apache2/sites-available/000-default.conf

# ---------- 4. Activar SSL y recargar Apache ----------
echo "Activando el módulo ssl y el sitio default-ssl..."
a2enmod ssl
a2ensite default-ssl

echo "Comprobando la sintaxis de Apache..."
apache2ctl configtest

echo "Recargando Apache..."
systemctl reload apache2

# ---------- Comprobar que funciona ----------
if systemctl is-active --quiet apache2; then
    echo "OK: Apache está running"
else
    echo "ERROR: Apache NO está running"
    exit 1
fi

if curl -sk https://localhost > /dev/null; then
    echo "OK: Apache responde por HTTPS"
else
    echo "ERROR: Apache no responde por HTTPS"
    exit 1
fi

echo "HTTPS configurado correctamente"
