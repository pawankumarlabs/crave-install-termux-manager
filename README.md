# Crave Build Manager for Termux

<div align="center">

```
  ██████╗██████╗  █████╗ ██╗   ██╗███████╗
 ██╔════╝██╔══██╗██╔══██╗██║   ██║██╔════╝
 ██║     ██████╔╝███████║██║   ██║█████╗
 ██║     ██╔══██╗██╔══██║╚██╗ ██╔╝██╔══╝
 ╚██████╗██║  ██║██║  ██║ ╚████╔╝ ███████╗
  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝
```

**Install, Configure & Manage Crave Cloud Builds directly from your Android phone via Termux**

[![Version](https://img.shields.io/badge/version-2.1.0-blue?style=flat-square)](https://github.com/pawankumarlabs/crave-install-termux-manager)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20ARM64-green?style=flat-square)](#)
[![License](https://img.shields.io/badge/license-MIT-orange?style=flat-square)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash-lightgrey?style=flat-square)](#)

</div>

---

## What is This?

[Crave](https://foss.crave.io) is a cloud-based build service that lets you compile Android ROMs (like LineageOS, PixelOS, CipherOS) on powerful remote servers — without needing a high-end PC.

**Crave Build Manager for Termux** is an all-in-one installer and manager that gets Crave running on your **Android phone in minutes** using [Termux](https://termux.dev) and PRoot Ubuntu. No root required.

---

## Features

| Feature | Description |
|---|---|
| ⚡ **One-command Install** | Installs Ubuntu PRoot, Crave binary, and wrappers automatically |
| 🔑 **Auto Config Import** | Scans Downloads folder and sets up `crave.conf` with token validation |
| ✅ **Live Token Check** | Validates your API token against foss.crave.io before applying |
| 🔍 **Diagnostics** | Full health check: Ubuntu, Crave binary, API auth, and project list |
| 🚀 **Devspace Launcher** | Launch interactive cloud SSH shell directly from the menu |
| 🔄 **Update & Repair** | Update Crave binary and auto-repair PATH/wrapper/permission issues |
| 📊 **Account Info** | View server, username, token details, and storage usage |
| 🗑 **Clean Uninstall** | Remove Crave, config, and optionally the Ubuntu container |

---

## Requirements

- Android device with **ARM64 (aarch64)** architecture
- **Termux** installed ([from F-Droid](https://f-droid.org/packages/com.termux/))
- Active internet connection
- A valid **[Crave account](https://foss.crave.io)** and `crave.conf` file
- **Root is NOT required**

---

## Installation

### Quick Start

```bash
# Step 1: Install Termux from F-Droid
# Step 2: In Termux, run:

pkg install git -y
git clone https://github.com/pawankumarlabs/crave-install-termux-manager.git
cd crave-install-termux-manager
chmod +x crave-installer-termux.sh
./crave-installer-termux.sh
```

Then select **`[4] Full Installation`** from the menu.

---

## Getting crave.conf

1. Sign up or log in at **[foss.crave.io](https://foss.crave.io)**
2. Go to **Account → API Keys**
3. Download your `crave.conf` file
4. Place it in your Android **Downloads** folder

The script will **automatically detect and import it** for you.

---

## Usage

### Interactive Menu

```bash
./crave-installer-termux.sh
```

```
  CRAVE Build Manager • Termux Cloud Suite (v2.1.0)
  ──────────────────────────────────────────────────

  ╭── SYSTEM STATUS ─────────────────────────────────╮
  │  Ubuntu PRoot : ● Ready                          │
  │  Crave CLI    : ● Installed (v0.2-7220)          │
  │  CLI Wrapper  : ● Active in PATH                 │
  │  Account Auth : ● Active (yourmail@example.com)  │
  ╰──────────────────────────────────────────────────╯

  QUICK ACTIONS
    [1]  Launch Devspace        Start interactive cloud shell
    [2]  Check Connection       Test API token & project list
    [3]  Import Config          Scan Downloads & set crave.conf

  MANAGEMENT & SETUP
    [4]  Full Installation      Install Ubuntu, Crave & tools
    [5]  Update Crave           Fetch latest release from GitHub
    [6]  Repair & Fix           Restore PATH & permissions
    [7]  Account & Details      View quota, server & projects
    [8]  Uninstall              Remove Crave cleanly

    [0]  Exit
```

### Direct CLI Flags

After installation, the `crave` command is available system-wide in Termux:

```bash
# Use Crave directly (works from any directory)
crave list                      # Show your projects
crave run --projectID 79 -- "mka bacon"   # Start a build
crave devspace                  # Launch interactive cloud shell
crave getlog                    # View build logs

# Script CLI shortcuts
./crave-installer-termux.sh -d  # Quick Devspace launch
./crave-installer-termux.sh -t  # Run diagnostics test
./crave-installer-termux.sh -c  # Import crave.conf
./crave-installer-termux.sh -h  # Help
```

---

## How It Works

```
Termux (Android)
    └── ~/bin/crave (wrapper script)
            └── proot-distro login ubuntu
                    ├── /root/crave (binary)        ← Crave CLI
                    └── /root/crave.conf (config)   ← Your API token
```

The wrapper script:
1. Auto-detects your `crave.conf` from the current directory or `~/crave.conf`
2. Binds it into the Ubuntu PRoot container
3. Executes the Crave binary inside Ubuntu with full ARM64 support
4. Passes all your arguments through transparently

---

## File Structure

```
crave-install-termux-manager/
└── crave-installer-termux.sh   ← Main installer & manager script

After install, these are created:
~/bin/crave                     ← Termux CLI wrapper
~/bin/devspace                  ← Devspace shortcut
~/crave.conf                    ← Your Crave credentials
```

---

## Troubleshooting

### `Error: Error checking crave update. Please check crave.conf`

Your API token is **expired**. Fix:
1. Download a fresh `crave.conf` from [foss.crave.io](https://foss.crave.io)
2. Place it in Downloads
3. Run the script and choose **`[3] Import Config`**

### Crave command not found after restart

Run this once in Termux:
```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Or run **`[6] Repair & Fix`** from the menu.

### Config not syncing to Ubuntu container

Run **`[6] Repair & Fix`** — it re-syncs `~/crave.conf` to `/root/crave.conf` inside the Ubuntu container.

---

## Supported Projects on Crave (foss.crave.io)

The following Android projects can be built with Crave:

- LineageOS 16 / 18.1 / 20 / 22.1 / 23.2
- CipherOS
- DerpFest AOSP
- PixelOS
- TWRP
- ROM Dumper
- And more...

---

## Contributing

Pull requests are welcome! If you find a bug or want to add a new feature:

1. Fork the repo
2. Create your branch: `git checkout -b feature/your-feature`
3. Commit changes: `git commit -m 'Add some feature'`
4. Push: `git push origin feature/your-feature`
5. Open a Pull Request

---

## License

[MIT License](LICENSE) — Free to use, modify and distribute.

---

<div align="center">

Made with ❤️ for the Android custom ROM community

**[Report a Bug](https://github.com/pawankumarlabs/crave-install-termux-manager/issues)** · **[Request a Feature](https://github.com/pawankumarlabs/crave-install-termux-manager/issues)**- Internet connection
- Sufficient storage space

Root access is not required.
