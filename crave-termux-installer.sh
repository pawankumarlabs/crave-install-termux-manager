#!/data/data/com.termux/files/usr/bin/bash

# ==============================================================================
#                       CRAVE BUILD MANAGER FOR TERMUX
#                   Fast, Modern Cloud Build CLI Environment
# ==============================================================================

set -o pipefail

# Configuration Paths & URLs
CRAVE_RELEASE_URL="https://github.com/accupara/crave/releases/download/0.2-7220/crave-0.2-7220-linux-aarch64.bin"
CRAVE_PATH="/root/crave"
BIN_DIR="$HOME/bin"
CRAVE_CMD="$BIN_DIR/crave"
DEVSPACE_CMD="$BIN_DIR/devspace"
CONFIG_FILE="$HOME/crave.conf"
VERSION="2.1.0"

# Professional Color Palette (Clean, high-contrast, terminal-safe)
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

C_CYAN="\033[38;5;51m"
C_BLUE="\033[38;5;75m"
C_GREEN="\033[38;5;48m"
C_YELLOW="\033[38;5;221m"
C_RED="\033[38;5;203m"
C_GRAY="\033[38;5;244m"
C_DARK="\033[38;5;238m"
C_WHITE="\033[38;5;255m"

# Terminal Cursor & Signal Management
cleanup() {
    printf "\033[?25h" # Restore cursor
}
trap cleanup EXIT INT TERM

# ==============================================================================
# UI COMPONENTS
# ==============================================================================

draw_divider() {
    printf "  ${C_DARK}──────────────────────────────────────────────────${RESET}\n"
}

draw_section_header() {
    local title="$1"
    echo
    printf "  ${C_BLUE}──${RESET} ${BOLD}%s${RESET} ${C_DARK}─────────────────────────────────────────${RESET}\n\n" "$title"
}

msg_ok() {
    printf "  ${C_GREEN}✔${RESET}  %s\n" "$1"
}

msg_err() {
    printf "  ${C_RED}✖${RESET}  %s\n" "$1"
}

msg_warn() {
    printf "  ${C_YELLOW}⚠${RESET}  %s\n" "$1"
}

msg_info() {
    printf "  ${C_CYAN}➜${RESET}  %s\n" "$1"
}

msg_bullet() {
    printf "     ${C_GRAY}•${RESET} %s\n" "$1"
}

pause_key() {
    echo
    printf "  ${C_GRAY}Press ${C_WHITE}[Enter]${C_GRAY} to return to main menu...${RESET}"
    read -r _unused
}

# Spinner animation wrapper
run_spinner() {
    local message="$1"
    shift
    local cmd=("$@")

    local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    printf "\033[?25l"

    local tmp_log
    tmp_log="$(mktemp)"
    "${cmd[@]}" >"$tmp_log" 2>&1 &
    local pid=$!

    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i + 1) % 10 ))
        printf "\r  ${C_CYAN}${spin[$i]}${RESET}  %s " "$message"
        sleep 0.1
    done

    wait "$pid"
    local exit_code=$?
    printf "\033[?25h"

    if [ "$exit_code" -eq 0 ]; then
        printf "\r  ${C_GREEN}✔${RESET}  %s               \n" "$message"
        rm -f "$tmp_log"
        return 0
    else
        printf "\r  ${C_RED}✖${RESET}  %s (Failed)      \n" "$message"
        if [ -s "$tmp_log" ]; then
            printf "     ${C_RED}Log:${RESET} %s\n" "$(head -n 2 "$tmp_log")"
        fi
        rm -f "$tmp_log"
        return 1
    fi
}

# ==============================================================================
# ENVIRONMENT CHECKS & VALIDATION
# ==============================================================================

ubuntu_installed() {
    proot-distro login ubuntu -- true >/dev/null 2>&1
}

crave_installed() {
    ubuntu_installed && proot-distro login ubuntu -- test -x "$CRAVE_PATH" >/dev/null 2>&1
}

wrapper_installed() {
    [ -x "$CRAVE_CMD" ]
}

# Fast Python-based config inspector & live token tester
validate_crave_conf() {
    local target="$1"
    if [ ! -f "$target" ]; then
        echo "MISSING||File does not exist"
        return
    fi

    python3 -c "
import json, urllib.request, ssl, sys

path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except Exception as e:
    print(f'CORRUPT||Invalid JSON format')
    sys.exit(0)

username = data.get('username', 'Unknown')
server = data.get('server', '').rstrip('/')
headers = data.get('headers', {})

if not server or not headers.get('Authorization'):
    print(f'INCOMPLETE|{username}|Missing server or token')
    sys.exit(0)

try:
    req = urllib.request.Request(server + '/crave/v1/getCraveVersion', headers=headers)
    ctx = ssl.create_default_context()
    with urllib.request.urlopen(req, timeout=4, context=ctx) as resp:
        res_data = json.loads(resp.read().decode())
        if res_data.get('success'):
            ver = res_data.get('data', {}).get('version', 'OK')
            print(f'VALID|{username}|{ver}')
        else:
            print(f'INVALID|{username}|Server rejected token')
except urllib.error.HTTPError as e:
    if e.code == 401:
        print(f'EXPIRED|{username}|Token Expired (401)')
    else:
        print(f'HTTP_ERR|{username}|HTTP {e.code}')
except Exception as e:
    print(f'NET_ERR|{username}|Offline Check')
" "$target" 2>/dev/null || echo "ERROR||Inspection failed"
}

# Format row inside status card with exact width alignment (Width: 54 chars)
print_status_row() {
    local label="$1"
    local val_color="$2"
    local val_text="$3"
    local total=52
    local prefix="  │  $label : $val_text"
    local pad_len=$(( total - ${#prefix} ))
    [ "$pad_len" -lt 0 ] && pad_len=0
    local pad
    pad=$(printf "%*s" "$pad_len" "")
    printf "  ${C_BLUE}│${RESET}  ${C_GRAY}%s :${RESET} %b%s%b%s ${C_BLUE}│${RESET}\n" "$label" "$val_color" "$val_text" "$RESET" "$pad"
}

# Header Banner
show_header() {
    clear
    printf "\n"
    printf "  ${C_CYAN}${BOLD}CRAVE${RESET} ${C_WHITE}Build Manager${RESET} ${C_DARK}•${RESET} ${C_GRAY}Termux Cloud Suite${RESET} ${C_DARK}(v%s)${RESET}\n" "$VERSION"
    draw_divider
}

# Status Box
show_status_box() {
    # 1. Ubuntu PRoot
    local ub_color="$C_RED"
    local ub_text="● Missing"
    if ubuntu_installed; then
        ub_color="$C_GREEN"
        ub_text="● Ready"
    fi

    # 2. Crave Binary
    local crave_color="$C_RED"
    local crave_text="● Missing"
    if crave_installed; then
        crave_color="$C_GREEN"
        crave_text="● Installed (v0.2-7220)"
    fi

    # 3. CLI Wrapper
    local wrap_color="$C_RED"
    local wrap_text="● Missing"
    if wrapper_installed; then
        wrap_color="$C_GREEN"
        wrap_text="● Active in PATH"
    fi

    # 4. Config & Auth
    local conf_info
    conf_info="$(validate_crave_conf "$CONFIG_FILE")"
    local c_status c_user c_detail
    IFS='|' read -r c_status c_user c_detail <<< "$conf_info"

    # Truncate username cleanly if too long for mobile width
    local display_user="$c_user"
    if [ ${#display_user} -gt 22 ]; then
        display_user="${display_user:0:19}..."
    fi

    local auth_color="$C_RED"
    local auth_text="● Missing"
    case "$c_status" in
        VALID)
            auth_color="$C_GREEN"
            auth_text="● Active (${display_user})"
            ;;
        EXPIRED)
            auth_color="$C_RED"
            auth_text="● Expired Token (${display_user})"
            ;;
        INVALID|INCOMPLETE|CORRUPT)
            auth_color="$C_YELLOW"
            auth_text="● Invalid Config"
            ;;
        NET_ERR)
            auth_color="$C_YELLOW"
            auth_text="● Cached (${display_user})"
            ;;
    esac

    echo
    printf "  ${C_BLUE}╭──${RESET} ${BOLD}SYSTEM STATUS${RESET} ${C_BLUE}─────────────────────────────────╮${RESET}\n"
    print_status_row "Ubuntu PRoot" "$ub_color" "$ub_text"
    print_status_row "Crave CLI   " "$crave_color" "$crave_text"
    print_status_row "CLI Wrapper " "$wrap_color" "$wrap_text"
    print_status_row "Account Auth" "$auth_color" "$auth_text"
    printf "  ${C_BLUE}╰──────────────────────────────────────────────────╯${RESET}\n"
}

# ==============================================================================
# WRAPPER GENERATION
# ==============================================================================

generate_wrappers() {
    mkdir -p "$BIN_DIR"

    # ~/bin/crave
    cat > "$CRAVE_CMD" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

# Crave CLI Termux Wrapper
CONFIG_FILE=""
CRAVE_ARGS=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        -c|--configFile)
            CONFIG_FILE="${2:-}"
            shift 2
            ;;
        *)
            CRAVE_ARGS+=("$1")
            shift
            ;;
    esac
done

# Auto-detect config location
if [ -z "$CONFIG_FILE" ]; then
    if [ -f "./crave.conf" ]; then
        CONFIG_FILE="$(pwd)/crave.conf"
    elif [ -f "$HOME/crave.conf" ]; then
        CONFIG_FILE="$HOME/crave.conf"
    fi
fi

if [ -n "$CONFIG_FILE" ] && [[ "$CONFIG_FILE" != /* ]]; then
    CONFIG_FILE="$(pwd)/$CONFIG_FILE"
fi

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    echo -e "\033[1;31m[ERROR]\033[0m crave.conf not found!"
    echo -e "Please place crave.conf in current directory or Home (~):"
    echo -e "  cp /sdcard/Download/crave.conf* ~/crave.conf"
    echo -e "Or run: \033[1;36mcrave-termux-installer.sh\033[0m to configure automatically."
    exit 1
fi

CURRENT_DIR="$(pwd)"

exec proot-distro login ubuntu \
    --bind "$CONFIG_FILE:/root/crave.conf" \
    -- /bin/bash -c 'cd "$1" && shift && exec /root/crave "$@"' \
    bash "$CURRENT_DIR" "${CRAVE_ARGS[@]}"
EOF

    chmod +x "$CRAVE_CMD"

    # ~/bin/devspace
    cat > "$DEVSPACE_CMD" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec crave devspace "$@"
EOF

    chmod +x "$DEVSPACE_CMD"

    # Setup ~/.bashrc PATH
    touch "$HOME/.bashrc"
    if ! grep -Fq 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc"; then
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
    fi
    export PATH="$BIN_DIR:$PATH"
}

# ==============================================================================
# ACTIONS
# ==============================================================================

# 1. Quick Devspace Launcher
action_launch_devspace() {
    show_header
    draw_section_header "LAUNCH CRAVE DEVSPACE"

    if ! crave_installed || ! wrapper_installed; then
        msg_err "Crave is not installed yet. Please run Install first."
        pause_key
        return 1
    fi

    if [ ! -f "$CONFIG_FILE" ]; then
        msg_err "crave.conf is missing. Please import your config first."
        pause_key
        return 1
    fi

    msg_info "Connecting to Crave Cloud Devspace..."
    msg_bullet "To exit and return to Termux, simply type: ${C_CYAN}exit${RESET}"
    echo
    draw_divider
    echo

    crave devspace "$@"

    echo
    draw_divider
    msg_info "Devspace session disconnected."
    pause_key
}

# 2. Check Connection & Diagnostics
action_diagnostics() {
    show_header
    draw_section_header "SYSTEM & CONNECTION DIAGNOSTICS"

    # Check 1: PRoot Ubuntu
    msg_info "1. Testing PRoot Ubuntu Environment..."
    if ubuntu_installed; then
        msg_ok "Ubuntu PRoot container is active and responsive"
    else
        msg_err "Ubuntu PRoot container is not installed"
    fi

    # Check 2: Binary
    msg_info "2. Testing Crave CLI Binary..."
    if crave_installed; then
        local ver_out
        ver_out="$(proot-distro login ubuntu -- /root/crave version 2>/dev/null || echo "Failed")"
        if [[ "$ver_out" == *"crave"* ]]; then
            msg_ok "Binary verified: ${C_WHITE}$ver_out${RESET}"
        else
            msg_err "Binary failed to run: $ver_out"
        fi
    else
        msg_err "Crave binary missing (/root/crave)"
    fi

    # Check 3: Token authentication
    msg_info "3. Validating crave.conf Authentication..."
    local conf_info
    conf_info="$(validate_crave_conf "$CONFIG_FILE")"
    local status user details
    IFS='|' read -r status user details <<< "$conf_info"

    case "$status" in
        VALID)
            msg_ok "API Authentication Successful!"
            msg_bullet "User Account : ${C_WHITE}${user}${RESET}"
            msg_bullet "Cloud Engine : ${C_WHITE}${details}${RESET}"
            ;;
        EXPIRED)
            msg_err "Authentication Failed: Token is expired (HTTP 401)"
            msg_bullet "User Account : ${user}"
            msg_bullet "Solution     : Download a fresh crave.conf from foss.crave.io"
            ;;
        MISSING)
            msg_err "crave.conf not found at $CONFIG_FILE"
            ;;
        *)
            msg_warn "API check: $status ($details)"
            ;;
    esac

    # Check 4: Live query (crave list)
    if [ "$status" = "VALID" ] && crave_installed && wrapper_installed; then
        echo
        msg_info "4. Fetching Cloud Project List (crave list)..."
        local list_out
        list_out="$(crave list 2>&1)"
        if [[ "$list_out" == *"Configured Projects"* ]] || [[ "$list_out" == *"Projects"* ]]; then
            msg_ok "Server returned project list successfully"
            echo
            printf "${C_GRAY}%s${RESET}\n" "$list_out" | head -n 14
        else
            msg_warn "Server response:"
            printf "${C_GRAY}%s${RESET}\n" "$list_out" | head -n 8
        fi
    fi

    echo
    draw_divider
    pause_key
}

# 3. Import Config (crave.conf)
action_import_config() {
    show_header
    draw_section_header "SETUP / IMPORT CRAVE.CONF"

    msg_info "Scanning for crave.conf files..."

    local found_files=()
    while IFS= read -r line; do
        [ -n "$line" ] && found_files+=("$line")
    done < <(python3 -c "
import os, glob

search_dirs = [
    '/sdcard/Download',
    '/storage/emulated/0/Download',
    os.path.expanduser('~/storage/downloads'),
    os.path.expanduser('~'),
    '.'
]

found = []
for d in search_dirs:
    if os.path.isdir(d):
        for pattern in ['*crave*.conf*', '*crave.conf*']:
            for p in glob.glob(os.path.join(d, pattern)):
                abs_p = os.path.abspath(p)
                if os.path.isfile(abs_p) and abs_p not in found:
                    found.append(abs_p)

for f in found:
    print(f)
")

    local selected_file=""

    if [ ${#found_files[@]} -gt 0 ]; then
        printf "\n  ${C_WHITE}Found %d configuration file(s):${RESET}\n" "${#found_files[@]}"
        local idx=1
        for f in "${found_files[@]}"; do
            local f_size
            f_size="$(wc -c < "$f" 2>/dev/null || echo 0)"
            printf "    ${C_CYAN}[%d]${RESET} %s ${C_DARK}(%s B)${RESET}\n" "$idx" "$f" "$f_size"
            idx=$((idx + 1))
        done
        printf "    ${C_YELLOW}[M]${RESET} Enter custom file path manually\n"
        printf "    ${C_DARK}[C]  Cancel${RESET}\n\n"

        printf "  ${BOLD}Select file [1-%d/M/C]: ${RESET}" "${#found_files[@]}"
        read -r sel

        case "$sel" in
            [0-9]*)
                if [ "$sel" -ge 1 ] && [ "$sel" -le "${#found_files[@]}" ]; then
                    selected_file="${found_files[$((sel - 1))]}"
                else
                    msg_err "Invalid selection."
                    pause_key
                    return 1
                fi
                ;;
            m|M)
                printf "  Enter path to crave.conf: "
                read -r selected_file
                ;;
            *)
                msg_info "Cancelled."
                pause_key
                return 0
                ;;
        esac
    else
        msg_warn "No crave.conf found in Downloads automatically."
        printf "  Please enter the full path to your crave.conf:\n"
        printf "  Path: "
        read -r selected_file
    fi

    if [ -z "$selected_file" ] || [ ! -f "$selected_file" ]; then
        msg_err "File not found: $selected_file"
        pause_key
        return 1
    fi

    echo
    msg_info "Verifying file: $selected_file..."

    local validation
    validation="$(validate_crave_conf "$selected_file")"
    local status user details
    IFS='|' read -r status user details <<< "$validation"

    case "$status" in
        VALID)
            msg_ok "Token is valid! Account: ${C_WHITE}${user}${RESET}"
            ;;
        EXPIRED)
            msg_err "Token in this file is EXPIRED (401 Unauthorized)."
            msg_bullet "Account: $user"
            msg_warn "Please download a fresh crave.conf from foss.crave.io"
            printf "\n  Do you still want to copy it? [y/N]: "
            read -r force_copy
            case "$force_copy" in
                y|Y) ;;
                *) pause_key; return 1 ;;
            esac
            ;;
        CORRUPT|INCOMPLETE)
            msg_err "File format error: $details"
            pause_key
            return 1
            ;;
        *)
            msg_warn "Live check unavailable ($details). Importing file."
            ;;
    esac

    # Copy to Termux Home
    cp "$selected_file" "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    msg_ok "Config saved to $CONFIG_FILE"

    # Sync into Ubuntu PRoot
    if ubuntu_installed; then
        proot-distro login ubuntu -- bash -c "cp '$CONFIG_FILE' /root/crave.conf && chmod 600 /root/crave.conf" >/dev/null 2>&1
        msg_ok "Synced to PRoot environment (/root/crave.conf)"
    fi

    generate_wrappers

    echo
    draw_divider
    printf "  ${C_GREEN}${BOLD}✔ Configuration active and ready!${RESET}\n"
    draw_divider
    pause_key
}

# 4. Full Installation
action_full_install() {
    show_header
    draw_section_header "FULL CRAVE INSTALLATION"

    # 1. Base packages
    msg_info "Checking Termux base packages..."
    local needed_pkgs=()
    command -v proot-distro >/dev/null 2>&1 || needed_pkgs+=("proot-distro")
    command -v curl >/dev/null 2>&1 || needed_pkgs+=("curl")
    command -v wget >/dev/null 2>&1 || needed_pkgs+=("wget")
    command -v python3 >/dev/null 2>&1 || needed_pkgs+=("python")

    if [ ${#needed_pkgs[@]} -gt 0 ]; then
        msg_info "Installing dependencies: ${needed_pkgs[*]}..."
        pkg update -y >/dev/null 2>&1
        pkg install -y "${needed_pkgs[@]}"
        msg_ok "Termux packages installed"
    else
        msg_ok "Termux packages already up to date"
    fi

    # 2. Storage
    if [ ! -d "$HOME/storage" ]; then
        msg_info "Requesting Android storage permission..."
        termux-setup-storage >/dev/null 2>&1
        sleep 1
    fi

    # 3. Ubuntu PRoot
    msg_info "Checking Ubuntu PRoot environment..."
    if ubuntu_installed; then
        msg_ok "Ubuntu PRoot container is already installed"
    else
        msg_info "Installing Ubuntu PRoot container (takes ~1 minute)..."
        proot-distro install ubuntu
        if ! ubuntu_installed; then
            msg_err "Ubuntu PRoot installation failed."
            pause_key
            return 1
        fi
        msg_ok "Ubuntu PRoot container installed successfully"
    fi

    # 4. Ubuntu dependencies
    msg_info "Configuring Ubuntu build dependencies..."
    run_spinner "Updating Ubuntu package index" proot-distro login ubuntu -- apt update -y
    run_spinner "Installing build tools (wget, rsync, git, curl, ca-certificates)" \
        proot-distro login ubuntu -- apt install -y wget rsync git curl ca-certificates

    # 5. Crave binary
    msg_info "Installing Crave CLI (aarch64)..."
    if crave_installed; then
        msg_ok "Crave binary is already installed (/root/crave)"
    else
        run_spinner "Downloading Crave 0.2-7220 binary" \
            proot-distro login ubuntu -- bash -c "wget -q '$CRAVE_RELEASE_URL' -O '$CRAVE_PATH' && chmod +x '$CRAVE_PATH'"
        if crave_installed; then
            msg_ok "Crave binary installed and verified"
        else
            msg_err "Failed to download Crave binary."
            pause_key
            return 1
        fi
    fi

    # 6. Wrappers
    msg_info "Setting up Termux commands (~/bin/crave, ~/bin/devspace)..."
    generate_wrappers
    msg_ok "Wrappers created & PATH configured"

    # 7. Check config
    local conf_info
    conf_info="$(validate_crave_conf "$CONFIG_FILE")"
    local c_status
    IFS='|' read -r c_status _ _ <<< "$conf_info"

    if [ "$c_status" = "VALID" ]; then
        msg_ok "Existing crave.conf is authenticated and ready!"
    else
        echo
        printf "  ${C_YELLOW}⚠ crave.conf needs to be imported.${RESET}\n"
        printf "  Would you like to import it now? [Y/n]: "
        read -r do_conf
        case "$do_conf" in
            n|N) ;;
            *) action_import_config ;;
        esac
    fi

    echo
    draw_divider
    printf "  ${C_GREEN}${BOLD}🎉 Installation Completed Successfully!${RESET}\n"
    printf "  You can now use ${C_CYAN}crave list${RESET} or ${C_CYAN}devspace${RESET} anywhere.\n"
    draw_divider
    pause_key
}

# 5. Update Crave Binary
action_update_crave() {
    show_header
    draw_section_header "UPDATE CRAVE BINARY"

    if ! ubuntu_installed; then
        msg_err "Ubuntu PRoot is not installed."
        pause_key
        return 1
    fi

    msg_info "Downloading latest Crave aarch64 binary..."
    run_spinner "Updating Crave binary" \
        proot-distro login ubuntu -- bash -c "
            rm -f '$CRAVE_PATH.new' &&
            wget -q '$CRAVE_RELEASE_URL' -O '$CRAVE_PATH.new' &&
            chmod +x '$CRAVE_PATH.new' &&
            mv '$CRAVE_PATH.new' '$CRAVE_PATH'
        "

    if crave_installed; then
        generate_wrappers
        msg_ok "Crave updated successfully!"
    else
        msg_err "Update failed."
    fi

    draw_divider
    pause_key
}

# 6. Repair Environment
action_repair_env() {
    show_header
    draw_section_header "REPAIR ENVIRONMENT & PERMISSIONS"

    msg_info "Regenerating command wrappers..."
    generate_wrappers
    msg_ok "Wrappers recreated: $CRAVE_CMD, $DEVSPACE_CMD"

    msg_info "Fixing permissions..."
    chmod +x "$BIN_DIR"/* 2>/dev/null
    [ -f "$CONFIG_FILE" ] && chmod 600 "$CONFIG_FILE"
    msg_ok "Permissions corrected"

    if [ -f "$CONFIG_FILE" ] && ubuntu_installed; then
        msg_info "Syncing crave.conf into Ubuntu container..."
        proot-distro login ubuntu -- bash -c "cp '$CONFIG_FILE' /root/crave.conf && chmod 600 /root/crave.conf" >/dev/null 2>&1
        msg_ok "Config synced (/root/crave.conf)"
    fi

    echo
    draw_divider
    printf "  ${C_GREEN}${BOLD}✔ Environment repaired!${RESET}\n"
    draw_divider
    pause_key
}

# 7. Account & System Details
action_account_details() {
    show_header
    draw_section_header "ACCOUNT & SYSTEM DETAILS"

    if [ -f "$CONFIG_FILE" ]; then
        python3 -c "
import json

try:
    with open('$CONFIG_FILE') as f:
        d = json.load(f)
    print('  \033[1;97mAccount Information:\033[0m')
    print(f'    \033[38;5;244mUsername :\033[0m {d.get(\"username\", \"N/A\")}')
    print(f'    \033[38;5;244mServer   :\033[0m {d.get(\"server\", \"N/A\")}')
    print(f'    \033[38;5;244mProjects :\033[0m {len(d.get(\"projects\", []))} configured')
    auth = d.get('headers', {}).get('Authorization', '')
    if auth:
        print(f'    \033[38;5;244mToken    :\033[0m {auth[:20]}... (Length: {len(auth)})')
except Exception as e:
    print(f'  Error: {e}')
"
    else
        msg_warn "No crave.conf found."
    fi

    echo
    printf "  ${C_WHITE}${BOLD}System Details:${RESET}\n"
    printf "    ${C_GRAY}Architecture :${RESET} %s\n" "$(uname -m)"
    printf "    ${C_GRAY}Home Storage :${RESET} %s free\n" "$(df -h "$HOME" | awk 'NR==2 {print $4}')"

    if ubuntu_installed; then
        printf "\n  ${C_WHITE}${BOLD}Ubuntu Environment:${RESET}\n"
        printf "    ${C_GRAY}Distro OS    :${RESET} %s\n" "$(proot-distro login ubuntu -- lsb_release -ds 2>/dev/null || echo "Ubuntu")"
        if crave_installed; then
            printf "    ${C_GRAY}Crave CLI    :${RESET} %s\n" "$(proot-distro login ubuntu -- /root/crave version 2>/dev/null || echo "v0.2-7220")"
        fi
    fi

    echo
    draw_divider
    pause_key
}

# 8. Uninstall
action_uninstall() {
    show_header
    draw_section_header "UNINSTALL CRAVE"

    msg_warn "This will remove the Crave CLI binary and wrappers."
    printf "  Continue? [y/N]: "
    read -r confirm
    case "$confirm" in
        y|Y) ;;
        *) msg_info "Cancelled."; pause_key; return 0 ;;
    esac

    echo
    msg_info "Removing Crave binaries and wrappers..."
    if ubuntu_installed; then
        proot-distro login ubuntu -- rm -f "$CRAVE_PATH"
    fi
    rm -f "$CRAVE_CMD" "$DEVSPACE_CMD"
    msg_ok "Crave CLI removed"

    printf "\n  Delete crave.conf as well? [y/N]: "
    read -r del_conf
    case "$del_conf" in
        y|Y)
            rm -f "$CONFIG_FILE"
            msg_ok "Deleted $CONFIG_FILE"
            ;;
    esac

    printf "\n  Remove Ubuntu PRoot container as well? [y/N]: "
    read -r del_ub
    case "$del_ub" in
        y|Y)
            msg_info "Removing Ubuntu container..."
            proot-distro remove ubuntu
            msg_ok "Ubuntu container removed"
            ;;
    esac

    echo
    draw_divider
    msg_ok "Uninstall completed."
    draw_divider
    pause_key
}

# ==============================================================================
# MAIN MENU LOOP
# ==============================================================================

main_menu() {
    while true; do
        show_header
        show_status_box

        echo
        printf "  ${C_WHITE}${BOLD}QUICK ACTIONS${RESET}\n"
        printf "    ${C_CYAN}[1]${RESET}  ${C_WHITE}Launch Devspace${RESET}        ${C_GRAY}Start interactive cloud shell${RESET}\n"
        printf "    ${C_CYAN}[2]${RESET}  ${C_WHITE}Check Connection${RESET}       ${C_GRAY}Test API token & project list${RESET}\n"
        printf "    ${C_CYAN}[3]${RESET}  ${C_WHITE}Import Config${RESET}          ${C_GRAY}Scan Downloads & set crave.conf${RESET}\n"
        echo
        printf "  ${C_WHITE}${BOLD}MANAGEMENT & SETUP${RESET}\n"
        printf "    ${C_CYAN}[4]${RESET}  ${C_WHITE}Full Installation${RESET}      ${C_GRAY}Install Ubuntu, Crave & tools${RESET}\n"
        printf "    ${C_CYAN}[5]${RESET}  ${C_WHITE}Update Crave${RESET}           ${C_GRAY}Fetch latest release from GitHub${RESET}\n"
        printf "    ${C_CYAN}[6]${RESET}  ${C_WHITE}Repair & Fix${RESET}           ${C_GRAY}Restore PATH & permissions${RESET}\n"
        printf "    ${C_CYAN}[7]${RESET}  ${C_WHITE}Account & Details${RESET}      ${C_GRAY}View quota, server & projects${RESET}\n"
        printf "    ${C_RED}[8]${RESET}  ${C_WHITE}Uninstall${RESET}              ${C_GRAY}Remove Crave cleanly${RESET}\n"
        echo
        printf "    ${C_DARK}[0]  Exit${RESET}\n"

        draw_divider
        printf "  ${BOLD}Select an option [0-8]: ${RESET}"
        read -r choice

        case "$choice" in
            1) action_launch_devspace ;;
            2) action_diagnostics ;;
            3) action_import_config ;;
            4) action_full_install ;;
            5) action_update_crave ;;
            6) action_repair_env ;;
            7) action_account_details ;;
            8) action_uninstall ;;
            0|q|Q)
                clear
                echo
                printf "  ${C_CYAN}${BOLD}Crave Manager closed.${RESET}\n"
                printf "  ${C_GRAY}Type ${C_CYAN}crave-termux-installer.sh${C_GRAY} anytime to reopen.${RESET}\n\n"
                exit 0
                ;;
            *)
                msg_err "Invalid selection. Please choose 0 to 8."
                sleep 1
                ;;
        esac
    done
}

# CLI Argument handling (e.g. ./crave-termux-installer.sh --devspace)
case "${1:-}" in
    -d|--devspace)
        action_launch_devspace
        exit $?
        ;;
    -t|--test|--diagnostics)
        action_diagnostics
        exit $?
        ;;
    -c|--config|--import)
        action_import_config
        exit $?
        ;;
    -i|--install)
        action_full_install
        exit $?
        ;;
    -h|--help)
        echo "Usage: crave-termux-installer.sh [option]"
        echo "  (no args)       Open interactive menu"
        echo "  -d, --devspace  Quick launch Crave devspace"
        echo "  -t, --test      Run connection & diagnostics test"
        echo "  -c, --config    Import/configure crave.conf"
        echo "  -i, --install   Run automated full installation"
        echo "  -h, --help      Show this help message"
        exit 0
        ;;
    *)
        if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
            main_menu
        fi
        ;;
esac
