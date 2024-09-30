#!/bin/bash

# Nagios ZFS Health Check Plugin

# Get a list of all ZFS pools
pools=$(zpool list -H -o name 2>/dev/null)

# Check if there are any pools available
if [ -z "$pools" ]; then
  echo "UNKNOWN: No ZFS pools found or zpool command failed."
  exit 3
fi

# Initialize status flags
status_ok=0
status_warning=0
status_critical=0
message=""

# Function to check the status of each pool
check_pool_health() {
  local pool=$1

  # Get the status of the pool
  status=$(zpool status "$pool" 2>/dev/null)

  # Check if the pool is healthy
  if echo "$status" | grep -q "ONLINE"; then
    message+="Pool '$pool' is healthy. "
  elif echo "$status" | grep -q "DEGRADED"; then
    message+="Pool '$pool' is DEGRADED. "
    status_warning=1
  else
    if echo "$status" | grep -q -E "FAULTED|OFFLINE|UNAVAIL|REMOVED"; then
      message+="Pool '$pool' is in CRITICAL state: $(echo "$status" | grep -E 'FAULTED|OFFLINE|UNAVAIL|REMOVED'). "
      status_critical=1
    fi
  fi
}

# Loop through each pool and check its health
for pool in $pools; do
  check_pool_health "$pool"
done

# Determine the final exit code based on the worst condition
if [ $status_critical -eq 1 ]; then
  echo "CRITICAL: $message"
  exit 2
elif [ $status_warning -eq 1 ]; then
  echo "WARNING: $message"
  exit 1
else
  echo "OK: $message"
  exit 0
fi
