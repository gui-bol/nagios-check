#!/bin/bash

# Nagios return codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Default temperature thresholds
WARN_TEMP=45
CRIT_TEMP=55
NVME_WARN_TEMP=65
NVME_CRIT_TEMP=75

# Default empty exclude list
EXCLUDE_DRIVES=""

# Function to print usage
usage() {
    echo "Usage: $0 [-e exclude_drives] [-w warning_temp] [-c critical_temp] [-W nvme_warning_temp] [-C nvme_critical_temp]"
    echo "  -e: Comma-separated list of drives to exclude (e.g., sda,sdb)"
    echo "  -w: Warning temperature threshold for HDD/SATA drives (default: 45)"
    echo "  -c: Critical temperature threshold for HDD/SATA drives (default: 55)"
    echo "  -W: Warning temperature threshold for NVMe drives (default: 65)"
    echo "  -C: Critical temperature threshold for NVMe drives (default: 75)"
    exit $UNKNOWN
}

# Parse command line options
while getopts ":e:w:c:W:C:" opt; do
  case ${opt} in
    e )
      EXCLUDE_DRIVES=$OPTARG
      ;;
    w )
      WARN_TEMP=$OPTARG
      ;;
    c )
      CRIT_TEMP=$OPTARG
      ;;
    W )
      NVME_WARN_TEMP=$OPTARG
      ;;
    C )
      NVME_CRIT_TEMP=$OPTARG
      ;;
    \? )
      echo "UNKNOWN: Invalid option: $OPTARG" 1>&2
      usage
      ;;
    : )
      echo "UNKNOWN: Invalid option: $OPTARG requires an argument" 1>&2
      usage
      ;;
  esac
done

# Validate temperature thresholds
if ! [[ "$WARN_TEMP" =~ ^[0-9]+$ ]] || ! [[ "$CRIT_TEMP" =~ ^[0-9]+$ ]] || ! [[ "$NVME_WARN_TEMP" =~ ^[0-9]+$ ]] || ! [[ "$NVME_CRIT_TEMP" =~ ^[0-9]+$ ]]; then
    echo "UNKNOWN: Warning and critical temperatures must be integers"
    exit $UNKNOWN
fi

if [ $WARN_TEMP -ge $CRIT_TEMP ]; then
    echo "UNKNOWN: Warning temperature must be less than critical temperature"
    exit $UNKNOWN
fi

if [ $NVME_WARN_TEMP -ge $NVME_CRIT_TEMP ]; then
    echo "UNKNOWN: NVMe warning temperature must be less than NVMe critical temperature"
    exit $UNKNOWN
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a drive should be excluded
should_exclude() {
    local drive=$1
    IFS=',' read -ra EXCLUDE_ARRAY <<< "$EXCLUDE_DRIVES"
    for excluded in "${EXCLUDE_ARRAY[@]}"; do
        if [[ $drive == $excluded* ]]; then
            return 0
        fi
    done
    return 1
}

# Find smartctl in common locations
SMARTCTL=""
for path in /usr/sbin/smartctl /usr/bin/smartctl /sbin/smartctl; do
    if [ -x "$path" ]; then
        SMARTCTL="$path"
        break
    fi
done

# Check if smartctl was found
if [ -z "$SMARTCTL" ]; then
    echo "UNKNOWN: smartctl not found. Please install smartmontools package."
    exit $UNKNOWN
fi

# smartctl needs root; use sudo only when not already root (sudo is absent on Proxmox)
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

# Initialize variables
max_temp=0
output=""
perfdata=""
exit_code=$OK

# Get all disk devices
disks=$(lsblk -ndo NAME | grep -E '^sd[a-z]$|^nvme[0-9]n[1-9]$')

# Loop through each disk
for disk in $disks; do
    # Skip excluded drives
    if should_exclude "$disk"; then
        continue
    fi

    # Use smartctl to get the temperature (requires sudo)
    # NVMe drives run hotter by design, so they get their own thresholds
    if [[ $disk == sd* ]]; then
        temp=$($SUDO $SMARTCTL -A /dev/$disk 2>/dev/null | grep Temperature_Celsius | awk '{print $10}')
        warn=$WARN_TEMP
        crit=$CRIT_TEMP
    elif [[ $disk == nvme* ]]; then
        temp=$($SUDO $SMARTCTL -A /dev/$disk 2>/dev/null | grep Temperature: | awk '{print $2}')
        warn=$NVME_WARN_TEMP
        crit=$NVME_CRIT_TEMP
    fi

    # Check if temperature was found
    if [ -n "$temp" ]; then
        output="${output}/dev/$disk: ${temp}°C, "
        perfdata="${perfdata}'$disk'=${temp};$warn;$crit "

        # Update max temperature
        if (( temp > max_temp )); then
            max_temp=$temp
        fi

        # Check against thresholds
        if (( temp >= crit )); then
            exit_code=$CRITICAL
        elif (( temp >= warn && exit_code != CRITICAL )); then
            exit_code=$WARNING
        fi
    else
        output="${output}/dev/$disk: Temperature unknown, "
        if [ $exit_code != $CRITICAL ]; then
            exit_code=$UNKNOWN
        fi
    fi
done

# Prepare final output
output=${output%, }  # Remove trailing comma and space
case $exit_code in
    $OK)       status="OK"       ;;
    $WARNING)  status="WARNING"  ;;
    $CRITICAL) status="CRITICAL" ;;
    $UNKNOWN)  status="UNKNOWN"  ;;
esac

echo "${status}: Drive Temperatures - ${output} | ${perfdata}"
exit $exit_code
