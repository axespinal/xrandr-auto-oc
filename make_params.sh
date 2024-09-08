#!/bin/bash
# make_params.sh | part of xrandr-auto-oc that sets the params for the xrandr setting
# axel was here 2024-08-25

# absolute path
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
MODELINE_FILE="$SCRIPT_DIR/modeline.txt"

# help function
display_help() {
    echo "Usage: $0 [width] [height] [refresh rate] [options]"
    echo
    echo "Options:"
    echo "  -h, --help      Display this help message"
    echo "  --output <file> Specify a custom output file path"
    echo "  --setup         Save output to default directory"
    echo
}

# check target file function
check_target_file() {
    if [ -f "$1" ]; then
        echo
        echo "File $1 already exists."
        echo "Last modified: $(stat -c %y "$1")"
        echo
        return 0
    else
        return 1
    fi
}

# generation function
create_modeline() {
    local width="$1"
    local height="$2"
    local refrate="$3"
    local output_file="$4"

    # use cvt to generate the modeline
    if [ -z "$refrate" ]; then 
        # no refresh rate given
        echo "Generating modeline parameters for ${width}x${height}..."
        MODELINE=$(cvt $width $height | grep "Modeline" | sed 's/Modeline //')
    else    
        # refresh rate given
        echo "Generating modeline parameters for ${width}x${height} @ ${refrate}hz..."
        MODELINE=$(cvt $width $height $refrate | grep "Modeline" | sed 's/Modeline //')
    fi

    # check if cvt returned a modeline
    if [ -z "$MODELINE" ]; then
        echo "Failed to generate modeline. Exiting..."
        exit 1
    fi

    # check if the output file already exists and prompt for confirmation if it does
    if check_target_file "$output_file"; then
        read -p "Do you want to overwrite it? (y/N): " OVERWRITE
        echo
        if [[ "$OVERWRITE" != "y" && "$OVERWRITE" != "Y" ]]; then
            echo "Exiting without changes."
            echo
            exit 1
        fi
    fi

    # save modeline to the specified output file
    echo "$MODELINE" > "$output_file"
    echo "Modeline parameters have been saved to $output_file"
    echo
}

# function to check if a value is a positive integer
posint() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

# initialize variables for custom output and setup flag
OUTPUT_FILE=""
SETUP_FLAG=false

# parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            display_help
            exit 0
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --setup)
            SETUP_FLAG=true
            shift
            ;;
        *)
            # capture width, height, and refresh rate arguments
            if [[ "$1" =~ ^[0-9]+x[0-9]+x[0-9]+$ ]]; then
                # format: 1920x1080x60
                WIDTH=$(echo "$1" | cut -d'x' -f1)
                HEIGHT=$(echo "$1" | cut -d'x' -f2)
                REFRATE=$(echo "$1" | cut -d'x' -f3)
                shift
            elif [[ "$1" =~ ^[0-9]+x[0-9]+$ ]]; then
                # format: 1920x1080 (default refresh rate)
                WIDTH=$(echo "$1" | cut -d'x' -f1)
                HEIGHT=$(echo "$1" | cut -d'x' -f2)
                REFRATE=""
                echo "WARNING: No refresh rate given. Using default refresh rate..."
                shift
            else
                if [ -z "$WIDTH" ]; then
                    WIDTH="$1"
                elif [ -z "$HEIGHT" ]; then
                    HEIGHT="$1"
                elif [ -z "$REFRATE" ]; then
                    REFRATE="$1"
                else
                    echo "Invalid argument: $1"
                    display_help
                    exit 1
                fi
                shift
            fi
            ;;
    esac
done

# validate and parse resolution and refresh rate
if [ -n "$WIDTH" ] && [ -n "$HEIGHT" ]; then
    if [[ "$WIDTH" =~ ^[0-9]+$ && "$HEIGHT" =~ ^[0-9]+$ ]]; then
        if [ -n "$REFRATE" ]; then
            if ! [[ "$REFRATE" =~ ^[0-9]+$ ]]; then
                echo "Refresh rate must be a positive integer. Exiting..."
                exit 1
            fi
        fi
    else
        echo "Width and height must be positive integers. Exiting..."
        exit 1
    fi
else
    # prompt user for resolution and refresh rate if not provided
    read -p "Enter resolution (e.g., 1920x1080 or 1920 1080): " RESOLUTION
    read -p "Enter refresh rate (e.g., 60): " REFRATE
    echo

    # validate user input and parse width + height
    if echo "$RESOLUTION" | grep -Eq '^[0-9]+x[0-9]+$'; then
        WIDTH=$(echo "$RESOLUTION" | cut -d'x' -f1)
        HEIGHT=$(echo "$RESOLUTION" | cut -d'x' -f2)
    elif echo "$RESOLUTION" | grep -Eq '^[0-9]+ [0-9]+$'; then
        WIDTH=$(echo "$RESOLUTION" | cut -d' ' -f1)
        HEIGHT=$(echo "$RESOLUTION" | cut -d' ' -f2)
    else
        echo "Invalid resolution format. Exiting..."
        echo
        exit 1
    fi

    # validate refresh rate if provided
    if [ -n "$REFRATE" ] && ! echo "$REFRATE" | grep -Eq '^[0-9]+$'; then
        echo "Invalid refresh rate. Exiting..."
        echo
        exit 1
    fi
fi

# determine the output file path based on the --setup flag and --output flag
if [ "$SETUP_FLAG" = true ] && [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE="$MODELINE_FILE"
elif [ -z "$OUTPUT_FILE" ]; then
    echo "No output file specified and --setup flag not used. Exiting..."
    exit 1
fi

# create modeline file
create_modeline "$WIDTH" "$HEIGHT" "$REFRATE" "$OUTPUT_FILE"