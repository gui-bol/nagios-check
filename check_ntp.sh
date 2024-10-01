#!/bin/bash

# Nagios exit states
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# Default values
WARNING_THRESHOLD=1  # 1 second
CRITICAL_THRESHOLD=5 # 5 seconds
NTP_SERVER="pool.ntp.org"

# Parse command line options
while getopts "w:c:s:h" opt; do
  case $opt in
    w) WARNING_THRESHOLD=$OPTARG ;;
    c) CRITICAL_THRESHOLD=$OPTARG ;;
    s) NTP_SERVER=$OPTARG ;;
    h) echo "Usage: $0 [-w warning_threshold] [-c critical_threshold] [-s ntp_server]"
       exit $STATE_OK ;;
    \?) echo "Invalid option: -$OPTARG" >&2
        exit $STATE_UNKNOWN ;;
  esac
done

# Check if ntpdate is installed
if ! command -v ntpdate &> /dev/null; then
    echo "UNKNOWN: ntpdate is not installed"
    exit $STATE_UNKNOWN
fi

# Get the time offset
OFFSET=$(ntpdate -q $NTP_SERVER 2>/dev/null | tail -1 | awk '{print $6}')

if [ $? -ne 0 ]; then
    echo "CRITICAL: Unable to reach NTP server $NTP_SERVER"
    exit $STATE_CRITICAL
fi

# Remove sign from offset
OFFSET_ABS=$(echo $OFFSET | tr -d '-')

# Compare offset with thresholds
if (( $(echo "$OFFSET_ABS > $CRITICAL_THRESHOLD" | bc -l) )); then
    echo "CRITICAL: Time offset is $OFFSET seconds"
    exit $STATE_CRITICAL
elif (( $(echo "$OFFSET_ABS > $WARNING_THRESHOLD" | bc -l) )); then
    echo "WARNING: Time offset is $OFFSET seconds"
    exit $STATE_WARNING
else
    echo "OK: Time is in sync. Offset is $OFFSET seconds"
    exit $STATE_OK
fi