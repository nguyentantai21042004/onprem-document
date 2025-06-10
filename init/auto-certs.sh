#!/bin/sh

echo "Enter the subdomain you want to issue SSL for (e.g., sub.domain.com):"
read DOMAIN

echo "Enter the email you want to use for the certificate (e.g., tantai@gmail.com):"
read EMAIL

# Set fixed destination folder
DEST_FOLDER="/home/tantai/certs"

# Create directory if it doesn't exist
mkdir -p "$DEST_FOLDER"

# Authenticate using webroot or standalone
echo "Choose authentication method:"
echo "1. Webroot (server is running)"
echo "2. Standalone (temporarily stop web server)"
read METHOD

if [ "$METHOD" = "1" ]; then
    echo "Enter webroot path (e.g., /var/www/html):"
    read WEBROOT
    sudo certbot certonly --webroot -w "$WEBROOT" -d "$DOMAIN" --non-interactive --agree-tos -m $EMAIL
elif ư[ "$METHOD" = "2" ]; then
    sudo certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos -m $EMAIL --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx"
else
    echo "Invalid method!"
    exit 1
fi

# Copy certificates to destination folder
SRC_PATH="/etc/letsencrypt/live/$DOMAIN"
if [ -d "$SRC_PATH" ]; then
    cp "$SRC_PATH/fullchain.pem" "$DEST_FOLDER/$DOMAIN-fullchain.pem"
    cp "$SRC_PATH/privkey.pem" "$DEST_FOLDER/$DOMAIN-privkey.pem"
    echo "✔ Certificates have been saved to $DEST_FOLDER"
else
    echo "❌ Certificates not found. An error may have occurred."
fi