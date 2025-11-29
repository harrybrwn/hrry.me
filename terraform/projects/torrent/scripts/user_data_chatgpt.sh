#!/bin/bash
set -eux

DEVICE_NAME="${ device_name }"
MOUNT_POINT="${ mount_point }"

# Wait for the volume to be attached
while [ ! -b $DEVICE_NAME ]; do
	echo "Waiting for $DEVICE_NAME..."
	sleep 2
done
sleep 2 # another one just in case

if ! blkid "$DEVICE_NAME"; then
	echo "No a block device"
	exit 1
fi

# Check if the device is formatted; if not, format it
if ! file -s $DEVICE_NAME | grep -q 'filesystem'; then
	mkfs.xfs $DEVICE_NAME
fi

mkdir -p "$MOUNT_POINT"
mount "$DEVICE_NAME" "$MOUNT_POINT"

# Persist the mount
echo "$DEVICE_NAME $MOUNT_POINT xfs defaults,nofail 0 2" >> /etc/fstab

