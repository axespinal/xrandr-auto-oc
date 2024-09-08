#!/bin/bash
# fetch_edid.sh | part of xrandr-auto-oc that generates the edid
# axel was here 2024-08-25

# get the absolute path of the script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# sets the default path for the EDID file in case of --setup
TARGET_EDID="$SCRIPT_DIR/target_edid.txt"

# function to display help
display_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --setup         Save EDID file to default path ($TARGET_EDID)"
    echo "  --path          Save EDID to specified path"
    echo "  -h, --help      Display this help message"
    echo
}

# function to check if the target file exists and print its last modification time
check_target_file() {
    if [ -f "$1" ]; then
        echo "File $1 already exists."
        echo "Last modified: $(stat -c %y "$1")"
        echo
        return 0
    else
        return 1
    fi
}

# function to fetch and save the EDID
fetch_edid() {
    local output_path="$1"

    # fetch all current monitors
    MONITORS=($(xrandr --listmonitors | awk '{if (NR!=1) print $NF}'))

    # prompt user to pick a monitor
    echo "Available monitors:"
    for i in "${!MONITORS[@]}"; do
        echo "$((i+1)). ${MONITORS[i]}"
    done

    echo
    read -p "Enter the number of the monitor to fetch the EDID for: " CHOICE

    # validate user input
    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt "${#MONITORS[@]}" ]; then
        echo Invalid choice. Exiting...
        exit 1
    fi

    # get the selected monitor
    MONITOR="${MONITORS[$CHOICE-1]}"

    # find the EDID path
    EDID_PATH=$(find /sys/class/drm/card*/edid | grep -w $MONITOR/edid)

    if [ -z "$EDID_PATH" ]; then
        echo "EDID file not found for $MONITOR."
        echo "Failed to retrieve EDID, exiting..."
        exit 1
    fi

    # fetch the EDID and save it to the target file
    cat "$EDID_PATH" | hexdump | awk '{for(i=2;i<=NF;i++) printf $i}' > "$output_path"

    echo
    echo "EDID for $MONITOR has been saved to $output_path"
    echo
}

# parse cli args
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -s|--setup)
            SETUP_MODE=true
            ;;
        -p|--path)
            CUSTOM_PATH="$2"
            shift
            ;;
        -h|--help)
            display_help
            exit 0
            ;;
        *)
            echo "Unknown parameter passed: $1"
            display_help
            exit 1
            ;;
    esac
    shift
done

# main logic
echo
if [ "$SETUP_MODE" = true ]; then
    # use default path for --setup
    if check_target_file "$TARGET_EDID"; then
        read -p "Do you want to overwrite it? (y/N): " OVERWRITE
        echo
        if [[ "$OVERWRITE" != "y" && "$OVERWRITE" != "Y" ]]; then
            echo "Exiting without changes."
            echo
            exit 1
        fi
    fi
    fetch_edid "$TARGET_EDID"
elif [ ! -z "$CUSTOM_PATH" ]; then
    # check if the custom path file already exists
    if check_target_file "$CUSTOM_PATH"; then
        read -p "Do you want to overwrite it? (y/N): " OVERWRITE
        echo
        if [[ "$OVERWRITE" != "y" && "$OVERWRITE" != "Y" ]]; then
            echo "Exiting without changes."
            echo
            exit 1
        fi
    fi
    fetch_edid "$CUSTOM_PATH"
else
    display_help
fi

