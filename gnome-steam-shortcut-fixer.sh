#!/bin/bash

# Functions
# Function to init the variables
initVariables() {
    # Variables
    shortcutsPath="$HOME/.local/share/applications"
    iconsPath="$HOME/.local/share/icons/hicolor/"
    steamLibraryConfigVdf="$HOME/.local/share/Steam/config/libraryfolders.vdf"
    steamInstallType="native"

    if [ ! -f "$steamLibraryConfigVdf" ]; then
        # If the default path returns nothing try the Debian path
        echo -e "\e[31mSteam library config file not found in the default path. Trying Debian path\e[0m"
        steamLibraryConfigVdf="$HOME/.steam/debian-installation/config/libraryfolders.vdf"
        steamInstallType="native"
        if [ ! -f "$steamLibraryConfigVdf" ]; then
            # If both the default path and Debian path are nil, try flatpak path
            echo -e "\e[31mSteam library config file not found in Debian path. Trying the flatpak path\e[0m"
            steamLibraryConfigVdf="$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/config/libraryfolders.vdf"
            steamInstallType="flatpak"
            if [ ! -f "$steamLibraryConfigVdf" ]; then
                # If both the default path, Debian, and flatpak path are nil, try snap path
                echo -e "\e[31mSteam library config file not found in flatpak path. Trying the snap path\e[0m"
                steamLibraryConfigVdf="$HOME/snap/steam/common/.local/share/Steam/config/libraryfolders.vdf"
                steamInstallType="snap"
                if [ ! -f "$steamLibraryConfigVdf" ]; then
                    echo -e "\e[31mError: Steam library config file not found\e[0m"
                    exit 1
                fi
            fi
        fi
    fi
    echo -e "\e[32mSteam library config file found at $steamLibraryConfigVdf\e[0m"
}

# Function to download and install game icon from Steam CDN if missing locally
downloadGameIcon() {
    local appId="$1"
    local gameName="$2"
    local downloaded=false
    local tempFile="/tmp/steam_icon_${appId}_temp"

    echo -e "\e[33mIcon not found locally for $gameName. Downloading from Steam CDN...\e[0m"

    # 1. Try to find cached icon in Steam client's librarycache first
    for cacheDir in \
        "$HOME/.steam/debian-installation/appcache/librarycache/$appId" \
        "$HOME/.local/share/Steam/appcache/librarycache/$appId" \
        "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/appcache/librarycache/$appId" \
        "$HOME/snap/steam/common/.local/share/Steam/appcache/librarycache/$appId"
    do
        if [ -d "$cacheDir" ]; then
            local localJpg=$(find "$cacheDir" -mindepth 1 -maxdepth 1 -name "????????????????????????????????????????.jpg" 2>/dev/null | head -n 1)
            if [ -n "$localJpg" ]; then
                cp "$localJpg" "$tempFile"
                downloaded=true
                break
            fi
        fi
    done

    # 2. If not found in local librarycache, try downloading from Steam Community / CDN
    if [ "$downloaded" = false ]; then
        local iconUrl=$(curl -s -L -b "birthtime=283993201; mature_content=1; wants_mature_content=1; lastagecheckage=1-0-1990; Steam_Language=english" "https://steamcommunity.com/app/$appId" | grep -oP '(?<=<div class="apphub_AppIcon"><img src=")[^"]+' | head -n 1)

        # Fallback to Steam CDN store assets if community apphub icon was not found
        if [ -z "$iconUrl" ]; then
            local testStatus=$(curl -s -o /dev/null -w "%{http_code}" "https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/logo.png")
            if [ "$testStatus" -eq 200 ]; then
                iconUrl="https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/logo.png"
            else
                testStatus=$(curl -s -o /dev/null -w "%{http_code}" "https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/header.jpg")
                if [ "$testStatus" -eq 200 ]; then
                    iconUrl="https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/header.jpg"
                fi
            fi
        fi

        if [ -n "$iconUrl" ]; then
            if curl -s -L -f "$iconUrl" -o "$tempFile" && [ -s "$tempFile" ]; then
                downloaded=true
            fi
        fi
    fi

    # 3. If downloaded / found, install to hicolor icons directory
    if [ "$downloaded" = true ] && [ -s "$tempFile" ]; then
        mkdir -p "$iconsPath/32x32/apps" "$iconsPath/48x48/apps" "$iconsPath/64x64/apps" "$iconsPath/128x128/apps" "$iconsPath/256x256/apps"

        local installed=false
        # Try converting and resizing with python3 if available
        if command -v python3 &>/dev/null; then
            python3 -c "
from PIL import Image
try:
    img = Image.open('$tempFile').convert('RGBA')
    resample = getattr(Image, 'Resampling', Image).LANCZOS
    for sz in [32, 48, 64, 128, 256]:
        img.resize((sz, sz), resample).save(f'$iconsPath/{sz}x{sz}/apps/steam_icon_$appId.png', 'PNG')
except Exception:
    exit(1)
" 2>/dev/null
            if [ -f "$iconsPath/48x48/apps/steam_icon_$appId.png" ]; then
                installed=true
            fi
        fi

        # Fallback: try ffmpeg if python conversion failed or wasn't available
        if [ "$installed" = false ] && command -v ffmpeg &>/dev/null; then
            ffmpeg -y -i "$tempFile" -vf scale=48:48 "$iconsPath/48x48/apps/steam_icon_$appId.png" &>/dev/null
            ffmpeg -y -i "$tempFile" -vf scale=32:32 "$iconsPath/32x32/apps/steam_icon_$appId.png" &>/dev/null
            if [ -f "$iconsPath/48x48/apps/steam_icon_$appId.png" ]; then
                installed=true
            fi
        fi

        # Fallback: direct copy if conversion tools aren't available
        if [ "$installed" = false ]; then
            cp "$tempFile" "$iconsPath/32x32/apps/steam_icon_$appId.png"
            cp "$tempFile" "$iconsPath/48x48/apps/steam_icon_$appId.png"
            installed=true
        fi

        rm -f "$tempFile"

        if [ "$installed" = true ]; then
            gtk-update-icon-cache -f -t "$iconsPath" 2>/dev/null || true
            echo -e "\e[32mIcon successfully downloaded and saved for $gameName\e[0m"
            return 0
        fi
    fi

    rm -f "$tempFile"
    echo -e "\e[31mFailed to download icon for $gameName, falling back to default Steam icon\e[0m"
    return 1
}

# Function to fix the existing shortcuts
fixExistingShortcuts() {
    echo -e "\e[90mFixing existing shortcuts\e[0m"
    shortcutFiles=()
    # Get all the .desktop files in the .local/share/applications folder
    while IFS= read -r -d '' desktopFile; do
        shortcutFiles+=("$desktopFile")
    done < <(find "$shortcutsPath" -name "*.desktop" -print0)
    echo -e "\e[90mFound ${#shortcutFiles[@]} existing shortcuts\e[0m"
    echo -e "\e[90m--------------------------\e[0m"
    # Loop through all the .desktop files and if one has an exec starting with steam
    # Then get the ID from the exec and add it to the StartupWMClass
    for shortcutFile in "${shortcutFiles[@]}"
    do
        # Get the exec line from the .desktop file
        gameName=$(grep -oP '^Name=.*' "$shortcutFile" | cut -d'=' -f2)
        if [ "$gameName" == "Steam" ]; then
            echo -e "\e[90mSkipping Steam shortcut\e[0m"
            echo -e "\e[90m--------------------------\e[0m"
            continue
        fi
        execLine=$(grep -oP '^Exec=.*' "$shortcutFile" | cut -d'=' -f2)
        # Check if the exec line starts with steam
        if [[ "$execLine" == "steam"* ]]; then
            # Get the ID from the exec line
            appId=$(echo "$execLine" | grep -oP '(?<=steam steam://rungameid/)[0-9]+')
            if [ -z "$appId" ]; then
                echo -e "\e[31mError: App ID not found for $gameName\e[0m"
                echo -e "\e[90m--------------------------\e[0m"
                continue
            else 
                echo -e "\e[32mFixing $gameName, with app id: $appId\e[0m"
                # Check if the StartupWMClass already exists in the .desktop file
                if grep -q "StartupWMClass" "$shortcutFile"; then
                    echo -e "\e[90mStartupWMClass already exists, skipped\e[0m"
                else
                    # Add the StartupWMClass to the .desktop file
                    echo "StartupWMClass=steam_app_$appId" >> "$shortcutFile"
                    echo -e "\e[32mStartupWMClass added to $shortcutFile\e[0m"
                fi
                # Check if stealth mode is requested
                if [ "$isStealth" = true ]; then
                    if ! grep -q "^NoDisplay=" "$shortcutFile"; then
                        echo "NoDisplay=true" >> "$shortcutFile"
                        echo -e "\e[32mNoDisplay=true added to $shortcutFile\e[0m"
                    fi
                fi
                echo -e "\e[90m--------------------------\e[0m"
            fi
        fi
    done
}

# Get all the installed appIds from the libraryfolders.vdf file
getAllLibraryFolders() {
    # Get the IDS
    libraryFolders=()
    while IFS= read -r folder; do
        [ -n "$folder" ] && libraryFolders+=("$folder")
    done < <(grep -oP '(?<="path"\t\t").*(?=")' "$steamLibraryConfigVdf")

    # Add ~/.steam/debian-installation if its steamapps folder exists and it is not already listed
    if [ -d "$HOME/.steam/debian-installation/steamapps" ]; then
        local debianSteamPath="$HOME/.steam/debian-installation"
        local foundDebian=0
        for folder in "${libraryFolders[@]}"; do
            if [ "$folder" == "$debianSteamPath" ]; then
                foundDebian=1
                break
            fi
        done
        if [ $foundDebian -eq 0 ]; then
            libraryFolders+=("$debianSteamPath")
        fi
    fi

    # Ensure default ~/.local/share/Steam is added if it has steamapps and is not listed
    if [ -d "$HOME/.local/share/Steam/steamapps" ]; then
        local defaultSteamPath="$HOME/.local/share/Steam"
        local foundDefault=0
        for folder in "${libraryFolders[@]}"; do
            if [ "$folder" == "$defaultSteamPath" ]; then
                foundDefault=1
                break
            fi
        done
        if [ $foundDefault -eq 0 ]; then
            libraryFolders+=("$defaultSteamPath")
        fi
    fi

    echo -e "\e[90mFound ${#libraryFolders[@]} library folders\e[0m"
}

# In the library folders get the installed apps ids from the appmanifest files
getInstalledAppIds() {
    appIds=()
    # Loop through all the library folders
    for libraryFolder in "${libraryFolders[@]}"
    do
        # Check if the steamapps folder exists in the library folder
        if [ -d "$libraryFolder/steamapps" ]; then
            # Get the appmanifest files in the steamapps folder
            appManifestFiles=()
            while IFS= read -r -d '' appManifestFile; do
                appManifestFiles+=("$appManifestFile")
            done < <(find "$libraryFolder/steamapps" -maxdepth 1 -name "appmanifest_*.acf" -print0)

            echo -e "\e[90mFound ${#appManifestFiles[@]} appmanifest files in $libraryFolder\e[0m"
            # Loop through all the appmanifest files
            for appManifestFile in "${appManifestFiles[@]}"
            do
                # Get the appid from the appmanifest file
                appId=$(grep -oP '(?<="appid"\t\t").*(?=")' "$appManifestFile")
                if [ -n "$appId" ]; then
                    appIds+=("$appId")
                fi
            done
        else
            echo -e "\e[31mError: steamapps folder not found in $libraryFolder\e[0m"
        fi
    done

    # Remove duplicates from appIds
    if [ ${#appIds[@]} -gt 0 ]; then
        local sortedUnique=($(printf "%s\n" "${appIds[@]}" | sort -u))
        appIds=("${sortedUnique[@]}")
    fi
}

# Function to create/replace new shortcuts for all games
createNewShortcuts() {
    # Get the library folders from the libraryfolders.vdf file
    getAllLibraryFolders
    # Get all the installed appIds from the appmanifest files in the steamapps folder for all the library folders
    getInstalledAppIds
    # Loop through all the previously found appIds and create a shortcut for each game
    echo -e "\e[90m--------------------------\e[0m"
    for appId in "${appIds[@]}"
    do 
        # Create a shortcut for each game in the steamapps/compatdata folder
        # First, retrieve the name of the game from Steam API
        gameName=$(curl -s -b "birthtime=283993201; mature_content=1; wants_mature_content=1; lastagecheckage=1-0-1990; Steam_Language=english" "https://store.steampowered.com/api/appdetails?appids=$appId" | jq -r ".\"$appId\".data.name")
        # If the game name is not null, then create a shortcut for the game in .local/share/applications
        if [ "$gameName" != "null" ] && [ -n "$gameName" ]; then
            # Sanitize gameName for filename (replace forward slashes)
            safeGameName="${gameName//\//-}"

            # Check if the icon exists in the .local/share/icons/hicolor folder
            gameIcon=$(find "$iconsPath" -name "steam_icon_$appId.png" 2>/dev/null | head -n 1)

            # If not found locally, download from Steam CDN / API
            if [ -z "$gameIcon" ]; then
                downloadGameIcon "$appId" "$gameName"
                gameIcon=$(find "$iconsPath" -name "steam_icon_$appId.png" 2>/dev/null | head -n 1)
            fi

            echo -e "\e[32mCreating shortcut for $gameName\e[0m"
            echo -e "\e[90m--------------------------\e[0m"
            echo "[Desktop Entry]" > "$shortcutsPath/$safeGameName.desktop"
            echo "Name=$gameName" >> "$shortcutsPath/$safeGameName.desktop"

            case "$steamInstallType" in
                flatpak)
                    echo "Exec=flatpak run com.valvesoftware.Steam steam steam://rungameid/$appId" >> "$shortcutsPath/$safeGameName.desktop"
                    ;;
                snap)
                    echo "Exec=snap run steam -applaunch $appId" >> "$shortcutsPath/$safeGameName.desktop"
                    ;;
                *)
                    echo "Exec=steam steam://rungameid/$appId" >> "$shortcutsPath/$safeGameName.desktop"
                    ;;
            esac
            # -----------------------------

            echo "Type=Application" >> "$shortcutsPath/$safeGameName.desktop"

            if [ -n "$gameIcon" ]; then
                echo "Icon=steam_icon_$appId" >> "$shortcutsPath/$safeGameName.desktop"
            else
                echo "Icon=steam" >> "$shortcutsPath/$safeGameName.desktop"
            fi

            echo "Categories=Game;" >> "$shortcutsPath/$safeGameName.desktop"
            echo "Terminal=false" >> "$shortcutsPath/$safeGameName.desktop"
            echo "StartupWMClass=steam_app_$appId" >> "$shortcutsPath/$safeGameName.desktop"
            echo "Comment=Play $gameName on Steam" >> "$shortcutsPath/$safeGameName.desktop"
            if [ "$isStealth" = true ]; then
                echo "NoDisplay=true" >> "$shortcutsPath/$safeGameName.desktop"
            fi
        else
            echo -e "\e[31mError: Name not found for $appId (it is probably not a game and doesn't need a shortcut)\e[0m"
            echo -e "\e[90m--------------------------\e[0m"
        fi
    done
}

# Function to display the help message
helpCommand() {
    echo "Usage: gnome-steam-shortcut-fixer.sh [OPTION]"
    echo "Fix or create new shortcuts for Steam games running with Proton on GNOME"
    echo "Note: this utility will create and fix shortcuts even for native games not running with Proton, but the default icon won't be fixed for these games"
    echo "Options:"
    echo "  -h, --help      Display this help message"
    echo "  -f, --fix       Fix existing shortcuts"
    echo "  -c, --create    Create new shortcuts"
    echo "  -s, --stealth   Create shortcuts with NoDisplay=true (hides from GNOME search menu, keeps Alt+Tab icon)"
}

# Main
# Route the command line arguments
action=""
isStealth=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            helpCommand
            exit 0
            ;;
        -f|--fix)
            action="fix"
            shift
            ;;
        -c|--create)
            action="create"
            shift
            ;;
        -s|--stealth)
            isStealth=true
            shift
            ;;
        *)
            echo "Invalid option: $1. Use -h or --help for help"
            exit 1
            ;;
    esac
done

# If stealth flag was passed without an explicit action, default to creating shortcuts
if [ -z "$action" ] && [ "$isStealth" = true ]; then
    action="create"
fi

if [ -z "$action" ]; then
    echo "Invalid option. Use -h or --help for help"
    exit 1
fi

initVariables

case "$action" in
    fix)
        fixExistingShortcuts
        exit 0
        ;;
    create)
        createNewShortcuts
        exit 0
        ;;
esac
