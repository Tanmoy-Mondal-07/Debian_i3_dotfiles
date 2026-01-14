#!/bin/bash

# --- Configuration ---
ENABLED_COLOR="#A3BE8C"
DISABLED_COLOR="#D35F5E"
SIGNAL_ICONS=("󰤟 " "󰤢 " "󰤥 " "󰤨 ")
SECURED_SIGNAL_ICONS=("󰤡 " "󰤤 " "󰤧 " "󰤪 ")
WIFI_ICON=" "
ETH_ICON="󰈀"
CONNECTED_ICON=" "

# Detect Environment
SESSION_TYPE="${XDG_SESSION_TYPE:-x11}"

# --- Helper Functions ---

# Get the name of the wifi and ethernet interfaces dynamically
WLAN_INT=$(nmcli -t -f DEVICE,TYPE device | grep ":wifi" | cut -d: -f1 | head -n1)
ETH_INT=$(nmcli -t -f DEVICE,TYPE device | grep ":ethernet" | cut -d: -f1 | head -n1)

get_status() {
    local status_icon=$WIFI_ICON
    local status_color=$DISABLED_COLOR

    if nmcli -t -f TYPE,STATE device status | grep -q 'ethernet:connected'; then
        status_icon=$ETH_ICON
        status_color=$ENABLED_COLOR
    elif nmcli -t -f TYPE,STATE device status | grep -q 'wifi:connected'; then
        local wifi_info=$(nmcli --terse --fields "SIGNAL,SECURITY" device wifi list --rescan no | grep '^\*' | head -n1)
        if [ -n "$wifi_info" ]; then
            IFS=: read -r in_use signal security <<< "$wifi_info"
            local level=$(( signal / 25 ))
            [ $level -gt 3 ] && level=3
            
            if [[ "$security" =~ "WPA" || "$security" =~ "WEP" ]]; then
                status_icon="${SECURED_SIGNAL_ICONS[$level]}"
            else
                status_icon="${SIGNAL_ICONS[$level]}"
            fi
            status_color=$ENABLED_COLOR
        fi
    fi

    if [[ "$SESSION_TYPE" == "wayland" ]]; then
        echo "<span color=\"$status_color\">$status_icon</span>"
    else
        echo "%{F$status_color}$status_icon%{F-}"
    fi
}

manage_wifi() {
    # Get list of networks
    local wifi_list=$(nmcli --terse --fields "IN-USE,SIGNAL,SECURITY,SSID" device wifi list --rescan yes)
    local formatted_list=""
    
    while IFS=: read -r in_use signal security ssid; do
        [ -z "$ssid" ] && continue
        
        local level=$(( signal / 25 )); [ $level -gt 3 ] && level=3
        local icon="${SIGNAL_ICONS[$level]}"
        [[ "$security" =~ "WPA" || "$security" =~ "WEP" ]] && icon="${SECURED_SIGNAL_ICONS[$level]}"
        
        local prefix=""
        [[ "$in_use" == "*" ]] && prefix="$CONNECTED_ICON "
        
        formatted_list+="$prefix$icon $ssid\n"
    done <<< "$wifi_list"

    local chosen=$(echo -e "$formatted_list" | rofi -dmenu -i -p "Wi-Fi: " -markup-rows)
    [ -z "$chosen" ] && return

    # Extract SSID (strip the icon and prefix)
    local chosen_ssid=$(echo "$chosen" | sed "s/^$CONNECTED_ICON //" | awk '{print $2}')
    
    # Action Menu
    local is_active=$(echo "$chosen" | grep "$CONNECTED_ICON")
    local action=$(echo -e "󰸋 Connect\n Disconnect\n Forget" | rofi -dmenu -p "Action for $chosen_ssid: ")

    case $action in
        *"Connect")
            if nmcli -g NAME connection show | grep -Fxq "$chosen_ssid"; then
                nmcli connection up id "$chosen_ssid"
            else
                local pass=$(rofi -dmenu -p "Password: " -password)
                nmcli device wifi connect "$chosen_ssid" password "$pass"
            fi
            ;;
        *"Disconnect")
            nmcli device disconnect "$WLAN_INT"
            ;;
        *"Forget")
            nmcli connection delete id "$chosen_ssid"
            ;;
    esac
}

manage_ethernet() {
    if [ -z "$ETH_INT" ]; then
        notify-send "Network" "No Ethernet device found."
        return
    fi
    
    local state=$(nmcli -t -f STATE device show "$ETH_INT" | grep STATE | cut -d: -f2 | awk '{print $1}')
    local action_prompt="Connect Ethernet"
    [[ "$state" == "connected" ]] && action_prompt="Disconnect Ethernet"

    local action=$(echo -e "$action_prompt\nCancel" | rofi -dmenu -i -p "Ethernet: ")
    
    if [[ "$action" == "Connect Ethernet" ]]; then
        nmcli device connect "$ETH_INT"
    elif [[ "$action" == "Disconnect Ethernet" ]]; then
        nmcli device disconnect "$ETH_INT"
    fi
}

# --- Main Logic ---

# Check dependencies
for cmd in nmcli rofi; do
    if ! command -v $cmd &> /dev/null; then
        notify-send "Error" "$cmd is not installed."
        exit 1
    fi
done

# Handle arguments
case "$1" in
    --status) get_status; exit 0 ;;
esac

# Check if NetworkManager is running
if ! pgrep -x "NetworkManager" > /dev/null; then
    pkexec systemctl start NetworkManager
fi

# Main Menu
WIFI_ENABLED=$(nmcli radio wifi)
W_TOGGLE="󱚽 Enable Wi-Fi"
[[ "$WIFI_ENABLED" == "enabled" ]] && W_TOGGLE="󱛅 Disable Wi-Fi"

CHOSEN=$(echo -e "$W_TOGGLE\n󱓥 Manage Wi-Fi\n󱓥 Manage Ethernet" | rofi -dmenu -p "Network:")

case "$CHOSEN" in
    *"Wi-Fi")
        if [[ "$CHOSEN" == *"Manage"* ]]; then
            manage_wifi
        else
            nmcli radio wifi $([[ "$WIFI_ENABLED" == "enabled" ]] && echo "off" || echo "on")
        fi
        ;;
    *"Ethernet")
        manage_ethernet
        ;;
esac
