#!/bin/bash

# Mount root as read-write and ensure critical paths are accessible
sudo /bin/mount -o remount,rw /

# Disable unnecessary services for better performance
sudo systemctl stop systemd-timesyncd 2>/dev/null
sudo systemctl disable systemd-timesyncd 2>/dev/null

# Check if ubuntu.img exists and is less than 6GB
if [ ! -f /userdata/ubuntu.img ]; then
    echo "Error: /userdata/ubuntu.img does not exist"
    exit 1
fi

current_size=$(stat -f %z /userdata/ubuntu.img)
if [ $current_size -ge 6442450944 ]; then  # 6GB in bytes
    echo "Error: ubuntu.img is already 6GB or larger"
    exit 1
fi

# Check available space in /userdata
available_space=$(df /userdata | awk 'NR==2 {print $4}')  # Available space in KB
needed_space=$((5242880))  # 5GB in KB

if [ $available_space -lt $needed_space ]; then
    echo "Error: Not enough space in /userdata. Need at least 5GB free."
    exit 1
fi

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

echo "Service created, SSH configuration updated, optimizations applied, and services restarted."
