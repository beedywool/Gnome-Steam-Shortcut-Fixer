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
    echo "Fixing existing shortcuts"
    # Get all the .desktop files in the .local/share/applications folder
    while IFS= read -r -d '' desktopFile; do
        shortcutFiles+=("$desktopFile")
    done < <(find "$shortcutsPath" -name "*.desktop" -print0)
    echo "Found ${#shortcutFiles[@]} existing shortcuts"
    # Loop through all the .desktop files and if one has an exec starting with steam
    # Then get the ID from the exec and add it to the StartupWMClass
    for shortcutFile in "${shortcutFiles[@]}"
    do
        # Get the exec line from the .desktop file
        execLine=$(grep -oP '^Exec=.*' "$shortcutFile" | cut -d'=' -f2)
        # Check if the exec line starts with steam
        if [[ "$execLine" == "steam"* ]]; then
            # Get the ID from the exec line
            appId=$(echo "$execLine" | grep -oP '(?<=steam steam://rungameid/)[0-9]+')
            if [ -z "$appId" ]; then
                echo -e "\e[31mError: App ID not found in $shortcutFile\e[0m"
                continue
            else 
                echo -e "\e[32mFixing $shortcutFile, with app id: $appId\e[0m"
                # Check if the StartupWMClass already exists in the .desktop file
                if grep -q "StartupWMClass" "$shortcutFile"; then
                    echo -e "\e[90mStartupWMClass already exists, skipped\e[0m"
                    echo -e "\e[90m--------------------------\e[0m"
                else
                    # Add the StartupWMClass to the .desktop file
                    echo "StartupWMClass=steam_app_$appId" >> "$shortcutFile"
                    echo -e "\e[32mStartupWMClass added to $shortcutFile\e[0m"
                    echo -e "\e[90m--------------------------[0m"
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
    echo "Found ${#libraryFolders[@]} library folders"
}

# In the library folders get the installed apps ids from the appmanifest files
getInstalledAppIds() {
    # Loop through all the library folders
    for libraryFolder in "${libraryFolders[@]}"
    do
        # Check if the steamapps folder exists in the library folder
        if [ -d "$libraryFolder/steamapps" ]; then
            echo -e "\e[32mFound steamapps folder in $libraryFolder\e[0m"
            # Get the appmanifest files in the steamapps folder
            appManifestFiles=($(find "$libraryFolder/steamapps" -name "appmanifest_*.acf"))
            echo -e "\e[32mFound ${#appManifestFiles[@]} appmanifest files in $libraryFolder\e[0m"
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
        fi
    done
}

# Main
# Ask if the user wants to fix existing shortcuts to add the StartupWMClass or create new shortcuts for all the games in the steamapps/compatdata folder
echo "Do you want to fix existing shortcuts or create new shortcuts for all the games installed in the current SteamLibrary directory?"
echo "1. Fix existing shortcuts"
echo "2. Create new shortcuts"
read -p "Enter your choice (1 or 2): " userChoice

# If the user chooses 1, then fix existing shortcuts
if [ "$userChoice" == "1" ]; then
    echo "Fixing existing shortcuts"
    fixExistingShortcuts
elif [ "$userChoice" == "2" ]; then
    echo "Creating new shortcuts"
    createNewShortcuts
else
    echo "Invalid choice. Please enter 1 or 2"
    exit 1
fi