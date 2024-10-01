#!/bin/bash

# Default thresholds (in milliseconds)
WARNING_THRESHOLD=100
CRITICAL_THRESHOLD=500
NTP_SERVER=""

# Function to print usage
usage() {
    echo "Usage: $0 -s <ntp_server> [-w warning_threshold] [-c critical_threshold]"
    echo "  -s: NTP server to check (e.g., time.google.com)"
    echo "  -w: Warning threshold in milliseconds (default: 100 ms)"
    echo "  -c: Critical threshold in milliseconds (default: 500 ms)"
    exit 3
}

# Parse command-line options
while getopts "s:w:c:" opt; do
    case $opt in
        s) NTP_SERVER=$OPTARG ;;
        w) WARNING_THRESHOLD=$OPTARG ;;
        c) CRITICAL_THRESHOLD=$OPTARG ;;
        *) usage ;;
    esac
done

# Check if NTP server is provided
if [ -z "$NTP_SERVER" ]; then
    usage
fi

# Check if ntpq or chronyc is installed
if command -v ntpq &> /dev/null; then
    NTP_COMMAND="ntpq -p $NTP_SERVER"
elif command -v chronyc &> /dev/null; then
    NTP_COMMAND="chronyc sources"
else
    echo "UNKNOWN: Neither ntpq nor chronyc is installed. Install ntp or chrony."
    exit 3
fi

# Query the NTP server and get offset in milliseconds
if command -v ntpq &> /dev/null; then
    OFFSET=$(ntpq -c "rv 0 offset" | awk -F'=' '/offset/ {print $2}' | awk '{print $1}')
elif command -v chronyc &> /dev/null; then
    OFFSET=$(chronyc tracking | awk '/Last offset/ {print $3 * 1000}')
fi

# Ensure offset was retrieved
if [ -z "$OFFSET" ]; then
    echo "UNKNOWN: Could not retrieve NTP offset from $NTP_SERVER"
    exit 3
fi

# Convert offset to milliseconds (ntpq returns seconds, chrony returns milliseconds)
OFFSET_MS=$(awk "BEGIN {printf \"%.2f\", $OFFSET}")

# Prepare performance data for Nagios
perfdata="offset=${OFFSET_MS}ms;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0"

# Check against thresholds and set exit status
if (( $(awk 'BEGIN {print ('"$OFFSET_MS"' >= '"$CRITICAL_THRESHOLD"') ? 1 : 0}') )); then
    echo "CRITICAL: NTP offset is $OFFSET_MS ms (against $NTP_SERVER) | $perfdata"
    exit 2
elif (( $(awk 'BEGIN {print ('"$OFFSET_MS"' >= '"$WARNING_THRESHOLD"') ? 1 : 0}') )); then
    echo "WARNING: NTP offset is $OFFSET_MS ms (against $NTP_SERVER) | $perfdata"
    exit 1
else
    echo "OK: NTP offset is $OFFSET_MS ms (against $NTP_SERVER) | $perfdata"
    exit 0
fi