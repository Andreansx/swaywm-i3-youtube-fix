#!/bin/bash

C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_RED='\033[0;31m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_BOLD='\033[1m'
C_NONE='\033[0m'

show_usage() {
    echo -e "${C_BOLD}Usage: ./media-fix.sh [command]${C_NONE}"
    echo ""
    echo "A small utility to diagnose and fix video playback issues on Arch Linux."
    echo ""
    echo "Commands:"
    echo -e "  ${C_GREEN}(no command)${C_NONE}\t- (sudo) Runs the main fix: replaces PulseAudio with PipeWire."
    echo -e "  ${C_BLUE}--diagnose${C_NONE}\t- Runs a system check-up without making any changes."
    echo -e "  ${C_YELLOW}--undo${C_NONE}\t\t- (sudo) Reverts the changes: replaces PipeWire with PulseAudio."
    echo -e "  ${C_CYAN}--help${C_NONE}\t\t- Shows this help message."
}

diagnose_system() {
    echo -e "${C_BLUE}--- Running System Diagnostics ---${C_NONE}"
    local all_ok=true

    echo -ne "[${C_CYAN}1/4${C_NONE}] Checking codecs (ffmpeg)... "
    if pacman -Q ffmpeg &>/dev/null; then
        echo -e "${C_GREEN}OK${C_NONE}"
    else
        echo -e "${C_RED}MISSING${C_NONE}"
        all_ok=false
    fi

    echo -ne "[${C_CYAN}2/4${C_NONE}] Checking VA-API drivers... "
    local gpu_vendor
    gpu_vendor=$(lspci -k | grep -A 2 -E "(VGA|3D)" | tr '[:upper:]' '[:lower:]')
    local driver_ok=false
    if echo "$gpu_vendor" | grep -q "intel"; then
        if pacman -Q intel-media-driver &>/dev/null; then driver_ok=true; fi
        echo -n "(Intel) "
    elif echo "$gpu_vendor" | grep -q "amd"; then
        if pacman -Q libva-mesa-driver &>/dev/null; then driver_ok=true; fi
        echo -n "(AMD) "
    elif echo "$gpu_vendor" | grep -q "nvidia"; then
        if pacman -Q libva-nvidia-driver-git &>/dev/null || pacman -Q libva-vdpau-driver-vp9-git &>/dev/null ; then driver_ok=true; fi
        echo -n "(NVIDIA) "
    fi

    if $driver_ok; then
        echo -e "${C_GREEN}OK${C_NONE}"
    else
        echo -e "${C_RED}MISSING${C_NONE}"
        all_ok=false
    fi

    echo -ne "[${C_CYAN}3/4${C_NONE}] Checking audio server... "
    if pacman -Q pipewire-pulse &>/dev/null; then
        echo -e "${C_GREEN}PipeWire${C_NONE}"
    elif pacman -Q pulseaudio &>/dev/null; then
        echo -e "${C_YELLOW}PulseAudio${C_NONE}"
        all_ok=false
    else
        echo -e "${C_RED}None${C_NONE}"
        all_ok=false
    fi
    
    echo -ne "[${C_CYAN}4/4${C_NONE}] Checking session type... "
    if [[ "$XDG_SESSION_TYPE" ]]; then
        echo -e "${C_GREEN}${XDG_SESSION_TYPE}${C_NONE}"
    else
        echo -e "${C_YELLOW}Unknown${C_NONE}"
    fi

    echo -e "${C_BLUE}--- Diagnostics Complete ---${C_NONE}"
    if $all_ok; then
        echo -e "\n${C_GREEN}Your base media configuration looks correct!${C_NONE}"
        echo "If issues persist, they might be related to Firefox's internal settings."
    else
        echo -e "\n${C_RED}Potential issues detected. Suggested actions:${C_NONE}"
        if ! pacman -Q ffmpeg &>/dev/null; then echo "  - Install ffmpeg: ${C_YELLOW}sudo pacman -S ffmpeg${C_NONE}"; fi
        if ! $driver_ok; then echo "  - Install the correct VA-API drivers for your GPU."; fi
        if pacman -Q pulseaudio &>/dev/null; then echo "  - Consider switching to PipeWire by running: ${C_YELLOW}sudo ./media-fix.sh${C_NONE}"; fi
    fi
}

perform_fix() {
    if pacman -Q pipewire-pulse &>/dev/null; then
        echo -e "${C_GREEN}PipeWire is already installed. Nothing to do.${C_NONE}"
        exit 0
    fi

    echo -e "${C_CYAN}This script will replace ${C_YELLOW}pulseaudio${C_CYAN} with ${C_GREEN}pipewire-pulse${C_NONE}."
    read -n 1 -p "Are you sure you want to continue? [Y/n]: " choice
    echo ""
    if [[ "$choice" =~ ^[Nn]$ ]]; then
        echo -e "${C_RED}Operation canceled.${C_NONE}"; exit 0
    fi

    echo -e "\n${C_CYAN}---> Step 1: Removing pulseaudio...${C_NONE}"
    pacman -Rns --noconfirm pulseaudio || echo -e "${C_YELLOW}PulseAudio was not installed. Skipping.${C_NONE}"

    echo -e "\n${C_CYAN}---> Step 2: Installing pipewire-pulse...${C_NONE}"
    if pacman -S --noconfirm --needed pipewire-pulse; then
        echo -e "${C_GREEN}PipeWire has been successfully installed.${C_NONE}"
    else
        echo -e "${C_RED}An error occurred during installation. Aborting.${C_NONE}"; exit 1
    fi

    echo -e "\n${C_GREEN}Operation completed! Please reboot for the changes to take effect.${C_NONE}"
}

perform_undo() {
    if ! pacman -Q pipewire-pulse &>/dev/null; then
        echo -e "${C_RED}PipeWire is not installed. Nothing to undo.${C_NONE}"; exit 0
    fi

    echo -e "${C_YELLOW}This script will restore ${C_YELLOW}pulseaudio${C_NONE}."
    read -n 1 -p "Are you sure you want to continue? [Y/n]: " choice
    echo ""
    if [[ "$choice" =~ ^[Nn]$ ]]; then
        echo -e "${C_RED}Operation canceled.${C_NONE}"; exit 0
    fi

    echo -e "\n${C_CYAN}---> Step 1: Removing pipewire-pulse...${C_NONE}"
    pacman -Rns --noconfirm pipewire-pulse

    echo -e "\n${C_CYAN}---> Step 2: Installing pulseaudio...${C_NONE}"
    if pacman -S --noconfirm --needed pulseaudio pulseaudio-alsa; then
        echo -e "${C_GREEN}PulseAudio has been successfully re-installed.${C_NONE}"
    else
        echo -e "${C_RED}An error occurred during installation. Aborting.${C_NONE}"; exit 1
    fi
    
    echo -e "\n${C_GREEN}Undo operation completed! Please reboot for the changes to take effect.${C_NONE}"
}

case "$1" in
    --diagnose)
        diagnose_system
        ;;
    --undo)
        if [[ $EUID -ne 0 ]]; then echo -e "${C_RED}Error: This operation requires root privileges.${C_NONE}" >&2; exit 1; fi
        perform_undo
        ;;
    ""|--fix)
        if [[ $EUID -ne 0 ]]; then echo -e "${C_RED}Error: This operation requires root privileges.${C_NONE}" >&2; exit 1; fi
        perform_fix
        ;;
    --help|*)
        show_usage
        ;;
esac

exit 0