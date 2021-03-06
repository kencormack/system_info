# system_info
## A Raspberry Pi System Configuration Reporting Tool

![Image](https://raw.githubusercontent.com/kencormack/system_info/master/scr-title.jpg)

This script attempts to perform a fairly complete audit of the current configuration of a Raspberry Pi.  The target
hardware is any variant or model of Pi (except the Pico microcontroller), from the original Model B, through and
including, the Pi 4B in all it's available memory configurations (1/2/4/8GB), as well as the 400, and CM4.

Supported OS versions include Raspbian Buster, and the newly renamed "Raspberry Pi OS", in 32-bit versions.
**Expect things not to work on the 64-bit OS, while it is still beta.**  No attempts will be made to back-port this
to older versions of Raspbian, nor will I port this to Ubuntu, OSMC, LibreELEC, or any other OS distribution
available for the Pi.

## SUPPORT FOR "STRETCH" HAS ENDED WITH SYSTEM_INFO V2.1.2
**BEGINNING WITH VERSION 3.0.0 OF THIS SCRIPT, SUPPORT FOR STRETCH HAS BEEN REMOVED.
Version 2.1.2 will remain here for those who wish to run that version on Stretch, but
3.0.0 and later will require Buster.**

```
NOTE: 30 December 2020
My primary development Pi, an early 2GB 4B (rev b03111), has been upgraded to an 8GB model
(rev d03114).  The 2GB Pi has taken over for the failed 3B+.

NOTE: 20 December 2020
My Pi3B+ Stretch system has died, and will be replaced with a 4B, necessitating Buster.  As such,
I no longer have a system with which to ensure continued compatability with Stretch.

NOTE: 03 November 2020
The new Pi 400 "Pi in a keyboard" has just been released.  Few details are published at this time,
but aside from being faster, it appears largely identical in features and function, to a 4B. 
```

## A note about the BETA 64-Bit "Raspberry Pi OS"

I will not be testing the new 64-bit "Raspberry Pi OS" until it comes out of beta, as I prefer not to
chase a moving target, especially this early in it's development.

For more details see: https://www.raspberrypi.org/forums/viewtopic.php?t=275370

## Differences between "Raspbian" and "Raspberry Pi OS"

Over the course of writing and testing system_info, I've encountered a few distinct differences between the old
"Raspbian", and the new "Raspberry Pi OS".  These differences are detected and used in reporting whether the installed
OS was initially created from a "Raspbian" or "Raspberry Pi OS" image.  These differences include:

1. Under Raspbian, the /bin, /lib, and /sbin directories are actual directories.  On Raspberry Pi OS they are
symbolic links to /usr/bin, /usr/lib, and /usr/sbin, respectively.  I take philosophical issue with this change, but
discussion is outside the scope of system_info.  It is what it is.

2. Under Raspbian, /tmp was a ram-based tmpfs filesystem.  Under Raspberry Pi OS, /tmp is simply a directory on the
boot media.  As a result, the creation, deletion, and other manipulation of temporary files may increase the number
of writes performed on wear-sensitive media (such as SD cards), but makes more memory available for other system use.
This difference has no bearing on the operation of system_info but is mentioned here as general info..

3. Under Raspbian, the easiest way to detect the presence of the official 7" touch screen was to look to see if
"ft5406" was found in the output of dmesg.  Under Raspberry Pi OS this string is not found, but "raspberrypi-ts" is.
As such, system_info searches for both strings.  If either is found, the presence of the official 7" touchscreen is
noted in the system_info report.

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

The script must be run as the user, and will call sudo only for those commands that need root privilege.

## Installation

The script is designed to run with the bash shell.  Just install, enable execute permission, and run it...
```
Pull down the script...
  $ git clone https://github.com/kencormack/system_info.git

Change to the "system_info" directory that was just created...
  $ cd system_info

ON BUSTER...
If your Pi is running Buster, make the script executable, and execute it...
  $ chmod +x system_info*
  ./system_info*

ON STRETCH...
If your Pi is still using "Stretch", do this with the v2.x version instead...
  $ chmod +x stretch-system_info*
  $ ./stretch-system_info*

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

- agnostics
- alsa-utils
- bc
- bluez
- coreutils
- cron
- i2c-tools
- initramfs-tools
- iproute2
- libc-bin
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
- curl
- dc
- docker-ce-cli ("docker.io", on Stretch)
- ethtool
- evtest
- hdparm
- joystick
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
- pulseaudio
- python3-gpiozero
- quota
- rkfill
- rkhunter
- rng-tools
- rpcbind
- rtl-sdr
- samba
- screen
- selinux-utils
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

![Image](https://raw.githubusercontent.com/kencormack/system_info/master/scr-supp-pkgs.jpg)

The supplemental packages are not required, and the user will not be instructed to install them.  But they will be
utilized if installed and configured.  Sections of the output made possible by the supplemental packages will be
marked with *** in the heading of any sections involved, or in the part of an otherwise core test that has made use
of the supplemental package.

## A word about WiringPi

If you have a raspberry pi 4B, and have WiringPi installed, ensure that it is version 2.52.
See: [http://wiringpi.com/wiringpi-updated-to-2-52-for-the-raspberry-pi-4b/](http://wiringpi.com/wiringpi-updated-to-2-52-for-the-raspberry-pi-4b/).

As 2.52 is now deprecated, and likely not to work on later models such as the CM4 or new Pi 400, I do not call
upon it when examining the later models.  All Pi 4B variants will still be examined, if WiringPi 2.52 is found
to be installed.  The Pi 400 and CM4, however, will not.

## system_info is menu-driven

![Image](https://raw.githubusercontent.com/kencormack/system_info/master/scr-menu.jpg)

This allows sub-sets of the inspections to run.  The last option on the menu allows the user to run all the
categories without having to select every category individually, if desired.  Any time the last selection is set,
all categories will be executed regardless of any categories above it being marked selected or not.  The user's
selections are saved to the file ".system_inforc" in the home directory of the userid that ran the script.  Those
menu selections are then recalled and auto-selected for you, the next time that userid runs the script (unless
commandline options "-m" or "--menu" are used, which overrides and ignores the .system_inforc file.)

## All reports are saved to disk

![Image](https://raw.githubusercontent.com/kencormack/system_info/master/scr-summary.jpg)

By default, each time a report is run, a report file is created in the home directory of the userid running the script.
If you launch the script as user "pi", the report will end up in /home/pi (pi's homedir).  You can specify an alternate
filename and location by specifying the target with the "-o" or "--output" option.  At the bottom of the report,
the name given to the report, along with where it was saved, is listed.  The default filename of the report contains
the hostname, the name of the script, and the date and time the report was run, in the format:

hostname-scriptname-YYYYMMDD-HHMMSS

On my development system (hostname "pi-max"), an example report run on 2020 Dec 30, at 10:39:51 AM, would be named:
/home/pi/pi-max-system_info-20201230-103951

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

## Commandline options & parameters

![Image](https://raw.githubusercontent.com/kencormack/system_info/master/scr-usage.jpg)

![Image](https://raw.githubusercontent.com/kencormack/system_info/master/scr-help1.jpg)

## A built-in debugging facility

![Image](https://raw.githubusercontent.com/kencormack/system_info/master/scr-help2.jpg)

If you write your own shell scripts, or would like to modify system_info to suit your own needs, see the file
"DEBUGGING_PROFILING.md" for details of the built-in debug/trace and profiling facilities built into system_info,
as of version 2.0.4.

![Image](https://raw.githubusercontent.com/kencormack/system_info/master/scr-debug.jpg)

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

**hostname: pi-max (Primary Development & Test System)**
- Pi 4B (8GB) w/ Raspbian Buster
- X150 9-port USB hub
- DVK512 board w/ RTC
- 128×32 Pixel SPI/I2C 2.23inch OLED Display HAT
- DockerPi Powerboard
- fit_StatUSB USB LED
- USB Bluetooth dongle
- Hauppauge WinTV HVR950Q USB TV Tuner
- RTL-SDR USB Software Defined Radio
- X825 SATA III Board w/ 1TB SSD
- 16GB EMMC Module (plugs into the SD card slot)
- 4K HDMI Display Emulator Dummy Plugs (2 Ea.)
- 40-inch Insignia NS-40D510NA21 Flatscreen TV Display

**hostname: pi-2gb (Secondary Test System)**
- Pi 4B (2GB) w/ Raspberry Pi OS - Buster
- X150 9-port USB hub
- DVK512 board w/ RTC
- 128×32 Pixel SPI/I2C 2.23inch OLED Display HAT
- DockerPi Powerboard
- fit_StatUSB USB LED
- X820 SATA III Board w/128GB SSD drive
- USB-attached 4TB hard drive
- 40-inch Insignia NS-40D510NA21 Flatscreen TV Display

**hostname: pi-devel-2GB (William's - Initial 4B Testing)**
- Pi 4B (2GB memory) w/ Raspbian Buster
- PiOled i2c display
- USB flash drive
- USB Ethernet adapter
