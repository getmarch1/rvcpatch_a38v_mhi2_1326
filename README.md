Idea from https://github.com/mrfixpl/Audi-MHI2-RVC-fullscreen

Wanted to make an SWDLautorun solution if no wifi or d-link is available

Audi A3 8V MHI2_ER_AU37x_P5089_MU1326 only at the moment!!!

Use at your own risk.

Create backups before doing anything.

Vibecoded with Claude

FAT32 formatted SD Card needed


Patching takes about 4 minutes! Please be patient

Big Thank you to @nadeem2626 for fixing the Metainfo-Bug in the early releases



## v0.09 (changes)

- Status images: shorter black gap between two images. The helper calls no longer wait in fixed one-second steps, and after the first successfully displayed image the start-up wait is 1 s instead of 2 s. The time each image stays on screen is unchanged.

## v0.08 (changes)

- Verify: `cmp` is not available on the unit, so the copied files are now compared to the package files by checksum (sha1sum, otherwise cksum). On a mismatch the original files are restored and the installation is aborted. The method used is written to `rvcpatch.log`.
- Success image: new text (the unit restarts, please cancel the rear view documentation afterwards).

## v0.07 (changes)

- Status images: the library path for the display tool now also contains the graphics driver directories (the log of v0.06 showed a shader error). If the display tool exits or crashes, the screen is no longer switched (no black screen) and no further attempts are made in that run. The reason is written to `rvcpatch.log`.
- Second log: now written to `/HBpersistence/SWDL/RVCpatch_log/` (the old path was the version file created by SWDL). Limit 32 KB, plus one `.old` file.
- `uname` removed from the log (not available on the unit), free space of `/HBpersistence` added.

## v0.06 (changes)

- Status images: the display tools are now started with their own environment (PATH, library path, config dir), and every call and its output is written to `rvcpatch.log` (`[img]` lines) for troubleshooting.
- The log shows why the second log (internal memory) could not be written, if it fails.
- Firmware check: the log now shows the bytes read (hex) instead of an empty text.

## v0.05 (changes)

- Firmware check: the package only installs on `MHI2_ER_AU37x_P5089_MU1326`. Train and MU are read from the EEPROM (read only) at the very beginning, before anything is changed. If the firmware does not match or cannot be read, the installation is aborted and an error image is shown. The values found are written to `rvcpatch.log`. Set `FW_CHECK=0` at the top of `RVCpatch/tools/postscript.sh` to switch the check off (and update `scriptPostCheckSum` in `metainfo2.txt` afterwards).

## v0.04 (changes)

- Status images are shown on the display during the installation (check, backup, install, verify, success / error). They are best effort: if showing an image fails, the patch continues unaffected. Set `SHOW_IMAGES=0` at the top of `RVCpatch/tools/postscript.sh` to switch them off (and update `scriptPostCheckSum` in `metainfo2.txt` afterwards).
- More detailed log: package version, date, free space and checksums (unit vs. package) before and after.
- Backups are first created under a temporary name and renamed only after copying has finished, so an interrupted backup is never treated as valid.
- The log `rvcpatch.log` is written to the SD card and additionally to the internal memory (if writable).
