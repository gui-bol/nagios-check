#!/bin/bash

# Nagios return codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Default temperature thresholds
WARN_TEMP=45
CRIT_TEMP=55

# Default empty exclude list
EXCLUDE_DRIVES=""

# Function to print usage
usage() {
    echo "Usage: $0 [-e exclude_drives] [-w warning_temp] [-c critical_temp]"
    echo "  -e: Comma-separated list of drives to exclude (e.g., sda,sdb)"
    echo "  -w: Warning temperature threshold (default: 45)"
    echo "  -c: Critical temperature threshold (default: 55)"
    exit $UNKNOWN
}

# Parse command line options
while getopts ":e:w:c:" opt; do
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
if ! [[ "$WARN_TEMP" =~ ^[0-9]+$ ]] || ! [[ "$CRIT_TEMP" =~ ^[0-9]+$ ]]; then
    echo "UNKNOWN: Warning and critical temperatures must be integers"
    exit $UNKNOWN
fi

if [ $WARN_TEMP -ge $CRIT_TEMP ]; then
    echo "UNKNOWN: Warning temperature must be less than critical temperature"
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

# Check if smartctl is installed
if ! command_exists smartctl; then
    echo "UNKNOWN: smartctl is not installed. Please install smartmontools package."
    exit $UNKNOWN
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

    # Use smartctl to get the temperature
    if [[ $disk == sd* ]]; then
        temp=$(smartctl -A /dev/$disk | grep Temperature_Celsius | awk '{print $10}')
    elif [[ $disk == nvme* ]]; then
        temp=$(smartctl -A /dev/$disk | grep Temperature: | awk '{print $2}')
    fi

    # Check if temperature was found
    if [ -n "$temp" ]; then
        output="${output}/dev/$disk: ${temp}°C, "
        perfdata="${perfdata}'$disk'=${temp};$WARN_TEMP;$CRIT_TEMP "

        # Update max temperature
        if (( temp > max_temp )); then
            max_temp=$temp
        fi

        # Check against thresholds
        if (( temp >= CRIT_TEMP )); then
            exit_code=$CRITICAL
        elif (( temp >= WARN_TEMP && exit_code != CRITICAL )); then
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