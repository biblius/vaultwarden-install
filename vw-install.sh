#!/bin/bash

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
  local password=$(read_password)
  local salt="$(openssl rand -base64 32)"
  #https://github.com/dani-garcia/vaultwarden/wiki/Enabling-admin-page#using-argon2
  local hash_output=$(echo -n "$password" | argon2 "$salt" -e -id -k 65540 -t 3 -p 4)
  echo "$hash_output"
}

# Create directories
mkdir -p testpi/opt/vaultwarden/bin testpi/opt/vaultwarden/data

token=$(gen_admin_token)

echo "Successfully set admin token"
echo "$token"

#echo "$hash_output" >> hash_output.txt
#echo "Hash has been appended to hash_output.txt"
