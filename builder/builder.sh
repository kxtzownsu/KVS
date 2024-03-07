#!/bin/bash
# KVS Builder v1
# Basically a skidded wax, please forgive me
# Credits to the Mercury Workshop team for the shim shrinking stuff :3
# Made by kxtzownsu
# 3-6-2024
# GNU Affero GPL v3

SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=${SCRIPT_DIR:-"."}
. "$SCRIPT_DIR/functions.sh"

VERSION=1
echo "KVS Shim Builder v$VERSION"
echo "-=-=-=-=-=-=-=-=-=-"
[ "$EUID" -ne 0 ] && error "Please run KVS builder as root"
[ "$1" == "" ] && error "Shim not specified, remember, usage is $0 <shim> <flag>"
[ $(echo $1 | grep -qs '.bin' - && echo true || echo false) == "false" ] && error "Shim is NOT a .bin file!"
echo "Requirements: cgpt, e2fsprogs, sgdisk, raw shim"
echo "-=-=-=-=-=-=-=-=-=-"
echo "Before the shim starts building, I'd like to say thank you to the Mercury Workshop team, most of the code (shim shrinking, verity disabling, etc) is from them."
echo "Pres Enter to continue building"
read -r

STATE_SIZE=$((4 * 1024 * 1024)) # 4MiB
STATE_MNT=$(mktemp -d)
ROOT_MNT=$(mktemp -d)
LOOPDEV=$(losetup -f)

clean_mnts(){
  umount -R "$STATE_MNT"
  umount -R "$ROOT_MNT"
  rm -rf "$STATE_MNT"
  rm -rf "$ROOT_MNT"
}

create_stateful() {
	log "Creating KVS/Stateful partition (1/"
	local final_sector=$(get_final_sector "$LOOPDEV")
	local sector_size=$(get_sector_size "$LOOPDEV")
	cgpt add "$LOOPDEV" -i 1 -b $((final_sector + 1)) -s $((STATE_SIZE / sector_size)) -t data -l KVS
	partx -u -n 1 "$LOOPDEV"
	mkfs.ext4 -F -L KVS "${LOOPDEV}p1" &> /dev/null

	safesync

	mount "${LOOPDEV}p1" "$STATE_MNT"
	touch "$STATE_MNT/dev_image/etc/lsb-factory"
	chmod -R +x "$STATE_MNT"

	umount "$STATE_MNT"
}

inject_stateful(){
  log "Injecting Stateful (2"
  
  mount
}

shrink_root() {
	log "Shrinking ROOT (4"

	enable_rw_mount "${LOOPDEV}p3"
	suppress e2fsck -fy "${LOOPDEV}p3"
	suppress resize2fs -M "${LOOPDEV}p3"
	disable_rw_mount "${LOOPDEV}p3"

	local sector_size=$(get_sector_size "$LOOPDEV")
	local block_size=$(tune2fs -l "${LOOPDEV}p3" | grep "Block size" | awk '{print $3}')
	local block_count=$(tune2fs -l "${LOOPDEV}p3" | grep "Block count" | awk '{print $3}')

	log "sector size: ${sector_size}, block size: ${block_size}, block count: ${block_count}"

	local original_sectors=$(cgpt show -i 3 -s -n -q "$LOOPDEV")
	local original_bytes=$((original_sectors * sector_size))

	local resized_bytes=$((block_count * block_size))
	local resized_sectors=$((resized_bytes / sector_size))

	log "Resizing ROOT from $(format_bytes ${original_bytes}) to $(format_bytes ${resized_bytes})"
	"$CGPT" add -i 3 -s "$resized_sectors" "$LOOPDEV"
	partx -u -n 3 "$LOOPDEV"
}

inject_root(){
  enable_rw_mount "${LOOPDEV}p3"
  log "Injecting scripts (3"
  
  mount "${LOOPDEV}p3" "${ROOT_MNT}"
  
  # scary if ROOT_MNT gets set to nothing!
  cp -r scripts/* "${ROOT_MNT}/usr/sbin"
}


create_stateful
inject_stateful
inject_root
shrink_root
shrink_partitions "$LOOPDEV"

# for prebuilt bins hosted on dl.kxtz.dev
if [ "$2" == "--noskid" ]; then
  disable_rw_mount "${LOOPDEV}p3"
  log "Disabled RW mounting for ROOT-A"
fi

clean_mnts
losetup -D "$LOOPDEV"

truncate_image "$1"