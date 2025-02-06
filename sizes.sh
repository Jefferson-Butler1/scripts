#!/bin/bash

# Function to convert all sizes to bytes for proper sorting
convert_to_bytes() {
    size=$1
    unit=${size: -1}
    number=${size:0:-1}
    
    case $unit in
        K) echo "$number * 1024" | bc ;;
        M) echo "$number * 1024 * 1024" | bc ;;
        G) echo "$number * 1024 * 1024 * 1024" | bc ;;
        T) echo "$number * 1024 * 1024 * 1024 * 1024" | bc ;;
        *) echo "$number" ;;
    esac
}

# Format as markdown table
echo "| Size | Path |"
echo "|------|------|"

# Get disk usage for all items in current directory, sort by size
du -sh * 2>/dev/null | while read size path; do
    echo "| $size | $path |"
done | sort -hr

# For piping to bat, uncomment this version instead:
du -sh * 2>/dev/null | sort -hr
