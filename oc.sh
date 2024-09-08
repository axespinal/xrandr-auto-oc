#!/bin/bash
# oc.sh | part of xrandr-auto-oc that applies or sets up overclocking
# axel was here 2024-09-08

# absolute path
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
TARGET_EDID_FILE="$SCRIPT_DIR/target_edid.txt"
MODELINE_FILE="$SCRIPT_DIR/modeline.txt"

# debugging flag
DEBUG=false

# Functions
display_help() {
    echo "Usage: $0 [command] [options]"
    echo
    echo "Commands:"
    echo "  -h, --help                Show this help message"
    echo "  apply                     Apply settings using the configuration files"
    echo "  readconf                  Read and display configuration files"
    echo "  fetch                     Fetch EDID for monitors"
    echo "  setup [-s|--setup]        Setup missing configuration files"
    echo
    echo "Options:"
    echo "  -m, --modeline <path>     Specify a custom path for modeline.txt"
    echo "  -e, --edid <path>         Specify a custom path for target_edid.txt"    
    echo
}

check_target_file() {
    if [ -f "$1" ]; then
        if $DEBUG; then
        echo "File $1 already exists."
        echo "Last modified: $(stat -c %y "$1")"
        fi
        return 0
    else
        return 1
    fi
}

fetch_edid() {
    local target_edid_file="$1"

    # fetch all monitors
    MONITORS=($(xrandr --listmonitors | awk '{if (NR!=1) print $NF}'))
        for MONITOR in "${MONITORS[@]}"; do
            EDID_PATH=$(find /sys/class/drm/card*/edid | grep -w $MONITOR/edid)
                
            echo "Target EDID: $TARGET_EDID"
            echo

            if [ -n "$EDID_PATH" ]; then
                MONITOR_EDID=$(cat "$EDID_PATH" | hexdump | awk '{for(i=2;i<=NF;i++) printf $i}')
                TARGET_EDID=$(cat "$target_edid_file")

                echo "Checking EDID for monitor $MONITOR"
                echo
                echo "Monitor EDID: $MONITOR_EDID"
                echo
                
                if [ "$MONITOR_EDID" == "$TARGET_EDID" ]; then
                    echo "Monitor $MONITOR matches the saved EDID"
                    echo "Exiting..."
                    exit 0
                fi
            fi
        done

        echo No matching monitor found. Exiting...
        exit 1
}

parse_xrandr_output() {
    local target_monitor="$MONITOR"
    local target_mode="$MODENAME"
    local current_monitor=""
    local mode_found=false
    local mode_active=false

    while IFS= read -r line; do
        if [[ $line =~ ^[A-Za-z0-9-]+[[:space:]]+(connected|disconnected) ]]; then
            current_monitor=$(echo "$line" | awk '{print $1}')
            if [[ "$current_monitor" == "$target_monitor" ]]; then
                mode_found=false
                mode_active=false
            fi
        elif [[ "$current_monitor" == "$target_monitor" ]]; then
            if [[ $line == *"$target_mode"* ]]; then
                mode_found=true
                if [[ $line == *"*current"* ]]; then
                    mode_active=true
                    break
                fi
            fi
        fi
    done < <(xrandr --verbose)

    if $mode_active; then
        echo "active"
    elif $mode_found; then
        echo "present"
    else
        echo "not_present"
    fi
}


apply_modeline() {
    local modeline_path="$1"
    local target_edid_file="$2"

    if [ -f "$modeline_path" ]; then
        MODELINE=$(cat "$modeline_path")
        MODENAME=$(echo "$MODELINE" | awk '{print $1}')

        # debug: show modelines
        if $DEBUG; then
            echo "Modeline: $MODELINE"
            echo
            echo "Modeline Name: $MODENAME"
            echo
        fi

        # Find the monitor with the matching EDID
        MONITORS=($(xrandr --listmonitors | awk '{if (NR!=1) print $NF}'))
        for MONITOR in "${MONITORS[@]}"; do
            EDID_PATH=$(find /sys/class/drm/card*/edid | grep -w $MONITOR/edid)

            if [ -n "$EDID_PATH" ]; then
                MONITOR_EDID=$(cat "$EDID_PATH" | hexdump | awk '{for(i=2;i<=NF;i++) printf $i}')
                TARGET_EDID=$(cat "$target_edid_file")

                # debug: show monitors' edids
                if $DEBUG; then
                    echo "Checking EDID for monitor $MONITOR"
                    echo
                    echo "Monitor EDID: $MONITOR_EDID"
                    echo
                    echo "Target EDID: $TARGET_EDID"
                    echo
                fi

                if [ "$MONITOR_EDID" == "$TARGET_EDID" ]; then
                    echo "Applying modeline to monitor $MONITOR."
                    echo

                    # check if the modeline exists

                    if ! xrandr | grep -q "$MODENAME"; then
                        xrandr --newmode $MODELINE
                    else
                        echo "Modeline $MODENAME already exists."
                        echo
                    fi
                    
                    # check if modeline is added to the monitor and if it's active
                    mode_status=$(parse_xrandr_output)
                    case $mode_status in
                        "not_present")
                            echo "Adding mode $MODENAME to $MONITOR."
                            xrandr --addmode "$MONITOR" "$MODENAME"
                            xrandr --output "$MONITOR" --mode "$MODENAME"
                            ;;
                        "present")
                            echo "Mode $MODENAME already added to $MONITOR, but not active. Activating it."
                            xrandr --output "$MONITOR" --mode "$MODENAME"
                            ;;
                        "active")
                            echo "Mode $MODENAME is already active on $MONITOR. No changes needed."
                            ;;
                    esac

                    return
                fi
            fi
        done

        echo "No matching EDID found to apply the modeline."
        exit 1
    else
        echo "Modeline file not found at $modeline_path"
        exit 1
    fi
}

setup() {
    local setup_path="$SCRIPT_DIR"

    echo "Checking configuration files..."

    if ! check_target_file "$TARGET_EDID_FILE" || ! check_target_file "$MODELINE_FILE"; then
        echo "Configuration files are missing."
        echo "Setting up missing files..."

        if ! check_target_file "$TARGET_EDID_FILE"; then
            echo "Fetching EDID..."
            ./fetch_edid.sh --setup
        fi

        if ! check_target_file "$MODELINE_FILE"; then
            echo "Generating modeline..."
            ./make_params.sh --setup
        fi

        echo "Setup complete. You can now apply settings using '$0 apply'."
    else
        echo "All configuration files are present."
        echo "Use '$0 apply' to apply settings."
        echo
    fi
}

# Main script
case "$1" in
    -h|--help)
        display_help
        ;;

    readconf)
        echo
        echo "xrandr-auto-oc | axel was here 2024-09-08"
        echo
        echo "Default path: $SCRIPT_DIR"
        echo
        echo "Saved configuration:"
        echo
        if [ -f "$TARGET_EDID_FILE" ]; then
            echo "Display ID: $TARGET_EDID_FILE"
            echo
            cat "$TARGET_EDID_FILE" && echo
            echo
        else
            echo "Display ID: $TARGET_EDID_FILE [MISSING]"
            echo
        fi

        if [ -f "$MODELINE_FILE" ]; then
            echo "Parameters: $MODELINE_FILE"
            echo
            cat "$MODELINE_FILE"
            echo
        else
            echo "Parameters: $MODELINE_FILE [MISSING]"
            echo
        fi
        ;;

    fetch)

        EDID_PATH="$TARGET_EDID_FILE"

        while [[ $# -gt 1 ]]; do
            case "$2" in
                -e|--edid)
                    EDID_PATH="$3"
                    shift 2
                    ;;
                *)
                    echo "Invalid option: $2"
                    display_help
                    exit 1
                    ;;
            esac
        done
    
        fetch_edid "$EDID_PATH"
        ;;

    setup|-s|--setup)
        setup
        ;;

    apply)
        if ! check_target_file "$TARGET_EDID_FILE" || ! check_target_file "$MODELINE_FILE"; then
            echo "Configuration files are missing. Please run setup."
            exit 1
        fi

        MODEL_PATH="$MODELINE_FILE"
        EDID_PATH="$TARGET_EDID_FILE"

        while [[ $# -gt 1 ]]; do
            case "$2" in
                -m|--modeline)
                    MODEL_PATH="$3"
                    shift 2
                    ;;
                -e|--edid)
                    EDID_PATH="$3"
                    shift 2
                    ;;
                *)
                    echo "Invalid option: $2"
                    display_help
                    exit 1
                    ;;
            esac
        done

        apply_modeline "$MODEL_PATH" "$EDID_PATH"
        ;;

    *)
        display_help
        ;;
esac
