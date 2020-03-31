#!/bin/bash

VERSION="1.2.8"

# system_info.sh
# Written by:     Ken Cormack, unixken@yahoo.com
# Contributions:  William Stearns, william.l.stearns@gmail.com
# First released: March, 2020
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
#   lshw, usbutils, util-linux, alsa-utils, bluez, wireless-tools, bc, dc,
#   and wiringpi
#
# NOTE:
# If you have a raspberry pi 4, install at least version 2.52 of wiringpi
# See - http://wiringpi.com/wiringpi-updated-to-2-52-for-the-raspberry-pi-4b/
#
# The script will explicitly test that each of those packages is installed.
# If any are missing, the script will inform the user, and instruct to install.
#
# BONUS...
# If the script also finds the "cups" and "nmap" packages installed, it will
# report on any configured printers via lpstat, and perform port scans of any
# configured network interfaces via nmap, to show any service daemons that may
# be listening on them.  These two packages are not requirements for the
# script.  Not everyone prints on a Pi, so no sense forcing someone to install
# "cups" just so that the script can tell them that no printers are configured.
# Likewise, with nmap - not everyone needs it.  But if these tools are present,
# we'll report what we can see with them.
#
# This script was tested on the following hardware:
#   hostname: pi-media (Ken's)
#   Pi 3B+ w/ Raspbian Stretch
#   X150 9-port USB hub
#   DVK512 board w/ RTC
#   DockerPi Powerboard
#   fit_StatUSB USB LED
#   USB-attached 128GB SATA III SSD drive
#   USB-attached 4TB hard drive
#   HDMI Sony Flatscreen TV
#
#   hostname: pi-dev (Ken's)
#   Pi 3B w/ Raspbian Buster
#   X150 9-port USB hub
#   DVK512 board w/ RTC
#   DockerPi Powerboard
#   fit_StatUSB USB LED
#   USB Bluetooth dongle (onboard BT disabled)
#   Hauppauge WinTV HVR950Q USB TV Tuner
#   RTL-SDR USB Software Defined Radio
#   X820 SATA III Board w/ 1TB SSD
#   Headless - SSH and VNC only (No Display)
#
#   hostname: pi-devel-2GB (William's)
#   Pi 4B w/ Raspbian Buster (2GB memory)
#   PiOled i2c display
#   USB flash drive
#   USB Ethernet adapter

##################################################
# A COUPLE HANDY FUNCTIONS WE'LL BE USING...
##################################################

fnBANNER() {
  echo "==============================================================================="
  echo "${@}"
  echo
}

fnREQUIRE() {
  # Returns true if all binaries listed as parameters exist somewhere in the path, False if one or more missing.
  while [ -n "${1}" ]
  do
    if ! type -path "${1}" >/dev/null 2>&1
    then
      echo Missing utility "${1}". Please install it. >&2
      return 1	# False, app is not available.
    fi
    shift
  done
  return 0	# True, app is there.
}

##################################################
# MAKE SURE WE HAVE EVERYTHING WE NEED...
##################################################

#---------------
PATH=${PATH}:/sbin:/usr/sbin
# Check to make sure all needed utilities are installed - warn if any missing
fnREQUIRE amixer aplay apt arecord awk bc bluetoothctl cat cut date dc df dmesg dpkg free gpio grep hwclock i2cdetect ifconfig ip iwconfig iwlist ls lsblk lscpu lshw lsipc lsmod lsusb modinfo route ps sed sort strings stty swapon systemctl systemd-analyze tvservice uname uptime vcgencmd || echo "Missing utility, please install" >&2

#---------------
fnBANNER " RASPBERRY PI SYSTEM INFORMATION TOOL - v${VERSION}"
echo "Written By Ken Cormack, unixken@yahoo.com"
echo "With contributions from William Stearns, william.l.stearns@gmail.com"
echo "Initial release - March, 2020"
echo
echo "Now on github - https://github.com/kencormack/system_info"
echo
echo "Report Date and Time:"
date
echo

#---------------
# Written for Stretch and above.  Jessie and older are not supported.
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
  fi
else
  fnBANNER " LINUX VERSION UNKNOWN"
  echo "This script is designed for Raspbian GNU/Linux 9 (stretch), and above."
  echo "Unable to identify your version of the operating system... Exiting."
  echo
  exit 1
fi

#---------------
# If we're not already root, set "${SUDO}" so that commands that need root privs will run under sudo
SUDO=$(type -path sudo)
if [ "${EUID}" -ne 0 ] && [ "${SUDO}" = "" ]
then
  echo
  echo "${0} has not been run as root and sudo is not available, exiting." >&2
  exit 1
fi

#---------------
# Test for needed packages and alert the user to install them if missing.
echo "Checking software dependencies..."
PKG_MISSING=0
if type -path dpkg >/dev/null 2>&1
then
  INSTALLED=$(dpkg -l 2>/dev/null | awk '{ print $2 }' | grep -i "^lshw$\|^usbutils$\|^util-linux$\|^alsa-utils$\|^bluez$\|^wireless-tools$\|^bc$\|^dc$\|^i2c-tools$\|^libraspberrypi-bin$\|^wiringpi$")
  for REQUIRED in alsa-utils bc bluez dc i2c-tools libraspberrypi-bin lshw usbutils util-linux wireless-tools wiringpi
  do
    echo "${INSTALLED}" | grep "${REQUIRED}" > /dev/null
    if [ ${?} -ne 0 ]
    then
      # A lot of people developing with WiringPi elect to build the latest
      # libraries and tools from source, rather than go with the package
      # from the repositories.  An allowance is made for this, as long as
      # we find the compiled "gpio" tool present in the user's path.
      # If you have a raspberry pi 4, install at least version 2.52 of wiringpi
      # See - http://wiringpi.com/wiringpi-updated-to-2-52-for-the-raspberry-pi-4b/
      if [ "${REQUIRED}" = "wiringpi" ] && type -path gpio >/dev/null 2>&1
      then
        echo "WiringPi not from repository, but is present, perhaps built from source... OK"
        continue
        echo
      fi
      fnBANNER "Required package \"${REQUIRED}\" is not installed."
      echo "Install with:"
      echo "  sudo apt install -y ${REQUIRED}"
      PKG_MISSING=1
      echo
    fi
  done
  if [ ${PKG_MISSING} -ne 0 ]
  then
    fnBANNER "Once any missing packages are installed, re-run this script."
    echo
    exit
  else
    echo "All required tools are installed."
    if type -path lpstat >/dev/null 2>&1
    then
      echo "  (Also found optional lpstat .. we can make use of that, too.)"
    fi
    if type -path nmap >/dev/null 2>&1
    then
      echo "  (Also found optional nmap .... we can make use of that, too.)"
    fi
    echo
  fi
else
  echo "Missing utility dpkg, unable to verify package dependencies" >&2
  exit 1
fi

##################################################
# ALL SET - START ACTUALLY GATHERING CONFIG DETAILS...
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
if type -path vcgencmd >/dev/null 2>&1
then
  vcgencmd version
  echo
else
  echo "Missing utility vcgencmd, skipping system version" >&2
fi

#---------------
if type -path lscpu >/dev/null 2>&1
then
  fnBANNER " CPU INFORMATION"
  lscpu
  echo
else
  echo "Missing utility lscpu, skipping cpu information" >&2
fi

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
if type -path vcgencmd >/dev/null 2>&1
then
  BOOT_TO_USB=$(vcgencmd otp_dump | grep "17:")
  if [ "${BOOT_TO_USB}" = "17:3020000a" ]
  then
    fnBANNER " OTP BOOT-FROM-USB STATUS"
    echo "Boot From USB: enabled"
    echo
  else
    echo "Boot From USB: not enabled"
    echo
  fi
else
  echo "Missing utility vcgencmd, skipping otp boot-from-usb check" >&2
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
if type -path vcgencmd >/dev/null 2>&1 && type -path dmesg >/dev/null 2>&1
then
  # There is a flaw in "vcgencmd get_mem arm" on Pi 4B models with more than 1GB of memory.
  # On those models, the command only considers the first GB of memory.
  # The technique used here instead, works universally, and is accurate on all Pi models.
  ARM=$(($(dmesg < /dev/null | grep "Memory:" | grep "available" | cut -f2 -d"/" | cut -f1 -d"K") / 1024 ))
  echo "ARM: ${ARM} MB"
  echo -n "GPU: "
  vcgencmd get_mem gpu | cut -f2 -d"=" | sed 's/M$/ MB/'
else
  echo "Missing utility vcgencmd, skipping memory split probing" >&2
fi
echo

#---------------
fnBANNER " ACTIVE DISPLAY DRIVER"
if type -path lsmod >/dev/null 2>&1 && type -path dmesg >/dev/null 2>&1 && type -path awk >/dev/null 2>&1 && type -path grep >/dev/null 2>&1
then
  if [ "$(lsmod | awk '{ print $1 }' | grep ^vc4)" = "" -a "$(lsmod | awk '{ print $1 }' | grep ^drm)" = "" ]
  then
    echo "Standard Broadcom Display Driver"
  else
    if [ "$(dmesg | grep firmwarekms)" != "" ]
    then
      echo "\"Fake\" OpenGL Display Driver"
    else
      echo "\"Full\" OpenGL Display Driver"
    fi
  fi
else
  echo "Missing one of lsmod, dmesg, awk, or grep.  Skipping display driver check" >&2
fi
echo

#---------------
if type -path vcgencmd >/dev/null 2>&1 && type -path bc >/dev/null 2>&1
then
  fnBANNER " PROCESSOR SPEEDS"
  FREQ=$(vcgencmd measure_clock arm | cut -f2 -d"=")
  MHZ=$(echo "${FREQ} / 1000000" | bc)
  echo " CPU: ${MHZ} MHz"
  FREQ=$(vcgencmd measure_clock core | cut -f2 -d"=")
  MHZ=$(echo "${FREQ} / 1000000" | bc)
  echo "CORE: ${MHZ} MHz"
  echo
else
  echo "Missing utility vcgencmd, skipping processor speed check" >&2
fi

#---------------
if type -path vcgencmd >/dev/null 2>&1
then
  fnBANNER " CLOCK FREQUENCIES"
  for CLOCK in arm core h264 isp v3d uart pwm emmc pixel vec hdmi dpi
  do
    echo -e "${CLOCK}:\t$(vcgencmd measure_clock ${CLOCK})"
  done
  echo
else
  echo "Missing utility vcgencmd, skipping clock frequency check" >&2
fi

#---------------
if type -path vcgencmd >/dev/null 2>&1
then
  fnBANNER " VOLTAGES"
  for VOLTS in core sdram_c sdram_i sdram_p
  do
    echo -e "${VOLTS}:   $(vcgencmd measure_volts ${VOLTS})" | sed 's/core:/   core:/'
  done
  echo
else
  echo "Missing utility vcgencmd, skipping voltage check" >&2
fi

#---------------
if type -path vcgencmd >/dev/null 2>&1
then
  fnBANNER " TEMPERATURE"
  PI_TEMP=$(vcgencmd measure_temp)
  C=$(echo ${PI_TEMP} | cut -f2 -d"=" | cut -f1 -d"'")
  if type -path dc >/dev/null 2>&1
  then
    F=$(echo "2 k 9 5 / ${C} * 32 + p" | dc)
    echo "Temp: ${C}°C (${F}°F)"
  else
    echo "Temp: ${C}°C"
  fi
  echo
else
  echo "Missing utility vcgencmd, skipping temperature check" >&2
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
if type -path vcgencmd >/dev/null 2>&1
then
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
else
  echo "Missing utility vcgencmd, skipping processor throttle status" >&2
fi

#---------------
if type -path vcgencmd >/dev/null 2>&1
then
  fnBANNER " CODECS"
  for CODEC in MPG2 WVC1
  do
    LIC_CHECK=$(vcgencmd codec_enabled ${CODEC} | cut -f2 -d"=")
    if [ "${LIC_CHECK}" = "enabled" ]
    then
      LIC_STATUS="(licensed)"
    else
      LIC_STATUS="(seperate license required)"
    fi
    echo -e "$(vcgencmd codec_enabled ${CODEC})\t${LIC_STATUS}"
  done
  for CODEC in AFIF AGIF FLAC H263 H264 MJPA MJPB MJPG MPG4 MVC0 MVCG PCM THRA VORB VP6 VP8 WMV9
  do
    echo -e "$(vcgencmd codec_enabled ${CODEC})"
  done
  echo
else
  echo "Missing utility vcgencmd, skipping codec check" >&2
fi

#---------------
if type -path vcgencmd >/dev/null 2>&1
then
  fnBANNER " CAMERA"
  vcgencmd get_camera
  echo
else
  echo "Missing utility vcgencmd, skipping camera check" >&2
fi

#---------------
if type -path i2cdetect >/dev/null 2>&1
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
else
  echo "Missing utility i2cdetect, skipping i2c probing" >&2
fi

#---------------
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
fnBANNER " USB AND OTHER DEVICE INFO"
if type -path lsusb >/dev/null 2>&1
then
  lsusb | sort
  echo
else
  echo "Missing utility lsusb, skipping usb probing" >&2
fi
if type -path lshw >/dev/null 2>&1
then
  ${SUDO} lshw -businfo 2>/dev/null >/tmp/.lshw_businfo.${PPID}
  cat /tmp/.lshw_businfo.${PPID}
  echo
  # The tmpfile negates need to run the above slow command multiple times.
  # we'll grab the next few variables now, for use in later routines.
  LSHW_STORAGE=$(grep "storage" /tmp/.lshw_businfo.${PPID})
  LSHW_MULTIMEDIA=$(grep "multimedia" /tmp/.lshw_businfo.${PPID})
  LSHW_COMMUNICATION=$(grep "communication" /tmp/.lshw_businfo.${PPID})
  # Now get rid of the tmpfile.
  rm /tmp/.lshw_businfo.${PPID}
else
  echo "Missing utility lshw, skipping hardware listing" >&2
fi

#---------------
if type -path lshw >/dev/null 2>&1
then
  if [ "${LSHW_STORAGE}" != "" ]
  then
    fnBANNER " STORAGE DEVICES"
    ${SUDO} lshw -class storage
    echo
    ${SUDO} lshw -short -class disk -class storage -class volume
    echo
  fi
else
  echo "Missing utility lshw, skipping storage hardware listing" >&2
fi

#---------------
if type -path lsblk >/dev/null 2>&1
then
  fnBANNER " DISK CONFIGURATION"
  lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,LABEL,UUID,PARTUUID,MODEL | grep -v zram
  echo
else
  echo "Missing utility lsblk, skipping drive and partition listing" >&2
fi
df -h -T | grep -v tmpfs
echo

#---------------
if [ -f /etc/fstab ]
then
  fnBANNER " FSTAB FILE"
  cat /etc/fstab | grep -v ^$ | grep -v ^#
  echo
else
  echo "Missing file /etc/fstab" >&2
fi

#---------------
if type -path lshw >/dev/null 2>&1
then
  if [ "${LSHW_MULTIMEDIA}" != "" ]
  then
    fnBANNER " MULTIMEDIA DEVICES"
    ${SUDO} lshw -class multimedia
    echo
  fi
else
  echo "Missing utility lshw, skipping multimedia hardware listing" >&2
fi

#---------------
fnBANNER " ALSA MODULES"
cat /proc/asound/modules 2>/dev/null
echo

#---------------
fnBANNER " ALSA SOUND HARDWARE"
cat /proc/asound/cards
echo

#---------------
if type -path amixer >/dev/null 2>&1
then
  cat /proc/asound/cards | grep "^ [0123]" | awk '{ print $1 }' | while read CARD_NUM
  do
    fnBANNER " ALSA CARD-${CARD_NUM} INFO"
    amixer -c ${CARD_NUM} 2>/dev/null
    echo
  done
else
  echo "Missing utility amixer, skipping alsa card probing" >&2
fi

#---------------
if type -path aplay >/dev/null 2>&1 && type -path arecord >/dev/null 2>&1
then
  fnBANNER " ALSA PLAYBACK AND CAPTURE DEVICES"
  aplay -l 2>/dev/null
  echo
  arecord -l 2>/dev/null
  echo
else
  echo "Missing utility aplay or arecord, skipping listing audio input/output devices" >&2
fi

#---------------
if [ -c /dev/ttyACM? ]
then
  if type -path lshw >/dev/null 2>&1
  then
    if [ "${LSHW_COMMUNICATION}" != "" ]
    then
      fnBANNER " ACM COMMUNICATION DEVICES"
      ${SUDO} lshw -class communication
      echo
    fi
  else
    echo "Missing utility lshw, skipping ACM communication hardware listing" >&2
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
if type -path bluetoothctl >/dev/null 2>&1
then
  # Making sure bluetoothd is running because if not,
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
else
  fnBANNER "Missing utility bluetoothctl, skipping bluetooth probing"
  echo
fi

#---------------
fnBANNER " MEMORY AND SWAP"
if type -path free >/dev/null 2>&1
then
  free -h
  echo
else
  echo "Missing utility free, skipping free memory display" >&2
fi
if type -path swapon >/dev/null 2>&1
then
  swapon --summary
  echo
else
  echo "Missing utility swapon, skipping free swap display" >&2
fi

#---------------
if type -path lsipc >/dev/null 2>&1
then
  fnBANNER " IPC STATUS"
  lsipc
  echo
else
  echo "Missing utility lsipc, skipping lsipc status display" >&2
fi

#---------------
if type -path systemd-analyze >/dev/null 2>&1
then
  fnBANNER " SYSTEMD CRITICAL CHAIN"
  systemd-analyze time
  echo
  systemd-analyze critical-chain
  echo
else
  echo "Missing utility systemd-analyze, skipping systemd-analyze critical-chain display" >&2
fi

#---------------
if type -path systemd-analyze >/dev/null 2>&1
then
  fnBANNER " SYSTEMD BLAME"
  systemd-analyze blame
  echo
else
  echo "Missing utility systemd-analyze, skipping systemd-analyze blame display" >&2
fi

#---------------
if type -path systemctl >/dev/null 2>&1
then
  fnBANNER " SYSTEMCTL STATUS"
  systemctl status
  echo
else
  echo "Missing utility systemctl, skipping systemctl status display" >&2
fi

#---------------
if type -path systemctl >/dev/null 2>&1
then
  fnBANNER " SYSTEMCTL UNIT FAILURES"
  systemctl list-units --failed --all | grep -v "list-unit-files"
  echo
else
  echo "Missing utility systemctl, skipping systemctl unit failures display" >&2
fi

#---------------
if [ -d /var/log/journal ]
then
  fnBANNER " PERSISTENT JOURNALING"
  echo "Peristent Journaling is configured..."
  ls -ld /var/log/journal
  echo
fi

#---------------
if type -path systemctl >/dev/null 2>&1
then
  fnBANNER " SYSTEMCTL LIST-UNIT-FILES"
  systemctl list-unit-files
  echo
else
  echo "Missing utility systemctl, skipping systemctl list-unit-files display" >&2
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
# Not everyone has "cups" installed, so "lpstat" (part of the cups-client package)
# is not a required dependency for this script.  If they have it, great.  If not,
# it's no big deal.
if type -path lpstat >/dev/null 2>&1
then
  CUPS_RUNNING="$(lpstat -r 2>/dev/null)"
  if [ "${CUPS_RUNNING}" = "scheduler is running" ]
  then
    fnBANNER " PRINTER STATUS (CUPS)"
    lpstat -t
    echo
  fi
fi

#---------------
if type -path dmesg >/dev/null 2>&1
then
  fnBANNER " OFFICIAL 7\" TOUCHSCREEN"
  PI_TOUCHSCR="$(dmesg | grep -i ft5406)"
  if [ -n "${PI_TOUCHSCR}" ]
  then
    echo "detected"
  else
    echo "not detected"
  fi
  echo
else
  echo "Missing utility dmesg, skipping touchscreen detection display" >&2
fi

#---------------
# This routine was developed and tested on a Pi 3B and 3B+ only.
# I do not own, nor have access to, a Pi 4B at this time. :'(
# It is a "best guess" that it will work on a Pi 4B to detect
# multiple displays, given the Pi 4B's dual HDMI ports.  This
# assumption is based soley on the "tvservice" help screen.
if type -path tvservice >/dev/null 2>&1
then
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

    if type -path vcgencmd >/dev/null 2>&1
    then
      echo "CURRENT SCREEN RESOLUTION"
      echo "HORIZONTAL : $(vcgencmd get_lcd_info | awk '{ print $1 }') pixels"
      echo "VERTICAL   : $(vcgencmd get_lcd_info | awk '{ print $2 }') pixels"
      echo "COLOR DEPTH: $(vcgencmd get_lcd_info | awk '{ print $3 }') bits"
      echo
    else
      echo "Missing utility vcgencmd, skipping resolution and color depth display" >&2
    fi
  done
else
  echo "Missing utility tvservice, skipping hdmi current display mode display" >&2
fi

#---------------
# If you have a raspberry pi 4, install at least version 2.52 of wiringpi
# See - http://wiringpi.com/wiringpi-updated-to-2-52-for-the-raspberry-pi-4b/
if type -path gpio >/dev/null 2>&1
then
  fnBANNER " GPIO PIN STATUS"
  gpio readall
  echo
else
  echo "Missing utility gpio (part of wiringpi package), skipping gpio pin status display" >&2
fi

#---------------
if type -path grep >/dev/null 2>&1
then
  if [ -n "$(grep ipv6.disable=1 /boot/cmdline.txt)" ]
  then
    fnBANNER " IPV6 DISABLED"
    echo "IPv6 has been disabled in cmdline.txt"
    echo
  fi
else
  echo "Missing utility grep, skipping cmdline.txt ipv6.disable test" >&2
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
if type -path route >/dev/null 2>&1
then
  fnBANNER " ROUTE TABLE - IPV4"
  route -4 2> /dev/null
  echo
  fnBANNER " ROUTE TABLE - IPV6"
  route -6 2> /dev/null
  echo
else
  echo "Missing utility route, skipping route table display" >&2
fi

#---------------
if type -path lshw >/dev/null 2>&1
then
  fnBANNER " NETWORK ADAPTORS"
  ${SUDO} lshw -class network
  echo
else
  echo "Missing utility lshw, skipping network adaptor display" >&2
fi

#---------------
if type -path ifconfig >/dev/null 2>&1
then
  fnBANNER " IFCONFIG"
  ifconfig
else
  echo "Missing utility ifconfig, skipping ifconfig display" >&2
fi

#---------------
if type -path ip >/dev/null 2>&1
then
  fnBANNER " IP NEIGHBORS (ARP CACHE)"
  ip neigh | grep -v FAILED
  echo
else
  echo "Missing utility ip, skipping ip neighbors display" >&2
fi

#---------------
if [ -f /etc/wpa_supplicant/wpa_supplicant.conf ]
then
  if type -path ip >/dev/null 2>&1
  then
    fnBANNER " WPA_SUPPLICANT FILE (Passwords will not be displayed)"
    ${SUDO} cat /etc/wpa_supplicant/wpa_supplicant.conf | grep -v ^$ \
      | sed 's/psk=.*/psk=**PASSWORD_HIDDEN**/' \
      | sed 's/wep_key0=.*/wep_key0=**PASSWORD_HIDDEN**/' \
      | sed 's/password=.*/password=**PASSWORD_HIDDEN**/' \
      | sed 's/passwd=.*/passwd=**PASSWORD_HIDDEN**/'
    echo
  else
    echo "Missing utility sed, skipping wpa_supplicant display" >&2
  fi
fi

#---------------
if type -path iwconfig >/dev/null 2>&1 && type -path ip >/dev/null 2>&1 && type -path iwlist >/dev/null 2>&1
then
  fnBANNER " IWCONFIG"
  ip -s link | grep wlan[0-3] | awk '{ print $2 }' | cut -f1 -d":" | while read WLAN
  do
    iwconfig ${WLAN} 2>/dev/null
  done
else
  echo "Missing utility iwconfig, skipping wireless configuration display" >&2
fi

#---------------
if type -path iwlist >/dev/null 2>&1
then
  fnBANNER " VISIBLE WIFI ACCESS POINTS"
  iwlist scan 2>/dev/null | grep -v ^$ | grep -v "Unknown:"
  echo
else
  echo "Missing utility iwlist, skipping visible access points display" >&2
fi

#---------------
# Not everyone has, or needs, nmap.  So, it's not a required dependency
# for this script.  However, if we do find that it is available, we can
# make use of it here.
if type -path nmap >/dev/null 2>&1
then
  if type -path ifconfig >/dev/null 2>&1 && type -path awk >/dev/null 2>&1 && type -path grep >/dev/null 2>&1
  then
    # IPV4
    ifconfig | grep "inet " | awk '{ print $2 }' | while read MY_IP
    do
      fnBANNER " SCANNING FOR SERVICES LISTENING ON IPV4: ${MY_IP}"
      nmap -Pn -sV -T4 -p 1-65535 --version-light ${MY_IP} | grep "^PORT\|^[1-9][0-9]"
      echo
    done
    # IPV6
    ifconfig | grep "inet6 " | grep -v "inet6 ....::" | awk '{ print $2 }' | while read MY_IP
    do
      fnBANNER " SCANNING FOR SERVICES LISTENING ON IPV6: ${MY_IP}"
      nmap -6 -Pn -sV -T4 -p 1-65535 --version-light ${MY_IP} | grep "^PORT\|^[1-9][0-9]"
      echo
    done
  else
    echo "Missing one of ifconfig, awk, or grep.  Skipping port scan display" >&2
  fi
fi

#---------------
if type -path lsmod >/dev/null 2>&1
then
  fnBANNER " LOADED MODULES"
  lsmod | head -1
  lsmod | sort | grep -v "Used by"
  echo
else
  echo "Missing utility lsmod, skipping loaded modules display" >&2
fi

# This next module generates information about each loaded module listed
# by the above section.  The amount of information can be significant,
# depending upon how many modules are running.  Uncomment if you'ld like,
# but it may give more information than you are willing to scroll through.
# #---------------
# if type -path modinfo >/dev/null 2>&1
# then
#   fnBANNER " MODULE DETAILS"
#   lsmod | awk '{ print $1 }' | grep -v ^Module | sort | while read MODULE
#   do
#     echo "===================="
#     modinfo ${MODULE}
#     echo
#   done
# else
#   echo "Missing utility modinfo, skipping module details display" >&2
# fi

#---------------
if type -path dpkg >/dev/null 2>&1
then
  fnBANNER " INSTALLED PACKAGE LIST"
  dpkg -l 2>/dev/null
  echo
else
  echo "Missing utility dpkg, skipping installed package list" >&2
fi

# This next module will likely never see the light of day.  It generates
# information about each installed package listed by the above section.
# Uncommented, it can take many hours to run, would take forever reading
# from an SD card, and would result in many MB of information - far more
# than any admin is likely to ever be interested in.  If you want this
# information, uncomment as you will.  You've been warned.
# #---------------
# if type -path apt >/dev/null 2>&1
# then
#   fnBANNER " PACKAGE DETAILS"
#   apt list 2>/dev/null | cut -f1 -d"/" | sort | while read PACKAGE
#   do
#     echo "===================="
#     apt show ${PACKAGE} 2>/dev/null
#   done
# else
#   echo "Missing utility apt, skipping package details" >&2
# fi

fnBANNER " * * * END OF REPORT * * *"

##################################################
# ALL DONE
##################################################
