#!/bin/bash

# Functions
# Function to init the variables
initVariables() {
    # Variables
    shortcutsPath="$HOME/.local/share/applications"
    iconsPath="$HOME/.local/share/icons/hicolor/"
    steamLibraryConfigVdf="$HOME/.local/share/Steam/config/libraryfolders.vdf"
    if [ ! -f "$steamLibraryConfigVdf" ]; then
        # If the default path returns nothing try the flatpak path
        echo -e "\e[31mSteam library config file not found in the default path. Trying the flatpak path\e[0m"
        steamLibraryConfigVdf="$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/config/libraryfolders.vdf"
        if [ ! -f "$steamLibraryConfigVdf" ]; then
            echo -e "\e[31mError: Steam library config file not found\e[0m"
            exit 1
        fi
    fi
    echo -e "\e[32mSteam library config file found at $steamLibraryConfigVdf\e[0m"
}

# Function to fix the existing shortcuts
fixExistingShortcuts() {
    echo -e "\e[90mFixing existing shortcuts\e[0m"
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
                    echo -e "\e[90m--------------------------\e[0m"
                else
                    # Add the StartupWMClass to the .desktop file
                    echo "StartupWMClass=steam_app_$appId" >> "$shortcutFile"
                    echo -e "\e[32mStartupWMClass added to $shortcutFile\e[0m"
                    echo -e "\e[90m--------------------------\e[0m"
                fi
            fi
        fi
    done
    # TODO
}

# Get all the installed appIds from the libraryfolders.vdf file
getAllLibraryFolders() {
    # Get the IDS
    libraryFolders=($(    grep -oP '(?<="path"\t\t").*(?=")' "$steamLibraryConfigVdf"))
    echo -e "\e[90mFound ${#libraryFolders[@]} library folders\e[0m"
}

# In the library folders get the installed apps ids from the appmanifest files
getInstalledAppIds() {
    # Loop through all the library folders
    for libraryFolder in "${libraryFolders[@]}"
    do
        # Check if the steamapps folder exists in the library folder
        if [ -d "$libraryFolder/steamapps" ]; then
            # Get the appmanifest files in the steamapps folder
            appManifestFiles=($(find "$libraryFolder/steamapps" -name "appmanifest_*.acf"))
            echo -e "\e[90mFound ${#appManifestFiles[@]} appmanifest files in $libraryFolder\e[0m"
            # Loop through all the appmanifest files
            for appManifestFile in "${appManifestFiles[@]}"
            do
                # Get the appid from the appmanifest file
                appId=$(grep -oP '(?<="appid"\t\t").*(?=")' "$appManifestFile")
                appIds+=("$appId")
            done
        else
            echo -e "\e[31mError: steamapps folder not found in $libraryFolder\e[0m"
        fi
    done
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
        gameName=$(curl -s "https://store.steampowered.com/api/appdetails?appids=$appId" | jq -r ".\"$appId\".data.name")
        # If the game name is not null, then create a shortcut for the game in .local/share/applications
        if [ "$gameName" != "null" ]; then
            # Check if the icon exists in the .local/share/icons/hicolor/48x48/apps folder
            gameIcon=$(find "$iconsPath" | grep "steam_icon_$appId.png")

            echo -e "\e[32mCreating shortcut for $gameName\e[0m"
            echo -e "\e[90m--------------------------\e[0m"
            echo "[Desktop Entry]" > "$shortcutsPath/$gameName.desktop"
            echo "Name=$gameName" >> "$shortcutsPath/$gameName.desktop"
            echo "Exec=steam steam://rungameid/$appId" >> "$shortcutsPath/$gameName.desktop"
            echo "Type=Application" >> "$shortcutsPath/$gameName.desktop"
            # If the icon exists, then use it, otherwise use the default steam icon
            if [ -n "$gameIcon" ]; then
                echo "Icon=steam_icon_$appId" >> "$shortcutsPath/$gameName.desktop"
            else
                echo "Icon=steam" >> "$shortcutsPath/$gameName.desktop"
            fi
            echo "Categories=Game;" >> "$shortcutsPath/$gameName.desktop"
            echo "Terminal=false" >> "$shortcutsPath/$gameName.desktop"
            echo "StartupWMClass=steam_app_$appId" >> "$shortcutsPath/$gameName.desktop"
            echo "Comment=Play $gameName on Steam" >> "$shortcutsPath/$gameName.desktop"
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
}

# Main
# Route the command line arguments
case "$1" in
    -h|--help)
        helpCommand
        exit 0
        ;;
    -f|--fix)
        initVariables
        fixExistingShortcuts
        exit 0
        ;;
    -c|--create)
        initVariables
        createNewShortcuts
        exit 0
        ;;
    *)
        echo "Invalid option. Use -h or --help for help"
        exit 1
        ;;
esac