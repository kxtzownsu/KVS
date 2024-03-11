#!/usr/bin/env bash

SCRIPT_DIR=$(dirname "$0")
VERSION=1

HOST_ARCH=$(lscpu | grep Architecture | awk '{print $2}')
if [ $HOST_ARCH == "x86_64" ]; then
  CGPT="$SCRIPT_DIR/bins/cgpt.x86-64"
  SFDISK="$SCRIPT_DIR/bins/sfdisk.x86-64"
else
  CGPT="$SCRIPT_DIR/bins/cgpt.aarch64"
  SFDISK="$SCRIPT_DIR/bins/sfdisk.aarch64"
fi

source $SCRIPT_DIR/functions.sh

echo "KVS Shim Builder v$VERSION"
echo "-=-=-=-=-=-=-=-=-=-"
echo "gdisk, e2fsprogs required. must be ran as root"
echo "-=-=-=-=-=-=-=-=-=-"
[ "$EUID" -ne 0 ] && error "Please run as root"
[ "$1" == "" ] && error "No shim specified."

# Stateful is REALLY small, only about 45K with a full one.
STATE_SIZE=$((1 * 1024 * 1024)) # 1MiB
STATE_MNT="$(mktemp -d)"
ROOT_MNT="$(mktemp -d)"
LOOPDEV="$(losetup -f)"
IMG="$1"

echo "Before building, huge credits to the MercuryWorkshop team for their work on wax,"
echo "some of this builder would have been impossible without it, at least with my disk knowledge"
echo "-=-=-=-=-=-=-=-=-=-=-"
echo "Press ENTER to continue building!"
read -r
echo "-=-=-=-=-=-=-=-=-=-=-"

#we need this before we re-create stateful
STATE_START=$("$CGPT" show "$IMG" | grep "STATE" | awk '{print $1}')
suppress shrink_partitions "$IMG"
losetup -P "$LOOPDEV" "$IMG"
enable_rw_mount "${LOOPDEV}p3"

log "Correcting GPT errors.."
suppress fdisk "$LOOPDEV" <<EOF
w
EOF

inject_root
safesync

shrink_root
safesync

create_stateful
safesync

inject_stateful
safesync

umount_all
safesync

squash_partitions "$LOOPDEV"
safesync

log "Checking for anti-skid lock..."
if [ "$2" == "--antiskid" ]; then
  echo "Skid lock found!"
  echo "Disabling RW mount.."
  disable_rw_mount "${LOOPDEV}p3"
else
  echo "Skid lock disabled.."
  echo "Enabling RW Mount.."
  enable_rw_mount "${LOOPDEV}p3"
fi

cleanup
safesync

truncate_image "$IMG"
safesync

log "Done building KVS!"
trap - EXIT
