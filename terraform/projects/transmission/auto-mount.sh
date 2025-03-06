#!/usr/bin/bash

set -euo pipefail

lsblk -p | grep '/dev/nvme1n1'
uuid="$(blkid /dev/nvme1n1 | sed -n 's/.*UUID="\([^"]*\)".*/\1/p')"
if [ -z "${uuid:-}" ]; then
	sudo mkfs -t ext4 /dev/nvme1n1
fi

uuid="$(blkid /dev/nvme1n1 | sed -n 's/.*UUID="\([^"]*\)".*/\1/p')"
if grep "/mnt/storage" /etc/fstab ; then
  echo "Already in fstab"
else
	echo -e "UUID=${uuid}	/mnt/storage		ext4	errors=remount-ro		0	1" | sudo tee -a /etc/fstab
fi

if [ ! -d /mnt/storage ]; then
	sudo mkdir -p /mnt/storage
	sudo chmod 0777 /mnt/storage
fi
sudo mount /mnt/storage
lsblk -p

# vim: noexpandtab
