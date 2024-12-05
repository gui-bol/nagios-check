#!/bin/bash

# Check if both arguments are provided
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "CRITICAL: Usage: $0 <file_path> <string_to_search>"
    exit 2
fi

FILE="$1"
STRING="$2"

# Check if the file exists
if [ ! -f "$FILE" ]; then
    echo "CRITICAL: File $FILE does not exist!"
    exit 2
fi

# Search for the string in the file
if grep -q "$STRING" "$FILE"; then
    echo "OK: String '$STRING' found in $FILE"
    exit 0
else
    echo "WARNING: String '$STRING' not found in $FILE"
    exit 1
fi
