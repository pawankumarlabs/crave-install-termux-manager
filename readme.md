# Crave Installer Termux

A simple and powerful manager for installing and managing Crave on Android through Termux and Ubuntu Proot-Distro.

## Overview

Crave Installer Termux simplifies the process of installing and managing Crave on ARM64 Android devices.

The project runs Crave inside an Ubuntu environment managed through Proot-Distro and provides a simple terminal-based manager for handling the Crave installation.

## Features

- Install Crave automatically
- Reinstall Crave when needed
- Update Crave
- Uninstall Crave
- Check installation status
- Interactive terminal-based UI
- Automatic Ubuntu setup

## Requirements

- Android device with ARM64 architecture
- Termux
- Internet connection
- Sufficient storage space

Root access is not required.

## Installation

Clone the repository:

```bash
git clone https://github.com/pawankumarlabs/crave-install-termux-manager.git
cd crave-install-termux-manager
chmod +x crave-installer-termux.sh
./crave-installer-termux.sh