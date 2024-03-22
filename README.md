![KVS (dark)](/assets/kvs_dark-med.png#gh-dark-mode-only)
![KVS (light)](/assets/kvs_light-med.png#gh-light-mode-only)
<br>
## **K**ernel **V**ersion **S**witcher <br>
Made to easily change the kernver for Chromebooks. <br>
Works on unenrolled Chromebooks only. <br>
### How this works
This uses [`builder.sh`](https://github.com/kxtzownsu/KVS/blob/main/builder/builder.sh) to modify an RMA shim to inject our custom payload. <br>
The only reason we can inject a custom payload is due to the fact that in RMA Shims, only the KERNEL partitions are signed. <br>
We can edit the ROOTFS partitions all we want (*as long as we remove the forced RO bit (\377) on them*)

# How to use KVS
Please [download](https://dl.kxtz.dev/shims/KVS/) or [build](#build-instructions) a KVS Shim. <br>
After downloading, [boot](#booting-a-kvs-shim) your shim.

# Build Instructions
1) Clone the repo: <br />
```
git clone https://github.com/kxtzownsu/KVS.git
cd KVS/builder/
```

2) Make sure you have the following dependicies installed: <br />
```
gdisk e2fsprogs
```

3) Run the builder: <br />
```
sudo bash builder.sh <path to RAW shim> <optional flags>
```


# Booting a KVS shim
After flashing KVS to a RAW shim, download & open the [Chrome Recovery Utility](https://chromewebstore.google.com/detail/chromebook-recovery-utili/pocpnlppkickgojjlmhdmidojbmbodfm?pli=1). [🖼️ Attachment](https://github.com/kxtzownsu/KVS/assets/116377025/d30f383e-73c2-4809-a025-850490679dc9)
<br />
Press the Settings (⚙️) icon in the top right, and press "Use Local Image". Select your built KVS shim, and then select your target USB / SD.

After the shim is done flashing, go to your target Chromebook, press `ESC + Refresh (↻) + Power (⏻)` to enter the recovery menu, then press `CTRL+D` and then `ENTER` to enter the developer enviroment. Press `ESC + Refresh (↻) + Power (⏻)` again to enter the developer recovery menu. Now, insert your flashed USB/SD to the target Chromebook. Your Chromebook should now be booting the KVS shim.

# Why this only works unenrolled
So, due to [The Tsunami](https://github.com/MercuryWorkshop/sh1mmer?tab=readme-ov-file#the-tsunami), some TPM indexes are unable to be written to when FWMP (`0x100A` index) exists.<br> One of these indexes are `0x1008`, aka kernver.<br> Due to this, this is only able to be ran on verified images ***OR*** shims.

## Credits
[kxtzownsu](https://discord.com/users/952792525637312552) - Providing kernver 0 & kernver 1 files. <br>
[planetearth](https://discord.com/users/1057636239576154182) - Providing kernver 2 files. <br>
[miimaker](https://discord.com/users/449363069357785089) - Providing kernver 3 files. <br>
[OlyB](https://discord.com/users/476169716998733834) - Helping me with the shim builder, most of the shim builder wouldn't exist without them. <br>
[Google](https://google.com) - Writing the `tpmc` command :3
