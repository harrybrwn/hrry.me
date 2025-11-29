#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# target mount point
MOUNT_POINT='${ mount_point }' # example: /mnt/storage
FS_TYPE='xfs'                  # change to ext4 if you prefer
LABEL='ebs_vol'                # optional label

log() {
	local lvl=info
	case "$1" in
		info|warning)
			lvl="$1"
			shift
			;;
		*)
			;;
	esac
	echo "[ebs-auto-mount] $*"
	echo "[ebs-auto-mount] $*" | systemd-cat -t "ebs-auto-mount" -p "$lvl"
}

if [ -z "$${FS_TYPE:-}" ]; then
  FS_TYPE='xfs'
fi
if [ -z "$${MOUNT_POINT:-}" ]; then
  log error 'No mount point given'
  exit 1
fi

END_AT=$(($(date '+%s') + 60))
# Wait for a second disk to showup
while [ $(lsblk -dn -o NAME,TYPE | awk '$2=="disk" {print $1}' | wc -l) -lt 2 ]; do
	if [ $(date '+%s') -gt $END_AT ]; then
		break
	fi
	log info 'Waiting for another block device...'
	sleep 2
done

# wait briefly for the kernel to expose block devices (udev)
log "waiting for udev..."
udevadm settle --timeout=30

# If already mounted, skip everything
if mountpoint -q "$${MOUNT_POINT}"; then
  log "$${MOUNT_POINT} already mounted -- nothing to do"
  exit 0
fi

# gather candidate disks (type disk) excluding loop and ram and such
mapfile -t disks < <(lsblk -dn -o NAME,TYPE | awk '$2=="disk" {print $1}')

if [ $${#disks[@]} -eq 0 ]; then
  log warning "no disk devices found"
  exit 0
fi

choose_dev=""
for name in "$${disks[@]}"; do
  devpath="/dev/$${name}"
  log "checking device $${devpath}"

  # make sure device exists as block node
  if [ ! -b "$${devpath}" ]; then
    log "  $${devpath} not present as block device, skipping"
    continue
  fi

  # 1) skip if any partitions exist on this device
  #    lsblk prints parent+children - count lines; headerless listing
  #    If more than 1 line, children (partitions) exist.
	child_count=$(lsblk -n -l -o NAME,TYPE "$${devpath}" | awk 'NR>1 && ($2=="part" || $2=="lvm") {count++} END {print (count+0)}')
  if [ "$${child_count}" -gt 0 ]; then
    log "  has partitions (count=$${child_count}), skipping"
    continue
  fi

  # 2) skip if any mountpoints exist for device or its children
  #    check lsblk MOUNTPOINT column for non-empty entries
  if lsblk -n -o MOUNTPOINT "$${devpath}" | grep -qve '^$'; then
		# TODO: This breaks if we're using LVM because the storage partition will
		# have children but no mount point and this check will always be true.
		log "  has mountpoint(s), skipping"
    continue
  fi

  # 3) skip if device already contains a filesystem
  #    check FSTYPE from lsblk (empty = no fs)
  fstype=$(lsblk -n -o FSTYPE "$${devpath}" | tr -d '[:space:]' || true)
  if [ -n "$${fstype}" ]; then
    log "  device has filesystem ($${fstype}), skipping"
    continue
  fi

  # If we reached here, this is a candidate
  choose_dev="$${devpath}"
  log "  selected $${choose_dev} as candidate"
  break
done

if [ -z "$${choose_dev}" ]; then
  log "no suitable device found (no unpartitioned, unmounted, unformatted disk). Exiting."
  exit 0
fi

# format the device if necessary (force to avoid prompts)
# double-check there's no filesystem now (avoid accidental overwrite)
if [ -z "$(lsblk -n -o FSTYPE "$${choose_dev}" | tr -d '[:space:]')" ]; then
  log "Formatting $${choose_dev} as $${FS_TYPE} with -L $${LABEL}..."
  if [ "$${FS_TYPE}" = "xfs" ]; then
    log "Running: mkfs.xfs -f -L \"$${LABEL}\" \"$${choose_dev}\""
    mkfs.xfs -f -L "$${LABEL}" "$${choose_dev}"
  else
    # default to ext4 if requested
    mkfs.ext4 -F -L "$${LABEL}" "$${choose_dev}"
  fi
else
  log "$${choose_dev} already has a filesystem, skipping format."
fi

# make mountpoint and mount by UUID to be stable across reboots
mkdir -p "$${MOUNT_POINT}"

uuid=$(blkid -s UUID -o value "$${choose_dev}" || true)
if [ -z "$${uuid}" ]; then
  # grab by LABEL fallback
  uuid=$(blkid -s UUID -o value "$${choose_dev}" || true)
fi

if [ -z "$${uuid}" ]; then
  # last-resort: use device path in fstab (less stable if kernel renames devices)
  fstab_entry="$${choose_dev} $${MOUNT_POINT} $${FS_TYPE} defaults,nofail 0 2"
else
  fstab_entry="UUID=$${uuid} $${MOUNT_POINT} $${FS_TYPE} defaults,nofail 0 2"
fi

# mount now
log "Mounting $${choose_dev} to $${MOUNT_POINT}..."
mount "$${choose_dev}" "$${MOUNT_POINT}"

# add fstab entry if not present
if ! grep -Fq "$${MOUNT_POINT}" /etc/fstab; then
  log "Adding to /etc/fstab: $${fstab_entry}"
  # make a safe backup then append
  cp /etc/fstab /etc/fstab.orig || true
  echo "$${fstab_entry}" >> /etc/fstab
else
  log "/etc/fstab already contains an entry for $${MOUNT_POINT}"
fi

log "Done. $${choose_dev} mounted at $${MOUNT_POINT}"
