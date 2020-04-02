# system_info
A Raspberry Pi System Configuration Reporting Tool

This script attempts to perform a fairly complete audit of the current
configuration of a Raspberry Pi.  The target hardware is any variant or
model of Pi, up to and including the Pi 4B in all it's available memory
configurations (1/2/4GB).  Supported OS versions include Raspbian Stretch
and Buster.  No attempts will be made to back-port this to Jessie or older.

The script is an "examination only" affair, making no attempts to add,
delete, or change anything on the system.

The intended audience for this script is any Pi user who wants to see how
aspects of their Pi are currently equipped and configured, for general
troubleshooting, confirmation, or education/curiosity purposes.  It does
nothing that hasn't already been done by any/all of the tools it calls upon.
I'm just consolidating everything into one place.  Deliberate attempts were
made to make things easy to follow, and the coding style is meant for easy
readability.

'sudo' access is required.  The script can be run as the user, and will
call sudo only for those commands that need root privilege.

The following packages are required, to do a full inspection:
  lshw, usbutils, util-linux, alsa-utils, bluez, wireless-tools, bc, dc,
  i2c-tools, and wiringpi

An allowance is made with regard to wiringpi.  As the repository package
available at the time of this writing does not support the Pi 4, some
people may choose instead to install wiringpi from the update available at:
http://wiringpi.com/wiringpi-updated-to-2-52-for-the-raspberry-pi-4b/

When this script checks for the presence of wiringpi, it allows for either
the repository package, or, in the absence of the repository package,
the compiled and installed binary from wiringpi.com

In addition to the required packages listed above, this script can report
on any configured printers if it finds that "cups" is installed, and will
perform a port scan if it finds "nmap" installed.  If neither "cups" nor
"nmap" is present, the script will silently skip those checks and move on.
 
Tested on the following hardware:

  hostname: pi-media (Ken's),
  Pi 3B+ w/ Raspbian Stretch,
  X150 9-port USB hub,
  DVK512 board w/ RTC,
  DockerPi Powerboard,
  fit_StatUSB USB LED,
  USB-attached 128GB SATA III SSD drive,
  USB-attached 4TB hard drive,
  HDMI Sony Flatscreen TV

  hostname: pi-dev (Ken's),
  Pi 3B w/ Raspbian Buster,
  X150 9-port USB hub,
  DVK512 board w/ RTC,
  DockerPi Powerboard,
  fit_StatUSB USB LED,
  USB Bluetooth dongle (onboard BT disabled),
  Hauppauge WinTV HVR950Q USB TV Tuner,
  RTL-SDR USB Software Defined Radio,
  X820 SATA III Board w/ 1TB SSD,
  Headless - SSH and VNC only (No Display)

  hostname: pi-devel-2GB (William's),
  Pi 4B w/ Raspbian Buster (2GB memory),
  PiOled i2c display,
  USB flash drive,
  USB Ethernet adapter

  Pi0WH (William's),
  Raspbian Buster,
  PiOled i2c display
