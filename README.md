# system_info
## A Raspberry Pi System Configuration Reporting Tool

This script attempts to perform a fairly complete audit of the current configuration of a Raspberry Pi.  The target hardware is any variant or model of Pi, up to and including the Pi 4B in all it's available memory configurations (1/2/4/8GB).  Supported OS versions include Raspbian Stretch, and Buster (including the newly renamed "Raspberry Pi OS", in 32-bit versions).  No attempts will be made to back-port this to Jessie or older, nor will I attempt to port this to Ubuntu, OSMC, LibreELEC, or any other OS distribution available for the Pi.
```
NOTE: 21 June 2020
The new 8GB model of Pi 4B is now available.  This script has not specifically been tested on the new
hardware, as I do not have access to one at the moment.  I expect no issues with this script on the
8GB hardware, under the existing stable Raspbian Buster, or newly renamed "Raspberry Pi OS" (32-bit).

I will not be testing the new 64-bit "Raspberry Pi OS" until it comes out of beta, as I prefer not to
chase a moving target, especially this early in it's development.

For more details see: https://www.raspberrypi.org/forums/viewtopic.php?t=275370
```
The script is an "examination only" affair, making no attempts to add, delete, or change anything on the system.  No re-configuration of any subsystem is done, it makes no recommendations, nor does it attempt to install anything.  It's job is simply to report what it finds.

The intended audience for this script is any Pi user who wants to see how aspects of their Pi are currently equipped and configured, for general troubleshooting, confirmation, or education/curiosity purposes.  In it's inspection of a system, it does nothing that hasn't already been done by any/all of the tools it calls upon.  I'm just consolidating everything into one place.  Deliberate attempts were made to make things easy to follow, and the coding style is meant for easy readability.

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

# Updating

To update, just 'cd' into the directory into which you originally installed system_info, and run the following command:
```
# git pull
```

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
- lshw
- net-tools
- procps
- rpi-eeprom
- usbutils
- sed
- util-linux
- v4l-utils
- wireless-tools

```
If the Pi being examined is a 4B, the package 'rpi-eeprom' is also required.
```
The script will explicitly test that each of those required packages is installed.  If any are missing, the script will inform the user, and instruct them to install.

## The following supplemental packages may also be utilized, to provide a more comprehensive examination:

- at
- chkrootkit
- clamav
- cups-client
- dc
- docker-ce-cli ("docker.io", on Stretch)
- ethtool
- hdparm
- lirc
- lm-sensors
- lvm2
- m4
- mdadm
- nfs-kernel-server
- nmap
- perl-base
- pigpiod ("pigpio", on Stretch)
- python3-gpiozero
- quota
- rng-tools
- rpcbind
- rtl-sdr
- samba
- smartmontools
- sysbench
- sysstat
- systemd-container
- systemd-coredump
- watchdog
- wiringpi
- x11-xserver-utils

The supplemental packages are not required, and the user will not be instructed to install them.  But they will be utilized if installed and configured.  Sections of the output made possible by the supplemental packages will be marked with *** in the heading of any sections involved, or in the part of an otherwise core test that has made use of the supplemental package.

## A word about WiringPi
If you have a raspberry pi 4B (1/2/4GB models only), install version 2.52 of WiringPi, see:
[http://wiringpi.com/wiringpi-updated-to-2-52-for-the-raspberry-pi-4b/](http://wiringpi.com/wiringpi-updated-to-2-52-for-the-raspberry-pi-4b/).  I do not know if version 2.52 works with the new 8GB variant of the Pi 4B, and as WiringPi is now deprecated, I have elected to not call upon it when examining an 8GB variant of the Pi 4B, in this script.  The Pi 4B 1/2/4GB variants will still be examined, if WiringPi 2.52 is found to be installed.  The 8GB model, however, will not.

## system_info is menu-driven
This allows sub-sets of the inspections to run.  The last option on the menu allows the user to run all the categories without having to select every category individually, if desired.  Any time the last selection is set, all categories will be executed regardless of any categories above it being marked selected or not.  The user's selections are saved to the file ".system_inforc" in the home directory of the userid that ran the script.  Those selections are then recalled, and those same menu options auto-selected for you, the next time that userid runs the script.

## All reports are saved to disk
Each time a report is run, a report file is created in the home directory of the userid running the script.  If you launch the script as user "pi", the report will end up in /home/pi (pi's homedir).  If you launch the script with "sudo", sudo makes you "root", thus the report will end up in /root (root's homedir).  At the bottom of the report, the name given to the report, along with where it was saved, is listed.  The filename of the report contains the hostname, the name of the script, and the date and time the report was run, in the format:

hostname-scriptname-YYYY-MM-DD-HH-MM-SS

On my development system (hostname "pi-dev"), an example report run on 2020 June 06, at 10:39:51 AM, would be named:
/home/pi/pi-dev-system_info-2020-06-06-10-39-51

## The Sysbench File IO test, and wear-sensitive media
If the supplemental package "sysbench" is installed, system_info includes functions to perform three different sysbench performance tests... the CPU, Memory read/write, and File I/O speed tests.  The first two of these (CPU and Memory read/write) will be performed without user intervention.  But because the last of these (the File I/O speed test) creates, writes, reads and deletes 128 files, 16Mb each (2GB total), most people will NOT want to do that much writing to their media (particularly those running on SD cards and SSD drives), on a regular basis.  Hence, system_info's default behavior is NOT to run the sysbench File I/O test under normal use.

- If the user DOES want to enable the sysbench File I/O tests (assuming they have sysbench installed), manually "touch ${HOME}/.system_info_io" to enable that test.  If system_info finds that that file exists, it will perform the sysbench File I/O tests (again, assuming sysbench is installed.)
- The command "rm ${HOME}/.system_info_io" (if that file exists) will remove the touchfile, preventing the sysbench File I/O test's execution.
- IMPORTANT: In addition to the wear and tear thrown at wear-sensitive media, potentially decreasing it's limited lifespan, enabling this test will add 5 minutes to system_info's total execution time.

## Limitations and Caveats
- Not all inspections are possible on all systems, in all configurations.  For example, with the vc4-kms-v3d(-pi4) "Full" OpenGL display driver, "tvservice" cannot be used to query HDMI characteristics, nor can "vcgencmd get_lcd_info" determine current display resolution and color depth.
- The Pi 4B brings new clocks, voltage and temperature sensors, codecs, boot methods, and other new features, along with new bugs.  In some cases, "the old ways" work to get the data being sought.  In others, new ways will have to be found (where possible) to present similar data.  In some cases, there are no alternative methods yet available.  The 4B also adds additional I2C busses, UARTs, and other goodies.  As I experiment with how to activate and detect them, and gather appropriate details of their configuration, reporting on those additional hardware features will be added to the script.
- Some people will run the 64-bit kernel on their 64-bit capable systems.  Minimal testing has been done in that environment, and I am certain it will present it's own suite of challenges and opportunities.
- Aspects of this script have been the result of online research, and the feedback of a couple very helpful people.  If you have a Raspberry Pi and would like to assist with the testing and/or development of this script, any ideas, contributed code, or even sample output showing "broken" routines to be fixed, would be gratefully considered.

## A development shortcut that users may find useful
Though intended for use during my development/testing, there is a way to specify a single main menu option via the commandline.  Just pass the main menu option number as a commandline parameter.  Examples would include:

      system_info 1
      system_info 2
      system_info 3
      ...and so on.

The use of a commandline parameter ignores whatever is saved in the user's ${HOME}/.system_inforc file.  It also does NOT update the rc file with whatever value was passed from the commandline.  ONLY A SINGLE MAIN MENU OPTION NUMBER CAN BE SPECIFIED ON THE COMMANDLINE.  However, if you specify option 16 ("system_info 16"), ALL main menu options will be executed, just as when that option is chosen via the menu. During my testing, the use of a commandline parameter just helps me more rapidly run what I need to test, without having to first deselect whatever may have been previously saved in my rc file.

## This script was tested on the following hardware:

hostname: pi-dev (Primary Development & Test System)
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

hostname: pi-media (My Secondary Test System)
- Pi 3B+ w/ Raspbian Stretch
- X150 9-port USB hub
- DVK512 board w/ RTC
- DockerPi Powerboard
- fit_StatUSB USB LED
- X820 SATA III Board w/128GB SSD drive
- USB-attached 4TB hard drive
- HDMI Sony Flatscreen TV

hostname: pi-devel-2GB (William's - Initial 4B Testing)
- Pi 4B (2GB memory) w/ Raspbian Buster
- PiOled i2c display
- USB flash drive
- USB Ethernet adapter