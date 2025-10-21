# MyHelpers

A collection of utility scripts designed to streamline common tasks on Windows and Linux systems. These scripts help automate system updates, display management, and network interface switching.

## Windows

### Features
#### Display Management

- `win_utils/ExtendDisplay.bat`: Extends your display setup to multiple monitors
- `win_utils/FirstDisplay.bat`: Switches to primary display only
- `win_utils/SecondDisplay.bat`: Switches to secondary display only

#### Network Management
- `win_utils/NetworkInterfaceSwitch.ps1`: PowerShell script for managing network interfaces
- `win_utils/SwitchToEthernet.bat`: Quickly switch to Ethernet connection using `NetworkInterfaceSwitch.ps1`
- `win_utils/SwitchToWiFi.bat`: Quickly switch to WiFi connection using `NetworkInterfaceSwitch.ps1`

### Installation & Setup

1. Clone this repository or download the files
2. Keep all files in the `win_utils` directory together
3. You may want to add the `win_utils` directory to your system's PATH for easier access
4. For network scripts, note your network interface names:
    - Open PowerShell and run `Get-NetAdapter` to see your interface names
    - Update the .bat files if your interface names differ from the defaults

### Usage

#### Display Scripts
You can use either the convenience batch files or the PowerShell script directly:

1. Using batch files (simplest):
    - `ExtendDisplay.bat`: Extends to multiple displays
    - `FirstDisplay.bat`: Switches to primary display
    - `SecondDisplay.bat`: Switches to secondary display

#### Network Scripts
1. For quick network switching:
    - Run `SwitchToEthernet.bat` to enable Ethernet and disable WiFi
    - Run `SwitchToWiFi.bat` to enable WiFi and disable Ethernet

## Windows Requirements
- Windows 11
- PowerShell 5.1 or later
- Administrative privileges (for network interface management on Windows)

## Linux

### Features
#### System Updates

- `linux_utils/upgrade.sh`: Updates, upgrades, and cleans up the system using apt with colored output

### Installation & Setup

1. Clone this repository or download the files
2. Keep all files in the `linux_utils` directory
3. Ensure the script is executable: `chmod +x linux_utils/upgrade.sh`

### Usage

#### Upgrade Script
Run `./linux_utils/upgrade.sh` to update and upgrade your system packages.

### Linux Requirements
- Ubuntu/Debian-based Linux distribution
- sudo privileges
- apt package manager


### Security Note
Some scripts require administrative privileges to function properly, especially those dealing with network interfaces. Run PowerShell or Command Prompt as Administrator when using Windows network management scripts. For Linux, ensure you have sudo access for system updates.
