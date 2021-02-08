# [Arcade: Zaxxon](https://www.system16.com/hardware.php?id=689) port to [MiSTer](https://github.com/MiSTer-devel/Main_MiSTer/wiki)

MiSTer port by Dar (darfpga@aol.fr - sourceforge/darfpga)

## Description

A simulation model of Sega's Zaxxon hardware.

## Games

Currently implemented:

* Zaxxon
* Super Zaxxon
* Future Spy

## High score save/load

High score save/load is set to 'Manual' by default for this core.
 * To save your scores use the 'Save Settings' option in the OSD
 * To restore original scores, set the 'High Score Save' option to 'Off' and reset the core

## ROM Files Instructions

**ROMs are not included!** In order to use this arcade core, you will need to provide the correct ROM file yourself.

To simplify the process .mra files are provided in the releases folder, that specify the required ROMs with their checksums. The ROMs .zip filename refers to the
corresponding file from the MAME project.

Please refer to https://github.com/MiSTer-devel/Main_MiSTer/wiki/Arcade-Roms for information on how to setup and use the environment.

Quick reference for folders and file placement:

```
/_Arcade/<game name>.mra  
/_Arcade/cores/<game rbf>.rbf  
/_Arcade/mame/<mame rom>.zip  
/_Arcade/hbmame/<hbmame rom>.zip  
```
