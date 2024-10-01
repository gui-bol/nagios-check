#!/bin/bash

# Nagios return codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# Default thresholds
WARNING_THRESHOLD=70
CRITICAL_THRESHOLD=90

# Parse command-line options
while getopts ":w:c:" opt; do
  case $opt in
    w)
      WARNING_THRESHOLD=$OPTARG
      ;;
    c)
      CRITICAL_THRESHOLD=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit $STATE_UNKNOWN
      ;;
  esac
done

# Get swap usage from /proc/meminfo
SWAP_TOTAL=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
SWAP_FREE=$(grep SwapFree /proc/meminfo | awk '{print $2}')

if [ $SWAP_TOTAL -eq 0 ]; then
    echo "OK: No swap configured on this system"
    exit $STATE_OK
fi

SWAP_USED=$((SWAP_TOTAL - SWAP_FREE))
SWAP_PERCENTAGE=$((SWAP_USED * 100 / SWAP_TOTAL))

# Convert to MB for display
SWAP_TOTAL_MB=$((SWAP_TOTAL / 1024))
SWAP_USED_MB=$((SWAP_USED / 1024))

# Check against thresholds
if [ $SWAP_PERCENTAGE -ge $CRITICAL_THRESHOLD ]; then
    echo "CRITICAL: Swap usage is $SWAP_PERCENTAGE% ($SWAP_USED_MB MB out of $SWAP_TOTAL_MB MB) | swap_used=$SWAP_USED;$((WARNING_THRESHOLD * SWAP_TOTAL / 100));$((CRITICAL_THRESHOLD * SWAP_TOTAL / 100));0;$SWAP_TOTAL"
    exit $STATE_CRITICAL
elif [ $SWAP_PERCENTAGE -ge $WARNING_THRESHOLD ]; then
    echo "WARNING: Swap usage is $SWAP_PERCENTAGE% ($SWAP_USED_MB MB out of $SWAP_TOTAL_MB MB) | swap_used=$SWAP_USED;$((WARNING_THRESHOLD * SWAP_TOTAL / 100));$((CRITICAL_THRESHOLD * SWAP_TOTAL / 100));0;$SWAP_TOTAL"
    exit $STATE_WARNING
else
    echo "OK: Swap usage is $SWAP_PERCENTAGE% ($SWAP_USED_MB MB out of $SWAP_TOTAL_MB MB) | swap_used=$SWAP_USED;$((WARNING_THRESHOLD * SWAP_TOTAL / 100));$((CRITICAL_THRESHOLD * SWAP_TOTAL / 100));0;$SWAP_TOTAL"
    exit $STATE_OK
fi