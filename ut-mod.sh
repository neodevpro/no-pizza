#!/bin/bash

sudo /bin/mount -o remount,rw /

# Create the systemd service file
cat <<EOL | sudo tee /etc/systemd/system/remount-rw.service
[Unit]
Description=Remount Root Filesystem as Read/Write
DefaultDependencies=no
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/bin/mount -o remount,rw /

[Install]
WantedBy=multi-user.target
EOL

# Enable the service to run at boot
sudo systemctl enable remount-rw.service

# Update SSH configuration
SSH_CONFIG="/etc/ssh/sshd_config"

# Backup the original sshd_config file
sudo cp $SSH_CONFIG $SSH_CONFIG.bak

# Find and replace or add configurations
sudo sed -i "/^# Include \/etc\/ssh\/sshd_config.d\/\*.conf/c\Include /etc/ssh/sshd_config.d/*.conf" $SSH_CONFIG
sudo sed -i "/^Port/c\Port 22" $SSH_CONFIG
sudo sed -i "/^PasswordAuthentication/c\PasswordAuthentication yes" $SSH_CONFIG
sudo sed -i "/^PermitEmptyPasswords/c\PermitEmptyPasswords yes" $SSH_CONFIG
sudo sed -i "/^PermitRootLogin/c\PermitRootLogin yes" $SSH_CONFIG

# Restart SSH service to apply changes
sudo systemctl restart sshd

echo "Service created, SSH configuration updated, and SSH service restarted."