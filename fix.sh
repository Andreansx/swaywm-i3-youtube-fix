#!/bin/bash

C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_RED='\033[0;31m'
C_YELLOW='\033[1;33m'
C_RES='\033[0m'

if [[ $EUID -ne 0 ]]; then
   echo -e "${C_RED}Error: This script must be run with root privileges.${C_RES}"
   echo "Usage: sudo ./fix.sh"
   exit 1
fi

echo -e "${C_CYAN}This script will run a quick YouTube player issue in Firefox${C_RES}"
echo -e "${C_CYAN}by replacing ${C_YELLOW}pulseaudio${C_CYAN} with the modern ${C_YELLOW}pipewire-pulse${C_CYAN} server.${C_RES}"
echo ""
echo "The following commands will be executed:"
echo -e "  ${C_YELLOW}1. sudo pacman -Rns pulseaudio${C_RES}"
echo -e "  ${C_YELLOW}2. sudo pacman -S pipewire-pulse${C_RES}"
echo ""

read -n 1 -p "Are you sure you want to continue? [Y/n]: " choice
echo ""

if [[ "$choice" =~ ^[Nn]$ ]]; then
    echo -e "${C_RED}Operation canceled by the user.${C_RES}"
    exit 0
fi

echo -e "\n${C_CYAN}---> Step 1: Removing pulseaudio...${C_RES}"
if pacman -Rns --noconfirm pulseaudio; then
    echo -e "${C_GREEN}PulseAudio has been successfully removed.${C_RES}"
else
    echo -e "${C_RED}Failed to remove PulseAudio. It might not have been installed.${C_RES}"
    echo -e "${C_YELLOW}Continuing with PipeWire installation...${C_RES}"
fi

echo -e "\n${C_CYAN}---> Step 2: Installing pipewire-pulse...${C_RES}"
if pacman -S --noconfirm --needed pipewire-pulse; then
    echo -e "${C_GREEN}PipeWire has been successfully installed.${C_RES}"
else
    echo -e "${C_RED}An error occurred during PipeWire installation. Aborting script.${C_RES}"
    exit 1
fi

echo -e "\n${C_GREEN}--------------------------------------------------${C_RES}"
echo -e "${C_GREEN}Operation completed successfully!${C_RES}"
echo -e "For the changes to take effect, please ${C_YELLOW}reboot your computer${C_RES} or at least"
echo "log out and log back into your graphical session."
echo -e "${C_GREEN}--------------------------------------------------${C_RES}"

exit 0