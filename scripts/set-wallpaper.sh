#!/usr/bin/env bash
# Set wallpaper via hyprpaper and regenerate the pywal palette.
# Quickshell picks up the new colors live (Colors.qml watches ~/.cache/wal/colors.json).
set -eu

img="$(realpath "$1")"

hyprctl hyprpaper reload ,"$img"
wal -n --saturate 0.6 -i "$img"
