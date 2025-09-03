#!/bin/bash

# Mount root as read-write and ensure critical paths are accessible
sudo /bin/mount -o remount,rw /

# Disable unnecessary services for better performance
sudo systemctl stop systemd-timesyncd 2>/dev/null
sudo systemctl disable systemd-timesyncd 2>/dev/null

echo "Resizing ubuntu.img to 5GB..."
truncate -s 5G /userdata/ubuntu.img
echo "Updating loop device..."
losetup -c /dev/loop0
echo "Resizing filesystem..."
resize2fs /dev/loop0
echo "Resize operations completed successfully."


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

# Find and replace or add configurations
sudo sed -i '/^Include \/etc\/ssh\/sshd_config.d\/\*.conf/s/^/# /' /etc/ssh/sshd_config
sudo sed -i "/^Port/c\Port 22" $SSH_CONFIG
sudo sed -i "/^PasswordAuthentication/c\PasswordAuthentication yes" $SSH_CONFIG
sudo sed -i "/^PermitEmptyPasswords/c\PermitEmptyPasswords yes" $SSH_CONFIG
sudo sed -i "/^PermitRootLogin/c\PermitRootLogin yes" $SSH_CONFIG

# Restart SSH service to apply changes
sudo service ssh restart

echo "Service created, SSH configuration updated, optimizations applied, and services restarted."
