#!/usr/bin/env bash

SCRIPT_DIR=$(dirname "$0")
VERSION=1
source $SCRIPT_DIR/functions.sh

echo "KVS Shim Builder v$VERSION"
echo "-=-=-=-=-=-=-=-=-=-"
echo "fdisk, e2fsprogs required. must be ran as root"
echo "-=-=-=-=-=-=-=-=-=-"
[ "$EUID" -ne 0 ] && error "Please run as root"
[ "$1" == "" ] && error "No shim specified."


STATE_SIZE=$((4 * 1024 * 1024)) # 4 MiB
STATE_MNT="$(mktemp -d)"
ROOT_MNT="$(mktemp -d)"
LOOPDEV="$(losetup -f)"
IMG="$1"

echo "loop: $LOOPDEV"
echo "root mount: $ROOT_MNT"
echo "state mount: $STATE_MNT"
echo "state size: $STATE_SIZE"
echo "shim: $IMG"
echo "-=-=-=-=-=-=-=-=-=-"
echo "Before building, huge credits to the MercuryWorkshop team for their work on wax,"
echo "some of this builder would have been impossible without it, at least with my disk knowledge"
echo "Press ENTER to continue, CTRL+C to quit"
read -r

#we need this before we re-create stateful
STATE_START=$(cgpt show "$IMG" | grep "STATE" | awk '{print $1}')
shrink_partitions "$IMG"
losetup -P "$LOOPDEV" "$IMG"
enable_rw_mount "$LOOPDEV"p3

log "Correcting GPT errors.."
fdisk -l "$LOOPDEV"
fdisk "$LOOPDEV" <<EOF
w
EOF

shrink_root
safesync

squash_partitions "$LOOPDEV"
safesync

create_stateful
safesync

inject_stateful
safesync

inject_root
safesync

cleanup
safesync

log "pre-truncate"
fdisk -l "$IMG"

truncate_image "$IMG"
safesync

log "post-truncate"
fdisk -l "$IMG"


log "Done building!"

