#!/bin/bash

VERSION="1.3.4"
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
#   lshw, usbutils, util-linux, wireless-tools, wiringpi
#
# The script will explicitly test that each of those packages is installed.
# If any are missing, it will inform the user, and instruct them to install.
#
# NOTE:
# If you have a raspberry pi 4, install at least version 2.52 of wiringpi
# See - http://wiringpi.com/wiringpi-updated-to-2-52-for-the-raspberry-pi-4b/
#
# The following supplemental packages may also be utilized:
#   cups-client, dc, nmap, rpcbind, nfs-kernel-server, samba, sysstat,
#   watchdog, and python3-gpiozero
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
#   USB-attached 4TB hard drive,
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
  REQUIRED=$(dpkg -l 2>/dev/null | awk '{ print $2 }' | grep -i "^alsa-utils$\|^bluez$\|^coreutils$\|^i2c-tools$\|^iproute2$\|^libraspberrypi-bin$\|^lshw$\|^util-linux$\|^usbutils$\|^v4l-utils$\|^wireless-tools$\|^wiringpi$")
  REQ_HIT=0
  REQ_MAX=0
  for PACKAGE in alsa-utils bluez coreutils i2c-tools iproute2 libraspberrypi-bin lshw usbutils util-linux v4l-utils wireless-tools wiringpi
  do
    # If the package is installed...
    echo "${REQUIRED}" | grep "${PACKAGE}" > /dev/null
    if [ ${?} -eq 0 ]
    then
      echo "  found: ${PACKAGE}"
      let REQ_HIT++
    else
      # Make an allowance here, if wiringpi is built from a source tarball...
      # A lot of people developing with WiringPi elect to build the latest
      # libraries and tools from source, rather than go with the package
      # from the repositories.  An allowance is made for this, as long as
      # we find the compiled "gpio" tool present in the user's path.
      # If you have a raspberry pi 4, install at least version 2.52 of wiringpi
      # See - http://wiringpi.com/wiringpi-updated-to-2-52-for-the-raspberry-pi-4b/
      if [ "${PACKAGE}" = "wiringpi" ] && type -path gpio >/dev/null 2>&1
      then
        # WiringPi not from repository, but is present, perhaps built from source
        echo "  found: ${PACKAGE}"
        let REQ_HIT++
        continue
        echo
      fi
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
    SUPPLEMENTAL=$(dpkg -l 2>/dev/null | awk '{ print $2 }' | grep -i "^cups-client$\|^dc$\|^nfs-kernel-server$\|^nmap$\|^python3-gpiozero$\|^rpcbind$\|^rtl-sdr$\|^samba$\|^sysstat$\|^watchdog$")
    SUP_HIT=0
    SUP_MAX=0

    # For supplemental PRINTER STATUS
    # If the package is installed...
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^cups-client$")" ]
    then
      # ...and the command we need is available...
      if type -path lpstat >/dev/null 2>&1
      then
        # ...then we're good with this package
        echo "  found: cups-client"
        let SUP_HIT++
      fi
    fi
    let SUP_MAX++

    # For supplemental Centigrade-to-Farenheit conversion in TEMPERATURE
    # If the package is installed...
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^dc$")" ]
    then
      # ...and the command we need is available...
      if type -path dc >/dev/null 2>&1
      then
        # ...then we're good with this package
        echo "  found: dc"
        let SUP_HIT++
      fi
    fi
    let SUP_MAX++

    # For supplemental EXPORTED NFS DIRS
    # If the package is installed...
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^nfs-kernel-server$")" ]
    then
      # ...and the service is actually running...
      PS_NFS=$(ps -ef | grep [n]fsd)
      if [ -n "${PS_NFS}" ]
      then
        # ...then we're good with this package
        echo "  found: nfs-kernel-server"
        let SUP_HIT++
      fi
    fi
    let SUP_MAX++

    # For supplemental SCANNING FOR SERVICES
    # If the package is installed...
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^nmap$")" ]
    then
      # ...and the command we need is available...
      if type -path nmap >/dev/null 2>&1
      then
        # ...then we're good with this package
        echo "  found: nmap"
        let SUP_HIT++
      fi
    fi
    let SUP_MAX++

    # For supplemental SYSTEM DIAGRAM
    # If the package is installed...
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^python3-gpiozero$")" ]
    then
      # ...and the command we need is available...
      if type -path pinout >/dev/null 2>&1
      then
        # ...then we're good with this package
        echo "  found: python3-gpiozero"
        let SUP_HIT++
      fi
    fi
    let SUP_MAX++

    # For supplemental PORTMAPPER - RPCINFO
    # If the package is installed...
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^rpcbind$")" ]
    then
      # ...and the service is actually running...
      PS_RPC=$(ps -ef | grep [r]pcbind)
      if [ -n "${PS_RPC}" ]
      then
        # ...then we're good with this package
        echo "  found: rpcbind"
        let SUP_HIT++
      fi
    fi
    let SUP_MAX++

    # For supplemental RTL-SDR TUNER
    # If the package is installed...
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^rtl-sdr$")" ]
    then
      # ...and the commands we need are available...
      if type -path rtl_eeprom >/dev/null 2>&1 && type -path rtl_test >/dev/null 2>&1
      then
        # ...then we're good with this package
        echo "  found: rtl-sdr"
        let SUP_HIT++
      fi
    fi
    let SUP_MAX++

    # For supplemental SMBSTATUS
    # If the package is installed...
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^samba$")" ]
    then
      # ...and the service is actually running...
      PS_SMB=$(ps -ef | grep [s]mbd)
      if [ -n "${PS_SMB}" ]
      then
        # ...then we're good with this package
        echo "  found: samba"
        let SUP_HIT++
      fi
    fi
    let SUP_MAX++

    # For supplemental SYSSTAT
    # If the package is installed...
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^sysstat$")" ]
    then
      # ...and the commands we need are available...
      if type -path mpstat >/dev/null 2>&1 && type -path iostat >/dev/null 2>&1
      then
        # ...then we're good with this package
        echo "  found: sysstat"
        let SUP_HIT++
      fi
    fi
    let SUP_MAX++

    # For supplemental WATCHDOG
    # If the package is installed...
    if [ -n "$(echo "${SUPPLEMENTAL}" | grep -i "^watchdog$")" ]
    then
      # ...and the service is actually running...
      PS_WD=$(ps -ef | grep [w]atchdog)
      if [ -n "${PS_WD}" ]
      then
        # ...then we're good with this package
        echo "  found: watchdog"
        let SUP_HIT++
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
fnBANNER " DECODED SYSTEM REVISION NUMBER"
## The following revision-decoding logic was shamelessly borrowed from:
## https://raspberrypi.stackexchange.com/questions/100076/what-revisions-does-cat-proc-cpuinfo-return-on-the-new-pi-4-1-2-4gb
## I've made only some coding style changes to match the rest of this script.
REVISION=$(cat /proc/cpuinfo | grep "Revision" | awk '{print $3}')
echo "Revision      : "${REVISION}
ENCODED=$((0x${REVISION} >> 23 & 1))
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

  # Save these for later, should we need to make decisions based on model or onboard ram
  MY_MODEL=${MODEL_NAME[$((0x${REVISION}>>4&0xff))]}
  MY_RAM=${MEMORY_SIZE[$((0x${REVISION}>>20&7))]}
  # This next one will help later on, to identify a Pi 2 v1.2 versus an earlier Pi 2
  MY_PROCESSOR=${PROCESSOR[$((0x${REVISION}>>12&0xf))]}

  echo "PCB Revision  : "${PCB_REVISION[$((0x${REVISION}&0xf))]}
  echo "Model Name    : "${MODEL_NAME[$((0x${REVISION}>>4&0xff))]}
  echo "Processor     : "${PROCESSOR[$((0x${REVISION}>>12&0xf))]}
  echo "Manufacturer  : "${MANUFACTURER[$((0x${REVISION}>>16&0xf))]}
  echo "Memory Size   : "${MEMORY_SIZE[$((0x${REVISION}>>20&7))]}
  echo "Encoded Flag  : "${ENCODED_FLAG[$((0x${REVISION}>>23&1))]}
  if [ -n "${WARRANTY_VOID_OLD[$((0x${REVISION}>>24&1))]}" -o -n "${WARRANTY_VOID_NEW[$((0x${REVISION}>>25&1))]}" ]
  then
    WARRANTY_VOID="'warranty void' bit is set"
  else
    WARRANTY_VOID="no"
  fi
  echo "Warranty Void : ${WARRANTY_VOID}"
fi
echo

#---------------
# Boot-from-USB mass storage will be handled differently on the Pi 4B,
# versus older models.
if [ "${MY_MODEL}" = "4B" ]
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
    rpi-eeprom-update
    echo
  else
    echo "Missing utility rpi-eeprom-update, skipping eeprom update check" >&2
  fi
  fnBANNER " PI MODEL 4B EEPROM CONFIG"
  vcgencmd bootloader_config
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
  MY_OTP=${MY_MODEL}
  if [ "${MY_MODEL}" = "Pi2B" -a "${MY_PROCESSOR}" = "BCM2837" ]
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
for CLOCK in arm core h264 isp v3d uart pwm emmc pixel vec hdmi dpi
do
  echo -e "${CLOCK}:\t$(vcgencmd measure_clock ${CLOCK})"
done
echo

#---------------
fnBANNER " VOLTAGES"
for VOLTS in core sdram_c sdram_i sdram_p
do
  echo -e "${VOLTS}:   $(vcgencmd measure_volts ${VOLTS})" | sed 's/core:/   core:/'
done
echo

#---------------
fnBANNER " TEMPERATURE"
PI_TEMP=$(vcgencmd measure_temp)
C=$(echo ${PI_TEMP} | cut -f2 -d"=" | cut -f1 -d"'")
if type -path dc >/dev/null 2>&1
then
  # SUPPLEMENTAL CONVERSION to Farenheit
  F=$(echo "2 k 9 5 / ${C} * 32 + p" | dc)
  echo "Temp: ${C}°C (${F}°F) (***)"
else
  # Otherwise, show Centigrade/Celcius only
  echo "Temp: ${C}°C"
fi
echo

#---------------
fnBANNER " SCALING GOVERNOR"
GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
if type -path cat >/dev/null 2>&1
then
  FORCE=$(grep "^force_turbo=" /boot/config.txt | cut -f2 -d"=")
  echo "${GOV}"
  if [ "${GOV}" = "ondemand" -a "${FORCE}" = "1" ]
  then
    echo "(...but overridden by \"force_turbo=1\" found in config.txt)"
  fi
  echo
else
  echo "Missing utility grep, skipping override of scaling governor check" >&2
fi

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
fnBANNER " GPU HARDWARE-ACCELERATED CODECS"
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
    if [ "${MY_MODEL}" != "4B" ]
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
echo "Note: GPU hardware-accelerated codecs will be disabled if \"gpu_mem=16\"."
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
  systemctl status watchdog.service
  echo
fi

#---------------
fnBANNER " USB AND OTHER DEVICE INFO"
lsusb | sort
echo
${SUDO} lshw -businfo 2>/dev/null >/tmp/.lshw_businfo.${PPID}
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
  ${SUDO} lshw -class input
  echo
fi

#---------------
if [ "${LSHW_GENERIC}" != "" ]
then
  fnBANNER " GENERIC DEVICES"
  ${SUDO} lshw -class generic
  echo
fi

#---------------
# Note: A bug in the Pi 4B's USB (xhci host controllers that don't update endpoint DCS)
# may affect test results.  Firmware update has likely fixed this.
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
  ${SUDO} lshw -class storage
  echo
  ${SUDO} lshw -short -class disk -class storage -class volume
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
  ${SUDO} lshw -class multimedia
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
aplay -l 2>/dev/null
echo
arecord -l 2>/dev/null
echo

#---------------
if [ -c /dev/ttyACM? ]
then
  if [ "${LSHW_COMMUNICATION}" != "" ]
  then
    fnBANNER " ACM COMMUNICATION DEVICES"
    ${SUDO} lshw -class communication
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
systemd-analyze blame
echo

#---------------
fnBANNER " SYSTEMCTL STATUS"
systemctl status
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
systemctl list-unit-files
echo

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
echo "CURRENT SCREEN RESOLUTION"
echo "HORIZONTAL : $(vcgencmd get_lcd_info | awk '{ print $1 }') pixels"
echo "VERTICAL   : $(vcgencmd get_lcd_info | awk '{ print $2 }') pixels"
echo "COLOR DEPTH: $(vcgencmd get_lcd_info | awk '{ print $3 }') bits"
echo

#---------------
# If you have a raspberry pi 4, install at least version 2.52 of wiringpi
# See - http://wiringpi.com/wiringpi-updated-to-2-52-for-the-raspberry-pi-4b/
fnBANNER " GPIO PIN STATUS"
gpio readall
echo

#---------------
# SUPPLEMENTAL TEST
if type -path mpstat >/dev/null 2>&1
then
  fnBANNER " MPSTAT (***)"
  # 3 samples, 3 seconds apart
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
${SUDO} lshw -class network
echo

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
dpkg -l 2>/dev/null
echo

#---------------
# This next module will likely never see the light of day.  It generates
# information about each installed package listed by the above section.
# Uncommented, it can take many hours to run, would take forever reading
# from an SD card, and would result in many MB of information - far more
# than any admin is likely to ever be interested in.  If you want this
# information, uncomment as you will.  You've been warned.  But you're
# better off running "apt show" against only one or two packages of
# interest only, should the need ever arise.
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
