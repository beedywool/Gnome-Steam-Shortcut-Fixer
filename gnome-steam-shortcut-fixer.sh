#!/bin/bash

# Variables
shortcutsPath="$HOME/.local/share/applications"
iconsPath="$HOME/.local/share/icons/hicolor/48x48/apps"

# Functions
# Function to fix the existing shortcuts
fixExistingShortcuts() {
    echo "Fixing existing shortcuts"
    # TODO
}

# Function to create/replace new shortcuts for all games
createNewShortcuts() {
    # Look into the current folder for the steamapps/compatdata folder
    # If it exists, then we are in the right folder, if it doesn't exist throw an error
    if [ -d "steamapps/compatdata" ]; then
        echo "Found steamapps/compatdata folder in the current directory"
        # Get the name of all the folders in the steamapps/compatdata folder and store them in an array
        appIds=($(ls steamapps/compatdata))
        echo "Found ${#appIds[@]} games in the steamapps/compatdata folder"
        # Loop through all the folders in the steamapps/compatdata folder
        for appId in "${appIds[@]}"
        do 
            # Create a shortcut for each game in the steamapps/compatdata folder
            # First, retrieve the name of the game from Steam API
            gameName=$(curl -s "https://store.steampowered.com/api/appdetails?appids=$appId" | jq -r ".\"$appId\".data.name")
            # If the game name is not null, then create a shortcut for the game in .local/share/applications
            if [ "$gameName" != "null" ]; then
                # Check if the icon exists in the .local/share/icons/hicolor/48x48/apps folder
                gameIcon=$(ls "$iconsPath" | grep "steam_icon_$appId.png")

                echo "Creating shortcut for $gameName"
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
                echo "Error: Game name not found for $folder"
            fi
        done
    else
        echo "Error: steamapps/compatdata folder not found in the current directory"
        exit 1
    fi
}

# Main
# Ask if the user wants to fix existing shortcuts to add the StartupWMClass or create new shortcuts for all the games in the steamapps/compatdata folder
echo "Do you want to fix existing shortcuts or create new shortcuts for all the games installed in the current SteamLibrary directory?"
echo "1. Fix existing shortcuts"
echo "2. Create new shortcuts"
read -p "Enter your choice (1 or 2): " REPLY

# If the user chooses 1, then fix existing shortcuts
if [ "$REPLY" == "1" ]; then
    echo "Fixing existing shortcuts"
    fixExistingShortcuts
elif [ "$REPLY" == "2" ]; then
    echo "Creating new shortcuts"
    createNewShortcuts
else
    echo "Invalid choice. Please enter 1 or 2"
    exit 1
fi