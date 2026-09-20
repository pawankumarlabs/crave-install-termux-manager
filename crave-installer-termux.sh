#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
#                 CRAVE TERMUX MANAGER
# ============================================================

CRAVE_URL="https://github.com/accupara/crave/releases/download/0.2-7220/crave-0.2-7220-linux-aarch64.bin"

CRAVE_PATH="/root/crave"
BIN_DIR="$HOME/bin"
CRAVE_CMD="$BIN_DIR/crave"

# ============================================================
# COLORS
# ============================================================

RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

WHITE="\033[97m"
GRAY="\033[90m"
GREEN="\033[92m"
RED="\033[91m"
YELLOW="\033[93m"
CYAN="\033[96m"
BLUE="\033[94m"

# ============================================================
# TERMINAL
# ============================================================

cleanup() {
    printf "\033[?25h"
}

trap cleanup EXIT INT TERM

# ============================================================
# UI
# ============================================================

separator() {
    printf "${GRAY}────────────────────────────────────────────────────${RESET}\n"
}

small_separator() {
    printf "${GRAY}────────────────────────────${RESET}\n"
}

success() {
    printf "  ${GREEN}●${RESET} %s\n" "$1"
}

failed() {
    printf "  ${RED}●${RESET} %s\n" "$1"
}

info() {
    printf "  ${CYAN}›${RESET} %s\n" "$1"
}

warning() {
    printf "  ${YELLOW}●${RESET} %s\n" "$1"
}

pause_screen() {
    echo
    printf "${DIM}Press ENTER to return...${RESET}"
    read -r
}

# ============================================================
# HEADER
# ============================================================

header() {

    clear

    echo

    printf "${CYAN}${BOLD}"
    echo "   ██████╗██████╗  █████╗ ██╗   ██╗███████╗"
    echo "  ██╔════╝██╔══██╗██╔══██╗██║   ██║██╔════╝"
    echo "  ██║     ██████╔╝███████║██║   ██║█████╗  "
    echo "  ██║     ██╔══██╗██╔══██║╚██╗ ██╔╝██╔══╝  "
    echo "  ╚██████╗██║  ██║██║  ██║ ╚████╔╝ ███████╗"
    echo "   ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝"
    printf "${RESET}"

    echo
    printf "${GRAY}Termux Manager${RESET}"
    printf "  ${DIM}•${RESET}  ${GRAY}Crave Build Environment${RESET}"

    echo
    echo
}

# ============================================================
# CHECK UBUNTU
# ============================================================

ubuntu_exists() {

    proot-distro login ubuntu -- true >/dev/null 2>&1
}

# ============================================================
# CHECK CRAVE
# ============================================================

crave_exists() {

    ubuntu_exists &&
    proot-distro login ubuntu -- test -x "$CRAVE_PATH" >/dev/null 2>&1
}

# ============================================================
# CHECK WRAPPER
# ============================================================

wrapper_exists() {

    [ -x "$CRAVE_CMD" ]
}

# ============================================================
# STATUS BAR
# ============================================================

status_bar() {

    if ubuntu_exists
    then
        ubuntu_status="${GREEN}● Ready${RESET}"
    else
        ubuntu_status="${RED}● Missing${RESET}"
    fi

    if crave_exists
    then
        crave_status="${GREEN}● Installed${RESET}"
    else
        crave_status="${RED}● Missing${RESET}"
    fi

    if wrapper_exists
    then
        cli_status="${GREEN}● Ready${RESET}"
    else
        cli_status="${RED}● Missing${RESET}"
    fi

    printf "${GRAY}Environment${RESET}  ${ubuntu_status}"
    printf "    ${GRAY}Crave${RESET}  ${crave_status}"
    printf "    ${GRAY}CLI${RESET}  ${cli_status}"

    echo
    echo
}

# ============================================================
# CREATE TERMUX CRAVE COMMAND
# ============================================================

create_wrapper() {

    mkdir -p "$BIN_DIR"

    cat > "$CRAVE_CMD" <<'WRAPPER'
#!/data/data/com.termux/files/usr/bin/bash

exec proot-distro login ubuntu -- /root/crave "$@"
WRAPPER

    chmod +x "$CRAVE_CMD"

    touch "$HOME/.bashrc"

    if ! grep -Fq 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc"
    then
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
    fi

    export PATH="$BIN_DIR:$PATH"
}

# ============================================================
# INSTALL
# ============================================================

install_crave() {

    header

    printf "${WHITE}${BOLD}INSTALL${RESET}\n"
    separator
    echo

    info "Checking proot-distro..."

    pkg install proot-distro -y

    success "proot-distro ready"

    echo
    info "Checking Ubuntu..."

    if ubuntu_exists
    then

        success "Ubuntu environment detected"

    else

        warning "Ubuntu environment not found"

        echo
        info "Installing Ubuntu..."

        proot-distro install ubuntu

        if ! ubuntu_exists
        then
            failed "Ubuntu installation failed"
            pause_screen
            return
        fi

        success "Ubuntu installed"
    fi

    echo
    info "Updating Ubuntu packages..."

    proot-distro login ubuntu -- apt update -y

    success "Package lists updated"

    echo
    info "Installing dependencies..."

    proot-distro login ubuntu -- apt install wget rsync -y

    success "Dependencies ready"

    echo
    info "Checking Crave..."

    if crave_exists
    then

        warning "Crave is already installed"

    else

        info "Downloading Crave..."

        proot-distro login ubuntu -- bash -c "
            wget '$CRAVE_URL' -O '$CRAVE_PATH' &&
            chmod +x '$CRAVE_PATH'
        "

        if crave_exists
        then
            success "Crave installed"
        else
            failed "Crave installation failed"
            pause_screen
            return
        fi

    fi

    echo
    info "Creating Termux command..."

    create_wrapper

    success "Command 'crave' is ready"

    echo
    separator
    echo

    printf "${GREEN}${BOLD}Installation completed successfully.${RESET}\n"

    echo
    printf "${WHITE}Command:${RESET}\n"
    echo
    printf "  ${CYAN}crave -c crave.conf${RESET}\n"
    printf "  ${CYAN}crave devspace${RESET}\n"

    echo
    separator

    pause_screen
}

# ============================================================
# REINSTALL
# ============================================================

reinstall_crave() {

    header

    printf "${WHITE}${BOLD}REINSTALL${RESET}\n"
    separator
    echo

    if ! ubuntu_exists
    then
        failed "Ubuntu is not installed"
        pause_screen
        return
    fi

    warning "Existing Crave binary will be replaced."

    echo
    printf "${YELLOW}Continue? [y/N]: ${RESET}"
    read -r confirm

    case "$confirm" in

        y|Y)
            ;;

        *)
            info "Cancelled"
            pause_screen
            return
            ;;

    esac

    echo
    info "Removing existing Crave..."

    proot-distro login ubuntu -- rm -f "$CRAVE_PATH"

    success "Old binary removed"

    echo
    info "Downloading Crave..."

    proot-distro login ubuntu -- bash -c "
        wget '$CRAVE_URL' -O '$CRAVE_PATH' &&
        chmod +x '$CRAVE_PATH'
    "

    if crave_exists
    then
        success "Crave reinstalled"
    else
        failed "Reinstallation failed"
        pause_screen
        return
    fi

    create_wrapper

    echo
    separator
    echo

    printf "${GREEN}${BOLD}Reinstallation completed successfully.${RESET}\n"

    echo
    printf "${WHITE}Command:${RESET}\n"
    echo
    printf "  ${CYAN}crave -c crave.conf${RESET}\n"
    printf "  ${CYAN}crave devspace${RESET}\n"

    echo
    separator

    pause_screen
}

# ============================================================
# UPDATE
# ============================================================

update_crave() {

    header

    printf "${WHITE}${BOLD}UPDATE${RESET}\n"
    separator
    echo

    if ! ubuntu_exists
    then
        failed "Ubuntu is not installed"
        pause_screen
        return
    fi

    info "Downloading updated Crave..."

    proot-distro login ubuntu -- bash -c "

        rm -f '$CRAVE_PATH.new'

        wget '$CRAVE_URL' -O '$CRAVE_PATH.new'

        if [ \$? -eq 0 ]
        then

            chmod +x '$CRAVE_PATH.new'
            mv '$CRAVE_PATH.new' '$CRAVE_PATH'

        else

            rm -f '$CRAVE_PATH.new'
            exit 1

        fi
    "

    if crave_exists
    then
        success "Crave updated successfully"
    else
        failed "Update failed"
        pause_screen
        return
    fi

    create_wrapper

    echo
    separator
    echo

    printf "${GREEN}${BOLD}Update completed successfully.${RESET}\n"

    echo
    printf "${WHITE}Command:${RESET}\n"
    echo
    printf "  ${CYAN}crave -c crave.conf${RESET}\n"
    printf "  ${CYAN}crave devspace${RESET}\n"

    echo
    separator

    pause_screen
}

# ============================================================
# UNINSTALL
# ============================================================

uninstall_crave() {

    header

    printf "${WHITE}${BOLD}UNINSTALL${RESET}\n"
    separator
    echo

    warning "Crave will be removed."
    printf "${GRAY}Ubuntu will remain installed.${RESET}\n"

    echo
    printf "${YELLOW}Continue? [y/N]: ${RESET}"
    read -r confirm

    case "$confirm" in

        y|Y)
            ;;

        *)
            info "Cancelled"
            pause_screen
            return
            ;;

    esac

    echo
    info "Removing Crave..."

    if ubuntu_exists
    then
        proot-distro login ubuntu -- rm -f "$CRAVE_PATH"
    fi

    rm -f "$CRAVE_CMD"

    success "Crave removed"
    success "Termux command removed"

    echo
    separator
    echo

    printf "${GREEN}${BOLD}Crave uninstalled successfully.${RESET}\n"
    printf "${GRAY}Ubuntu environment was preserved.${RESET}\n"

    echo
    separator

    pause_screen
}

# ============================================================
# STATUS
# ============================================================

status_crave() {

    header

    printf "${WHITE}${BOLD}SYSTEM STATUS${RESET}\n"
    separator
    echo

    status_bar

    if crave_exists
    then

        printf "${WHITE}${BOLD}CRAVE DETAILS${RESET}\n"
        small_separator
        echo

        printf "  ${GRAY}Path${RESET}          /root/crave\n"

        printf "  ${GRAY}Architecture${RESET}  "
        proot-distro login ubuntu -- uname -m

        printf "  ${GRAY}Binary${RESET}        "
        proot-distro login ubuntu -- ls -lh "$CRAVE_PATH" | awk '{print $5}'

        echo

    fi

    separator

    pause_screen
}

# ============================================================
# MAIN MENU
# ============================================================

while true
do

    header

    status_bar

    printf "${WHITE}${BOLD}MANAGE CRAVE${RESET}\n"
    echo

    printf "  ${CYAN}1${RESET}  Install\n"
    printf "  ${CYAN}2${RESET}  Reinstall\n"
    printf "  ${CYAN}3${RESET}  Update\n"
    printf "  ${CYAN}4${RESET}  Uninstall\n"
    printf "  ${CYAN}5${RESET}  System Status\n"
    printf "  ${RED}6${RESET}  Exit\n"

    echo
    separator
    echo

    printf "${BOLD}Select [1-6]: ${RESET}"
    read -r choice

    case "$choice" in

        1)
            install_crave
            ;;

        2)
            reinstall_crave
            ;;

        3)
            update_crave
            ;;

        4)
            uninstall_crave
            ;;

        5)
            status_crave
            ;;

        6)

            clear

            echo
            printf "${CYAN}${BOLD}Crave Manager closed.${RESET}\n"
            printf "${GRAY}Termux session remains active.${RESET}\n"
            echo

            break
            ;;

        *)

            printf "${RED}Invalid option.${RESET}\n"
            sleep 1
            ;;

    esac

done
