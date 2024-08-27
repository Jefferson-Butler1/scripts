#!/bin/bash

# Function to list all connected monitors
list_monitors() {
    xrandr --query | grep " connected" | cut -d " " -f1
}

# Updated function to check if a monitor is active
is_monitor_active() {
    xrandr --query | grep "^$1 connected" | grep -q "[0-9]x[0-9]"
}

# Function to get current monitor configuration
get_monitor_config() {
    xrandr --query | grep -w "connected"
}

# Function to apply monitor configuration
apply_monitor_config() {
    local config="$1"
    local exclude_monitor="$2"
    local cmd="xrandr"
    
    while read -r line; do
        if [[ "$line" == *" connected "* && "$line" != *"$exclude_monitor"* ]]; then
            monitor=$(echo "$line" | cut -d " " -f1)
            if [[ "$line" == *" primary "* ]]; then
                mode=$(echo "$line" | grep -oP '\d+x\d+\+\d+\+\d+')
                cmd+=" --output $monitor --primary --mode ${mode%%+*} --pos ${mode#*+}"
            elif [[ "$line" != *" off"* ]]; then
                mode=$(echo "$line" | grep -oP '\d+x\d+\+\d+\+\d+')
                cmd+=" --output $monitor --mode ${mode%%+*} --pos ${mode#*+}"
            fi
        fi
    done <<< "$config"
    
    eval $cmd
}

# Function to safely turn off a monitor
turn_off_monitor() {
    local monitor=$1
    local active_monitors=$(list_monitors | wc -l)
    
    if [ $active_monitors -eq 1 ] && is_monitor_active "$monitor"; then
        echo "Cannot turn off the only active monitor."
        return 1
    fi
    
    local current_config=$(get_monitor_config)
    xrandr --output "$monitor" --off
    sleep 1  # Short wait for the change to take effect
    apply_monitor_config "$current_config" "$monitor"
}

# Updated function to turn on a monitor
turn_on_monitor() {
    local monitor=$1
    local current_config=$(get_monitor_config)

    # Check if the monitor is already on
    if is_monitor_active "$monitor"; then
        echo "Monitor $monitor is already on."
        return 0
    fi

    # Get the preferred mode for the monitor
    local preferred_mode=$(xrandr --query | grep "^$monitor" -A1 | tail -n1 | awk '{print $1}')

    # Find an active monitor to position relative to
    local ref_monitor=$(echo "$current_config" | grep -v "$monitor" | grep " connected [0-9]" | head -n1 | cut -d " " -f1)

    if [ -z "$ref_monitor" ]; then
        # If no other monitor is active, set this as primary
        xrandr --output "$monitor" --primary --mode "$preferred_mode" --pos 0x0
    else
        # Position to the right of the reference monitor
        local ref_pos=$(xrandr --query | grep "^$ref_monitor" | grep -oP '\+\d+\+\d+' | head -n1)
        local ref_width=$(xrandr --query | grep "^$ref_monitor" | grep -oP '\d+x\d+' | cut -d 'x' -f1)
        local new_x=$((${ref_pos#+}+ref_width))
        xrandr --output "$monitor" --mode "$preferred_mode" --pos "${new_x}x0" --right-of "$ref_monitor"
    fi

    sleep 1  # Short wait for the change to take effect

    # Reapply the configuration to ensure all monitors are positioned correctly
    apply_monitor_config "$current_config"
}

# Main menu
while true; do
    clear
    echo "Monitor Management Script"
    echo "========================="
    echo
    echo "Current monitor configuration:"
    get_monitor_config
    echo
    echo "Options:"
    echo "1. Turn off a monitor"
    echo "2. Turn on a monitor"
    echo "3. Exit"
    echo
    read -p "Enter your choice (1-3): " choice

    case $choice in
        1)
            echo
            echo "Select a monitor to turn off:"
            select monitor in $(list_monitors) "Cancel"; do
                if [ "$monitor" = "Cancel" ]; then
                    break
                elif [ -n "$monitor" ]; then
                    if turn_off_monitor "$monitor"; then
                        echo "Successfully turned off $monitor"
                    else
                        echo "Failed to turn off $monitor"
                    fi
                    break
                else
                    echo "Invalid selection"
                fi
            done
            ;;
        2)
            echo
            echo "Select a monitor to turn on:"
            select monitor in $(list_monitors) "Cancel"; do
                if [ "$monitor" = "Cancel" ]; then
                    break
                elif [ -n "$monitor" ]; then
                    if turn_on_monitor "$monitor"; then
                        echo "Successfully turned on $monitor"
                    else
                        echo "Failed to turn on $monitor"
                    fi
                    break
                else
                    echo "Invalid selection"
                fi
            done
            ;;
        3)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
done