# Gnome Steam Shortcuts Utility

Simple utility to fix Steam shortcuts so the icon of the games RUNNING WITH PROTON is displayed correctly on GNOME instead of the default 'no icon' program.
Can also be used to generate shortcuts for ALL your installed Steam games at once.
Note that the utility will fix the icon of games running with Proton and also apply this fix to native games, but the fix will only work with games running with Proton. For native games you can manually change the value of `StartupWMClass` in the .desktop file to the name of the executable. For exemple, for the game `Enter the Gungeon` you should put `StartupWMClass=EtG.x86_64`. Unfortunately this cannot be automated the same way as Proton games because it does not follow a pattern like them.

Shortcut creation WILL overwrite existing Steam games shortcuts but will not change shortcuts unrelated to Steam.
If the icon of the game is not found / doesn't exist it will default to the Steam icon.

Utility tested on 2 PCs with GNOME 47 on Nobara 41 and Fedora 41.

## Features

- Fix existing shortcuts to add `StartupWMClass` pointing to the correct `steam_app_<appId>` to display the correctly display the icon of games running with Proton when they are opened.
- Create new pre-patched shortcuts for all installed games in all SteamLibrary folders on the system

## Usage

1. Clone the repository:
    ```bash
    git clone https://github.com/beedywool/Gnome-Steam-Shortcut-Fixer.git
    cd Gnome-Steam-Shortcut-Fixer
    ```

2. Make sure `curl` and `jq` are installed on your system.

3. Make the script executable:
    ```bash
    chmod +x ./gnome-steam-shortcut-fixer.sh
    ```

4. Run the script:
    ```bash
    ./gnome-steam-shortcut-fixer.sh
    ```

5. Use the script from anywhere on your PC (it does not require to be executed from any specific directory).

## Arguments

Fix existing shortcuts:
`-f` or `--fix`

Create new shortcuts for all installed games:
`-c` or `--create`

Display the help message:
`-h` or `--help`

## Requirements

- `curl`: To retrieve game names from the Steam API.
- `jq`: To parse JSON responses from the Steam API.
