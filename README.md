# system_info
## A Raspberry Pi System Configuration Reporting Tool

![Image](https://raw.githubusercontent.com/kencormack/system_info/master/scr-title.jpg)

This script attempts to perform a fairly complete audit of the current configuration of a Raspberry Pi.  The target
hardware is any variant or model of Pi, including the Pi 4B in all it's available memory configurations (1/2/4/8GB),
the 400, and CM4.  Supported OS versions include Raspbian Buster, and the newly renamed "Raspberry Pi OS, in
32-bit versions.  **Expect things not to work on the 64-bit OS, while it is still beta.**  No attempts will
be made to back-port this to Jessie or older, nor will I attempt to port this to Ubuntu, OSMC, LibreELEC, or any
other OS distribution available for the Pi.

## SUPPORT FOR "STRETCH" OFFICIALLY ENDS WITH VERSION 2.1.2 OF THIS SCRIPT.##
**Later versions of this script *may* run under Stretch, but no testing will be performed on Stretch, and no
assurances of compatability given.**

```
NOTE: 20 December 2020
My Pi3B+ Stretch system has died, and will be replaced with a 4B, necessitating Buster.  As such,
I no longer have a system with which to ensure continued compatability with Stretch.

NOTE: 03 November 2020
The new Pi 400 "Pi in a keyboard" has just been released.  Few details are published at this time,
but aside from being faster, it appears largely identical in features and function, to a 4B. 

NOTE: 21 June 2020
The 8GB model of Pi 4B is now available.  This script has not specifically been tested on the new
hardware, as I do not have access to one at the moment.  I expect no issues with this script on the
8GB hardware, under the existing stable Raspbian Buster, or newly renamed "Raspberry Pi OS" (32-bit).
```

## A note about the BETA 64-Bit "Raspberry Pi OS"

I will not be testing the new 64-bit "Raspberry Pi OS" until it comes out of beta, as I prefer not to
chase a moving target, especially this early in it's development.

For more details see: https://www.raspberrypi.org/forums/viewtopic.php?t=275370

## With all of that having been said...

The script is an "examination only" affair, making no attempts to add, delete, or change anything on the system.
No re-configuration of any subsystem is done, nor does it attempt to install anything.  It's job is simply to report
what it finds.

The intended audience for this script is any Pi user who wants to see how aspects of their Pi are currently equipped
and configured, for general troubleshooting, confirmation, or education/curiosity purposes.  In it's inspection of a
system, it does nothing that hasn't already been done by any/all of the tools it calls upon.  I'm just consolidating
everything into one place.  Deliberate attempts were made to make things easy to follow, and the coding style is
meant for easy readability.

## 'sudo' access is required.

The script can be run as the user, and will call sudo only for those
commands that need root privilege.

## Installation

The script is designed to run with the bash shell.  Just install, enable execute permission, and run it...
```
$ git clone https://github.com/kencormack/system_info.git
$ cd system_info
$ chmod +x system_info*
$ ./system_info*
```

## Updating

To update, 'cd' into the directory into which you originally installed system_info, and run the following command:
```
$ git pull
```
That should do it.

**If, for any reason, git detects that your local copy has changed, and gives the following message...**
```
error: Your local changes to the following files would be overwritten by merge:
        filename
Please commit your changes or stash them before you merge.
```
... copy your local changed file to an alternate location, and run the following command to reset git's pointers:
```
$ git reset --hard origin/master
```
... and then re-try the "git pull".  **This will overwrite your local changes with the update from github.**


## The following packages are required, to do a basic inspection:

- alsa-utils
- bc
- bluez
- coreutils
- cron
- i2c-tools
- initramfs-tools
- iproute2
- libraspberrypi-bin
- lsb-release
- lshw
- net-tools
- procps
- usbutils
- sed
- systemd
- util-linux
- v4l-utils
- wireless-tools

**If the Pi being examined is a 4B, CM4, or Pi 400, the package 'rpi-eeprom' is also required.**

The script will explicitly test that each of the above required packages is installed.  If any are missing, the
script will inform the user, and instruct them to install.

## The following supplemental packages may also be utilized, to provide a more comprehensive examination:

- apparmor
- at
- auditd
- chkrootkit
- clamav
- cups-client
- dc
- docker-ce-cli ("docker.io", on Stretch)
- ethtool
- hdparm
- lirc
- lm-sensors
- lynis
- lvm2
- m4
- mdadm
- nfs-kernel-server
- nmap
- perl-base
- pigpiod ("pigpio", on Stretch)
- python3-gpiozero
- quota
- rkhunter
- rng-tools
- rpcbind
- rtl-sdr
- samba
- smartmontools
- snort
- sysbench
- sysstat
- systemd-container
- systemd-coredump
- tripwire
- ufw
- unhide
- watchdog
- wiringpi
- x11-xserver-utils

The supplemental packages are not required, and the user will not be instructed to install them.  But they will be
utilized if installed and configured.  Sections of the output made possible by the supplemental packages will be
marked with *** in the heading of any sections involved, or in the part of an otherwise core test that has made use
of the supplemental package.

## A word about WiringPi

If you have a raspberry pi 4B (1/2/4GB models only), and have WiringPi installed, ensure that it is version 2.52.
See: [http://wiringpi.com/wiringpi-updated-to-2-52-for-the-raspberry-pi-4b/](http://wiringpi.com/wiringpi-updated-to-2-52-for-the-raspberry-pi-4b/).

As 2.52 does not work with the 8GB variant of the Pi 4B (or later models such as the CM4 or new Pi 400), and as
WiringPi is now deprecated, I do not call upon it when examining the 8GB Pi 4B, or later models.  The Pi 4B 1/2/4GB
variants will still be examined, if WiringPi 2.52 is found to be installed.  The Pi 4B 8GB, and later Pi models,
however, will not.

## system_info is menu-driven

![Image](https://raw.githubusercontent.com/kencormack/system_info/master/scr-menu.jpg)

This allows sub-sets of the inspections to run.  The last option on the menu allows the user to run all the
categories without having to select every category individually, if desired.  Any time the last selection is set,
all categories will be executed regardless of any categories above it being marked selected or not.  The user's
selections are saved to the file ".system_inforc" in the home directory of the userid that ran the script.  Those
selections are then recalled, and those same menu options auto-selected for you, the next time that userid runs
the script.

## All reports are saved to disk

![Image](https://raw.githubusercontent.com/kencormack/system_info/master/scr-summary.jpg)

Each time a report is run, a report file is created in the home directory of the userid running the script.  If you
launch the script as user "pi", the report will end up in /home/pi (pi's homedir).  If you launch the script with
"sudo", sudo makes you "root", thus the report will end up in /root (root's homedir).  At the bottom of the report,
the name given to the report, along with where it was saved, is listed.  The filename of the report contains the
hostname, the name of the script, and the date and time the report was run, in the format:

hostname-scriptname-YYYY-MM-DD-HH-MM-SS

On my development system (hostname "pi-dev"), an example report run on 2020 June 06, at 10:39:51 AM, would be named:
/home/pi/pi-dev-system_info-2020-06-06-10-39-51

## The Sysbench File IO test, and wear-sensitive media

If the supplemental package "sysbench" is installed, system_info includes functions to perform three different
sysbench performance tests... the CPU, Memory read/write, and File I/O speed tests.  The first two of these (CPU
and Memory read/write) will be performed without user intervention.  But because the last of these (the File I/O
speed test) creates, writes, reads and deletes 128 files, 16Mb each (2GB total), most people will NOT want to do
that much writing to their media (particularly those running on SD cards and SSD drives), on a regular basis.
Hence, system_info's default behavior is NOT to run the sysbench File I/O test under normal use.

- If the user DOES want to enable the sysbench File I/O tests (assuming they have sysbench installed), manually
"touch ${HOME}/.system_info_io" to enable that test.  If system_info finds that that file exists, it will perform
the sysbench File I/O tests (again, assuming sysbench is installed.)
- The command "rm ${HOME}/.system_info_io" (if that file exists) will remove the touchfile, preventing the sysbench
File I/O test's execution.
- IMPORTANT: In addition to the wear and tear thrown at wear-sensitive media, potentially decreasing it's limited
lifespan, enabling this test will add 5 minutes to system_info's total execution time.

## Limitations and Caveats

- Not all inspections are possible on all systems, in all configurations.  For example, with the vc4-kms-v3d(-pi4)
"Full" OpenGL display driver, "tvservice" cannot be used to query HDMI characteristics, nor can the command
"vcgencmd get_lcd_info" determine current display resolution and color depth.
- The Pi 4B and later models bring new clocks, voltage and temperature sensors, codecs, boot methods, and other new
features, along with new bugs.  In some cases, "the old ways" work to get the data being sought.  In others, new
ways will have to be found (where possible) to present similar data.  In some cases, there are no alternative
methods yet available.  These models also add additional I2C busses, UARTs, and other goodies.  As I experiment
with how to activate and detect them, and gather appropriate details of their configuration, reporting on those
additional hardware features will be added to the script.
- Some people will run the 64-bit kernel ("arm_64bit=1" in /boot/config.txt), with 32-bit userland, on their 64-bit
capable systems.  I have been running this configurtion on a 4B for several months, with no issues detected.  **Do not
confuse this with the 64-bit "Raspberry Pi OS" (64-bit kernel and 64-bit userland.)**
- Aspects of this script have been the result of online research, and the feedback of a couple very helpful people.
If you have a Raspberry Pi and would like to assist with the testing and/or development of this script, any ideas,
contributed code, or even sample output showing "broken" routines to be fixed, would be gratefully considered.

## A test & development shortcut that users may find useful

Though intended for use during my development/testing, there is a way to specify a single main menu option via the
commandline.  Just pass the main menu option number as a commandline parameter.  Examples would include:

      system_info 1
      system_info 2
      system_info 3
      ...and so on.

The use of a commandline parameter ignores whatever is saved in the user's ${HOME}/.system_inforc file.  It also
does NOT update the rc file with whatever value was passed from the commandline.  ONLY A SINGLE MAIN MENU OPTION
NUMBER CAN BE SPECIFIED ON THE COMMANDLINE.  However, if you specify option 17 ("system_info 17"), ALL main menu
options will be executed, just as when that option is chosen via the menu. During my testing, the use of a
commandline parameter just helps me more rapidly run what I need to test, without having to first deselect
whatever may have been previously saved in my rc file.

## A built-in debugging facility

If you write your own shell scripts, or would like to modify system_info to suit your own needs, see the file
"DEBUGGING.md" for details of the built-in debug/trace facility built into system_info, as of version 2.0.4.

![Image](https://raw.githubusercontent.com/kencormack/system_info/master/scr-debug.jpg)

## Getting Help

The script contains a rudimentary help screen, displayed when "--help" (or "-h") is passed to the script, on the
commandline:
```
$ system_info [ --help | -h ]
```
![Image](https://raw.githubusercontent.com/kencormack/system_info/master/scr-help.jpg)

## License

The developer of the original code and/or files is me, Ken Cormack. Portions created by me are copyright 2020
Ken Cormack. All rights reserved.

This program is free software. The contents of this file are subject to the terms of the GNU General Public License
as published by the Free Software Foundation; either version 3 of the License, or (at your option) any later
version. You may redistribute it and/or modify it only in compliance with the GNU General Public License.

This program is distributed in the hope that it will be useful. However, this program is distributed "AS-IS"
WITHOUT ANY WARRANTY; INCLUDING THE IMPLIED WARRANTY OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.
Please see the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the
Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

Nothing in the GNU General Public License or any other license to use the code or files shall permit you to use
my trademarks, service marks, or other intellectual property without my prior written consent.

If you have any questions, please contact me at unixken@yahoo.com.

## This script was tested on the following hardware:

**hostname: pi-dev (Primary Development & Test System)**
- Pi 4B (2G memory) w/ Raspbian Buster
- X150 9-port USB hub
- DVK512 board w/ RTC
- DockerPi Powerboard
- fit_StatUSB USB LED
- USB Bluetooth dongle
- Hauppauge WinTV HVR950Q USB TV Tuner
- RTL-SDR USB Software Defined Radio
- X825 SATA III Board w/ 1TB SSD
- 4K HDMI Display Emulator Dummy Plug (2 Ea.)
- Headless - SSH and VNC only (No Display)

**hostname: pi-media (My Secondary Test System)**
- Pi 3B+ w/ Raspbian Stretch
- X150 9-port USB hub
- DVK512 board w/ RTC
- DockerPi Powerboard
- fit_StatUSB USB LED
- X820 SATA III Board w/128GB SSD drive
- USB-attached 4TB hard drive
- HDMI Sony Flatscreen TV

**hostname: pi-devel-2GB (William's - Initial 4B Testing)**
- Pi 4B (2GB memory) w/ Raspbian Buster
- PiOled i2c display
- USB flash drive
- USB Ethernet adapter
