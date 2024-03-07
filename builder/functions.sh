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

log(){
  printf '${COLOR_GREEN}Info: %b${COLOR_RESET}\n' "$*"
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
	fdisk -l "$1" | grep "Sector size" | awk '{print $4}'
}

get_final_sector() {
	fdisk -l -o end "$1" | grep "^\s*[0-9]" | awk '{print $1}' | sort -nr | head -n 1
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
  q
EOF
}

truncate_image() {
	local buffer=35
	local sector_size=$(fdisk -l "$1" | grep "Sector size" | awk '{print $4}')
	local final_sector=$(get_final_sector "$1")
	local end_bytes=$(((final_sector + buffer) * sector_size))

	log_info "Truncating image to $(format_bytes "$end_bytes")"
	truncate -s "$end_bytes" "$1"

	# recreate backup gpt table/header
	suppress sgdisk -e "$1" 2>&1 | sed 's/\a//g'
}
