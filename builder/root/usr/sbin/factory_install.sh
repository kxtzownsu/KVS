#!/bin/bash
# KVS: Kernel Version Switcher
# Written by kxtzownsu / kxtz#8161
# https://kxtz.dev
# Licensed under GNU Affero GPL v3

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "$0 $(printf '\033[1;31mMUST\033[0m') be ran as root/sudo!"
    exit
fi

version=1
GITHUB_URL="https://github.com/kxtzownsu/KVS"
tpmver=$(tpmc tpmver)

if [ "$tpmver" == "2.0" ]; then
  tpmdaemon="trunksd"
else
  tpmdaemon="tscd"
fi

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

# detect if booted from usb boot or from recovery boot
if [ "$(crossystem mainfw_type)" == "recovery" ]; then
  source /usr/share/kvs/tpmutil.sh
  source /usr/share/kvs/functions.sh
  mkdir -p /mnt/state &2>1 /dev/null
  mount /dev/disk/by-label/KVS /mnt/state
  stop $tpmdaemon
  clear
elif [ "$(crossystem mainfw_type)" == "developer" ]; then
  source /usr/sbin/kvs/tpmutil.sh
  source /usr/sbin/kvs/functions.sh
  # panic "non-reco"
  # sleep infinity
  clear
  . ../share/kvs/functions.sh
  . ../share/kvs/tpmutil.sh
  source ../share/kvs/functions.sh
  source ../share/kvs/tpmutil.sh
  style_text "YOU ARE RUNNING A DEBUG VERSION OF KVS, THIS WAS OPTIMIZED TO RUN ON CHROMEOS ONLY! ALL ACTIONS ARE PURELY VISUAL AND NOT FUNCTIONAL IN THIS MODE!!!"
  sleep 5
  clear
fi

credits(){
  clear
  echo "KVS: Kernel Version Switcher v$version"
  echo "Current kernver: $kernver"
  echo "TPM Version: $tpmver"
  echo "TPMD: $tpmdaemon"
  echo "-=-=-=-=-=-=-=-=-=-=-"
  echo "kxtzownsu - Writing KVS, Providing kernver 0 & kernver 1 files."
  echo "planetearth1363 - Providing kernver 2 files."
  echo "miimaker - Providing kernver 3 files."
  echo "OlyB - Helping me figure out the shim builder, seriously, thanks."
  echo "Google - Writing the 'tpmc' command :3"
  echo "-=-=-=-=-=-=-=-=-=-=-"
  echo "Press ENTER to return to the main menu"
  read -r
}

endkvs(){
  # reboot now
  stopwatch
}


main(){
  echo "KVS: Kernel Version Switcher v$version"
  echo "Current kernver: $kernver"
  echo "TPM Version: $tpmver"
  echo "TPMD: $tpmdaemon"
  echo "-=-=-=-=-=-=-=-=-=-=-"
  echo "1) Set New kernver"
  echo "2) Backup kernver"
  echo "3) Bash Shell"
  echo "4) Credits"
  echo "5) Exit"
  printf '\x1b[?25h'
  read -rep "$(printf '\x1b[?25h')> " sel
  
  selection $sel
}


while true; do
  clear
  main
done
