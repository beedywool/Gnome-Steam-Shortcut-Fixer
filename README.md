# Gnome Steam Shortcuts Utility

Simple utility to fix Steam shortcuts so the icon of games RUNNING WITH PROTON is displayed correctly on GNOME instead of the default 'no icon' program.
Can also be used to generate shortcuts for ALL your installed Steam games at once.

Note that the utility will fix the icon of games running with Proton and also apply this fix to native games, but the fix will only work out of the box with games running with Proton. For native games you can manually change the value of `StartupWMClass` in the .desktop file to the name of the executable. For example, for the game `Enter the Gungeon` you should put `StartupWMClass=EtG.x86_64`. Unfortunately this cannot be automated the same way as Proton games because it does not follow a standard pattern.

Shortcut creation WILL overwrite existing Steam game shortcuts but will not change shortcuts unrelated to Steam.
If an icon is not found locally in your icon cache, the script will automatically attempt to download the official icon from the Steam CDN / Steam Community before falling back to the generic Steam icon.

Supports Native Steam (Arch/Fedora default paths and Debian/Ubuntu/Pop!_OS `debian-installation`), Flatpak, and Snap.

## Features

- **Fix Existing Shortcuts**: Add `StartupWMClass=steam_app_<appId>` to correctly display game icons and window grouping in GNOME (Alt+Tab and dock) for games running with Proton.
- **Create New Shortcuts**: Automatically generate pre-patched shortcuts for all installed games in all Steam library folders on the system.
- **Automatic Icon Download**: Fetches missing game icons directly from the Steam CDN / Steam Community if you have never generated shortcuts through the Steam client.
- **Stealth Mode (`-s` / `--stealth`)**: Injects `NoDisplay=true` into the `.desktop` files so that Alt+Tab icon association works seamlessly without cluttering your GNOME application menu or search results.
- **Cross-Distro Support**: Works out of the box on Debian, Ubuntu, Pop!_OS, Fedora, Nobara, Arch, Flatpak, and Snap installations.

## Usage

1. Clone the repository:
    ```bash
    git clone https://github.com/beedywool/Gnome-Steam-Shortcut-Fixer.git
    cd Gnome-Steam-Shortcut-Fixer
    ```

2. Make sure `curl` and `jq` are installed on your system:
    ```bash
    # Debian / Ubuntu / Pop!_OS
    sudo apt install curl jq

    # Fedora / Nobara
    sudo dnf install curl jq

    # Arch Linux
    sudo pacman -S curl jq
    ```

3. Make the script executable:
    ```bash
    chmod +x ./gnome-steam-shortcut-fixer.sh
    ```

4. Run the script with desired options:
    ```bash
    ./gnome-steam-shortcut-fixer.sh -h
    ```

You can execute the script from anywhere on your PC.

## Arguments

- **Fix existing shortcuts**:
  `-f` or `--fix`
  ```bash
  ./gnome-steam-shortcut-fixer.sh -f
  ```

- **Create new shortcuts for all installed games**:
  `-c` or `--create`
  ```bash
  ./gnome-steam-shortcut-fixer.sh -c
  ```

- **Stealth mode (create shortcuts with `NoDisplay=true`)**:
  `-s` or `--stealth`
  ```bash
  ./gnome-steam-shortcut-fixer.sh -s
  # or combined:
  ./gnome-steam-shortcut-fixer.sh -c -s
  ```
  *Hides the shortcuts from the GNOME app grid and search, but preserves the correct icon and window matching in Alt+Tab.*

- **Display the help message**:
  `-h` or `--help`
  ```bash
  ./gnome-steam-shortcut-fixer.sh -h
  ```

## Requirements

- `curl`: To retrieve game names from the Steam Store API and download missing icons from the Steam CDN.
- `jq`: To parse JSON responses from the Steam API.
- *Optional:* `python3` (with `python3-pil`) or `ffmpeg` for automatic icon resizing across standard resolutions (`32x32`, `48x48`, `64x64`, `128x128`, `256x256`). If unavailable, downloaded icons are installed directly.
