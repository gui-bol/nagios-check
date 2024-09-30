#!/bin/bash

# Default thresholds (in Mbps)
WARNING_THRESHOLD=100
CRITICAL_THRESHOLD=200

# Function to print usage
usage() {
    echo "Usage: $0 -i <interface> [-w warning_threshold] [-c critical_threshold]"
    echo "  -i: Network interface to monitor (e.g., eth0)"
    echo "  -w: Warning threshold in Mbps (default: 100 Mbps)"
    echo "  -c: Critical threshold in Mbps (default: 200 Mbps)"
    exit 3
}

# Parse command line options
while getopts "i:w:c:" opt; do
    case $opt in
        i) INTERFACE=$OPTARG ;;
        w) WARNING_THRESHOLD=$OPTARG ;;
        c) CRITICAL_THRESHOLD=$OPTARG ;;
        *) usage ;;
    esac
done

# Check if interface is provided
if [ -z "$INTERFACE" ]; then
    usage
fi

# Function to get the current received and transmitted bytes
get_network_bytes() {
    rx_bytes=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
    tx_bytes=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)
    echo "$rx_bytes $tx_bytes"
}

# Check if the interface exists
if [ ! -d "/sys/class/net/$INTERFACE" ]; then
    echo "UNKNOWN: Interface $INTERFACE not found"
    exit 3
fi

# Get initial RX and TX bytes
initial_data=$(get_network_bytes)
initial_rx_bytes=$(echo $initial_data | awk '{print $1}')
initial_tx_bytes=$(echo $initial_data | awk '{print $2}')

# Sleep for 1 second to measure data over time
sleep 1

# Get final RX and TX bytes after 1 second
final_data=$(get_network_bytes)
final_rx_bytes=$(echo $final_data | awk '{print $1}')
final_tx_bytes=$(echo $final_data | awk '{print $2}')

# Calculate the bytes per second
rx_bytes_per_sec=$((final_rx_bytes - initial_rx_bytes))
tx_bytes_per_sec=$((final_tx_bytes - initial_tx_bytes))

# Convert to megabits per second (1 byte = 8 bits, 1 Mbps = 1,000,000 bits)
rx_mbps=$(awk "BEGIN {printf \"%.2f\", $rx_bytes_per_sec * 8 / 1000000}")
tx_mbps=$(awk "BEGIN {printf \"%.2f\", $tx_bytes_per_sec * 8 / 1000000}")
total_mbps=$(awk "BEGIN {printf \"%.2f\", $rx_mbps + $tx_mbps}")

# Prepare performance data for Nagios
perfdata="rx=${rx_mbps}Mbps;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD} tx=${tx_mbps}Mbps;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD} total=${total_mbps}Mbps;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD}"

# Check against thresholds and set exit status
if (( $(awk 'BEGIN {print ('"$total_mbps"' >= '"$CRITICAL_THRESHOLD"') ? 1 : 0}') )); then
    echo "CRITICAL: Network traffic on $INTERFACE is $total_mbps Mbps | $perfdata"
    exit 2
elif (( $(awk 'BEGIN {print ('"$total_mbps"' >= '"$WARNING_THRESHOLD"') ? 1 : 0}') )); then
    echo "WARNING: Network traffic on $INTERFACE is $total_mbps Mbps | $perfdata"
    exit 1
else
    echo "OK: Network traffic on $INTERFACE is $total_mbps Mbps | $perfdata"
    exit 0
fi
