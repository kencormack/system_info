#!/bin/bash

VERSION="1.3.8"
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
#   alsa-utils, bluez, coreutils, i2c-tools, iproute2, libraspberrypi-bin,
#   lshw, net-tools, usbutils, util-linux, v4l-utils, wireless-tools
#
# If the Pi being examined is a 4B, the package rpi-eeprom is also required.
#
# The script will explicitly test that each of those packages is installed.
# If any are missing, it will inform the user, and instruct them to install.
#
# The following supplemental packages may also be utilized:
#   cups-client, dc, ethtool, nfs-kernel-server, nmap, python3-gpiozero,
#   rpcbind, rtl-sdr, samba, sysstat, watchdog, and wiringpi
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
#   Pi 3B w/ Raspbian Buster,
#   X150 9-port USB hub,
#   DVK512 board w/ RTC,
#   DockerPi Powerboard,
#   fit_StatUSB USB LED,
#   USB Bluetooth dongle (onboard BT disabled),
#   Hauppauge WinTV HVR950Q USB TV Tuner,
#   RTL-SDR USB Software Defined Radio,
#   X820 SATA III Board w/ 1TB SSD,
#   Headless - SSH and VNC only (No Display)
#
#   hostname: pi-devel-2GB (William's),
#   Pi 4B w/ Raspbian Buster (2GB memory),
#   PiOled i2c display,
#   USB flash drive,
#   USB Ethernet adapter

##################################################
# A HANDY FUNCTION WE'LL BE USING...
##################################################
fnBANNER() {
  echo "==============================================================================="
  echo "${@}"
  echo
}

##################################################
# TITLE
##################################################
#---------------
fnBANNER " RASPBERRY PI SYSTEM INFORMATION TOOL - v${VERSION}"
echo "Written By Ken Cormack, unixken@yahoo.com"
echo "With contributions from William Stearns, william.l.stearns@gmail.com"
echo "Latest version on github - https://github.com/kencormack/system_info"
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
  REQUIRED=$(dpkg -l 2>/dev/null | awk '{ print $2 }' | grep -i "^alsa-utils$\|^bluez$\|^coreutils$\|^i2c-tools$\|^iproute2$\|^libraspberrypi-bin$\|^lshw$\|^net-tools$\|^rpi-eeprom$\|^util-linux$\|^usbutils$\|^v4l-utils$\|^wireless-tools$")
  REQ_HIT=0
  REQ_MAX=0
  for PACKAGE in alsa-utils bluez coreutils i2c-tools iproute2 libraspberrypi-bin lshw net-tools rpi-eeprom usbutils util-linux v4l-utils wireless-tools
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
    echo "All core inspections can be performed."
    echo

    ######################################
    # Now, the supplemental packages.
    # If installed, great.  If not installed, don't trouble the user to add them.
    echo "Checking supplemental software dependencies..."
    SUPPLEMENTAL=$(dpkg -l 2>/dev/null | awk '{ print $2 }' | grep -i "^cups-client$\|^dc$\|^ethtool$\|^nfs-kernel-server$\|^nmap$\|^python3-gpiozero$\|^rpcbind$\|^rtl-sdr$\|^samba$\|^sysstat$\|^watchdog$\|^wiringpi$")
    SUP_HIT=0
    SUP_MAX=0

    # For supplemental PRINTER STATUS
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^cups-client$")" ] && type -path lpstat >/dev/null 2>&1
    then
      echo "  found: cups-client"
      let SUP_HIT++
    fi
    let SUP_MAX++

    # For supplemental Centigrade-to-Farenheit conversion in TEMPERATURE
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^dc$")" ] && type -path dc >/dev/null 2>&1
    then
      echo "  found: dc"
      let SUP_HIT++
    fi
    let SUP_MAX++

    # For supplemental ETHTOOL section
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^ethtool$")" ] && type -path ethtool >/dev/null 2>&1
    then
      echo "  found: ethtool"
      let SUP_HIT++
    fi
    let SUP_MAX++

    # For supplemental EXPORTED NFS DIRS
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^nfs-kernel-server$")" ] && [ -n "$(ps -ef | grep [n]fsd)" ]
    then
      echo "  found: nfs-kernel-server"
      let SUP_HIT++
    fi
    let SUP_MAX++

    # For supplemental SCANNING FOR SERVICES
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^nmap$")" ] && type -path nmap >/dev/null 2>&1
    then
      echo "  found: nmap"
      let SUP_HIT++
    fi
    let SUP_MAX++

    # For supplemental SYSTEM DIAGRAM
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^python3-gpiozero$")" ] && type -path pinout >/dev/null 2>&1
    then
      echo "  found: python3-gpiozero"
      let SUP_HIT++
    fi
    let SUP_MAX++

    # For supplemental PORTMAPPER - RPCINFO
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^rpcbind$")" ] && [ -n "$(ps -ef | grep [r]pcbind)" ]
    then
      echo "  found: rpcbind"
      let SUP_HIT++
    fi
    let SUP_MAX++

    # For supplemental RTL-SDR TUNER
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^rtl-sdr$")" ] && type -path rtl_eeprom >/dev/null 2>&1 && type -path rtl_test >/dev/null 2>&1
    then
      echo "  found: rtl-sdr"
      let SUP_HIT++
    fi
    let SUP_MAX++

    # For supplemental SMBSTATUS
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^samba$")" ] && [ -n "$(ps -ef | grep [s]mbd)" ]
    then
      echo "  found: samba"
      let SUP_HIT++
    fi
    let SUP_MAX++

    # For supplemental SYSSTAT
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^sysstat$")" ] && type -path mpstat >/dev/null 2>&1 && type -path iostat >/dev/null 2>&1
    then
      echo "  found: sysstat"
      let SUP_HIT++
    fi
    let SUP_MAX++

    # For supplemental WATCHDOG
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^watchdog$")" ] && [ -n "$(ps -ef | grep [w]atchdog)" ]
    then
      echo "  found: watchdog"
      let SUP_HIT++
    fi
    let SUP_MAX++

    # For supplemental GPIO PIN STATUS
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^wiringpi$")" ] && type -path gpio >/dev/null 2>&1
    then
      # Make sure that whatever version is installed supports the Pi we're examining,
      # before we declare it "found".  This is particularly important for the Pi 4B.
      # WiringPi v2.50 is in the repositories, but the Pi 4B requires v2.52 (which
      # may or may not ever make it into the repositories, as the package has been
      # depricated.)
      # If you have a raspberry pi 4B, install at least version 2.52 of wiringpi
      # See - http://wiringpi.com/wiringpi-updated-to-2-52-for-the-raspberry-pi-4b/
      if gpio readall >/dev/null 2>&1
      then
        echo "  found: wiringpi (v$(gpio -v 2>/dev/null | head -1 | awk '{ print $NF }'))"
        let SUP_HIT++
      else
        echo "Installed version of wiringpi (v$(gpio -v 2>/dev/null | head -1 | awk '{ print $NF }')) does not support this Pi."
      fi
    fi
    let SUP_MAX++

    echo "${SUP_HIT} out of ${SUP_MAX} supplemental packages are installed."
    if [ ${SUP_HIT} -gt 0 ]
    then
      echo "Some supplemental inspections can be performed."
    else
      echo "No supplemental inspections can be performed."
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
fnBANNER " MAC-ADDRESS(ES)"
MACS=$(ifconfig | grep '[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:' | awk '{print $2}' | tr "a-f" "A-F")
echo "${MACS}"
echo

#---------------
fnBANNER " MODEL AND FIRMWARE VERSION"
cat /sys/firmware/devicetree/base/model | strings
echo
vcgencmd version
echo

#---------------
# SUPPLEMENTAL TEST
fnBANNER " SYSTEM DIAGRAM (***)"
if type -path pinout >/dev/null 2>&1
then
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
  # The Pi 4 uses an EEPROM to control it's boot source.  As of
  # March 2020, boot-from-USB mass storage is promised in a future
  # EEPROM update, as they focus on stabilizing boot-from-network, first.
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
    rpi-eeprom-update
    echo
  else
    echo "Missing utility rpi-eeprom-update, skipping eeprom update check" >&2
  fi
  fnBANNER " PI MODEL 4B EEPROM CONFIG"
  vcgencmd bootloader_config | grep BOOT_UART
  echo "--If 1, then UART debug info is available on GPIO14 and 15."
  echo "  Configure the receiving debug terminal at 115200bps, 8 bits,"
  echo "  no parity bits, 1 stop bit."
  echo
  echo "  Default is 0"
  echo

  vcgencmd bootloader_config | grep WAKE_ON_GPIO
  echo "--If 1. then \"sudo halt\" will run low power mode until GPIO3 or"
  echo "  GLOBAL_EN is shorted to ground."
  echo
  echo "  Default is 0 in the original bootloader (2019-05-10)"
  echo "  Default is 1 in newer bootloaders"
  echo

  vcgencmd bootloader_config | grep POWER_OFF_ON_HALT
  echo "--If 1, and WAKE_ON_GPIO=0, then switch off all PMIC outputs on"
  echo "  halt.  This is the lowest possible power state for halt, but"
  echo "  may cause problems with some HATs because 5V will still be on."
  echo "  GLOBAL_EN must be shorted to ground in order to boot."
  echo
  echo "  Default is 0"
  echo

  vcgencmd bootloader_config | grep DHCP_TIMEOUT
  echo "--The timeout in milliseconds for the entire DHCP sequence before"
  echo "  failing the current iteration."
  echo
  echo "  Default is 45000"
  echo "  Minimum is 5000"
  echo

  vcgencmd bootloader_config | grep DHCP_REQ_TIMEOUT
  echo "--Timeout in milliseconds before retrying DHCP DISCOVER or DHCP REQ."
  echo
  echo "  Default is 4000"
  echo "  Minimum is 500"
  echo

  vcgencmd bootloader_config | grep TFTP_FILE_TIMEOUT
  echo "--Timeout in milliseconds for an individual file download via TFTP."
  echo
  echo "  Default is 15000"
  echo "  Minimum is 5000"
  echo

  vcgencmd bootloader_config | grep TFTP_IP
  echo "--Optional dotted decimal ip address for the TFTP server which"
  echo "  overrides the server-ip from the DHCP request.  This may be"
  echo "  useful on home networks because tftpd-hpa can be used instead"
  echo "  of dnsmasq where broadband router is the DHCP server."
  echo
  echo "  Default \"\""
  echo

  vcgencmd bootloader_config | grep TFTP_PREFIX
  echo "--In order to support unique TFTP boot directories for each Pi"
  echo "  the bootloader prefixes the filenames with a device specific"
  echo "  directory.  If neither start4.elf nor start.elf are found in"
  echo "  the prefixed directory then the prefix is cleared.  On earlier"
  echo "  models the serial number is used as the prefix, however, on"
  echo "  the Pi 4 the MAC address is no longer generated from the serial"
  echo "  number making it difficult to automatically create tftpboot"
  echo "  directories on the server by inspecting DHCPDISCOVER packets."
  echo "  To support this the TFTP_PREFIX may be customized to either the"
  echo "  MAC address, a fixed value, or the serial number."
  echo
  echo "  0 - Default, use the serial number."
  echo "  1 - Use the string specified by TFTP_PREFIX_STR"
  echo "  2 - Use the MAC address"
  echo

  vcgencmd bootloader_config | grep BOOT_ORDER
  echo "--The BOOT_ORDER setting allows flexible configuration for the"
  echo "  priority of different boot modes.  It is represented as 32bit"
  echo "  unsigned integer  where each nibble represents a bootmode."
  echo "  The bootmodes are attempted in lowest significant nibble to"
  echo "  highest significant nibble order."
  echo
  echo "  E.g. 0x21 means try SD first followed by network boot then stop."
  echo "  whereas 0x2 would  mean try network boot and then stop without"
  echo "  trying to boot from the SD card."
  echo
  echo "  Retry counters are reset when switching to the next boot mode."
  echo
  echo "  BOOT ORDER FIELDS:"
  echo "  0x0 - NONE (stop with error pattern)"
  echo "  0x1 - SD CARD"
  echo "  0x2 - NETWORK"
  echo
  echo "  Default: 0x00000001 (with 3 SD boot retries to match the current"
  echo "  bootloader behavior."
  echo

  vcgencmd bootloader_config | grep SD_BOOT_MAX_RETRIES
  echo "--Specify the maximum number of times that the bootloader will"
  echo "  retry booting from the SD card."
  echo
  echo "  Default is 0"
  echo "  1 means infinite retries"
  echo

  vcgencmd bootloader_config | grep NET_BOOT_MAX_RETRIES
  echo "--Specify the maximum number of times that the bootloader will"
  echo "  retry network boot."
  echo
  echo "  Default is 0"
  echo "  1 means infinite retries"
  echo

  vcgencmd bootloader_config | grep FREEZE_VERSION
  echo "--If 1 then the rpi-eeprom-update will skip automatic updates"
  echo "  on this board.  The parameter is not processed by the EEPROM"
  echo "  bootloader or recovery.bin since there is no way in software"
  echo "  of fully write protecting the EEPROM.  Custom EEPROM update"
  echo "  scripts must also check for this flag."
  echo
  echo "  Default is 0"
  echo
else
  # Some older Pi models use OTP (One Time Programable) memory to control
  # whether the Pi can boot from USB mass storage.  Here, we check the
  # model, and then perform the appropriate examination.  OTP-managed
  # USB mass storage boot is available on Pi 2B v1.2, 3A+, 3B, and 3B+
  # models only.  Any other model will not run this test.  The Pi 3B+
  # comes from the factory with boot from USB mass storage enabled.
  fnBANNER " OTP BOOT-FROM-USB STATUS"
  # If a Model 2B, make sure it's a v1.2 unit
  MY_OTP=${MY_MODEL_NAME}
  if [ "${MY_MODEL_NAME}" = "Pi2B" -a "${MY_PROCESSOR}" = "BCM2837" ]
  then
    MY_OTP="Pi2Bv1.2"
  fi
  case ${MY_OTP} in
    Pi2Bv1.2|3A+|3B|3B+)
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
fnBANNER " OPERATING SYSTEM"
uname -a
echo "${PRETTY_NAME}"
echo
uptime -p
echo

#---------------
fnBANNER " CMDLINE.TXT"
cat /boot/cmdline.txt
echo

#---------------
fnBANNER " CONFIG.TXT SETTINGS"
cat /boot/config.txt | grep -v ^$ | grep -v ^#
echo

#---------------
fnBANNER " MEMORY SPLIT"
# There is a flaw in "vcgencmd get_mem arm" on Pi 4B models with more than 1GB of memory.
# On those models, the command only considers the first GB of memory.
# The technique used here instead, works universally, and is accurate on all Pi models.
ARM=$(($(dmesg < /dev/null | grep "Memory:" | grep "available" | cut -f2 -d"/" | cut -f1 -d"K") / 1024 ))
ARM=`printf "%4d" ${ARM}`
echo "ARM: ${ARM} MB"
GPU="$(vcgencmd get_mem gpu | cut -f2 -d"=" | sed 's/M$//')"
GPU=`printf "%4d" ${GPU}`
echo "GPU: ${GPU} MB"
echo

#---------------
fnBANNER " ACTIVE DISPLAY DRIVER"
# If two particular modules are not running, it's the Broadcom driver.
# If the modules are loaded, the "fake" OpenGL driver shows "firmwarekms" in dmesg.
# If the modules are loaded, the "full" OpenGL driver does not show "firmwarekms" in dmesg.
# An example of why we needed to check for ring buffer wrap earlier,
if [ "$(lsmod | awk '{ print $1 }' | grep ^vc4)" = "" -a "$(lsmod | awk '{ print $1 }' | grep ^drm)" = "" ]
then
  echo "Broadcom Display Driver"
else
  if [ "$(dmesg | grep firmwarekms)" != "" ]
  then
    echo "\"Fake\" OpenGL Display Driver"
  else
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
echo "Clocks available across all Pi models..."
for CLOCK in arm core h264 isp v3d uart pwm emmc pixel vec hdmi dpi
do
  echo -e "${CLOCK}:\t$(vcgencmd measure_clock ${CLOCK})"
done
if [ "${MY_MODEL_NAME}" = "4B" ]
then
  echo
  echo "Additional Pi 4B-specific clocks..."
  for CLOCK in altscb cam0 cam1 ckl108 clk27 clk54 debug0 debug1 dft dsi0 dsi0esc dsi1 dsi1esc emmc2 genet125 genet250 gisb gpclk0 gpclk1 hevc m2mc otp pcm plla pllb pllc plld pllh pulse smi tectl testmux tsens usb wdog xpt
  do
    echo -e "${CLOCK}:\t$(vcgencmd measure_clock ${CLOCK})"
  done
fi
echo

#---------------
fnBANNER " VOLTAGES"
echo "Voltages available across all Pi models..."
for VOLTS in core sdram_c sdram_i sdram_p
do
  echo -e "${VOLTS}:   $(vcgencmd measure_volts ${VOLTS})" | sed 's/core:/   core:/'
done
if [ "${MY_MODEL_NAME}" = "4B" ]
then
  echo
  echo "Additional Pi 4B-specific voltages..."
  for VOLTS in 2711 ain1 usb_pd uncached
  do
    echo -e "${VOLTS}:   $(vcgencmd measure_volts ${VOLTS})"
  done
fi
echo

#---------------
fnBANNER " TEMPERATURE"
echo "Temperature available across all Pi models..."
PI_TEMP=$(vcgencmd measure_temp)
C=$(echo ${PI_TEMP} | cut -f2 -d"=" | cut -f1 -d"'")
if type -path dc >/dev/null 2>&1
then
  # SUPPLEMENTAL CONVERSION to Farenheit
  F=$(echo "2 k 9 5 / ${C} * 32 + p" | dc)
  echo "Core Temp: ${C}°C (${F}°F) (***)"
else
  # Otherwise, show Centigrade/Celcius only
  echo "Core Temp: ${C}°C"
fi
echo
if [ "${MY_MODEL_NAME}" = "4B" ]
then
  echo
  echo "Additional Pi 4B-specific PMIC temperature..."
  PMIC_TEMP=$(vcgencmd measure_temp pmic)
  C=$(echo ${PMIC_TEMP} | cut -f2 -d"=" | cut -f1 -d"'")
  if type -path dc >/dev/null 2>&1
  then
    # SUPPLEMENTAL CONVERSION to Farenheit
    F=$(echo "2 k 9 5 / ${C} * 32 + p" | dc)
    echo "PMIC Temp: ${C}°C (${F}°F) (***)"
  else
    # Otherwise, show Centigrade/Celcius only
    echo "PMIC Temp: ${C}°C"
  fi
  echo
fi

#---------------
fnBANNER " SCALING GOVERNOR"
GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
FORCE=$(grep "^force_turbo=" /boot/config.txt | cut -f2 -d"=")
echo "${GOV}"
if [ "${GOV}" = "ondemand" -a "${FORCE}" = "1" ]
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
fnBANNER " HARDWARE-ACCELERATED CODECS"
# FOR THE PI 4B...
# On the Raspberry Pi 4B, hardware decoding for MPG2 and WVC1
# is disabled and cannot be enabled even with a license key.
# The Pi 4B, with it's increased processing power compared to
# earlier models, can decode these in software such as VLC.
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
    # If a 4B, just show each codec's status, without concern for license.
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
echo
echo "Note: The H.265 codec, new w/ the Pi 4B, isn't part of the videocore."
echo "It's an entirely new block on the chip, so the VC6 knows nothing"
echo "about it.  Therefore, vcgencmd (which talks to the VC6) also knows"
echo "nothing about it.  The v4l2-ctl command used here, however, should"
echo "show the H.265 codec as enabled, on the Pi 4B."
echo

#---------------
# The Pi itself, will have /dev/video10 (decode), /dev/video11 (encode),
# and /dev/video12 (resize & format conversion) V4L devices.  What we
# want to look at here is any other V4L device found on the system, such
# as TV tuners.
for NUM in $(ls -1 /dev/video* 2>/dev/null | sed 's/\/dev\/video//' | grep -v 1[012]$)
do
  fnBANNER " ADDITIONAL VIDEO4LINUX DEVICE ${NUM}"
  v4l2-ctl -d ${NUM} --all
  echo
done

#---------------
fnBANNER " CAMERA"
# Refers to the small cameras that plug into the Pi's CSI connector
vcgencmd get_camera
echo

#---------------
fnBANNER " I2CDETECT"
i2cdetect -l 2>&1 | sort
echo
i2cdetect -l 2>&1 | sort | awk '{ print $1 }' | cut -f2 -d"-" | while read BUS
do
  echo " I2C BUS: ${BUS}"
  i2cdetect -y ${BUS} 2>&1
  echo
done

#---------------
# If the user has a realtime clock installed and configured...
if [ -c /dev/rtc0 -o -L /dev/rtc ]
then
  fnBANNER " RTC (REALTIME CLOCK)"
  dmesg | grep rtc | grep -v "Modules linked in:"
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
# If the watchdog timer is enabled...
if [ "$(systemctl | grep watchdog.service)" != "" ]
then
  fnBANNER " BROADCOM WATCHDOG TIMER"
  dmesg | grep watchdog
  echo
  cat /etc/watchdog.conf | grep -v ^$ | grep -v ^#
  echo
  DIR="$(grep "^test-directory" /etc/watchdog.conf | awk '{ print $3 }')"
  if [ "${DIR}" != "" ]
  then
    echo "Contents of ${DIR}:"
    ls -l ${DIR}
    echo
  fi
  DIR="$(grep "^log-dir" /etc/watchdog.conf | awk '{ print $3 }')"
  if [ "${DIR}" != "" ]
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
if [ "${LSHW_INPUT}" != "" ]
then
  fnBANNER " INPUT DEVICES"
  ${SUDO} lshw -class input 2>/dev/null
  echo
fi

#---------------
if [ "${LSHW_GENERIC}" != "" ]
then
  fnBANNER " GENERIC DEVICES"
  ${SUDO} lshw -class generic 2>/dev/null
  echo
fi

#---------------
# Note: A bug in the Pi 4B's USB (xhci host controllers that don't update endpoint DCS)
# may affect test results.  The following commands will update the firmware to
# correct the issue:
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
if [ "${LSHW_STORAGE}" != "" ]
then
  fnBANNER " STORAGE DEVICES"
  ${SUDO} lshw -class storage 2>/dev/null
  echo
  ${SUDO} lshw -short -class disk -class storage -class volume 2>/dev/null
  echo
fi

#---------------
fnBANNER " DISK CONFIGURATION"
lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,LABEL,UUID,PARTUUID,MODEL | grep -v zram
echo
df -h -T | grep -v tmpfs
echo

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
if [ "${LSHW_MULTIMEDIA}" != "" ]
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
  if [ "${LSHW_COMMUNICATION}" != "" ]
  then
    fnBANNER " ACM COMMUNICATION DEVICES"
    ${SUDO} lshw -class communication 2>/dev/null
    echo
  fi
fi

#---------------
fnBANNER " UARTS AND USB SERIAL PORTS"
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
      echo "Non-default BT Controller..."
    fi
    BTSHOW_OUT="$(echo show ${BTMAC} | ${SUDO} bluetoothctl 2>/dev/null)"
    echo "${BTSHOW_OUT}" | grep -v "\[" | grep -v ^$ | grep -v "Agent registered" | grep -v "Device registered not available"
    echo
  done
  #---------------
  fnBANNER " BLUETOOTH DEVICES (paired w/ default controller)"
  BTPAIRED_OUT="$(echo paired-devices | ${SUDO} bluetoothctl 2>/dev/null)"
  echo "${BTPAIRED_OUT}" | grep -v "\[" | awk '{ print $2 }' | while read BTMAC
  do
    echo "info ${BTMAC}" | ${SUDO} bluetoothctl 2>/dev/null | grep -v "\[" | grep -v ^$ | grep -v "Agent registered" | grep -v "Device registered not available"
  done
  echo
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
fnBANNER " SYSTEMD-ANALYZE CRITICAL-CHAIN"
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
if [ -d /var/log/journal ]
then
  fnBANNER " PERSISTENT JOURNALING"
  echo "Peristent Journaling is configured..."
  ls -ld /var/log/journal
  echo
fi

#---------------
fnBANNER " SYSTEMCTL LIST-UNIT-FILES"
# the tee eliminates the pause every screenfull
systemctl list-unit-files | tee /dev/null
echo

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
fnBANNER " HDMI DISPLAY DATA"
tvservice -l 2>&1
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
  fi
  echo "DISPLAY NUMBER : ${DISP_NUM}"
  echo "DISPLAY STATUS : ${TVSTATUS}"

  DEV_ID="$(tvservice -n -v ${DISP_NUM} 2>/dev/null)"
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

  TVGROUP="$(echo "${TVSTATUS}" | awk '{ print $4 }')"
  tvservice --modes=${TVGROUP} -v ${DISP_NUM} 2>&1
  echo
done

#---------------
fnBANNER " CURRENT SCREEN RESOLUTION"
echo "HORIZONTAL : $(vcgencmd get_lcd_info | awk '{ print $1 }') pixels"
echo "VERTICAL   : $(vcgencmd get_lcd_info | awk '{ print $2 }') pixels"
echo "COLOR DEPTH: $(vcgencmd get_lcd_info | awk '{ print $3 }') bits"
echo

#---------------
# The command will error if not a sufficient version, so we'll run it here
# silently, and check the return code before trying to run it visibly.
if type -path gpio >/dev/null 2>&1
then
  if gpio readall >/dev/null 2>&1
  then
    fnBANNER " GPIO PIN STATUS (***)"
    gpio readall
    echo
  fi
else
  echo "utility gpio (part of wiringpi) is missing or wrong version, skipping gpio display" >&2
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
