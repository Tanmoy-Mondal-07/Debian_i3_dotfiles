#!/usr/bin/env bash

# --- Configuration & Theming ---
# (Matches your Powermenu style)
uptime_info=$(uptime -p | sed -e 's/up //g')
host=$(hostnamectl hostname)
WLAN_INT=$(nmcli -t -f DEVICE,TYPE device | grep ":wifi" | cut -d: -f1 | head -n1)

# Main Menu Options
options=("Wi-Fi" "Ethernet" "Hotspot" "Scan")
icons=("󰖩" "󰈀" "󱄉" "󰑓")

# --- Helper Functions ---

notify() {
    # notify-send -u low -t 3000 
    echo "Network Manager" "$1"
}

rofi_cmd() {
    local prompt=$1
    local mesg=$2
    local list=$3
    echo -e "$list" | rofi -dmenu -i -p "$prompt" -mesg "$mesg" \
        -theme-str 'window {width: 800px; height: 500px;} listview {columns: 2; lines: 3;}'
}

# --- Hotspot Logic ---
manage_hotspot() {
    local active_hotspot=$(nmcli -t -f CONNECTION device show "$WLAN_INT" | grep "GENERAL.CONNECTION" | cut -d: -f2)
    # Check if the current connection is a hotspot type
    if nmcli -t -f connection.type connection show "$active_hotspot" 2>/dev/null | grep -q "802-11-access-point"; then
        nmcli connection down id "$active_hotspot" && notify "Hotspot Deactivated"
    else
        # Create/Up a basic hotspot named 'MyHotspot' if it doesn't exist
        if ! nmcli connection show "MyHotspot" &>/dev/null; then
            nmcli device wifi hotspot ssid "MyHotspot" password "12345678"
        else
            nmcli connection up id "MyHotspot"
        fi
        notify "Hotspot 'MyHotspot' Activated"
    fi
}

# --- Wi-Fi Management ---
manage_wifi() {
    # 1. Get the list of SSIDs
    local wifi_list=$(nmcli --terse --fields "IN-USE,SIGNAL,SSID" device wifi list --rescan yes)
    local formatted_list=""
    local active_ssid=""

    while IFS=: read -r in_use signal ssid; do
        [ -z "$ssid" ] && continue
        if [[ "$in_use" == "*" ]]; then
            active_ssid="$ssid"
            formatted_list="󰄬 $ssid (Connected)\n$formatted_list"
        else
            formatted_list+="$ssid\n"
        fi
    done <<< "$wifi_list"

    local chosen_ssid=$(echo -e "$formatted_list" | rofi -dmenu -i -p "Select Network")
    [ -z "$chosen_ssid" ] && return

    # Clean the string (remove icon and 'Connected' text)
    chosen_ssid=$(echo "$chosen_ssid" | sed 's/󰄬 //' | sed 's/ (Connected)//')

    # 2. Contextual Actions based on connection status
    local actions=""
    if [[ "$chosen_ssid" == "$active_ssid" ]]; then
        actions="󰈂 Disconnect\n Forget"
    else
        actions="󰄄 Connect\n Forget"
    fi

    local selected_action=$(echo -e "$actions" | rofi -dmenu -i -p "Action: $chosen_ssid")

    case "$selected_action" in
        *"Connect")
            if nmcli -g NAME connection show | grep -Fxq "$chosen_ssid"; then
                nmcli connection up id "$chosen_ssid" --wait 10 || notify "Connection Failed"
            else
                local pass=$(rofi -dmenu -p "Password: " -password)
                nmcli device wifi connect "$chosen_ssid" password "$pass" || notify "Wrong Password"
            fi
            ;;
        *"Disconnect")
            nmcli device disconnect "$WLAN_INT" && notify "Disconnected from $chosen_ssid"
            ;;
        *"Forget")
            nmcli connection delete id "$chosen_ssid" && notify "Forgotten $chosen_ssid"
            ;;
    esac
}

# --- Main Logic ---

# Create the main menu string with icons
main_menu_string=""
for ((i = 0; i < ${#options[@]}; i++)); do
    main_menu_string+="${icons[$i]} ${options[$i]}\n"
done

chosen_main=$(echo -ne "$main_menu_string" | rofi -dmenu -i \
    -p " $USER@$host" \
    -mesg " Uptime: $uptime_info" \
    -theme-str 'window {width: 700px; height: 350px;} listview {columns: 2; lines: 2;}')

case "$chosen_main" in
    *"Wi-Fi")
        # Toggle Wi-Fi Power
        current_status=$(nmcli radio wifi)
        if [[ "$current_status" == "enabled" ]]; then
            nmcli radio wifi off && notify "Wi-Fi Disabled"
        else
            nmcli radio wifi on && notify "Wi-Fi Enabled"
        fi
        ;;
    *"Scan"|*"Manage Wi-Fi")
        manage_wifi
        ;;
    *"Ethernet")
        # Simple toggle for the first ethernet device found
        ETH_INT=$(nmcli -t -f DEVICE,TYPE device | grep ":ethernet" | cut -d: -f1 | head -n1)
        if [ -n "$ETH_INT" ]; then
            state=$(nmcli device status | grep "$ETH_INT" | awk '{print $3}')
            if [[ "$state" == "connected" ]]; then
                nmcli device disconnect "$ETH_INT" && notify "Ethernet Disconnected"
            else
                nmcli device connect "$ETH_INT" && notify "Ethernet Connected"
            fi
        fi
        ;;
    *"Hotspot")
        manage_hotspot
        ;;
esac
