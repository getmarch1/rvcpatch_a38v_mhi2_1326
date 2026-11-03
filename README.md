Idea from https://github.com/mrfixpl/Audi-MHI2-RVC-fullscreen

Wanted to make an SWDLautorun solution if no wifi or d-link is available

Audi A3 8V MHI2_ER_AU37x_P5089_MU1326 only at the moment!!!

Use at your own risk.

Create backups before doing anything.

Vibecoded with Claude

FAT32 formatted SD Card needed


## v0.05 (changes)

- Firmware check: the package only installs on `MHI2_ER_AU37x_P5089_MU1326`. Train and MU are read from the EEPROM (read only) at the very beginning, before anything is changed. If the firmware does not match or cannot be read, the installation is aborted and an error image is shown. The values found are written to `rvcpatch.log`. Set `FW_CHECK=0` at the top of `RVCpatch/tools/postscript.sh` to switch the check off (and update `scriptPostCheckSum` in `metainfo2.txt` afterwards).

## v0.04 (changes)

~~- Status images are shown on the display during the installation (check, backup, install, verify, success / error). They are best effort: if showing an image fails, the patch continues unaffected. Set `SHOW_IMAGES=0` at the top of `RVCpatch/tools/postscript.sh` to switch them off (and update `scriptPostCheckSum` in `metainfo2.txt` afterwards).~~ does not work :( 
- More detailed log: package version, date, free space and checksums (unit vs. package) before and after.
- Backups are first created under a temporary name and renamed only after copying has finished, so an interrupted backup is never treated as valid.
- The log `rvcpatch.log` is written to the SD card and additionally to the internal memory (if writable).
