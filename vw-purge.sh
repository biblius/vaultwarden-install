#!/bin/bash

echo "Purging service"

systemctl stop vaultwarden.service
systemctl disable vaultwarden.service
rm /etc/systemd/system/vaultwarden.service
systemctl daemon-reload
systemctl reset-failed

echo "Purging user and group"

userdel -f vaultwarden

echo "Purging files"

rm -rf /opt/vaultwarden

echo "Successfully purged vaultwarden. If you do not need argon2, remove it with"
echo "  apt remove argon2"
