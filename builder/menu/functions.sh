#!/bin/bash

style_text() {
  printf "\e[31m\033[1m\033[5m$1\e[0m\n"
}

panic(){
  case "$1" in
    "invalid-kernver")
      style_text "KVS PANIC"
      printf "\e[31mERR\e[0m"
      printf ": Invalid Kernel Version. Please make a GitHub issue at \e[3;34m$GITHUB_URL\e[0m with a picture of this information.\n"
      echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-="
      echo "tpm_kernver: $(crossystem tpm_kernver)"
      echo "fwid: $(crossystem ro_fwid)"
      echo "date: $(date)"
      echo "model: $(cat /sys/class/dmi/id/product_name) $(cat /sys/class/dmi/id/product_version)"
      echo "Please shutdown your device now using REFRESH+PWR"
      sleep infinity
      ;;
    "mount-error")
      style_text "KVS PANIC"
      printf "\e[31mERR\e[0m"
      printf ": Unable to mount stateful. Please make a GitHub issue at \e[3;34m$GITHUB_URL\e[0m with a picture of this information.\n"
      echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-="
      echo "tpm_kernver: $(crossystem tpm_kernver)"
      echo "fwid: $(crossystem ro_fwid)"
      echo "state mounted: $([ -d /mnt/state/ ] && grep -qs '/mnt/state ' /proc/mounts && echo true || echo false)"
      echo "date: $(date)"
      echo "model: $(cat /sys/class/dmi/id/product_name) $(cat /sys/class/dmi/id/product_version)"
      echo "Please shutdown your device now using REFRESH+PWR"
      sleep infinity
      
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
      read -r kernver
      case $kernver in
        "0")
          echo "Setting kernver 0"
          ;;
        "1")
          echo "Setting kernver 1"
          ;;
        "2")
          echo "Setting kernver 2"
          ;;
        "3")
          echo "Setting kernver 3"
          ;;
        *)
          echo "Invalid kernver. Please check your input."
          main
          ;;
      esac ;;
    "2")
      if [ $currentkernver == "0x00000000" ]; then
        echo "Current kernver: 0"
        echo "Outputting to stateful/kernver-out"
        cp /mnt/state/versions/kernver0 /mnt/state/kernver-out
      elif [ $currentkernver == "0x00010001" ]; then
        echo "Current kernver: 1"
        echo "Outputting to stateful/kernver-out"
        cp /mnt/state/versions/kernver1 /mnt/state/kernver-out
      elif [ $currentkernver == "0x00010002" ]; then
        echo "Current kernver: 2"
        echo "Outputting to stateful/kernver-out"
        cp /mnt/state/versions/kernver2 /mnt/state/kernver-out
      elif [ $currentkernver == "0x00010003" ]; then
        echo "Current kernver: 3"
        echo "Outputting to stateful/kernver-out"
        cp /mnt/state/versions/kernver3 /mnt/state/kernver-out
      fi
      ;;
    "3")
      credits
      ;;
    "4")
      endkvs
      ;;
  esac
}
