#!/bin/bash
## Check SMART
## Description: This script to detect if there is
##              SMART errors on disks.
## By: Claude Gagne
## Date: 2013-07-10
## Changes:
##   2013-07-10 - Claude Gagne
##     - Initial version.

# Global variables.
LOG_FILE="/var/log/smart_parser/activity.log"
GENERIC_THRESHOLD=`echo $1`

# Function to check the difference of days between
# two dates.
# Return 0 if ok.
# Return 1 if not ok.
function check_day_diff {
  local START=`grep "Start:" $LOG_FILE | awk '{ print $2 }'`
  local END=`grep "End:" $LOG_FILE | awk '{ print $2 }'`
  local DATE_NOW=`date +%Y-%m-%d`
  local DAY_DIFF=`dateDiff -d $DATE_NOW $START`
  # If the difference is greater of day is greater
  # than it should be.
  if [ $DAY_DIFF -gt $1 ]; then {
    return 1
  }
  else {
    return 0
  }
  fi
}

# Function to convert a date to UNIX time stamp.
date2stamp () {
  date --utc --date "$1" +%s
}

# Function to calculate difference between two date.
dateDiff (){
  case $1 in
    -s)   sec=1;      shift;;
    -m)   sec=60;     shift;;
    -h)   sec=3600;   shift;;
    -d)   sec=86400;  shift;;
     *)    sec=86400;;
  esac
  dte1=$(date2stamp $1)
  dte2=$(date2stamp $2)
  diffSec=$((dte2-dte1))
  if ((diffSec < 0)); then abs=-1; else abs=1; fi
  echo $((diffSec/sec*abs))
}

# Function to get health status
function health_status {
  grep --quiet "\[HEALTH\]" $LOG_FILE
  if [ $? -eq 0 ]; then {
    HEALTH_RESULT=`grep "\[HEALTH\]" $LOG_FILE | awk '{ print $2 }' | awk -F ":" '{ print $1 }' | xargs`
  }
  else {
    HEALTH_RESULT="None"
  }
  fi
  echo $HEALTH_RESULT
}

# Function to get the selftest status
function selftest_status {
  grep --quiet "\[SELFTEST\]" $LOG_FILE
  if [ $? -eq 0 ]; then {
    SELFTEST_RESULT=`grep "\[SELFTEST\]" $LOG_FILE | awk '{ print $2 }' | awk -F ":" '{ print $1 }' | xargs`
  }
  else {
    SELFTEST_RESULT="None"
  }
  fi
  echo $SELFTEST_RESULT
}

# Function to get the generic error status
function generic_status {
  # If the threshold is at 0 it means that this check is disabled so return "None"
  if [ $GENERIC_THRESHOLD -ne 0 ]; then {
    grep --quiet "\[GENERIC\]" $LOG_FILE
    if [ $? -eq 0 ]; then {
      while read DRIVE
      do
        GENERIC_ERRORS=`grep "GENERIC" $LOG_FILE | grep $DRIVE | awk '{ print $3 }'`
        if [ $GENERIC_ERRORS -gt $GENERIC_THRESHOLD ]; then {
          GENERIC_RESULT="$DRIVE($GENERIC_ERRORS) $GENERIC_RESULT"
        }
        fi
      done < <(grep "\[GENERIC\]" $LOG_FILE | awk '{ print $2 }' | awk -F ":" '{ print $1 }')
      # If none of the drives have an higher number of errors than the threshold.
      if [ -z "$GENERIC_RESULT" ]; then {
        GENERIC_RESULT="None"
      }
      fi
    }
    else {
      GENERIC_RESULT="None"
    }
    fi
    echo $GENERIC_RESULT
  }
  else {
    echo "None"
  }
  fi
}

# Function to echo status and give a valide Nagios return code.
function output_status {
  local HEALTH_STATUS=""
  local HEALTH_RETURN=0
  local SELFTEST_STATUS=""
  local SELFTEST_RETURN=0
  local GENERIC_STATUS=""
  local GENERIC_RETURN=0
  local EXIT_CODE=0
  # Grab the result of each type of errors.
  HEALTH_STATUS=`health_status`
  SELFTEST_STATUS=`selftest_status`
  GENERIC_STATUS=`generic_status`
  # Return the proper exit code for the Nagios service status.
  if [ "$HEALTH_STATUS" != "None" ]; then {
    echo "Health: $HEALTH_STATUS - Selftest: $SELFTEST_STATUS - Generic: $GENERIC_STATUS"
    exit 2
  }
  fi
  if [ "$SELFTEST_STATUS" != "None" ]; then {
    echo "Health: $HEALTH_STATUS - Selftest: $SELFTEST_STATUS - Generic: $GENERIC_STATUS"
    exit 1
  }
  fi
  if [ "$GENERIC_STATUS" != "None" ]; then {
    echo "Health: $HEALTH_STATUS - Selftest: $SELFTEST_STATUS - Generic: $GENERIC_STATUS"
    exit 1
  }
  fi
  # If everything is at "None".
  echo "Health: None - Selftest: None - Generic: None"
}

# Check if the log file exist.
if [ -a $LOG_FILE ]; then {
  # Verify if the SMART Parser ran recently.
  check_day_diff 1
  if [ $? -eq 0 ]; then {
    # Check if the SMART Parser is still running.
    grep --quiet "End:" $LOG_FILE
    if [ $? -ne 0 ]; then {
      echo -e "The SMART Parser is running..."
      exit 0
    }
    # If not running.
    else {
      # Call the function that will take care of outputing on stdout and giving
      # the proper exit code for Nagios service status.
      output_status
    }
    fi
  }
  else {
    echo -e "SMART Parser didn't run since the `grep "Start:" $LOG_FILE | awk '{ print $2 }'`"
    exit 1
  }
  fi
}
else {
  echo "Log file for the SMART Parser doesn't exist."
  exit 2
}
fi
