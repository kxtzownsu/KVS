#!/bin/bash

COLOR_RESET="\033[0m"
COLOR_BLACK_B="\033[1;30m"
COLOR_RED="\033[0;31m"
COLOR_RED_B="\033[1;31m"
COLOR_GREEN="\033[0;32m"
COLOR_GREEN_B="\033[1;32m"
COLOR_YELLOW="\033[0;33m"
COLOR_YELLOW_B="\033[1;33m"
COLOR_BLUE="\033[0;34m"
COLOR_BLUE_B="\033[1;34m"
COLOR_MAGENTA="\033[0;35m"
COLOR_MAGENTA_B="\033[1;35m"
COLOR_CYAN="\033[0;36m"
COLOR_CYAN_B="\033[1;36m"

readlink /proc/$$/exe | grep -q bash || error "You MUST execute this with Bash!"

safesync(){
  sync
  sleep 0.2
}

log() {
  printf "%b\n" "${COLOR_BLUE_B}Info: $*${COLOR_RESET}"
}


cleanup(){
  suppress umount "$ROOT_MNT"
  rm -rf "$ROOT_MNT"
  
  suppress umount "$STATE_MNT"
  rm -rf "$STATE_MNT"
  
  suppress umount -R "$LOOPDEV"*
  
  losetup -d "$LOOPDEV"
  losetup -D #in case of cmd above failing
}

error(){
  printf "${COLOR_RED_B}ERR: %b${COLOR_RESET}\n" "$*" >&2 || :
  printf "${COLOR_RED}Exiting... ${COLOR_RESET}\n" >&2 || :
  exit 1
}

suppress() {
	if [ "${FLAGS_debug:-0}" = "${FLAGS_TRUE:-1}" ]; then
		"$@"
	else
		"$@" &>/dev/null
	fi
}

get_sector_size() {
	"$SFDISK" -l "$1" | grep "Sector size" | awk '{print $4}'
}

get_final_sector() {
	"$SFDISK" -l -o end "$1" | grep "^\s*[0-9]" | awk '{print $1}' | sort -nr | head -n 1
}

is_ext2() {
	local rootfs="$1"
	local offset="${2-0}"

	local sb_magic_offset=$((0x438))
	local sb_value=$(dd if="$rootfs" skip=$((offset + sb_magic_offset)) \
		count=2 bs=1 2>/dev/null)
	local expected_sb_value=$(printf '\123\357')
	if [ "$sb_value" = "$expected_sb_value" ]; then
		return 0
	fi
	return 1
}

enable_rw_mount() {
	local rootfs="$1"
	local offset="${2-0}"

	if ! is_ext2 "$rootfs" $offset; then
		echo "enable_rw_mount called on non-ext2 filesystem: $rootfs $offset" 1>&2
		return 1
	fi

	local ro_compat_offset=$((0x464 + 3))
	printf '\000' |
		dd of="$rootfs" seek=$((offset + ro_compat_offset)) \
			conv=notrunc count=1 bs=1 2>/dev/null
}

disable_rw_mount() {
	local rootfs="$1"
	local offset="${2-0}"

	if ! is_ext2 "$rootfs" $offset; then
		echo "disable_rw_mount called on non-ext2 filesystem: $rootfs $offset" 1>&2
		return 1
	fi

	local ro_compat_offset=$((0x464 + 3))
	printf '\377' |
		dd of="$rootfs" seek=$((offset + ro_compat_offset)) \
			conv=notrunc count=1 bs=1 2>/dev/null
}

shrink_partitions() {
  local shim="$1"
  fdisk "$shim" <<EOF
  d
  12
  d
  11
  d
  10
  d
  9
  d
  8
  d
  7
  d
  6
  d
  5
  d
  4
  d
  1
  w
EOF
}

truncate_image() {
	local buffer=35
	local sector_size=$("$SFDISK" -l "$1" | grep "Sector size" | awk '{print $4}')
	local final_sector=$(get_final_sector "$1")
	local end_bytes=$(((final_sector + buffer) * sector_size))

	log "Truncating image to $(format_bytes "$end_bytes")"
	truncate -s "$end_bytes" "$1"

	# recreate backup gpt table/header
	suppress sgdisk -e "$1" 2>&1 | sed 's/\a//g'
}

format_bytes() {
	numfmt --to=iec-i --suffix=B "$@"
}


create_stateful(){
  log "Creating KVS/Stateful Partition"
  local final_sector=$(get_final_sector "$LOOPDEV")
  local sector_size=$(get_sector_size "$LOOPDEV")
  # special UUID is from grunt shim, dunno if this is different on other shims
  "$CGPT" add "$LOOPDEV" -i 1 -b $((final_sector + 1)) -s $((STATE_SIZE / sector_size)) -t "9CC433E4-52DB-1F45-A951-316373C30605"
  partx -u -n 1 "$LOOPDEV"
  suppress mkfs.ext4 -F -L KVS "$LOOPDEV"p1
  safesync
}

inject_stateful(){
  log "Injecting KVS/Stateful Partition"
  
  echo "Mounting stateful.."
  mount "$LOOPDEV"p1 "$STATE_MNT"
  echo "Copying files.."
  cp -r $SCRIPT_DIR/stateful/* "$STATE_MNT"
  umount "$STATE_MNT"
}

shrink_root() {
  log "Shrinking ROOT-A Partition"

	enable_rw_mount "${LOOPDEV}p3"
	suppress e2fsck -fy "${LOOPDEV}p3"
	suppress resize2fs -M "${LOOPDEV}p3"
	disable_rw_mount "${LOOPDEV}p3"

	local sector_size=$(get_sector_size "$LOOPDEV")
	local block_size=$(tune2fs -l "${LOOPDEV}p3" | grep "Block size" | awk '{print $3}')
	local block_count=$(tune2fs -l "${LOOPDEV}p3" | grep "Block count" | awk '{print $3}')

	local original_sectors=$("$CGPT" show -i 3 -s -n -q "$LOOPDEV")
	local original_bytes=$((original_sectors * sector_size))

	local resized_bytes=$((block_count * block_size))
	local resized_sectors=$((resized_bytes / sector_size))

	echo "Resizing ROOT from $(format_bytes ${original_bytes}) to $(format_bytes ${resized_bytes})"
	"$CGPT" add -i 3 -s "$resized_sectors" "$LOOPDEV"
	partx -u -n 3 "$LOOPDEV"
}

inject_root(){
  log "Injecting ROOT-A Partition"
  
  echo "Mounting root.."
  suppress enable_rw_mount "$LOOPDEV"p3
  suppress mount "$LOOPDEV"p3 "$ROOT_MNT"
  echo "Copying files.."
  suppress cp -r "$SCRIPT_DIR"/root/* "$ROOT_MNT"
  echo "$(date +'%m-%d-%Y %I:%M%p %Z')" > "$ROOT_MNT"/DATE_COMPILED
  suppress umount "$ROOT_MNT"
}

get_parts_physical_order() {
	local part_table=$("$CGPT" show -q "$1")
	local physical_parts=$(awk '{print $1}' <<<"$part_table" | sort -n)
	for part in $physical_parts; do
		grep "^\s*${part}\s" <<<"$part_table" | awk '{print $3}'
	done
}

squash_partitions() {
	log "Squashing partitions"

	for part in $(get_parts_physical_order "$1"); do
		echo "Squashing ${1}p${part}"
		suppress "$SFDISK" -N "$part" --move-data "$1" <<<"+,-" || :
	done
}

umount_all(){
  suppress umount -R "$LOOPDEV"*
}