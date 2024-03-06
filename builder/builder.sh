#!/bin/bash

SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=${SCRIPT_DIR:-"."}
. "$SCRIPT_DIR/functions.sh"

VERSION=1
echo "KVS Shim Builder v$VERSION"
echo "-=-=-=-=-=-=-=-=-=-"
[ "$EUID" -ne 0 ] && error "Please run KVS builder as root"
[ "$1" == "" ] && error "Shim not specified, remember, usage is $0 <shim> <flag>"
echo "Requirements: cgpt, e2fsprogs, sgdisk"
echo "-=-=-=-=-=-=-=-=-=-"

STATE_SIZE=$((4 * 1024 * 1024)) # 4MiB
STATE_MNT=$(mktemp -d)
LOOPDEV=$(losetup -f)

create_stateful() {
	log "Creating KVS/Stateful partition"
	local final_sector=$(get_final_sector "$LOOPDEV")
	local sector_size=$(get_sector_size "$LOOPDEV")
	cgpt add "$LOOPDEV" -i 1 -b $((final_sector + 1)) -s $((STATE_SIZE / sector_size)) -t data -l KVS
	partx -u -n 1 "$LOOPDEV"
	mkfs.ext4 -F -L KVS "${LOOPDEV}p1" &> /dev/null

	sync
	sleep 0.2

	mount "${LOOPDEV}p1" "$STATE_MNT"
	touch "$STATE_MNT/dev_image/etc/lsb-factory"
	chmod -R +x "$STATE_MNT"

	umount "$STATE_MNT"
	rmdir "$STATE_MNT"
}

shrink_root() {
	log "Shrinking ROOT"

	enable_rw_mount "${LOOPDEV}p3"
	suppress e2fsck -fy "${LOOPDEV}p3"
	suppress resize2fs -M "${LOOPDEV}p3"
	disable_rw_mount "${LOOPDEV}p3"

	local sector_size=$(get_sector_size "$LOOPDEV")
	local block_size=$(tune2fs -l "${LOOPDEV}p3" | grep "Block size" | awk '{print $3}')
	local block_count=$(tune2fs -l "${LOOPDEV}p3" | grep "Block count" | awk '{print $3}')

	log_debug "sector size: ${sector_size}, block size: ${block_size}, block count: ${block_count}"

	local original_sectors=$("$CGPT" show -i 3 -s -n -q "$LOOPDEV")
	local original_bytes=$((original_sectors * sector_size))

	local resized_bytes=$((block_count * block_size))
	local resized_sectors=$((resized_bytes / sector_size))

	log_info "Resizing ROOT from $(format_bytes ${original_bytes}) to $(format_bytes ${resized_bytes})"
	"$CGPT" add -i 3 -s "$resized_sectors" "$LOOPDEV"
	partx -u -n 3 "$LOOPDEV"
}