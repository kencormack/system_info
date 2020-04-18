# system_info
## A Raspberry Pi System Configuration Reporting Tool

This script attempts to perform a fairly complete audit of the current configuration of a Raspberry Pi. The target hardware is any variant or model of Pi, up to and including the Pi 4B in all it's available memory configurations (1/2/4GB). Supported OS versions include Raspbian Stretch and Buster. No attempts will be made to back-port this to Jessie or older.
```
The script is an "examination only" affair, making no attempts to add, delete,
or change anything on the system.
```
The intended audience for this script is any Pi user who wants to see how aspects of their Pi are currently equipped and configured, for general troubleshooting, confirmation, or education/curiosity purposes. It does nothing that hasn't already been done by any/all of the tools it calls upon. I'm just consolidating everything into one place. Deliberate attempts were made to make things easy to follow, and the coding style is meant for easy readability.
```
'sudo' access is required. The script can be run as the user, and will call
sudo only for those commands that need root privilege.
```
## The following packages are required, to do a full inspection:

- alsa-utils
- bluez
- coreutils
- i2c-tools
- iproute2
- libraspberrypi-bin
- lshw
- usbutils
- util-linux
- v4l-utils
- wireless-tools
```
If the Pi being examined is a 4B, the package `rpi-eeprom` is also required.
```
The script will explicitly test that each of those required packages is installed. If any are missing, the script will inform the user, and instruct them to install.

## The following supplemental packages may also be utilized:

- cups-client
- dc
- ethtool
- nfs-kernel-server
- nmap
- python3-gpiozero
- rpcbind
- rtl-sdr
- samba
- sysstat
- watchdog
- wiringpi
```
NOTE: If you have a raspberry pi 4, install at least version 2.52 of wiringpi
See - [http://wiringpi.com/wiringpi-updated-to-2-52-for-the-raspberry-pi-4b/](http://wiringpi.com/wiringpi-updated-to-2-52-for-the-raspberry-pi-4b/)
```
The supplemental packages are not required, and the user will not be instructed to install them. But they will be utilized if installed and configured. Sections of the output made possible by the supplemental packages will be marked with *** in the heading of any sections involved, or in the part of an otherwise core test that has made use of the supplemental package.

## This script was tested on the following hardware:

hostname: pi-media (Ken's)
- Pi 3B+ w/ Raspbian Stretch,
- X150 9-port USB hub,
- DVK512 board w/ RTC,
- DockerPi Powerboard,
- fit_StatUSB USB LED,
- USB-attached 128GB,
- SATA III SSD drive,
- USB-attached 4TB hard drive,
- HDMI Sony Flatscreen TV

hostname: pi-dev (Ken's),
- Pi 3B w/ Raspbian Buster,
- X150 9-port USB hub,
- DVK512 board w/ RTC,
- DockerPi Powerboard,
- fit_StatUSB USB LED,
- USB Bluetooth dongle (onboard BT disabled),
- Hauppauge WinTV HVR950Q USB TV Tuner,
- RTL-SDR USB Software Defined Radio,
- X820 SATA III Board w/ 1TB SSD,
- Headless - SSH and VNC only (No Display)

hostname: pi-devel-2GB (William's)
- Pi 4B w/ Raspbian Buster (2GB memory)
- PiOled i2c display
- USB flash drive
- USB Ethernet adapter
