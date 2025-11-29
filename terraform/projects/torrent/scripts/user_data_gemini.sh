#!/bin/bash
set -e

DEVICE_NAME="/dev/sdf"
MOUNT_POINT="/mnt/storage"

# Wait for the device to become available
while [ ! -b $DEVICE_NAME ]; do
	echo "Waiting for $DEVICE_NAME..."
	sleep 2
done

# Check if a filesystem already exists
if ! sudo file -s $DEVICE_NAME | grep -q 'filesystem'; then
	echo "Creating filesystem on $DEVICE_NAME..."
	sudo mkfs.ext4 $DEVICE_NAME
fi

# Create mount point
sudo mkdir -p $MOUNT_POINT

# Get block device UUID
UUID=$(sudo blkid -s UUID -o value $DEVICE_NAME)

# Add to /etc/fstab to mount on boot
if ! grep -q "UUID=$UUID" /etc/fstab; then
	echo "UUID=$UUID  $MOUNT_POINT  ext4  defaults,nofail  0  2" | sudo tee -a /etc/fstab
fi

# Mount the volume
sudo mount -a
