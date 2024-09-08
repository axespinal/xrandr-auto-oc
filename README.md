# xrandr-auto-oc | an "automatic" monitor modesetting utility

## About

At its core, this utility:

1. Saves a monitor's EDID
2. Saves a custom resolution and refresh rate
3. Identifies all connected monitors
4. Applies the custom resolution and refresh rate to the saved monitor

## Installation

1. Clone the Git repository:

   ```bash
   git clone https://github.com/axespinal/xrandr-auto-oc.git
   ```

2. Verify that all scripts are executable and that you have read/write permissions on the directory.

3. Run the setup command:

   ```bash
   ./oc.sh setup
   ```

## Usage

Run one of the following commands:

- `./oc.sh apply` to apply the saved configuration.
- `./oc.sh help` to see all available options.

## Extra Info

This utility only works on X11 with `xrandr` because:

1. I use NVIDIA.
2. I haven't figured out how to overclock a monitor on Wayland.

The script can also handle custom configurations and export them. It is written in a way to avoid executing unnecessary `xrandr` commands when not needed.

I've only tested this script on **Arch Linux** with **GNOME 46**. The only known "bug" is GNOME-related: it turns the wallpaper dark when the custom resolution is applied. I'm not sure if it's due to one of my plugins, but the issue can be fixed by restarting the desktop environment through the run menu (`Alt + F2`, then `r`).

I might add an option for the script to automatically execute itself when it detects a new monitor in the future.
