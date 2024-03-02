#!/bin/bash
# KVS: Kernel Version Switcher
# Written by kxtzownsu / kxtz#8161
# https://kxtz.dev
# Licensed under GPLv3

version=1
GITHUB_URL="https://github.com/kxtzownsu/KVS"

# give me thy kernver NOW
case "$(crossystem tpm_kernver)" in
  "0x00000000")
    kernver="0"
    ;;
  "0x00010001")
    kernver="1"
    ;;
  "0x00010002")
    kernver="2"
    ;;
  "0x00010003")
    kernver="3"
    ;;
  *)
    panic "invalid-kernver"
    ;;
esac


source functions.sh
source tpmutil.sh

# detect if booted from usb boot or from recovery boot
if [ "$(crossystem mainfw_type)" == "recovery" ]; then
  source tpmutil.sh
  mkdir /mnt/state &2> /dev/zero
  mount /dev/disk/by-label/KVS /mnt/state
elif [ "$(crossystem mainfw_type)" == "developer" ]; then
  # echo "Please run this shim using the Recovery Boot method. (ESC+REFRESH+PWR)"
  echo ""
  clear
fi

credits(){
  echo "KVS: Kernel Version Switcher"
  echo "V$version"
  echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
  echo "kxtzownsu - Writing KVS, Providing kernver 0 & kernver 1 files."
  echo "??? - Providing kernver 2 files."
  echo "TBD - Providing kernver 3 files."
  echo "Google - Writing the `tpmc` command :3"
}

endkvs(){
  # reboot now
  stopwatch
}


main(){
  echo "KVS: Kernel Version Switcher v$version"
  echo "Current kernver: $kernver"
  echo "=-=-=-=-=-=-=-=-=-=-"
  echo "1) Set New kernver"
  echo "2) Backup kernver (WIP, Kinda Broken)"
  echo "3) Credits"
  echo "4) Exit"
  read -rep "> " sel
  
  selection $sel
}


panic mount-error