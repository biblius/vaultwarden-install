#!/bin/bash

if [ -z "$1" ]; then
    echo "Error: Missing path to binary."
    echo "Please provide it as the first argument when invoking this script."
    echo "If you have followed this guide (https://github.com/biblius/vaultwarden-install)"
    echo "it should be the path to wherever you scp'd the compiled binary"
    exit 1
fi

read_password() {
	local passwords_match=false

	while [ "$passwords_match" == false ]; do
	    read -p "Enter admin token: " -r password

            read -p "Confirm admin token: " -r confirm_password

	    if [ "$password" == "$confirm_password" ]; then
		passwords_match=true
	    else
		echo "Passwords do not match. Please try again."
	    fi
	done

	echo "$password"
}

gen_admin_token() {
  if ! command -v argon2 &> /dev/null; then
	echo "Argon is not installed, but is needed to generate a secure admin token. Installing it now."
	apt-get install argon2 -y
  fi

  local password=$(read_password)
  local salt="$(openssl rand -base64 32)"
  #https://github.com/dani-garcia/vaultwarden/wiki/Enabling-admin-page#using-argon2
  local hash_output=$(echo -n "$password" | argon2 "$salt" -e -id -k 65540 -t 3 -p 4)
  echo "$hash_output"
}

# MAIN #

BIN_PATH="$1"
VW_DIR="/opt/vaultwarden"
SYSD_DIR="/etc/systemd/system"
ENV_PATH="$VW_DIR/.env"

R_ADDRESS="0.0.0.0"
R_PORT="6060"

SYSD_CFG="W1VuaXRdCkRlc2NyaXB0aW9uPVZhdWx0d2FyZGVuIFNlcnZlcgpEb2N1bWVudGF0aW9uPWh0dHBzOi8vZ2l0aHViLmNvbS9kYW5pLWdhcmNpYS92YXVsdHdhcmRlbgpBZnRlcj1uZXR3b3JrLnRhcmdldAoKW1NlcnZpY2VdClVzZXI9dmF1bHR3YXJkZW4KR3JvdXA9dmF1bHR3YXJkZW4KRW52aXJvbm1lbnRGaWxlPS0vb3B0L3ZhdWx0d2FyZGVuLy5lbnYKRXhlY1N0YXJ0PS9vcHQvdmF1bHR3YXJkZW4vYmluL3ZhdWx0d2FyZGVuCkxpbWl0Tk9GSUxFPTY1NTM1CkxpbWl0TlBST0M9NDA5NgpQcml2YXRlVG1wPXRydWUKUHJpdmF0ZURldmljZXM9dHJ1ZQpQcm90ZWN0SG9tZT10cnVlClByb3RlY3RTeXN0ZW09c3RyaWN0CkRldmljZVBvbGljeT1jbG9zZWQKUHJvdGVjdENvbnRyb2xHcm91cHM9eWVzClByb3RlY3RLZXJuZWxNb2R1bGVzPXllcwpQcm90ZWN0S2VybmVsVHVuYWJsZXM9eWVzClJlc3RyaWN0TmFtZXNwYWNlcz15ZXMKUmVzdHJpY3RSZWFsdGltZT15ZXMKTWVtb3J5RGVueVdyaXRlRXhlY3V0ZT15ZXMKTG9ja1BlcnNvbmFsaXR5PXllcwpXb3JraW5nRGlyZWN0b3J5PS9vcHQvdmF1bHR3YXJkZW4KUmVhZFdyaXRlRGlyZWN0b3JpZXM9L29wdC92YXVsdHdhcmRlbi9kYXRhCkFtYmllbnRDYXBhYmlsaXRpZXM9Q0FQX05FVF9CSU5EX1NFUlZJQ0UKCltJbnN0YWxsXQpXYW50ZWRCeT1tdWx0aS11c2VyLnRhcmdldAo="

DEFAULT_ENV="REFUQV9GT0xERVI9L29wdC92YXVsdHdhcmRlbi9kYXRhLwpEQVRBQkFTRV9NQVhfQ09OTlM9MTAKV0VCX1ZBVUxUX0ZPTERFUj0vb3B0L3ZhdWx0d2FyZGVuL3dlYi12YXVsdC8KV0VCX1ZBVUxUX0VOQUJMRUQ9dHJ1ZQo="

echo "Creating directories"

mkdir -p "$VW_DIR/bin"
mkdir "$VW_DIR/data"

echo "Installing Web Vault"

curl -fsSLO https://github.com/dani-garcia/bw_web_builds/releases/download/v2023.12.0/bw_web_v2023.12.0.tar.gz 
tar -zxf bw_web_v2023.12.0.tar.gz -C "$VW_DIR"
rm -f bw_web_v2023.12.0.tar.gz

echo "Configuring network"

read -p "Enter the address on which vaultwarden will listen on ($R_ADDRESS):  " -r address
if [[ -n "$address" ]]; then
	R_ADDRESS="$address"
fi


read -p "Enter the port on which vaultwarden will listen on ($R_PORT):  " -r port
if [[ -n "$port" ]]; then
	R_PORT="$port"
fi

read -p "Enter the remote IP (PIE_IP) for the domain (https://<PIE_IP>:$R_PORT):  " -r DOMAIN_IP

echo "Configuring TLS"

if ! command -v mkcert &> /dev/null; then
	echo "mkcert not found, installing it now"
	curl -fsSL https://github.com/FiloSottile/mkcert/releases/download/v1.4.3/mkcert-v1.4.3-linux-arm -o /usr/local/bin/mkcert
	chmod +x /usr/local/bin/mkcert
fi

mkcert -install
update-ca-certificates

echo "Creating certificates"

mkdir "$VW_DIR/cert"

mkcert -cert-file "$VW_DIR/cert/rocket.pem" -key-file "$VW_DIR/cert/rocket-key.pem" "$DOMAIN_IP" "$DOMAIN_IP"

openssl verify -verbose -CAfile $(mkcert -CAROOT)/rootCA.pem "$VW_DIR/cert/rocket.pem"

echo "Certificates successfully created"

DOMAIN="https://$DOMAIN_IP:$R_PORT"

ADMIN_TOKEN=$(gen_admin_token)

echo "Successfully generated admin token, use it to access the admin panel 'https://<YOUR_VW_DOMAIN>/admin'"

echo "$DEFAULT_ENV" | base64 -d > "$ENV_PATH"

echo "ROCKET_ADDRESS=$R_ADDRESS" >> "$ENV_PATH"
echo "ROCKET_PORT=$R_PORT" >> "$ENV_PATH"
echo "ROCKET_TLS={certs="'"'"$VW_DIR/cert/rocket.pem"'"'",key="'"'"$VW_DIR/cert/rocket-key.pem"'"'"}" >> "$ENV_PATH"

echo "WEBSOCKET_ENABLED=true" >> "$ENV_PATH"
echo "WEBSOCKET_ADDRESS=$R_ADDRESS" >> "$ENV_PATH"
echo "WEBSOCKET_PORT=3012" >> "$ENV_PATH"

echo "DOMAIN=$DOMAIN" >> "$ENV_PATH"

echo "ADMIN_TOKEN='$ADMIN_TOKEN'" >> "$ENV_PATH"

echo "Successfully configured .env, adding user and group"

addgroup --system vaultwarden
adduser --system --home "$VW_DIR" --shell /usr/sbin/nologin --no-create-home --gecos 'vaultwarden' --ingroup vaultwarden --disabled-login --disabled-password vaultwarden

cp "$BIN_PATH" "$VW_DIR/bin/vaultwarden"

chown -R vaultwarden:vaultwarden "$VW_DIR"
chmod +x "$VW_DIR/bin/vaultwarden"

echo "Successfully added user and group, configuring systemd"

echo "$SYSD_CFG" | base64 -d > "$SYSD_DIR/vaultwarden.service"

echo "Wrote configuration, enabling service"

systemctl daemon-reload
systemctl enable vaultwarden.service
systemctl start vaultwarden.service

echo "Successfully set up Vaultwarden"
echo "You can now remove the original binary"
echo "  rm $BIN_PATH"
echo
echo "To get rid of warnings about untrusted certificates, the local mkcert CA must be in clients' respective trust stores"
cert=$(find /usr/local/share/ca-certificates -type f -name *mkcert*.crt)
if [ -n "$cert" ]; then
    echo
    echo "You can copy the following CA certificate and paste it in /usr/share/ca-certificate/mycert.crt on any of your linux desktop clients and run 'update-ca-certificates' or follow instructions on how to add them for your specific mobile devices" 
    echo
    cat "$cert"
fi
echo
echo "Vaultwarden should be accessible from your local network at $DOMAIN"
echo
echo "Have fun and stay safe!"

