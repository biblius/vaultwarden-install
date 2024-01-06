#!/bin/bash

if ! command -v rustc &> /dev/null; then
    echo "Rust is not installed. Please install Rust from https://www.rust-lang.org/tools/install"
    exit 0
fi

TARGET="aarch64-unknown-linux-gnu"

TARGET_CFG="W3RhcmdldC5hYXJjaDY0LXVua25vd24tbGludXgtZ251XQpsaW5rZXIgPSAiYWFyY2g2NC1saW51eC1nbnUtZ2NjIgpydXN0ZmxhZ3MgPSBbCiAgICAiLUwvdXNyL2xpYi9hYXJjaDY0LWxpbnV4LWdudSIsCiAgICAiLUN0YXJnZXQtZmVhdHVyZT0rY3J0LXN0YXRpYyIsCl0K"

CONFIG_FILE="$HOME/.cargo/config.toml"

echo -e "\nAdding target $TARGET \n"

rustup target add aarch64-unknown-linux-gnu

echo -e "\nInstalling cross compile dependencies \n"

sudo apt install gcc-aarch64-linux-gnu

echo -e "\nConfiguring cargo home"

if [ -e "$CONFIG_FILE" ]; then
    echo -e "\nThe configuration file '$CONFIG_FILE' already exists:\n"

    cat $CONFIG_FILE

    echo -e "\nMake sure the following configuration exists: \n"

    echo $TARGET_CFG | base64 -d

    echo 

    read -p "Would you like to add it to your config file? (y/n): " choice

    if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
	echo "$TARGET_CFG" | base64 -d >> $CONFIG_FILE
        echo -e "\nAdded configuration for $TARGET to $CONFIG_FILE.\n"
    fi
else
    read -p "The configuration file '$CONFIG_FILE' does not exist. Do you want to create it? (y/n): " choice

    if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
	echo "$TARGET_CFG" | base64 -d > $CONFIG_FILE
        echo "Configuration written to $CONFIG_FILE."
    else
        echo "Configuration not written. Exiting."
    fi
fi

echo "Cloning repository"

git clone git@github.com:dani-garcia/vaultwarden.git

cd vaultwarden

cargo build -F sqlite -F vendored_openssl --target=aarch64-unknown-linux-gnu --release 

echo "Successfully built Vaultwarden."
echo
echo "To transfer the binary to the remote, run"
echo
echo '  scp vaultwarden/target/aarch64-unknown-linux-gnu/release/vaultwarden root@<IP>:/path/to/wherever'
echo
