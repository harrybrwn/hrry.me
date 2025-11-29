#!/bin/bash
# Wait for the volume to be available
DEVICE="/dev/sdf"
MOUNT_POINT="/mnt/storage"

# Check if device exists
while [ ! -b $DEVICE ]; do
		echo "Waiting for $DEVICE to be available..."
		sleep 5
done

# Create filesystem if not already created
if ! blkid $DEVICE; then
		echo "Creating filesystem on $DEVICE"
		mkfs -t xfs $DEVICE
fi

# Create mount point
mkdir -p $MOUNT_POINT

# Mount the volume
mount $DEVICE $MOUNT_POINT

# Add to fstab for automatic mounting on reboot
echo "$DEVICE $MOUNT_POINT xfs defaults,nofail 0 2" >> /etc/fstab

# Verify mount
mountpoint $MOUNT_POINT && echo "Successfully mounted $DEVICE to $MOUNT_POINT"

