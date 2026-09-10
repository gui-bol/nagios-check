#!/bin/bash

# Default thresholds
WARNING_THRESHOLD=70
CRITICAL_THRESHOLD=85

# Function to print usage
usage() {
    echo "Usage: $0 [-w warning_threshold] [-c critical_threshold]"
    echo "  -w: Warning temperature in Celsius (default: 70°C)"
    echo "  -c: Critical temperature in Celsius (default: 85°C)"
    exit 3
}

# Parse command line options
while getopts "w:c:" opt; do
    case $opt in
        w) WARNING_THRESHOLD=$OPTARG ;;
        c) CRITICAL_THRESHOLD=$OPTARG ;;
        *) usage ;;
    esac
done

# Check if lm-sensors is installed
if ! command -v sensors &> /dev/null; then
    echo "UNKNOWN: lm-sensors is not installed. Please install it by running: sudo apt install lm-sensors"
    exit 3
fi

# Get CPU temperatures for all cores
core_temps=$(sensors | grep 'Core' | awk '{print $3}' | sed 's/+//;s/°C//')

# Check if temperatures were retrieved
if [ -z "$core_temps" ]; then
    echo "UNKNOWN: Could not retrieve CPU temperatures. Please ensure lm-sensors is configured correctly."
    exit 3
fi

# Initialize variables for tracking highest and total temperature
highest_temp=0
total_temp=0
core_count=0

# Loop through all core temperatures
for temp in $core_temps; do
    # Convert temperature to integer for comparison
    temp_int=$(echo "$temp" | awk '{printf "%d\n", $1}')
    
    # Track highest temperature
    if [ "$temp_int" -gt "$highest_temp" ]; then
        highest_temp=$temp_int
    fi
    
    # Sum all temperatures for average calculation
    total_temp=$(awk "BEGIN {print $total_temp + $temp}")
    ((core_count++))
done

# Calculate average temperature (using awk for floating-point division)
average_temp=$(awk "BEGIN {printf \"%.2f\", $total_temp / $core_count}")

# Prepare performance data for Nagios
perfdata="highest=${highest_temp}C;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD} average=${average_temp}C;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD}"

# Check against thresholds and exit with appropriate status
if (( $(awk 'BEGIN {print ('"$highest_temp"' >= '"$CRITICAL_THRESHOLD"') ? 1 : 0}') )); then
    echo "CRITICAL - CPU temperature too high: Highest=${highest_temp}°C, Average=${average_temp}°C | $perfdata"
    exit 2
elif (( $(awk 'BEGIN {print ('"$highest_temp"' >= '"$WARNING_THRESHOLD"') ? 1 : 0}') )); then
    echo "WARNING - CPU temperature elevated: Highest=${highest_temp}°C, Average=${average_temp}°C | $perfdata"
    exit 1
else
    echo "OK - CPU temperature normal: Highest=${highest_temp}°C, Average=${average_temp}°C | $perfdata"
    exit 0
fi
