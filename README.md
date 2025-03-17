# Gnome Steam Shortcut Fixer

Simple utility to fix Steam shortcuts so the icon of the games RUNNING WITH PROTON is displayed correctly on GNOME instead of the default 'no icon' program.
Tested only on GNOME 47 on Nobara 41 and Fedora 41.

## Features

- Fix existing shortcuts to add `StartupWMClass` pointing to the correct `steam_app_<appId>`.
- Create new pre-patched shortcuts for all installed games in all SteamLibrary folders on the system

## Usage

1. Clone the repository:
    ```bash
    git clone https://github.com/beedywool/GnomeSteamShortcutFixer.git
    cd GnomeSteamShortcutFixer
    ```

2. Make sure `curl` and `jq` are installed on your system.

3. Make the script executable:
    ```bash
    chmod +x GnomeSteamShortcutFixer.sh
    ```

4. Run the script:
    ```bash
    ./GnomeSteamShortcutFixer.sh
    ```

5. Follow the prompts to either fix existing shortcuts or create new ones.

## Requirements

- `curl`: To retrieve game names from the Steam API.
- `jq`: To parse JSON responses from the Steam API.