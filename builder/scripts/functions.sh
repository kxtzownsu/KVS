#!/bin/bash

style_text() {
  printf "\033[31m\033[1m\033[5m$1\033[0m\n"
}

panic(){
  case "$1" in
    "invalid-kernver")
      style_text "KVS PANIC"
      printf "\033[31mERR\033[0m"
      printf ": Invalid Kernel Version. Please make a GitHub issue at \033[3;34m$GITHUB_URL\033[0m with a picture of this information.\n"
      echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-="
      echo "tpm_kernver: $(crossystem tpm_kernver)"
      echo "fwid: $(dmidecode -s bios-version) (compiled: $(dmidecode -s bios-release-date))"
      echo "date: $(date +"%m-%d-%Y %I:%M:%S %p")"
      echo "model: $(cat /sys/class/dmi/id/product_name) $(cat /sys/class/dmi/id/product_version)"
      echo "Please shutdown your device now using REFRESH+PWR"
      sleep infinity
      ;;
    "mount-error")
      style_text "KVS PANIC"
      printf "\033[31mERR\033[0m"
      printf ": Unable to mount stateful. Please make a GitHub issue at \033[3;34m$GITHUB_URL\033[0m with a picture of this information.\n"
      echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-="
      echo "tpm_kernver: $(crossystem tpm_kernver)"
      echo "fwid: $(dmidecode -s bios-version) (compiled: $(dmidecode -s bios-release-date))"
      echo "state mounted: $([ -d /mnt/state/ ] && grep -qs '/mnt/state ' /proc/mounts && echo true || echo false)"
      echo "date: $(date +"%m-%d-%Y %I:%M:%S %p")"
      echo "model: $(cat /sys/class/dmi/id/product_name) $(cat /sys/class/dmi/id/product_version)"
      echo "Please shutdown your device now using REFRESH+PWR"
      sleep infinity
      ;;
    "non-reco")
      style_text "KVS PANIC"
      printf "\033[31mERR\033[0m"
      printf ": Wrong Boot Method. To fix: boot the shim using the recovery method. (ESC+REFRESH+PWR) and \033[31mNOT\033[0m USB Boot.\n"
      echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-="
      echo "tpm_kernver: $(crossystem tpm_kernver)"
      echo "fwid: $(dmidecode -s bios-version) (compiled: $(dmidecode -s bios-release-date))"
      echo "fw mode: $(crossystem mainfw_type)"
      echo "date: $(date +"%m-%d-%Y %I:%M:%S %p")"
      echo "model: $(cat /sys/class/dmi/id/product_name) $(cat /sys/class/dmi/id/product_version)"
      echo "Please shutdown your device now using REFRESH+PWR"
      sleep infinity
      ;;
    "tpmd-not-killed")
      style_text "KVS PANIC"
      printf "\033[31mERR\033[0m"
      printf ": $tpmdaemon unable to be killed. Please make a GitHub issue at \033[3;34m$GITHUB_URL\033[0m with a picture of this information.\n"
      echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-="
      echo "tpm_kernver: $(crossystem tpm_kernver)"
      echo "fwid: $(dmidecode -s bios-version) (compiled: $(dmidecode -s bios-release-date))"
      echo "tpmd ($tpmdaemon) running: $(status $tpmdaemon | grep stopped && echo true || echo false)"
      echo "date: $(date +"%m-%d-%Y %I:%M:%S %p")"
      echo "model: $(cat /sys/class/dmi/id/product_name) $(cat /sys/class/dmi/id/product_version)"
      echo "Please shutdown your device now using REFRESH+PWR"
      sleep infinity
      ;;
    "*")
      echo "Panic ID unable to be found: $1"
      echo "Exiting script to prevent crash, please make an issue at \033[3;34m$GITHUB_URL\033[0m."
  esac
}

stopwatch() {
    display_timer() {
        printf "[%02d:%02d:%02d]\n" $hh $mm $ss
    }
    hh=0 #hours
    mm=0 #minutes
    ss=0 #seconds
    
    while true; do
        clear
        echo "Initiated reboot, if this doesn't reboot please manually reboot with REFRESH+PWR"
        echo "Time since reboot initiated:"
        display_timer
        ss=$((ss + 1))
        # if seconds reach 60, increment the minutes
        if [ $ss -eq 60 ]; then
            ss=0
            mm=$((mm + 1))
        fi
        # if minutes reach 60, increment the hours
        if [ $mm -eq 60 ]; then
            mm=0
            hh=$((hh + 1))
        fi
        sleep 1
    done
}

selection(){
  case $1 in
    "1")
      echo "Please Enter Target kernver (0-3)"
      read -rep "> " kernver
      case $kernver in
        "0")
          echo "Setting kernver 0"
          write_tpm 0x1008 $(cat /mnt/realstate/kvs/kernver0)
          ;;
        "1")
          echo "Setting kernver 1"
          write_tpm 0x1008 $(cat /mnt/realstate/kvs/kernver1)
          ;;
        "2")
          echo "Setting kernver 2"
          write_tpm 0x1008 $(cat /mnt/realstate/kvs/kernver2)
          ;;
        "3")
          echo "Setting kernver 3"
          write_tpm 0x1008 $(cat /mnt/realstate/kvs/kernver3)
          ;;
        *)
          echo "Invalid kernver. Please check your input."
          main
          ;;
      esac ;;
    "2")
      case $currentkernver in
        "0x00000000")
          echo "Current kernver: 0"
          echo "Outputting to stateful/kernver-out"
          cp /mnt/realstate/kvs/kernver0 /mnt/state/kernver-out
          ;;
        "0x00010001")
          echo "Current kernver: 1"
          echo "Outputting to stateful/kernver-out"
          cp /mnt/realstate/kvs/kernver1 /mnt/state/kernver-out
          ;;
        "0x00010002")
          echo "Current kernver: 2"
          echo "Outputting to stateful/kernver-out"
          cp /mnt/realstate/kvs/kernver2 /mnt/state/kernver-out
          ;;
        "0x00010003")
          echo "Current kernver: 3"
          echo "Outputting to stateful/kernver-out"
          cp /mnt/realstate/kvs/kernver3 /mnt/state/kernver-out
          ;;
        *)
          panic "invalid-kernver"
          ;;
      esac ;;
    "3")
      credits
      ;;
    "4")
      endkvs
      ;;
  esac
}
