#!/bin/bash

# Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[36m"
RESET="\e[0m"

echo -e "${BLUE}⚡ SSL Auto Generator for Nginx (Certbot) - Fixed Version${RESET}"
echo ""

# --- 1. Input ---
read -p "Enter the subdomain you want to issue SSL for (e.g., sub.domain.com): " DOMAIN
read -p "Enter the email you want to use for the certificate: " EMAIL

# --- 2. Folders Setup ---
# Backup folder (User home)
DEST_FOLDER="/home/tantai/certs"
mkdir -p "$DEST_FOLDER"

# Nginx destination folder
NGINX_CERT_FOLDER="/etc/nginx/ssl-certs/$DOMAIN"
echo -e "${YELLOW}→ Creating Nginx cert folder: $NGINX_CERT_FOLDER${RESET}"
sudo mkdir -p "$NGINX_CERT_FOLDER"

# --- 3. Choose method ---
echo ""
echo "Choose authentication method:"
echo "1. Webroot (server running - No downtime)"
echo "2. Standalone (stop nginx temporarily - Good if webroot fails)"
read METHOD
echo ""

# --- 4. Issue/renew certificate ---
if [ "$METHOD" = "1" ]; then
    read -p "Enter webroot path (e.g., /var/www/html): " WEBROOT
    sudo certbot certonly --webroot \
        --cert-name "$DOMAIN" \
        -w "$WEBROOT" \
        -d "$DOMAIN" \
        --non-interactive --agree-tos -m "$EMAIL" \
        --force-renewal

elif [ "$METHOD" = "2" ]; then
    echo -e "${YELLOW}→ Stopping nginx to run standalone mode...${RESET}"
    sudo systemctl stop nginx

    sudo certbot certonly --standalone \
        --cert-name "$DOMAIN" \
        -d "$DOMAIN" \
        --non-interactive --agree-tos -m "$EMAIL" \
        --force-renewal
    
    # LƯU Ý: Chưa start Nginx ở đây, đợi copy xong mới start
else
    echo -e "${RED}Invalid method!${RESET}"
    exit 1
fi

# --- 5. Copy certificates ---
SRC_PATH="/etc/letsencrypt/live/$DOMAIN"

# Kiểm tra thư mục tồn tại bằng quyền root (sudo test)
if ! sudo test -d "$SRC_PATH"; then
    echo -e "${RED}❌ ERROR: Certificate folder not found at: $SRC_PATH${RESET}"
    echo -e "${RED}It seems Certbot failed to generate the certificate.${RESET}"
    
    # Nếu đang dùng Method 2 mà lỗi, phải start lại Nginx cho hệ thống chạy tiếp
    if [ "$METHOD" = "2" ]; then 
        echo -e "${YELLOW}→ Restarting Nginx before exiting...${RESET}"
        sudo systemctl start nginx
    fi
    exit 1
fi

echo -e "${GREEN}✔ Certificates found in: $SRC_PATH${RESET}"

# Copy to Nginx folder (Ghi đè file cũ)
echo -e "${YELLOW}→ Copying certificates to Nginx folder...${RESET}"
sudo cp "$SRC_PATH/fullchain.pem" "$NGINX_CERT_FOLDER/certificate.crt"
sudo cp "$SRC_PATH/privkey.pem" "$NGINX_CERT_FOLDER/private.key"

# Backup copy (Lưu vào thư mục home)
echo -e "${YELLOW}→ Backing up certificates...${RESET}"
# Vì copy từ thư mục root ra user thường, nên dùng sudo cp rồi chown lại nếu cần
sudo cp "$SRC_PATH/fullchain.pem" "$DEST_FOLDER/$DOMAIN-fullchain.pem"
sudo cp "$SRC_PATH/privkey.pem" "$DEST_FOLDER/$DOMAIN-privkey.pem"

echo -e "${GREEN}✔ Certificates copied successfully!${RESET}"

# --- 6. Restore Nginx (For Method 2) ---
if [ "$METHOD" = "2" ]; then
    echo -e "${YELLOW}→ Starting nginx back...${RESET}"
    sudo systemctl start nginx
fi

# --- 7. Test & Reload Nginx ---
echo -e "${BLUE}🔁 Testing nginx config...${RESET}"
sudo nginx -t

if [ $? -eq 0 ]; then
    # Chỉ reload nếu đang chạy, nếu Method 2 vừa start rồi thì reload cũng không sao
    sudo systemctl reload nginx
    echo -e "${GREEN}🎉 SSL setup for $DOMAIN completed successfully!${RESET}"
else
    echo -e "${RED}❌ Nginx config test failed! The certificate is copied but Nginx config might be wrong.${RESET}"
    exit 1
fi