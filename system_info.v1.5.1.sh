#!/bin/bash

VERSION="1.5.1"
PATH=${PATH}:/sbin:/usr/sbin

# system_info.sh
# Written by:     Ken Cormack, unixken@yahoo.com
# Contributions:  William Stearns, william.l.stearns@gmail.com
#
# This script attempts to perform a fairly complete audit of the current
# configuration of a Raspberry Pi.  The target hardware is any variant or
# model of Pi, up to and including the Pi 4B in all it's available memory
# configurations (1/2/4GB).  Supported OS versions include Raspbian Stretch
# and Buster.  No attempts will be made to back-port this to Jessie or older.
#
# The script is an "examination only" affair, making no attempts to add,
# delete, or change anything on the system.
#
# The intended audience for this script is any Pi user who wants to see how
# aspects of their Pi are currently equipped and configured, for general
# troubleshooting, confirmation, or education/curiosity purposes.  It does
# nothing that hasn't already been done by any/all of the tools it calls upon.
# I'm just consolidating everything into one place.  Deliberate attempts were
# made to make things easy to follow, and the coding style is meant for easy
# readability.
#
# 'sudo' access is required.  The script can be run as the user, and will
# call sudo only for those commands that need root privilege.
#
# The following packages are required, to do a full inspection:
#   alsa-utils, bc, bluez, coreutils, i2c-tools, iproute2, libraspberrypi-bin,
#   lshw, net-tools, sed, usbutils, util-linux, v4l-utils, wireless-tools
#
# If the Pi being examined is a 4B, the package rpi-eeprom is also required.
#
# The script will explicitly test that each of those packages is installed.
# If any are missing, it will inform the user, and instruct them to install.
#
# The following supplemental packages may also be utilized:
#   cups-client, dc, ethtool, ilvm2, mdadm, nfs-kernel-server, nmap,
#    python3-gpiozero, quota, rng-tools, rpcbind, rtl-sdr, samba, sysstat,
#    isystemd-coredump, watchdog, wiringpi, and x11-server-utils
#
# NOTE:
# If you have a raspberry pi 4, install at least version 2.52 of wiringpi
# See - http://wiringpi.com/wiringpi-updated-to-2-52-for-the-raspberry-pi-4b/
#
# Those packages are not required, and the user will not be instructed
# to install them.  But they will be utilized if installed and configured.
# Sections of the output made possible by the supplemental packages will be
# marked with (***) in the heading of any sections involved, or in the part
# of an otherwise core test that has made use of the supplemental package.
#
# This script was tested on the following hardware:
#   hostname: pi-media (Ken's),
#   Pi 3B+ w/ Raspbian Stretch,
#   X150 9-port USB hub,
#   DVK512 board w/ RTC,
#   DockerPi Powerboard,
#   fit_StatUSB USB LED,
#   USB-attached 128GB SATA III SSD drive,
#   USB-attached 4TB Seagate hard drive,
#   HDMI Sony Flatscreen TV
#
#   hostname: pi-dev (Ken's),
#   Pi 4B (2G memory) w/ Raspbian Buster,
#   X150 9-port USB hub,
#   DVK512 board w/ RTC,
#   DockerPi Powerboard,
#   fit_StatUSB USB LED,
#   USB Bluetooth dongle (onboard BT disabled),
#   Hauppauge WinTV HVR950Q USB TV Tuner,
#   RTL-SDR USB Software Defined Radio,
#   X820 SATA III Board w/ 1TB SSD,
#   4K HDMI Display Emulator Dummy Plug (2 Ea.),
#   Headless - SSH and VNC only (No Display)
#
#   hostname: pi-devel-2GB (William's),
#   Pi 4B (2GB memory) w/ Raspbian Buster,
#   PiOled i2c display,
#   USB flash drive,
#   USB Ethernet adapter

##################################################
# A HANDY FUNCTION WE'LL BE USING...
##################################################
fnBANNER()
{
  echo "==============================================================================="
  echo "${@}"
  echo "==============================================================================="
  echo
}

fnSUB_BANNER()
{
  echo "-------------------------------------------------------"
  echo "${@}"
  echo
}

##################################################
# TITLE
##################################################
#---------------
echo
echo "               _   VERSION ${VERSION}   _        __"
echo " ___ _   _ ___| |_ ___ _ __ ___   (_)_ __  / _| ___"
echo "/ __| | | / __| __/ _ \\ '_ \` _ \\  | | '_ \\| |_ / _ \\"
echo "\__ \ |_| \__ \ ||  __/ | | | | | | | | | |  _| (_) |"
echo "|___/\__, |___/\__\___|_| |_| |_| |_|_| |_|_|  \___/"
echo "     |___/"
echo "            RASPBERRY PI SYSTEM INFORMATION REPORT"
echo
echo "Written By: Ken Cormack, unixken@yahoo.com"
echo "Contributor: William Stearns, william.l.stearns@gmail.com"
echo "github: https://github.com/kencormack/system_info"
echo
echo "Report Date and Time:"
date
echo

##################################################
# SOME PRELIMINARY CHECKS
##################################################
#---------------
# Written for Stretch and above.  Jessie and older are not supported.
fnBANNER " PRELIMINARY CHECKS"
if [ -f /etc/os-release ]
then
  . /etc/os-release 2>/dev/null
  if [ ${VERSION_ID} -lt 9 ]
  then
    fnBANNER " UNSUPPORTED LINUX VERSION"
    echo "This script is designed for Raspbian GNU/Linux 9 (stretch), and above."
    echo "Version ${PRETTY_NAME} is not supported."
    echo
    exit 1
  else
    echo "OS version check:  OK"
  fi
else
  fnBANNER " LINUX VERSION UNKNOWN"
  echo "This script is designed for Raspbian GNU/Linux 9 (stretch), and above."
  echo "Unable to identify your version of the operating system... Exiting."
  echo
  exit 1
fi

#---------------
# Check that dmesg contains anything we might need.  Examples include the
# "memory split", "active display driver", "rtc", and several other tests.
if [ "$(dmesg | grep "Booting Linux")" = "" ]
then
  fnBANNER " DMESG RING BUFFER HAS WRAPPED - PLEASE REBOOT"
  echo "This script relies on \"dmesg\" to provide some of the data it needs."
  echo
  echo "Kernel messages are stored in a data structure called a ring buffer."
  echo "The buffer is fixed in size, with new data overwriting the oldest data."
  echo "When data we need has already been overwritten, that data is lost to us."
  echo
  echo "Your ring buffer has already wrapped.  Please reboot your system before"
  echo "attempting to re-run this script, to ensure that the buffer contains"
  echo "any data we need."
  echo
  exit 1
else
  echo "dmesg ring buffer: OK"
fi

#---------------
# If we're not already root, set "${SUDO}" so that commands that need root privs will run under sudo
SUDO=$(type -path sudo)
if [ "${EUID}" -ne 0 ] && [ "${SUDO}" = "" ]
then
  echo
  echo "${0} has not been run as root and sudo is not available, exiting." >&2
  exit 1
else
  if [ "${EUID}" -eq 0 ]
  then
    echo "running as root:   OK"
  else
    echo "running as user:   $(whoami)"
    if [ -n "${SUDO}" ]
    then
      echo "sudo is available: OK"
    fi
  fi
fi
echo

#---------------
fnBANNER " DECODED SYSTEM REVISION NUMBER"
## The following revision-decoding logic was shamelessly borrowed from:
## https://raspberrypi.stackexchange.com/questions/100076/what-revisions-does-cat-proc-cpuinfo-return-on-the-new-pi-4-1-2-4gb
## I've made only some coding style changes to match the rest of this script.
MY_REVISION=$(cat /proc/cpuinfo | grep "Revision" | awk '{print $3}')
echo "Revision      : "${MY_REVISION}
ENCODED=$((0x${MY_REVISION} >> 23 & 1))
if [ ${ENCODED} = 1 ]
then
  PCB_REVISION=("0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15")
  MODEL_NAME=("A" "B" "A+" "B+" "Pi2B" "Alpha" "CM1" "unknown" "3B" "Zero" "CM3" "unknown" "Zero W" "3B+" "3A+" "internal use only" "CM3+" "4B" "18 ?" "19 ?" "20 ?")
  PROCESSOR=("BCM2835" "BCM2836" "BCM2837" "BCM2711" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15")
  MANUFACTURER=("Sony UK" "Egoman" "Embest" "Sony Japan" "Embest" "Stadium" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15")
  MEMORY_SIZE=("256 MB" "512 MB" "1024 MB" "2048 MB" "4096 MB" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15")
  ENCODED_FLAG=("" "revision is a bit field")
  WARRANTY_VOID_OLD=("" "warranty void - Pre Pi2")
  WARRANTY_VOID_NEW=("" "warranty void - Post Pi2")

  # Save these for later, should we need to make decisions based on model, ram, etc.
  MY_PCB_REVISION=${PCB_REVISION[$((0x${MY_REVISION}&0xf))]}
  MY_MODEL_NAME=${MODEL_NAME[$((0x${MY_REVISION}>>4&0xff))]}
  MY_PROCESSOR=${PROCESSOR[$((0x${MY_REVISION}>>12&0xf))]}
  MY_MANUFACTURER=${MANUFACTURER[$((0x${MY_REVISION}>>16&0xf))]}
  MY_MEMORY_SIZE=${MEMORY_SIZE[$((0x${MY_REVISION}>>20&7))]}
  MY_ENCODED_FLAG=${ENCODED_FLAG[$((0x${MY_REVISION}>>23&1))]}
  MY_WARRANTY_VOID_OLD=${WARRANTY_VOID_OLD[$((0x${MY_REVISION}>>24&1))]}
  MY_WARRANTY_VOID_NEW=${WARRANTY_VOID_NEW[$((0x${MY_REVISION}>>25&1))]}

  echo "PCB Revision  : ${MY_PCB_REVISION}"
  echo "Model Name    : ${MY_MODEL_NAME}"
  echo "Processor     : ${MY_PROCESSOR}"
  echo "Manufacturer  : ${MY_MANUFACTURER}"
  echo "Memory Size   : ${MY_MEMORY_SIZE}"
  echo "Encoded Flag  : ${MY_ENCODED_FLAG}"
  if [ -n "${MY_WARRANTY_VOID_OLD}" -o -n "${MY_WARRANTY_VOID_NEW}" ]
  then
    WARRANTY_VOID="'warranty void' bit is set"
  else
    WARRANTY_VOID="no"
  fi
  echo "Warranty Void : ${WARRANTY_VOID}"
  echo

  # Pi 4B:
  # Revision [abc]03111 is original board with USB-C power design flaw.
  # Revision [abc]03112 is v1.2 board with fix.
  # (First char, a, b, or c, refers to 1GB, 2GB, or 4GB memory.)
  if [ "${MY_MODEL_NAME}" = "4B" ] && [ "$(echo "${MY_REVISION}" | cut -c2-)" = "03111" ]
  then
    echo "This 4B contains a USB-C power design flaw."
    echo "\"Smart\" USB-C cables will not power this Pi."
    echo
  fi
fi

##################################################
# CHECK FOR ALL REQUIRED AND SUPPLEMENTAL PACKAGES
##################################################
#---------------
fnBANNER " CHECKING SOFTWARE DEPENDENCIES"
echo "Checking required software dependencies..."
PKG_MISSING=0
if type -path dpkg >/dev/null 2>&1
then
  #################################
  # First, the required packages
  REQUIRED=$(dpkg -l 2>/dev/null | awk '{ print $2 }' | grep -i "^alsa-utils$\|^bc$\|^bluez$\|^coreutils$\|^i2c-tools$\|^iproute2$\|^libraspberrypi-bin$\|^lshw$\|^net-tools$\|^rpi-eeprom$\|^sed\|^util-linux$\|^usbutils$\|^v4l-utils$\|^wireless-tools$")
  REQ_HIT=0
  REQ_MAX=0
  for PACKAGE in alsa-utils bc bluez coreutils i2c-tools iproute2 libraspberrypi-bin lshw net-tools rpi-eeprom usbutils sed util-linux v4l-utils wireless-tools
  do
    # If the Pi is not a 4B, skip checking for the rpi-eeprom package
    if [ "${MY_MODEL_NAME}" != "4B" ] && [ "${PACKAGE}" = "rpi-eeprom" ]
    then
      continue
    fi
    # Otherwise, for all packages, on all models...
    # If the package is installed...
    echo "${REQUIRED}" | grep "${PACKAGE}" > /dev/null
    if [ ${?} -eq 0 ]
    then
      # Tell the user we found it.
      echo "  found: ${PACKAGE}"
      let REQ_HIT++
    else
      # Otherwise, tell the user to install it.
      fnBANNER "Required package \"${PACKAGE}\" is not installed." | grep -v "^$"
      echo "Install with:"
      echo "  sudo apt install -y ${PACKAGE}"
      PKG_MISSING=1
      echo
    fi
    let REQ_MAX++
  done
  if [ ${PKG_MISSING} -ne 0 ]
  then
    fnBANNER "Once any missing packages are installed, re-run this script."
    echo
    exit
  else
    echo "${REQ_HIT} out of ${REQ_MAX} required packages are installed."
    echo "All core inspections will be performed."
    echo

    ######################################
    # Now, the supplemental packages.
    # If installed, great.  If not installed, don't trouble the user to add them.
    fnSUB_BANNER "Checking supplemental software dependencies..." | grep -v ^$
    SUPPLEMENTAL=$(dpkg -l 2>/dev/null | awk '{ print $2 }' | grep -i "^cups-client$\|^dc$\|^ethtool$\|^lvm2$\|^m4$\|^mdadm$\|^nfs-kernel-server$\|^nmap$\|^perl-base$\|^python3-gpiozero$\|^quota$\|^rng-tools$\|^rpcbind$\|^rtl-sdr$\|^samba$\|^sysstat$\|^systemd-coredump$\|^watchdog$\|^wiringpi$\|^x11-xserver-utils$")
    SUP_HIT=0
    SUP_MAX=0
    for PACKAGE in cups-client dc ethtool lvm2 m4 mdadm nfs-kernel-server nmap perl-base python3-gpiozero quota rng-tools rpcbind rtl-sdr samba sysstat systemd-coredump watchdog wiringpi x11-xserver-utils
    do
      # If wiringpi is installed, it needs to be v2.52 on the Pi 4B.
      # See - http://wiringpi.com/wiringpi-updated-to-2-52-for-the-raspberry-pi-4b/
      if [ "${PACKAGE}" = "wiringpi" ]
      then
        WIRINGPI_VERS=$(gpio -v 2>/dev/null | head -1 | awk '{ print $NF }')
        if [ "${MY_MODEL_NAME}" = "4B" -a "${WIRINGPI_VERS}" = "2.52" ]
        then
          # Tell the user we found it.
          echo "  found: ${PACKAGE}"
          let SUP_HIT++
          let SUP_MAX++
          continue
        fi
        # If not a 4B, then wiringpi v2.50 from the repositories will do
        if [ "${MY_MODEL_NAME}" != "4B" ]
        then
          # Tell the user we found it.
          echo "  found: ${PACKAGE}"
          let SUP_HIT++
        fi
        let SUP_MAX++
      else
        # Otherwise, for all other packages, on all models...
        # If the package is installed...
        echo "${SUPPLEMENTAL}" | grep "${PACKAGE}" > /dev/null
        if [ ${?} -eq 0 ]
        then
          # Tell the user we found it.
          echo "  found: ${PACKAGE}"
          let SUP_HIT++
        fi
        let SUP_MAX++
      fi
    done
    echo "${SUP_HIT} out of ${SUP_MAX} supplemental packages are installed."
    if [ ${SUP_HIT} -gt 0 ]
    then
      echo "Some supplemental inspections will be performed."
    else
      echo "No supplemental inspections will be performed."
    fi
    echo
  fi
else
  echo "Missing utility dpkg, unable to verify package dependencies" >&2
  exit 1
fi

##################################################
# ALL SET - START ACTUALLY GATHERING SOME DATA...
##################################################
#---------------
fnBANNER " SYSTEM IDENTIFICATION"
echo "Hostname: $(hostname)"
echo "Serial #: $(cat /proc/cpuinfo | grep ^Serial | awk '{ print $NF }')"
echo

#---------------
fnBANNER " OPERATING SYSTEM"
if [ $(vcgencmd get_config arm_64bit | cut -f2 -d"=") = 1 ]
then
  BITS=64
else
  BITS=32
fi
echo "${PRETTY_NAME}"
uname -a
echo
echo "KERNEL IS: ${BITS}-BIT"
echo
uptime -p
echo

#---------------
fnBANNER " MAC-ADDRESS(ES)"
MACS=$(ifconfig | grep '[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:' | awk '{print $2}' | tr "a-f" "A-F")
echo "${MACS}"
echo

#---------------
fnBANNER " MODEL AND FIRMWARE VERSION"
strings /sys/firmware/devicetree/base/model
echo
vcgencmd version
echo

#---------------
# SUPPLEMENTAL TEST
if type -path pinout >/dev/null 2>&1
then
  fnBANNER " SYSTEM DIAGRAM (***)"
  pinout -m
  echo
fi

#---------------
fnBANNER " CPU INFORMATION"
lscpu
echo

#---------------
# Boot-from-USB mass storage will be handled differently on the Pi 4B,
# versus older models.
if [ "${MY_MODEL_NAME}" = "4B" ]
then
  # The Pi 4 uses an EEPROM to control it's boot source.  As of this
  # writing, boot-from-USB mass storage is promised in a future EEPROM
  # update, as they focus on stabilizing boot-from-network, first.
  fnBANNER " PI MODEL 4B EEPROM VERSION"
  vcgencmd bootloader_version
  echo
  if type -path rpi-eeprom-update >/dev/null 2>&1
  then
    # This command will indicate that an update is required, if the
    # timestamp of the most recent file in the firmware directory
    # (normally /lib/firmware/raspberrypi/bootloader/critical)
    # is newer than that reported by the current bootloader.
    fnBANNER " PI MODEL 4B EEPROM UPDATE STATUS"
    ${SUDO} rpi-eeprom-update
    echo
  else
    echo "Missing utility rpi-eeprom-update, skipping eeprom update check" >&2
  fi

  fnBANNER " PI MODEL 4B EEPROM CONFIG"
  echo "The meaning of each of these is documented here:"
  echo "https://www.raspberrypi.org/documentation/hardware/raspberrypi/bcm2711_bootloader_config.md"
  echo
  vcgencmd bootloader_config
else
  # Some older Pi models use OTP (One Time Programable) memory to control
  # whether the Pi can boot from USB mass storage.  Here, we check the
  # model, and then perform the appropriate examination.  OTP-managed
  # USB mass storage boot is available on Pi 2B v1.2, 3A+, 3B, and 3B+
  # models only.  Any other model will skip this test.  The Pi 3B+
  # comes from the factory with boot from USB mass storage enabled.
  # If a Model 2B, make sure it's a v1.2 unit.
  MY_OTP=${MY_MODEL_NAME}
  if [ "${MY_MODEL_NAME}" = "Pi2B" -a "${MY_PROCESSOR}" = "BCM2837" ]
  then
    MY_OTP="Pi2Bv1.2"
  fi
  case ${MY_OTP} in
    Pi2Bv1.2|3A+|3B|3B+)
      fnBANNER " OTP BOOT-FROM-USB STATUS"
      BOOT_TO_USB=$(vcgencmd otp_dump | grep "17:")
      if [ "${BOOT_TO_USB}" = "17:3020000a" ]
      then
        echo "Boot From USB: Enabled"
      else
        echo "Boot From USB: Available, but not enabled"
      fi
      ;;
    * )
      echo "Boot From USB: Feature not available on this model"
      ;;
  esac
  echo
fi

#---------------
fnBANNER " LOADED OVERLAYS"
${SUDO} vcdbg log msg 2>&1 | grep "Loaded overlay" | cut -f2- -d":"
echo

#---------------
fnBANNER " LOADED DTPARAMS"
${SUDO} vcdbg log msg 2>&1 | grep "dtparam:" | cut -f2- -d":"
echo

#---------------
# This section needs study for Pi 4 ethernet LEDs...
# dtparam=eth_led0=4
# dtparam=eth_led1=4
#
# perhaps use "sudo vcdbg log msg" and grep for:
# dtparam: eth_led0=
# dtparam: eth_led1=
# (maybe even "dtparam: act_led_trigger=heartbeat" for ACT LED, below, too.)
# 
# eth_led0 is green
# eth_led1 is amber

# The comments are also hard to decipher (e.g. what's the difference between 0, 2, and 7?):
# 0=Speed/Activity (default) 1=Speed
# 2=Flash activity           3=FDX
# 4=Off                      5=On
# 6=Alt                      7=Speed/Flash
# 8=Link                     9=Activity

# The comments are also hard to decipher (e.g. what's the difference between 0, 2, and 7?):
# My understanding is:

# Speed means on for a fast link (probably 1Gb/s), otherwise off.

# Activity inverts the current state for a short period for every packet,
# so more traffic means more flicker.

# Flash activity is like Activity but without the proportionality - the pulses
# (which could be on or off depending on the other part of the mode) are a
# fixed width and the gaps are of (the same) minimum width, such that you
# see a clear flash pattern if there is activity and a steady state if not.
#
# It looks like 2 is mislabelled and should just say Flash activity.

fnBANNER " LED TRIGGERS"
if [ -f /sys/class/leds/led0/trigger ]
then
  echo -n "LED0: "
  for TRIGGER in $(cat /sys/class/leds/led0/trigger)
  do
    echo ${TRIGGER} | grep "\["
  done
fi
if [ -f /sys/class/leds/led1/trigger ]
then
  echo -n "LED1: "
  for TRIGGER in $(cat /sys/class/leds/led1/trigger)
  do
    echo ${TRIGGER} | grep "\["
  done
fi
if [ -f /sys/class/leds/mmc0::/trigger ]
then
  echo -n "MMC0: "
  for TRIGGER in $(cat /sys/class/leds/mmc0::/trigger)
  do
    echo ${TRIGGER} | grep "\["
  done
fi
echo

#---------------
fnBANNER " CMDLINE.TXT"
cat /boot/cmdline.txt
echo

#---------------
fnBANNER " CONFIG.TXT SETTINGS"
cat /boot/config.txt | grep -v ^$ | grep -v ^#
echo

##---------------
#fnBANNER " CONFIG.TXT VALUES ABOVE, THAT ARE \"LIVE\""
## See what values any config.txt parameters are set to, in the running environment.
## Still need to determine what to do with some that don't show up with this
## technique.  Specifically, dtparm, dtoverlay, hdmi_*, config_hdmi_boost, force_turbo,
## start_x, max_usb_current, gpu_mem, and possibly others.
#strings /boot/start.elf | grep -Ei '^[a-z0-9_]{6,32}$' | sort -u | xargs -i vcgencmd get_config {} | grep = > /tmp/.config.${PPID} 2>/dev/null
#cat /boot/config.txt | grep -v ^$ | grep -v ^# | grep -v ^"\[" | while read CONFIG
#do
#  grep "^${CONFIG}$" /tmp/.config.${PPID} 2>/dev/null
#done
#rm /tmp/.config.${PPID} 2>/dev/null
#echo

#---------------
fnBANNER " MEMORY SPLIT"
# There is a flaw in "vcgencmd get_mem arm" on Pi 4B models with more than 1GB of memory.
# On those models, the command only considers the first GB of memory.
# The technique used here instead, is accurate on all Pi models regardless of memory.
ARM=$(($(dmesg | grep "Memory:" | grep "available" | cut -f2 -d"/" | cut -f1 -d"K") / 1024 ))
ARM=`printf "%4d" ${ARM}`
echo "ARM: ${ARM} MB"
GPU="$(vcgencmd get_mem gpu | cut -f2 -d"=" | sed 's/M$//')"
GPU=`printf "%4d" ${GPU}`
echo "GPU: ${GPU} MB"
echo
echo "Note: GPU hardware-accelerated codecs will be disabled if \"gpu_mem=16\"."
echo "At least \"gpu_mem=96\" is required for HW codecs to run correctly."
echo "At least \"gpu_mem=128\" is required for camera operation."
echo

#---------------
fnBANNER " ACTIVE DISPLAY DRIVER"
# If two particular modules are not running, it's the Broadcom driver.
# If the modules are loaded, the "fake" OpenGL driver shows "firmwarekms" in dmesg.
# If the modules are loaded, the "full" OpenGL driver does not show "firmwarekms" in dmesg.
# An example of why we needed to check for ring buffer wrap earlier,
# We need to remember which driver is used - we'll need this info later.
if [ "$(lsmod | awk '{ print $1 }' | grep ^vc4)" = "" -a "$(lsmod | awk '{ print $1 }' | grep ^drm)" = "" ]
then
  DISP_DRIVER="broadcom"
  echo "Broadcom Display Driver"
else
  if [ -n "$(dmesg | grep firmwarekms)" ]
  then
    DISP_DRIVER="fake"
    echo "\"Fake\" OpenGL Display Driver"
  else
    DISP_DRIVER="full"
    echo "\"Full\" OpenGL Display Driver"
  fi
fi
echo

#---------------
fnBANNER " PROCESSOR SPEEDS"
FREQ=$(vcgencmd measure_clock arm | cut -f2 -d"=")
MHZ=$(echo $((${FREQ} / 1000000)))
MHZ=`printf "%4d" ${MHZ}`
echo " CPU: ${MHZ} MHz"
FREQ=$(vcgencmd measure_clock core | cut -f2 -d"=")
MHZ=$(echo $((${FREQ} / 1000000)))
MHZ=`printf "%4d" ${MHZ}`
echo "CORE: ${MHZ} MHz"
echo

#---------------
fnBANNER " CLOCK FREQUENCIES"
if [ "${MY_MODEL_NAME}" = "4B" ]
then
  echo "Clocks available across all Pi models..."
fi
for CLOCK in arm core h264 isp v3d uart pwm emmc pixel vec hdmi dpi
do
  echo "${CLOCK}: $(vcgencmd measure_clock ${CLOCK})" | awk '{ printf("%- 10s %- 28s\n", $1, $2);}' 2>&1
done
if [ "${MY_MODEL_NAME}" = "4B" ]
then
  echo
  echo "Additional Pi 4B-specific clocks..."
  for CLOCK in altscb cam0 cam1 ckl108 clk27 clk54 debug0 debug1 dft dsi0 dsi0esc dsi1 dsi1esc emmc2 genet125 genet250 gisb gpclk0 gpclk1 hevc m2mc otp pcm plla pllb pllc plld pllh pulse smi tectl testmux tsens usb wdog xpt
  do
    echo "${CLOCK}: $(vcgencmd measure_clock ${CLOCK})" | awk '{ printf("%- 10s %- 28s\n", $1, $2);}' 2>&1
  done
fi
echo

#---------------
fnBANNER " VOLTAGES"
if [ "${MY_MODEL_NAME}" = "4B" ]
then
  echo "Voltages available across all Pi models..."
fi
for VOLTS in core sdram_c sdram_i sdram_p
do
  echo "${VOLTS}: $(vcgencmd measure_volts ${VOLTS})" | awk '{ printf("%- 10s %- 40s\n", $1, $2);}' 2>&1
done
if [ "${MY_MODEL_NAME}" = "4B" ]
then
  echo
  echo "Additional Pi 4B-specific voltages..."
  for VOLTS in 2711
  do
    echo -e "${VOLTS}:      $(vcgencmd measure_volts ${VOLTS})"
  done
  for VOLTS in ain1 usb_pd uncached
  do
    echo "${VOLTS}: $(vcgencmd measure_volts ${VOLTS})" | awk '{ printf("%- 10s %- 40s\n", $1, $2);}' 2>&1
  done
fi
echo

#---------------
fnBANNER " TEMPERATURE"
# Pointless venting - I wish bash could do floating point
# math directly in the shell like ksh can, without needing
# bc, dc, expr, awk, or other external commands.  Argh!
if [ "${MY_MODEL_NAME}" = "4B" ]
then
  echo "Temperatures available across all Pi models..."
fi
GPU_TEMP=$(vcgencmd measure_temp)
C=$(echo ${GPU_TEMP} | cut -f2 -d"=" | cut -f1 -d"'")
if type -path dc >/dev/null 2>&1
then
  # SUPPLEMENTAL CONVERSION to Fahrenheit
  F=$(echo "2 k 9 5 / ${C} * 32 + p" | dc)
  echo " GPU Temp: $(printf "%2.2f" ${C})°C ($(printf "%3.2f" ${F})°F) (***)"
else
  # Otherwise, show Centigrade/Celcius only
  echo " GPU Temp: $(printf "%2.2f" ${C})°C"
fi
ARM_TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
C=$(echo "scale=2;${ARM_TEMP}/1000" | bc)
if type -path dc >/dev/null 2>&1
then
  # SUPPLEMENTAL CONVERSION to Fahrenheit
  F=$(echo "2 k 9 5 / ${C} * 32 + p" | dc)
  echo " ARM Temp: $(printf "%2.2f" ${C})°C ($(printf "%3.2f" ${F})°F) (***)"
else
  # Otherwise, show Centigrade/Celcius only
  echo " ARM Temp: $(printf "%2.2f" ${C})°C"
fi

if [ "${MY_MODEL_NAME}" = "4B" ]
then
  echo
  echo "Additional Pi 4B-specific PMIC temperature..."
  PMIC_TEMP=$(vcgencmd measure_temp pmic)
  C=$(echo ${PMIC_TEMP} | cut -f2 -d"=" | cut -f1 -d"'")
  if type -path dc >/dev/null 2>&1
  then
    # SUPPLEMENTAL CONVERSION to Fahrenheit
    F=$(echo "2 k 9 5 / ${C} * 32 + p" | dc)
    echo "PMIC Temp: $(printf "%2.2f" ${C})°C ($(printf "%3.2f" ${F})°F) (***)"
  else
    # Otherwise, show Centigrade/Celcius only
    echo "PMIC Temp: $(printf "%2.2f" ${C})°C"
  fi
fi
echo

#---------------
fnBANNER " SCALING GOVERNOR"
GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
FORCE=$(grep "^force_turbo=" /boot/config.txt | cut -f2 -d"=")

# The possible governor settings are:
#   performance  - always use max cpu freq
#   powersave    - always use min cpu freq
#   ondemand     - change cpu freq depending on cpu load (On rasbian, it just switches min and max)
#   conservative - smoothly change cpu freq depending on cpu load
#   uesrspace    - allow user space daemon to control cpufreq
#   schedutil    - wiser about freq. selection than the other governors, but not quite there yet
# All but "performance" are overridden by "force_turbo=1" in config.txt.
# Both of those mean the same thing - run at max speed, all the time..

echo "${GOV}"
if [ "${GOV}" != "performance" -a "${FORCE}" = "1" ]
then
  echo "(...but overridden by \"force_turbo=1\" found in config.txt)"
fi
echo

#---------------
fnBANNER " DECODED PROCESSOR THROTTLING STATUS"
# These are what cause the overtemp (thermometer) icon,
# the undervolt (lightening bolt) icon, etc., to be
# displayed on a screen, when there's a problem.
#
# "vcgencmd get_throttled"
# Bit	Meaning
# ===============
#  0	undervoltage detected
#  1	Arm frequency capped
#  2	Currently throttled
#  3	Soft temperature limit active
# 16	Under voltage has occured
# 17	Arm frequency cap has occured
# 18	Throttling has occurred
# 19	Soft Temperature limit has occurred

#Flag Bits
UNDERVOLTED=0x1
CAPPED=0x2
THROTTLED=0x4
SOFT_TEMPLIMIT=0x8
HAS_UNDERVOLTED=0x10000
HAS_CAPPED=0x20000
HAS_THROTTLED=0x40000
HAS_SOFT_TEMPLIMIT=0x80000

#Output Strings
GOOD="no"
BAD="YES"

#Get Status, extract hex
STATUS=$(vcgencmd get_throttled)
STATUS=${STATUS#*=}

echo -n "Throttle Status: "
(($STATUS!=0)) && echo "${STATUS}" || echo "${STATUS}"
echo

echo "Undervolted:"
echo -n "    Currently: "
((($STATUS&UNDERVOLTED)!=0)) && echo "${BAD}" || echo "${GOOD}"
echo -n "   Since Boot: "
((($STATUS&HAS_UNDERVOLTED)!=0)) && echo "${BAD}" || echo "${GOOD}"
echo
echo "Throttled:"
echo -n "    Currently: "
((($STATUS&THROTTLED)!=0)) && echo "${BAD}" || echo "${GOOD}"
echo -n "   Since Boot: "
((($STATUS&HAS_THROTTLED)!=0)) && echo "${BAD}" || echo "${GOOD}"
echo
echo "Frequency Capped:"
echo -n "    Currently: "
((($STATUS&CAPPED)!=0)) && echo "${BAD}" || echo "${GOOD}"
echo -n "   Since Boot: "
((($STATUS&HAS_CAPPED)!=0)) && echo "${BAD}" || echo "${GOOD}"
echo
echo "Softlimit:"
echo -n "    Currently: "
((($STATUS&SOFT_TEMPLIMIT)!=0)) && echo "${BAD}" || echo "${GOOD}"
echo -n "   Since Boot: "
((($STATUS&HAS_SOFT_TEMPLIMIT)!=0)) && echo "${BAD}" || echo "${GOOD}"
echo

#---------------
fnBANNER " ULIMIT AND CORE DUMPS (***)"
ulimit -a
echo

ULIMIT=$(ulimit -c)
case ${ULIMIT} in
  "0")
    echo " Core dumps are disabled..."
    echo "ulimit = 0"
    ;;
  "unlimited")
    echo " Core dumps are enabled..."
    echo "ulimit = unlimited"
    ;;
  *)
    echo " Core dumps are enabled..."
    echo "ulimit = ${ULIMIT}"
    ;;
esac
echo

HITS=$(find /etc/security/limits* -type f -exec grep core {} \; | grep -v ^#)
if [ -n "${HITS}" ]
then
  echo " Core dumps are enabled globally in /etc/security/limits*..."
  echo "${HITS}"
  echo
fi

HITS=$(find /etc/systemd/system.conf -type f -exec grep DefaultLimitCORE {} \; | grep -v ^#)
if [ -n "${HITS}" ]
then
  echo " Default global core dump limit in /etc/systemd/system.conf..."
  echo "${HITS}"
  echo
fi

if [ -f /etc/systemd/coredump.conf ]
then
  echo " Contents of /etc/systemd/coredump.conf... (***)"
  cat /etc/systemd/coredump.conf | grep -v "^# " | grep -v "^#$" | grep -v "^$"
  echo
fi

if [ -n "$(journalctl -xe | grep "dumped core")" ]
then
  echo " journalctl -xe..."
  journalctl -xe | grep "dumped core"
  echo
fi

if type -path coredumpctl >/dev/null 2>&1
then
  echo " journalctl reports the following core dumps... (***)"
  ${SUDO} coredumpctl list 2>&1
  echo
  echo " Core dumps present in /var/lib/systemd/coredump... (***)"
  ls -l /var/lib/systemd/coredump
  echo
fi

#---------------
if type -path repquota >/dev/null 2>&1
then
  if [ -n "$(grep [usr\|grp]quota /etc/fstab)" ]
  then
    fnBANNER " QUOTAS (***)"
    echo " The following filesystems are configured for quotas..."
    grep [usr\|grp]quota /etc/fstab
    echo
    ${SUDO} repquota -u -g -v -a -s -t | grep -v "^#"
  fi
fi

#---------------
fnBANNER " HARDWARE-ACCELERATED CODECS"
# FOR THE PI 4B...
# On the Raspberry Pi 4B, hardware decoding for MPG2 and WVC1
# is disabled and cannot be enabled even with a license key.
# The Pi 4B, with it's increased processing power compared to
# earlier models, can decode these in software such as VLC.
# MPG4, H263, MPG2, and WVC1 hardware decode options have all
# been dropped, on the 4B.  The ARM cores on the Pi4 are more
# than capable of decoding those formats at better that real-
# time.  (There is no real material >1080p using those codecs.)
#
# FOR OLDER MODELS...
# Hardware decoding of MPG2 and WVC1 requires license keys,
# purchased seperately.
for CODEC in AGIF FLAC H263 H264 MJPA MJPB MJPG MPG2 MPG4 MVC0 " PCM" THRA VORB " VP6" " VP8" WMV9 WVC1
do
  STATUS=$(vcgencmd codec_enabled ${CODEC} | cut -f2 -d"=")
  # These two codecs...
  if [ "${CODEC}" = "MPG2" -o "${CODEC}" = "WVC1" ]
  then
    # ...on models other than the 4B...
    if [ "${MY_MODEL_NAME}" != "4B" ]
    then
      # ...if enabled...
      if [ "${STATUS}" = "enabled" ]
      then
        #... are marked as licensed.
        LIC_STATUS="(licensed)"
      else
        # If not enabled on these models, a license is required to enable.
        LIC_STATUS="(license required to enable)"
      fi
      # We then show their status (including whether licensed).
      echo "${CODEC}: ${STATUS} ${LIC_STATUS}"
    else
      # For other codecs, just show their status.
      echo "${CODEC}: ${STATUS}"
    fi
  else
    # Otherwise, show each codec's status, without concern for license.
    echo "${CODEC}: ${STATUS}"
  fi
done
echo
echo "Note 1: VP6, VP8, and MJPG are not handled by the hardware video decoder"
echo "in the Broadcom BCM2835 processor, but by the VideoCore GPU.  Enable these"
echo "by running:  sudo raspi-config -> Interfacing Options -> Camera -> Enable"
echo "or by adding \"start_x=1\" to /boot/config.txt"
echo
echo "Note 2: GPU hardware-accelerated codecs will be disabled if \"gpu_mem=16\"."
echo "At least \"gpu_mem=96\" is required for the codecs to run correctly."
echo

#---------------
fnBANNER " V4L2-CTL CODECS"
v4l2-ctl -d 10 --list-formats-out
if [ "$(v4l2-ctl -d 10 --list-formats-out | grep Pixel)" = "" ]
then
  echo
fi
if [ "${MY_MODEL_NAME}" = "4B" ]
then
  echo "Note: The H.265 codec, new w/ the Pi 4B, isn't part of the videocore."
  echo "It's an entirely new block on the chip, so the VC6 knows nothing"
  echo "about it.  Therefore, vcgencmd (which talks to the VC6) also knows"
  echo "nothing about it.  The v4l2-ctl command used here, however, should"
  echo "show the H.265 codec, when enabled, on the Pi 4B."
  echo
fi

#---------------
# The Pi itself, will have /dev/video10 (decode), /dev/video11 (encode),
# and /dev/video12 (resize & format conversion) V4L devices.  What we
# want to look at here is any other V4L device found on the system, such
# as TV tuners.
fnBANNER " VIDEO4LINUX DEVICES"
v4l2-ctl --list-devices 2>/dev/null
for DEV in $(v4l2-ctl --list-devices 2>/dev/null | grep /dev/)
do
  fnBANNER " VIDEO4LINUX DEVICE ${DEV}"
  v4l2-ctl -d ${DEV} --all
  echo
done

#---------------
fnBANNER " CAMERA"
# Refers to the small cameras that plug into the Pi's CSI connector
vcgencmd get_camera
if [ $(vcgencmd get_config disable_camera_led | cut -f2 -d"=") -eq 1 ]
then
  echo
  echo "Camera LED is disabled during record."
fi
echo

#---------------
if [ -d /sys/bus/w1/devices ]
then
  fnBANNER " W1-GPIO (1-WIRE INTERFACE) DRIVERS"
  echo " Loaded Modules..."
  lsmod | grep w1_gpio
  echo
  echo " Discovered 1-WIRE Drivers..."
  find /sys/bus/w1/drivers -type d | grep -v ^.$ | grep -v /drivers$ | while read DRIVER
  do
    basename ${DRIVER}
  done
  echo
fi

#---------------
if [ -n "$(lsmod | grep spi)" ]
then
  fnBANNER " SPI (SERIAL PERIPHERAL INTERFACE) DRIVERS"
  echo " Loaded Modules..."
  lsmod | grep spi
  echo
  echo " Discovered SPI Drivers..."
  find /sys/bus/spi/drivers -type d | grep -v ^.$ | grep -v /drivers$ | while read DRIVER
  do
    basename ${DRIVER}
  done
  echo
fi

#---------------
if [ -n "$(lsmod | grep i2s)" ]
then
  fnBANNER " I2S (INTER-IC SOUND) DRIVERS"
  echo " Loaded Modules..."
  lsmod | grep i2s
  echo
  echo " Discovered I2S Drivers..."
  ls -d /sys/bus/platform/drivers/*i2s | while read DRIVER
  do
    basename ${DRIVER}
  done
  echo
fi

#---------------
if [ -n "$(lsmod | grep i2c)" ]
then
  fnBANNER " I2C (INTER-IC COMMUNICATION) DRIVERS"
  echo " Loaded Modules..."
  lsmod | grep i2c
  echo
  echo " Discovered I2C Drivers..."
  find /sys/bus/i2c/drivers -type d | grep -v ^.$ | grep -v /drivers$ | grep -v /dummy$ | grep -v /stmpe-i2c$ | while read DRIVER
  do
    basename ${DRIVER}
  done
  echo
fi

#---------------
# If i2c is enabled, probe for i2c busses
if [ -n "$(grep "^dtparam=i2c_arm=on" /boot/config.txt)" ]
then
  fnBANNER " I2CDETECT"
  i2cdetect -l 2>&1 | sort
  echo
  i2cdetect -l 2>&1 | sort | awk '{ print $1 }' | cut -f2 -d"-" | while read BUS
  do
    echo " I2C BUS: ${BUS}"
    i2cdetect -y ${BUS} 2>&1
    echo
  done
fi

#---------------
# If the user has a realtime clock installed and configured...
if [ -c /dev/rtc0 -o -L /dev/rtc ]
then
  fnBANNER " RTC (REALTIME CLOCK)"
  dmesg | grep rtc | grep -v "Modules linked in:" | grep -v crtc
  echo
  lsmod | grep rtc
  echo
  ls -l /dev/rtc*
  echo
  echo "Hardware RTC says:"
  ${SUDO} hwclock
  echo
  echo "Operating System says:"
  date
  echo
fi

#---------------
# If Hardware Random Number Generator is enabled, and daemon is running...
if [ -c /dev/hwrng -a -n "$(ps -ef | grep "/usr/sbin/rngd -r /dev/hwrng")" ]
then
  # ...and if the test tool is available...
  if type -path rngtest >/dev/null 2>&1
  then
    fnBANNER " HARDWARE RANDOM NUMBER GENERATOR (***)"
    ${SUDO} cat /dev/hwrng | rngtest -c 1000 2>&1
    echo
  fi
fi

#---------------
# If the watchdog timer is enabled...
if [ -n "$(systemctl | grep watchdog.service)" ]
then
  fnBANNER " BROADCOM WATCHDOG TIMER (***)"
  dmesg | grep watchdog
  echo
  cat /etc/watchdog.conf | grep -v ^$ | grep -v ^#
  echo
  DIR="$(grep "^test-directory" /etc/watchdog.conf | awk '{ print $3 }')"
  if [ -n "${DIR}" ]
  then
    echo "Contents of ${DIR}:"
    ls -l ${DIR}
    echo
  fi
  DIR="$(grep "^log-dir" /etc/watchdog.conf | awk '{ print $3 }')"
  if [ -n "${DIR}" ]
  then
    echo "Contents of ${DIR}:"
    ls -l ${DIR}
    echo
  fi
  systemctl status watchdog.service | tee /dev/null
  echo
fi

#---------------
fnBANNER " USB AND OTHER DEVICE INFO"
lsusb | sort
echo
${SUDO} lshw -businfo >/tmp/.lshw_businfo.${PPID} 2>/dev/null
cat /tmp/.lshw_businfo.${PPID}
echo
# The tmpfile negates need to run the above slow command multiple times.
# we'll grab the next few variables now, for use in later routines.
LSHW_INPUT=$(grep "input" /tmp/.lshw_businfo.${PPID} | head -1)
LSHW_STORAGE=$(grep "storage" /tmp/.lshw_businfo.${PPID} | head -1)
LSHW_GENERIC=$(grep "generic" /tmp/.lshw_businfo.${PPID} | head -1)
LSHW_MULTIMEDIA=$(grep "multimedia" /tmp/.lshw_businfo.${PPID} | head -1)
LSHW_COMMUNICATION=$(grep "communication" /tmp/.lshw_businfo.${PPID} | head -1)
# We've set our variables, now get rid of the tmpfile.
rm /tmp/.lshw_businfo.${PPID}

#---------------
if [ -n "${LSHW_INPUT}" ]
then
  fnBANNER " INPUT DEVICES"
  ${SUDO} lshw -class input 2>/dev/null
  echo
fi

#---------------
if [ -n "${LSHW_GENERIC}" ]
then
  fnBANNER " GENERIC DEVICES"
  ${SUDO} lshw -class generic 2>/dev/null
  echo
fi

#---------------
# Note: A bug in the Pi 4B's USB (xhci host controllers that don't update endpoint DCS)
# may affect test results.  The following commands can update your firmware to
# correct the issue, if needed:
# sudo apt update
# sudo apt install rpi-eeprom
# sudo rpi-eeprom-update -a
# sudo reboot
if type -path rtl_eeprom >/dev/null 2>&1 && type -path rtl_test >/dev/null 2>&1
then
  if [ -n "$(lsmod | grep rtl2832)" ]
  then
    fnBANNER " RTL-SDR TUNER (***)"
    rtl_eeprom 2>&1
    echo
    rtl_test -t 2>&1 | grep ^S
    echo
  fi
fi

#---------------
if [ -n "${LSHW_STORAGE}" ]
then
  fnBANNER " STORAGE DEVICES"
  ${SUDO} lshw -class storage 2>/dev/null
  echo
  ${SUDO} lshw -short -class disk -class storage -class volume 2>/dev/null
  echo
fi

#---------------
fnBANNER " DISK CONFIGURATION"
${SUDO} blkid | grep -v zram | sort
echo
lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,LABEL,UUID,PARTUUID,MODEL | grep -v zram
echo
df -h -T | grep -v tmpfs
echo

#---------------
# SUPPLEMENTAL TEST
if [ -e /proc/mdstat ]
then
  fnBANNER " RAID ARRAY CONFIGURATION (***)"
  cat /proc/mdstat | grep ^[a-zA-Z]
  echo
  echo "Contents of /etc/mdadm/mdadm.conf..."
  cat /etc/mdadm/mdadm.conf | grep -v ^$ | grep -v "^#"
  echo
  cat /proc/mdstat | grep ^md | awk '{ print $1 }' | while read MD
  do
    fnSUB_BANNER " RAID ARRAY DEVICE /dev/${MD} (***)" | tr [a-z] [A-Z]
    ${SUDO} mdadm --query /dev/${MD} 2>/dev/null | sed 's/ Use mdadm --detail for more detail.//'
    echo
    UUID=$(blkid | grep "/dev/${MD}:" | awk '{ print $2 }' | cut -f2 -d"\"")
    FSTAB=$(grep "${UUID}" /etc/fstab)
    if [ -n "${FSTAB}" ]
    then
      echo "/etc/fstab entry..."
      echo "${FSTAB}"
      echo
      df -h $(grep "${UUID}" /etc/fstab | awk '{ print $2 }')
      echo
    fi
    ${SUDO} mdadm --detail /dev/${MD}
    echo
    ${SUDO} mdadm --detail /dev/${MD} | awk '{ print $NF }' | grep /dev/ | grep -v "/dev/${MD}:" | while read DEV
    do
      fnSUB_BANNER " RAID ARRAY DEVICE /dev/${MD} - COMPONENT ${DEV} (***)" | tr [a-z] [A-Z]
      ${SUDO} mdadm --query ${DEV} 2>/dev/null | grep -v "is not an md array" | sed 's/  Use mdadm --examine for more detail.//'
      echo
      ${SUDO} mdadm --examine ${DEV}
      echo
    done
  done
fi

#---------------
# SUPPLEMENTAL TEST
if type -path vgdisplay >/dev/null 2>&1
then
  if [ -n "$(${SUDO} vgdisplay 2>/dev/null)" ]
  then
    fnBANNER " LOGICAL VOLUME MANAGER CONFIGURATION (***)"
    echo "LOGICAL VOLUMES..."
    ${SUDO} lvs 2>&1
    echo
    ${SUDO} lvdisplay 2>&1

    fnSUB_BANNER "VOLUME GROUPS..."
    ${SUDO} vgs 2>&1
    echo
    ${SUDO} vgdisplay 2>&1

    fnSUB_BANNER "PHYSICAL VOLUMES..."
    ${SUDO} pvs 2>&1
    echo
    ${SUDO} pvdisplay 2>&1
  fi
fi

#---------------
if [ -f /etc/fstab ]
then
  fnBANNER " FSTAB FILE"
  cat /etc/fstab | grep -v ^$ | grep -v ^#
  echo
else
  # In truth, I can't envision a booted/running system without this file.
  echo "Missing file /etc/fstab" >&2
fi

#---------------
if [ -n "${LSHW_MULTIMEDIA}" ]
then
  fnBANNER " MULTIMEDIA DEVICES"
  ${SUDO} lshw -class multimedia 2>/dev/null
  echo
fi

#---------------
if [ -e /proc/asound/modules ]
then
  fnBANNER " ALSA MODULES"
  cat /proc/asound/modules 2>/dev/null
  echo
fi

#---------------
if [ -e /proc/asound/cards ]
then
  fnBANNER " ALSA SOUND HARDWARE"
  cat /proc/asound/cards
  echo
fi

#---------------
if [ -e /proc/asound/cards ]
then
  cat /proc/asound/cards | grep "^ [0123]" | awk '{ print $1 }' | while read CARD_NUM
  do
    fnBANNER " ALSA CARD-${CARD_NUM} INFO"
    amixer -c ${CARD_NUM} 2>/dev/null
    echo
  done
fi

#---------------
fnBANNER " ALSA PLAYBACK AND CAPTURE DEVICES"
if [ -n "$(aplay -l 2>/dev/null | grep ^card)" ]
then
  aplay -l 2>/dev/null
else
  aplay -l 2>/dev/null | grep PLAYBACK
  echo "No playback device found"
fi
echo
if [ -n "$(arecord -l 2>/dev/null | grep ^card)" ]
then
  arecord -l 2>/dev/null
else
  arecord -l 2>/dev/null | grep CAPTURE
  echo "No capture device found"
fi
echo

#---------------
if [ -c /dev/ttyACM? ]
then
  if [ -n "${LSHW_COMMUNICATION}" ]
  then
    fnBANNER " ACM COMMUNICATION DEVICES"
    ${SUDO} lshw -class communication 2>/dev/null
    echo
  fi
fi

#---------------
fnBANNER " UARTS AND USB SERIAL PORTS"
# By default, on Raspberry Pis equipped with wireless/Bluetooth module,
# (Raspberry Pi 3 and Raspberry Pi Zero W), the PL011 UART id connected
# to tye Bluetooth module, while the mini UART is used as the primary
# UART and will have a Linux console on it.  On all other models, the
# PL011 is used as the primary UART.
#
# In Linux device terms, by default, /dev/ttyS0 refers to the mini UART,
# and /dev/ttyAMA0 refers to the PL011.  The primary UART is the one
# assigned to the Linux Console, which depends on the Raspberry Pi model
# as described above.  There are also symlinksi: /dev/serial0, which
# always refers to the primary UART (if enabled), and /dev/serial1,
# which similarly always refers to the secondary UART (if enabled.)

ls -l /dev/ttyAMA? /dev/serial? /dev/ttyS? /dev/ttyACM? 2>/dev/null
echo
for NUM in 0 1
do
  if [ -L /dev/serial${NUM} ]
  then
    UART_NAME=$(ls -l /dev/serial${NUM} | awk '{ print $NF }')
    case "${UART_NAME}" in
      "ttyAMA0") UART_TYPE="PL011" ;;
      "ttyS0") UART_TYPE="miniUART" ;;
      *) UART_TYPE="unknown" ;;
    esac
    echo " SERIAL${NUM}... (/dev/${UART_NAME}, ${UART_TYPE})"
    stty -a -F /dev/serial${NUM}
    echo
  fi
done
for NUM in 0 1
do
  if [ -c /dev/ttyACM${NUM} ]
  then
    ACM_NAME=$(ls -l /dev/ttyACM${NUM} | awk '{ print $NF }')
    UART_TYPE=$(dmesg | grep ttyACM${NUM} | cut -f4 -d":" | cut -c2-)
    DEVICE=": $(systemctl list-units --all | grep dev-ttyACM${NUM}.device | awk '{ print $NF }')"
    echo " ACM${NUM}... (${ACM_NAME}, ${UART_TYPE}${DEVICE})"
    stty -a -F /dev/ttyACM${NUM}
    echo
  fi
done

#---------------
# Make sure bluetoothd is running, because if not,
# the bluetoothctl commands used here will hang.
PS_BT=$(ps -ef | grep [b]luetoothd)
if [ -n "${PS_BT}" ]
then
  #---------------
  fnBANNER " BLUETOOTH CONTROLLERS"
  BTMAC_OUT="$(echo list | ${SUDO} bluetoothctl 2>/dev/null)"
  BTDEFAULT=$(echo "${BTMAC_OUT}" | grep ^Controller | grep "default" | awk '{ print $2 }')
  echo "${BTMAC_OUT}" | grep ^Controller | awk '{ print $2 }' | while read BTMAC
  do
    if [ "${BTDEFAULT}" = "${BTMAC}" ]
    then
      echo "Default BT Controller..."
    else
      echo "Additional (Non-default) BT Controller..."
    fi
    BTSHOW_OUT="$(echo show ${BTMAC} | ${SUDO} bluetoothctl 2>/dev/null)"
    echo "${BTSHOW_OUT}" | grep -v "\[" | grep -v ^$ | grep -v "Agent registered" | grep -v "Device registered not available"
    echo
  done
  #---------------
  fnBANNER " BLUETOOTH DEVICES (paired w/ default controller)"
  BTPAIRED_OUT="$(echo paired-devices | ${SUDO} bluetoothctl 2>/dev/null)"
  if [ -n "${BTPAIRED_OUT}" ]
  then
    echo "${BTPAIRED_OUT}" | grep -v "\[" | awk '{ print $2 }' | while read BTMAC
    do
      echo "info ${BTMAC}" | ${SUDO} bluetoothctl 2>/dev/null | grep -v "\[" | grep -v ^$ | grep -v "Agent registered" | grep -v "Device registered not available"
    done
    echo
  fi
else
  #---------------
  fnBANNER " bluetoothd daemon not running"
  echo
fi

#---------------
fnBANNER " MEMORY AND SWAP"
free -h
echo
swapon --summary
echo

#---------------
if [ -e /proc/meminfo ]
then
  fnBANNER " MEMINFO"
  cat /proc/meminfo
  echo
fi

#---------------
fnBANNER " IPC STATUS"
lsipc
echo

#---------------
fnBANNER " DMESG - WARNINGS"
dmesg | grep -i warn
echo

#---------------
fnBANNER " DMESG - FAILURES"
dmesg | grep -i fail
echo

#---------------
fnBANNER " SYSTEMD-ANALYZE CRITICAL-CHAIN"
systemctl list-jobs
echo
systemd-analyze time
echo
systemd-analyze critical-chain
echo

#---------------
fnBANNER " SYSTEMD-ANALYZE BLAME"
# the tee eliminates the pause every screenfull
systemd-analyze blame | tee /dev/null
echo

#---------------
fnBANNER " SYSTEMCTL STATUS"
# the tee eliminates the pause every screenfull
systemctl status | tee /dev/null
echo

#---------------
fnBANNER " SYSTEMCTL UNIT FAILURES"
systemctl list-units --failed --all | grep -v "list-unit-files"
echo

#---------------
fnBANNER " SYSTEMCTL LIST-UNIT-FILES"
# the tee eliminates the pause every screenfull
systemctl list-unit-files | tee /dev/null
echo

#---------------
if [ -d /var/log/journal ]
then
  if [ -n "stat /var/log/journal | grep "2755" | grep "root" | grep "systemd-journal"" ]
  then
    fnBANNER " PERSISTENT JOURNALING"
    echo "Persistent Journaling is configured"
    ls -ld /var/log/journal
    echo
    ${SUDO} journalctl --sync
    ${SUDO} journalctl --flush
    ${SUDO} journalctl -b | grep "System journal"  | tail -1 | cut -f4- -d":"
    ${SUDO} journalctl -b | grep "Runtime journal" | tail -1 | cut -f4- -d":" | sed 's/^ //'
    echo
    echo "Journaled boots..."
    journalctl --list-boots
    echo
    journalctl --disk-usage
    echo
  fi
fi

#---------------
# SUPPLEMENTAL MODULE
# Logic in this module is shamelessly based on syslogconf,
# by Michael Hill, Lockheed Martin Astronotics, Denver, CO
# Perl is used here because bash sucks at nesting associative arrays.
if type -path perl >/dev/null 2>&1 && type -path m4 >/dev/null 2>&1
then
  fnBANNER " RSYSLOG.CONF ANALYSIS (***)"
  echo "This module creates a comprehensive listing of rsyslog.conf event logging."
  echo "The selector selects all messages of equal or higher severity.  For example,"
  echo "news.err really means news.err, news.crit, news.alert, news.emerg.  And"
  echo "mail,uucp.alert means mail.alert, mail.emerg, uucp.alert, and uucp.emerg."
  echo
  echo "Some versions of syslog allow an = character before the level specifier"
  echo "(as in news.=err to act only on messages of that level."
  echo
  echo "The output below interprets the directives to show where things are going."
  echo

  PERL_SCRIPT=$(cat <<'EOF'
  select (STDERR); $| = 1;        # Turn off buffered I/O
  select (STDOUT); $| = 1;
  ($progname = $0) =~ s/.*\///;
  chop ($uname = `uname -nsr`);
  @uname = split (' ', $uname);

  sub fatal {
    local ($errMesg, $errCode) = (@_);

    printf (STDERR "$progname:  %s\n", $errMesg);
    exit ($errCode);
  }

  $rsyslogconf = '/etc/rsyslog.conf';
  $loghost = '';
  @facilities = ('kern', 'user', 'mail', 'daemon',
    'auth', 'lpr', 'news', 'uucp', 'cron', 'local0',
    'local1', 'local2', 'local3', 'local4', 'local5',
    'local6', 'local7', 'mark');
  @levels = ('emerg', 'alert', 'crit', 'err', 'warning',
    'notice', 'info', 'debug');

  for $facil (@facilities) {
    for $lev (@levels) {
      $event_type{"$facil.$lev"} = 'no action';
    }
  }
  for $i ($[ .. $#levels) {
    $severity{$levels[$i]} = $i;
  }

  ($name) = gethostbyname ('loghost');
  if ($name eq $hostname) {
    # we're running on 'loghost'
    $loghost = '-DLOGHOST';
  }

  open (SYSLOGCONF, "m4 $loghost $rsyslogconf |") ||
    &fatal ("can't open 'm4 $rsyslogconf'", 2);

  while (<SYSLOGCONF>) {
    local (%eventlist);

    next if (/^\s*$/ || /^\s*#/);
    chop;

    %eventlist = ( );
    ($events, $action) = split (/\t+/);
    next if ($action eq '');

    # parse for multiple events
    @events = split (';', $events);
    for $event (@events) {
      local ($thislev, $evt);

      ($facils, $level) = split ('\.', $event);
      $thislev = $severity{$level};

      # parse for multiple facility specifications
      if ($facils eq '*') {
        @facils = grep (! /mark/, @facilities);
      } else {
        @facils = split (',', $facils);
      }
      if ($level eq 'none') {
        @levs = @levels;
      } else {
        @levs = grep ($severity{$_} <= $thislev, @levels);
      }
      for $facil (@facils) {
        for $lev (@levs) {
          if ($level eq 'none') {         # delete entry
            delete ($eventlist{"$facil.$lev"})
              if ($eventlist{"$facil.$lev"});
          } else {                        # add entry
            $eventlist{"$facil.$lev"} = 1;
          }
        }
      }
    }
    for $evt (keys (%eventlist)) {
      if ($event_type{$evt} eq 'no action') {
        $event_type{$evt} = $action;
      } else {
        $event_type{$evt} .= ", $action";
      }
    }
  }

  close (SYSLOGCONF);

  for $key (sort (keys (%event_type))) {
    printf ("Event:  %-16s\tAction:  %s\n", $key,
      $event_type{$key});
  }

  exit (0);
EOF
)
perl -e "${PERL_SCRIPT}"
echo
fi

#---------------
if [ -f /etc/rc.local ]
then
  fnBANNER " RC.LOCAL"
  cat /etc/rc.local | grep -v ^$ | grep -v ^#
  echo
else
  echo "Missing file /etc/rc.local" >&2
fi

#---------------
if [ -f /etc/default/locale 2>/dev/null ] && [ -f /etc/default/keyboard 2>/dev/null ] && [ -f /etc/default/console-setup 2>/dev/null ] && [ -f /etc/timezone 2>/dev/null ]
then
  fnBANNER " LOCALIZATION SETTINGS"
  . /etc/default/locale
  . /etc/default/keyboard
  . /etc/default/console-setup
  echo "Language : ${LANG}"
  echo "KB Model : ${XKBMODEL}"
  echo "KB Layout: ${XKBLAYOUT}"
  echo "Char. Map: ${CHARMAP}"
  echo "Timezone : $(cat /etc/timezone)"
  echo
else
  echo "Unable to determine locale settings on this Pi.  Skipping."
fi

#---------------
# SUPPLEMENTAL TEST
# Not everyone has "cups" installed, so "lpstat" (part of the cups-client package)
# is not a required dependency for this script.  If they have it, great.  If not,
# it's no big deal.
if type -path lpstat >/dev/null 2>&1
then
  CUPS_RUNNING="$(lpstat -r 2>/dev/null)"
  if [ "${CUPS_RUNNING}" = "scheduler is running" ]
  then
    fnBANNER " PRINTER STATUS {***)"
    lpstat -t
    echo
  fi
fi

#---------------
fnBANNER " OFFICIAL 7\" TOUCHSCREEN"
PI_TOUCHSCR="$(dmesg | grep -i ft5406)"
if [ -n "${PI_TOUCHSCR}" ]
then
  echo "detected"
else
  echo "not detected"
fi
echo

#---------------
# This routine was developed and tested on a Pi 3B and 3B+ only.
# I do not own, nor have access to, a Pi 4B at this time. :'(
# It is a "best guess" that it will work on a Pi 4B to detect
# multiple displays, given the Pi 4B's dual HDMI ports.  This
# assumption is based soley on the "tvservice -h" help screen.
#
# Unfortunately, tvservice is useless with vc4-kms-v3d(-pi4),
# but ok with broadcom and "fake" gl driver.
if [ "${DISP_DRIVER}" = "broadcom" -o "${DISP_DRIVER}" = "fake" ]
then
  fnBANNER " HDMI DISPLAY DATA"
  vcgencmd dispmanx_list 2>&1
  echo
  tvservice -l 2>/dev/null
  echo
  tvservice -l 2>/dev/null | grep "Display Number" | awk '{ print $3 }' | cut -f1 -d"," | while read DISP_NUM
  do
    TVSTATUS="$(tvservice -s -v ${DISP_NUM} 2>/dev/null)"
    TV_OFF="$(echo "${TVSTATUS}" | awk '{ print $2 }')"
    if [ "${TVSTATUS}" = "0x120000" ]
    then
      echo "Display ${DISP_NUM} is not HDMI... Skipping."
      echo
      continue
    else
      if [ "${TVSTATUS}" = "0x2" ]
      then
        echo "Display ${DISP_NUM} TV is Off... Skipping."
        echo
        continue
      fi
    fi
    fnSUB_BANNER "DISPLAY NUMBER : ${DISP_NUM}"
    echo "DISPLAY STATUS : ${TVSTATUS}"

    DEV_ID="$(tvservice -n -v ${DISP_NUM} 2>/dev/null | strings )"
    if [ "${DEV_ID}" = "" ]
    then
      DEV_ID="No Device Present"
    fi
    echo "EDID DEVICE ID : ${DEV_ID}"

    DEV_AUDIO="$(tvservice -a -v ${DISP_NUM} 2>/dev/null | sed 's/^     //')"
    if [ "${DEV_AUDIO}" = "" ]
    then
      DEV_AUDIO="No Device Present"
    fi
    echo "SUPPORTED AUDIO: ${DEV_AUDIO}"
    echo

    # Group is usually either DMT (monitors - group 2) or CEA (TV sets - group 1)
    # This forces "custom" modes to be listed (I hope) as DMT, mode 87
    TVGROUP="$(echo "${TVSTATUS}" | awk '{ print $4 }')"
    if [ "${TVGROUP}" != "DMT" -a "${TVGROUP}" != "CEA" ]
    then
      TVGROUP=DMT
    fi
    tvservice --modes=${TVGROUP} -v ${DISP_NUM} 2>/dev/null
    echo
  done
fi

#---------------
# 'vcgencmd get_lcd_info' is useless with vc4-kms-v3d(-pi4), but
# ok with broadcom and "fake" gl driver.
if [ "${DISP_DRIVER}" = "broadcom" -o "${DISP_DRIVER}" = "fake" ]
then
  fnBANNER " CURRENT SCREEN RESOLUTION"
  echo "HORIZONTAL : $(vcgencmd get_lcd_info | awk '{ print $1 }') pixels"
  echo "VERTICAL   : $(vcgencmd get_lcd_info | awk '{ print $2 }') pixels"
  echo "COLOR DEPTH: $(vcgencmd get_lcd_info | awk '{ print $3 }') bits"
  echo
fi

#---------------
# SUPPLEMENTAL TEST
if type -path xrandr >/dev/null 2>&1
then
  if [ -n "${DISPLAY}" ]
  then
    fnBANNER " CURRENT X-DISPLAY RESOLUTION (***)"
    echo "\$DISPLAY=${DISPLAY}"
    # xrandr is part of package "x11-xserver-utils"
    xrandr --verbose 2>&1 | grep -v "xrandr: Failed to get size of gamma for output default"
    echo
  fi
fi

#---------------
# SUPPLEMENTAL TEST
if type -path gpio >/dev/null 2>&1
then
  fnBANNER " GPIO PIN STATUS via WIRINGPI (***)"
  # Run on a 4B only if wiringpi is v2.52
  if [ ${MY_MODEL_NAME} = "4B" -a "${WIRINGPI_VERS}" = "2.52" ]
  then
    gpio readall
    echo
  fi
  # Run on other Pis with 2.50 from the repositories
  if [ ${MY_MODEL_NAME} != "4B" ]
  then
    gpio readall
    echo
  fi
fi

#---------------
# SUPPLEMENTAL MODULE
# See: http://www.raspberrypi.org/forums/viewtopic.php?t=254071
# for post entitled "GPIO Readall Code", by user "Milliways"
# requires python3-pigpio be installed.
# requires "/usr/bin/pigpiod" be running (systemctl enable pigpiod.service)
# Unfortunately, some older 26-pin Model A and B Pis may be out of luck.
if [ -n "$(ps -ef | grep "/usr/bin/pigpiod")" ]
then
  fnBANNER " GPIO PIN STATUS via PIGPIOD (***)"
  PY3_SCRIPT=$(cat <<'EOF'
"""
Read all GPIO
"""
import sys, os, time
import pigpio

MODES = ["IN", "OUT", "ALT5", "ALT4", "ALT0", "ALT1", "ALT2", "ALT3"]
HEADER = ('3.3v', '5v', 2, '5v', 3, 'GND', 4, 14, 'GND', 15, 17, 18, 27, 'GND', 22, 23, '3.3v', 24, 10, 'GND', 9, 25, 11, 8, 'GND', 7, 0, 1, 5, 'GND', 6, 12, 13, 'GND', 19, 16, 26, 20, 'GND', 21)
GPIOPINS = 40

FUNCTION = {
'Pull': ('High', 'High', 'High', 'High', 'High', 'High', 'High', 'High', 'High', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low', 'Low'),
'ALT0': ('SDA0', 'SCL0', 'SDA1', 'SCL1', 'GPCLK0', 'GPCLK1', 'GPCLK2', 'SPI0_CE1_N', 'SPI0_CE0_N', 'SPI0_MISO', 'SPI0_MOSI', 'SPI0_SCLK', 'PWM0', 'PWM1', 'TXD0', 'RXD0', 'FL0', 'FL1', 'PCM_CLK', 'PCM_FS', 'PCM_DIN', 'PCM_DOUT', 'SD0_CLK', 'SD0_XMD', 'SD0_DATO', 'SD0_DAT1', 'SD0_DAT2', 'SD0_DAT3'),
'ALT1': ('SA5', 'SA4', 'SA3', 'SA2', 'SA1', 'SAO', 'SOE_N', 'SWE_N', 'SDO', 'SD1', 'SD2', 'SD3', 'SD4', 'SD5', 'SD6', 'SD7', 'SD8', 'SD9', 'SD10', 'SD11', 'SD12', 'SD13', 'SD14', 'SD15', 'SD16', 'SD17', 'TE0', 'TE1'),
'ALT2': ('PCLK', 'DE', 'LCD_VSYNC', 'LCD_HSYNC', 'DPI_D0', 'DPI_D1', 'DPI_D2', 'DPI_D3', 'DPI_D4', 'DPI_D5', 'DPI_D6', 'DPI_D7', 'DPI_D8', 'DPI_D9', 'DPI_D10', 'DPI_D11', 'DPI_D12', 'DPI_D13', 'DPI_D14', 'DPI_D15', 'DPI_D16', 'DPI_D17', 'DPI_D18', 'DPI_D19', 'DPI_D20', 'DPI_D21', 'DPI_D22', 'DPI_D23'),
'ALT3': ('SPI3_CE0_N', 'SPI3_MISO', 'SPI3_MOSI', 'SPI3_SCLK', 'SPI4_CE0_N', 'SPI4_MISO', 'SPI4_MOSI', 'SPI4_SCLK', '_', '_', '_', '_', 'SPI5_CE0_N', 'SPI5_MISO', 'SPI5_MOSI', 'SPI5_SCLK', 'CTS0', 'RTS0', 'SPI6_CE0_N', 'SPI6_MISO', 'SPI6_MOSI', 'SPI6_SCLK', 'SD1_CLK', 'SD1_CMD', 'SD1_DAT0', 'SD1_DAT1', 'SD1_DAT2', 'SD1_DAT3'),
'ALT4': ('TXD2', 'RXD2', 'CTS2', 'RTS2', 'TXD3', 'RXD3', 'CTS3', 'RTS3', 'TXD4', 'RXD4', 'CTS4', 'RTS4', 'TXD5', 'RXD5', 'CTS5', 'RTS5', 'SPI1_CE2_N', 'SPI1_CE1_N', 'SPI1_CE0_N', 'SPI1_MISO', 'SPIl_MOSI', 'SPI1_SCLK', 'ARM_TRST', 'ARM_RTCK', 'ARM_TDO', 'ARM_TCK', 'ARM_TDI', 'ARM_TMS'),
'ALT5': ('SDA6', 'SCL6', 'SDA3', 'SCL3', 'SDA3', 'SCL3', 'SDA4', 'SCL4', 'SDA4', 'SCL4', 'SDA5', 'SCL5', 'SDA5', 'SCL5', 'TXD1', 'RXD1', 'CTS1', 'RTS1', 'PWM0', 'PWM1', 'GPCLK0', 'GPCLK1', 'SDA6', 'SCL6', 'SPI3_CE1_N', 'SPI4_CE1_N', 'SPI5_CE1_N', 'SPI6_CE1_N')
}

def pin_state(g):
    mode = pi.get_mode(g)
    if(mode<2):
        name = 'GPIO{}'.format(g)
    else:
        name = FUNCTION[MODES[mode]][g]
    return name, MODES[mode], pi.read(g)

if len(sys.argv) > 1:
    pi = pigpio.pi(sys.argv[1])
else:
    pi = pigpio.pi()

if not pi.connected:
    sys.exit(1)
rev = pi.get_hardware_revision()
if rev < 16 :
    GPIOPINS = 26

print('+-----+------------+------+---+----++----+---+------+-----------+-----+')
print('| BCM |    Name    | Mode | V |  Board   | V | Mode | Name      | BCM |')
print('+-----+------------+------+---+----++----+---+------+-----------+-----+')
for h in range(1, GPIOPINS, 2):
# odd pin
    hh = HEADER[h-1]
    if(type(hh)==type(1)):
        print('|{0:4} | {1[0]:<10} | {1[1]:<4} | {1[2]} |{2:3} '.format(hh, pin_state(hh), h), end='|| ')
    else:
        print('|     |  {:18}   | {:2}'.format(hh, h), end=' || ')
# even pin
    hh = HEADER[h]
    if(type(hh)==type(1)):
        print('{0:2} | {1[2]:<2}| {1[1]:<5}| {1[0]:<10}|{2:4} |'.format(h+1, pin_state(hh), hh))
    else:
        print('{:2} |             {:9}|     |'.format(h+1, hh))
print('+-----+------------+------+---+----++----+---+------+-----------+-----+')
print('| BCM |    Name    | Mode | V |  Board   | V | Mode | Name      | BCM |')
print('+-----+------------+------+---+----++----+---+------+-----------+-----+')
EOF
)
  python3 -c "${PY3_SCRIPT}"
  echo
fi

#---------------
# SUPPLEMENTAL TEST
if type -path mpstat >/dev/null 2>&1
then
  fnBANNER " MPSTAT (***)"
  # 3 samples, 3 seconds apart, to get an average
  mpstat 3 3
  echo
else
  echo "Missing utility mpstat (part of sysstat), skipping mpstat display" >&2
fi

#---------------
# SUPPLEMENTAL TEST
if type -path iostat >/dev/null 2>&1
then
  fnBANNER " IOSTAT (***)"
  iostat -x
else
  echo "Missing utility iostat (part of sysstat), skipping iostat display" >&2
fi

#---------------
if [ -n "$(grep ipv6.disable=1 /boot/cmdline.txt)" ]
then
  fnBANNER " IPV6 DISABLED"
  echo "IPv6 has been disabled in cmdline.txt"
  echo
fi

#---------------
if [ -f /etc/resolv.conf ]
then
  fnBANNER " RESOLV.CONF"
  cat /etc/resolv.conf | grep -v ^$ | grep -v ^#
  echo
else
  echo "Missing file /etc/resolv.conf" >&2
fi

#---------------
if [ -f /etc/hosts ]
then
  fnBANNER " HOSTS FILE"
  cat /etc/hosts | grep -v ^$ | grep -v ^#
  echo
else
  echo "Missing file /etc/hosts" >&2
fi

#---------------
if [ -f /etc/networks ]
then
  fnBANNER " NETWORKS FILE"
  cat /etc/networks | grep -v ^$ | grep -v ^#
  echo
else
  echo "Missing file /etc/networks" >&2
fi

#---------------
if [ -f /etc/iptables.up.rules ]
then
  fnBANNER " IPV4 FIREWALL RULES"
  cat /etc/iptables.up.rules | grep -v ^$ | grep -v ^#
  echo
else
  echo "Missing file /etc/iptables.up.rules" >&2
fi

#---------------
if [ -f /etc/ip6tables.up.rules ]
then
  fnBANNER " IPV6 FIREWALL RULES"
  cat /etc/ip6tables.up.rules | grep -v ^$ | grep -v ^#
  echo
else
  echo "Missing file /etc/ip6tables.up.rules" >&2
fi

#---------------
if [ -f /etc/hosts.deny ]
then
  fnBANNER " TCPWRAPPERS: HOSTS.DENY"
  HITS=`cat /etc/hosts.deny | grep -v "^#" | grep -v "^$" | wc -l`
  if [ ${HITS} -ne 0 ]
  then
    cat /etc/hosts.deny | grep -v "^#" | grep -v "^$"
  else
    echo "file is empty"
  fi
  echo
else
  echo "Missing file /etc/hosts.deny" >&2
fi

#---------------
if [ -f /etc/hosts.allow ]
then
  fnBANNER " TCPWRAPPERS: HOSTS.ALLOW"
  HITS=`cat /etc/hosts.allow | grep -v "^#" | grep -v "^$" | wc -l`
  if [ ${HITS} -ne 0 ]
  then
    cat /etc/hosts.allow | grep -v "^#" | grep -v "^$"
  else
    echo "file is empty"
  fi
  echo
else
  echo "Missing file /etc/hosts.allow" >&2
fi

#---------------
fnBANNER " ROUTE TABLE - IPV4"
route -4 2> /dev/null
echo
fnBANNER " ROUTE TABLE - IPV6"
route -6 2> /dev/null
echo

#---------------
fnBANNER " NETWORK ADAPTORS"
${SUDO} lshw -class network 2>/dev/null
echo

#---------------
# SUPPLEMENTAL TEST
if type -path ethtool >/dev/null 2>&1
then
  ip -s link | grep eth[0-9] | awk '{ print $2 }' | cut -f1 -d":" | while read ETH
  do
    fnBANNER " ETHTOOL (***)"
    echo "Found ${ETH}..."
    echo
    ${SUDO} ethtool -i ${ETH}
    echo
    ${SUDO} ethtool ${ETH}
    echo
  done
fi

#---------------
fnBANNER " IFCONFIG"
ifconfig

#---------------
fnBANNER " IP NEIGHBORS (ARP CACHE)"
ip neigh | grep -v FAILED
echo

#---------------
if [ -f /etc/wpa_supplicant/wpa_supplicant.conf ]
then
  fnBANNER " WPA_SUPPLICANT FILE (Passwords will not be displayed)"
  ${SUDO} cat /etc/wpa_supplicant/wpa_supplicant.conf | grep -v ^$ \
    | sed 's/psk=.*/psk=**PASSWORD_HIDDEN**/' \
    | sed 's/wep_key0=.*/wep_key0=**PASSWORD_HIDDEN**/' \
    | sed 's/password=.*/password=**PASSWORD_HIDDEN**/' \
    | sed 's/passwd=.*/passwd=**PASSWORD_HIDDEN**/'
  echo
fi

#---------------
fnBANNER " IWCONFIG"
ip -s link | grep wlan[0-3] | awk '{ print $2 }' | cut -f1 -d":" | while read WLAN
do
  iwconfig ${WLAN} 2>/dev/null
done

#---------------
fnBANNER " VISIBLE WIFI ACCESS POINTS"
iwlist scan 2>/dev/null | grep -v ^$ | grep -v "Unknown:"
echo

#---------------
fnBANNER " NETSTAT"
netstat -n 2>/dev/null
echo

#---------------
# SUPPLEMENTAL TEST
# Not everyone has, or needs, nmap.  So, it's not a required dependency
# for this script.  However, if we do find that it is available, we can
# make use of it here.
if type -path nmap >/dev/null 2>&1
then
  # IPV4
  ifconfig | grep "inet " | awk '{ print $2 }' | while read MY_IP
  do
    fnBANNER " SCANNING FOR SERVICES LISTENING ON IPV4: ${MY_IP} (***)"
    nmap -Pn -sV -T4 -p 1-65535 --version-light ${MY_IP} | grep "^PORT\|^[1-9][0-9]"
    echo
  done
  # IPV6
  ifconfig | grep "inet6 " | grep -v "inet6 ....::" | awk '{ print $2 }' | while read MY_IP
  do
    fnBANNER " SCANNING FOR SERVICES LISTENING ON IPV6: ${MY_IP} (***)"
    nmap -6 -Pn -sV -T4 -p 1-65535 --version-light ${MY_IP} | grep "^PORT\|^[1-9][0-9]"
    echo
  done
fi

#---------------
# SUPPLEMENTAL TEST
# Another supplemental test.  If they have the portmapper and NFS running,
# we'll show some information along with a list of any exports.
PS_RPC=$(ps -ef | grep [r]pcbind)
if [ -n "${PS_RPC}" ]
then
  if type -path rpcinfo >/dev/null 2>&1
  then
    fnBANNER " PORTMAPPER - RPCINFO (***)"
    rpcinfo localhost
    echo
  else
    echo "Missing utility rpcinfo, skipping rpcinfo display" >&2
  fi

  #---------------
  # SUPPLEMENTAL TEST
  if type -path showmount >/dev/null 2>&1
  then
    fnBANNER " EXPORTED NFS DIRS (***)"
    showmount -e localhost
    echo
  else
    echo "Missing utility showmount, skipping nfs exports display" >&2
  fi

  #---------------
  # SUPPLEMENTAL TEST
  fnBANNER " MOUNTED NFS DIRS (***)"
  if [ -n "df -hT --type=nfs --type=nfs4" ]
  then
    df -hT --type=nfs --type=nfs4
    echo
    if type -path nfsiostat >/dev/null 2>&1 && type -path grep >/dev/null 2>&1
    then
      fnBANNER " NFSIOSTAT (***)" | grep -v ^$
      nfsiostat
    else
      echo "Missing nfsiostat, skipping nfsiostat display" >&2
    fi
  else
    echo "No NFS shares mountted"
  fi
  echo
fi

#---------------
# SUPPLEMENTAL TEST
# Another supplemental test.  If they have smb running,
# we'll show some samba stats
PS_SMB=$(ps -ef | grep [s]mbd)
if [ -n "${PS_SMB}" ]
then
  if type -path smbstatus >/dev/null 2>&1
  then
    fnBANNER " SMBSTATUS - REMOTE SYSTEMS CONNECTED TO US (***)" | grep -v "^$"
    ${SUDO} smbstatus
  else
    echo "Missing utility smbstatus, skipping smbstatus display" >&2
  fi
fi

#---------------
fnBANNER " MOUNTED CIFS DIRS"
if [ -n "$(df -hT --type=cifs 2>/dev/null)" ]
then
  df -hT --type=cifs 2>/dev/null
else
  echo "No remote CIFS/Windows shares mounted"
fi
echo

#---------------
fnBANNER " LOADED MODULES"
lsmod | head -1
lsmod | sort | grep -v "Used by"
echo

#---------------
# This next routine generates information about each loaded module listed
# by the above section.  The amount of information can be significant,
# depending upon how many modules are running.  Uncomment if you'ld like,
# but it may give more information than you are willing to scroll through.
#
# fnBANNER " MODULE DETAILS"
# lsmod | awk '{ print $1 }' | grep -v ^Module | sort | while read MODULE
# do
#   echo "===================="
#   modinfo ${MODULE}
#   echo
# done

#---------------
# Packages can be placed "on hold" to prevent upgrading a package
# in question.  While on hold, apt, apt-get, dpkg, aptitude and so on
# will all refuse to upgrade the on-hold package.  Here, we remind
# the admin of any packages they may have placed "on hold".
#
# To place a package on hold to prevent upgrade:
#   sudo apt-mark hold <package_name>
# To release a package from hold to allow upgrade:
#   sudo apt-mark unhold <package_name>
# To view list of packages currently on hold:
#   sudo dpkg --get-selections | grep "hold"
fnBANNER " PACKAGES ON HOLD TO DISALLOW UPGRADE"
if [ "$(${SUDO} dpkg --get-selections | grep "hold$")" = "" ]
then
  echo "No packages placed on hold"
  echo
else
  ${SUDO} dpkg --get-selections | grep "hold$"
fi

#---------------
fnBANNER " INSTALLED PACKAGE LIST"
dpkg -l 2>/dev/null | tee /dev/null
echo

#---------------
# This next module will likely never see the light of day.  It generates
# information about every installed package on a system.  You're better
# off running "apt show" against a package of interest only, than having
# this script loop through every package.
#
# fnBANNER " PACKAGE DETAILS"
# apt list 2>/dev/null | cut -f1 -d"/" | sort | while read PACKAGE
# do
#   echo "===================="
#   apt show ${PACKAGE} 2>/dev/null
# done

fnBANNER " * * * END OF REPORT * * *"

##################################################
# ALL DONE
##################################################
