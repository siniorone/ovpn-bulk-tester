#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║           OpenVPN Bulk Tester v3.2  —  Linux Edition            ║
# ╚══════════════════════════════════════════════════════════════════╝

OVPN_DIR="${1:-configs}"
USERNAME="${OVPN_USER:-}"
PASSWORD="${OVPN_PASS:-}"
AUTH_FILE="/tmp/ovpn_auth_$$"
GOOD_FILE="working.txt"
LOG_FILE="test.log"
DETAIL_LOG="detail.log"
RESULTS_DIR="results"
CONNECT_TIMEOUT=20
SPEED_TEST_MB=5
SPEED_TEST=true
PASSED=0
FAILED=0

RED=$'\e[91m'; GREEN=$'\e[92m'; YELLOW=$'\e[93m'; CYAN=$'\e[96m'
BLUE=$'\e[94m'; MAGENTA=$'\e[95m'; WHITE=$'\e[97m'; GRAY=$'\e[90m'
BOLD=$'\e[1m'; RESET=$'\e[0m'
BG_GREEN=$'\e[42m\e[30m'; BG_RED=$'\e[41m\e[30m'
OK="✔"; FAIL="✘"; ARROW="➜"; BULLET="•"; SPEED="⚡"

log()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"    2>/dev/null || true; }
log_d() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$DETAIL_LOG"  2>/dev/null || true; }
hr()    { printf "${GRAY}%s${RESET}\n" "──────────────────────────────────────────────────────"; }

cleanup() {
    kill_openvpn
    rm -f "$AUTH_FILE" "/tmp/ovpn_temp_$$.log" "/tmp/ovpn_pid_$$.pid" 2>/dev/null || true
    tput cnorm 2>/dev/null || true
}
trap cleanup EXIT INT TERM

kill_openvpn() {
    local pid=""
    if [[ -f "/tmp/ovpn_pid_$$.pid" ]]; then
        pid=$(cat "/tmp/ovpn_pid_$$.pid" 2>/dev/null || true)
    fi
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        sudo kill "$pid" 2>/dev/null || true
        sleep 1
        kill -0 "$pid" 2>/dev/null && sudo kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "/tmp/ovpn_pid_$$.pid" 2>/dev/null || true
    sudo pkill -f "openvpn" 2>/dev/null || true
    sleep 0.5
}

check_deps() {
    clear; echo
    echo "${CYAN}${BOLD}  ▸ Checking Dependencies${RESET}"; echo
    local missing=()
    for t in openvpn curl ip awk grep; do
        if command -v "$t" &>/dev/null; then
            echo "  ${GREEN}${OK}${RESET}  $t"
        else
            echo "  ${RED}${FAIL}${RESET}  $t ${RED}(missing)${RESET}"
            missing+=("$t")
        fi
    done
    echo
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "  ${YELLOW}Missing: ${missing[*]}${RESET}"; echo
        printf "  ${CYAN}Install now? [Y/n]: ${RESET}"; read -r ans || ans="y"
        [[ "${ans,,}" != "n" ]] && install_deps "${missing[@]}"
    else
        echo "  ${GREEN}All dependencies OK.${RESET}"
    fi
    echo; read -rp "  Press Enter to return..." _ || true; show_menu
}

install_deps() {
    local pkgs=("$@"); echo
    echo "  ${CYAN}${ARROW} Detecting package manager...${RESET}"
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq 2>/dev/null || true
        sudo apt-get install -y "${pkgs[@]}" 2>&1 | tail -5
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y "${pkgs[@]}" 2>&1 | tail -5
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm "${pkgs[@]}" 2>&1 | tail -5
    else
        echo "  ${RED}Cannot detect package manager. Install manually: ${pkgs[*]}${RESET}"; return 1
    fi
    echo "  ${GREEN}${OK} Done.${RESET}"
}

uninstall_deps() {
    clear; echo
    echo "${CYAN}${BOLD}  ▸ Remove OpenVPN${RESET}"; echo
    printf "  ${CYAN}Continue? [y/N]: ${RESET}"; read -r ans || ans="n"
    if [[ "${ans,,}" == "y" ]]; then
        if command -v apt-get &>/dev/null; then sudo apt-get remove -y openvpn 2>&1 | tail -3
        elif command -v dnf &>/dev/null;     then sudo dnf remove -y openvpn 2>&1 | tail -3
        elif command -v pacman &>/dev/null;  then sudo pacman -R --noconfirm openvpn 2>&1 | tail -3
        fi
        echo "  ${GREEN}${OK} Removed.${RESET}"
    else
        echo "  Aborted."
    fi
    echo; read -rp "  Press Enter to return..." _ || true; show_menu
}

print_banner() {
    clear; echo
    echo "${CYAN}${BOLD}  ╔══════════════════════════════════════════════════════════╗${RESET}"
    echo "${CYAN}${BOLD}  ║   ${WHITE}⬡  OpenVPN Bulk Tester  v3.2  —  Linux Edition  ⬡      ${CYAN}║${RESET}"
    echo "${CYAN}${BOLD}  ╚══════════════════════════════════════════════════════════╝${RESET}"; echo
}

draw_progress() {
    local cur=$1 tot=$2 width=40
    local filled=$(( tot > 0 ? cur * width / tot : 0 ))
    local empty=$(( width - filled ))
    local pct=$(( tot > 0 ? cur * 100 / tot : 0 ))
    printf "  ${CYAN}["
    printf "${GREEN}"; printf '█%.0s' $(seq 1 $filled) 2>/dev/null || true
    printf "${GRAY}";  printf '░%.0s' $(seq 1 $empty)  2>/dev/null || true
    printf "${CYAN}]${RESET} ${BOLD}%3d%%${RESET} ${GRAY}(%d/%d)${RESET}\n" "$pct" "$cur" "$tot"
}

print_config_header() {
    local name=$1 idx=$2 total=$3
    clear; print_banner
    echo "  ${BOLD}${WHITE}Testing Config ${idx} of ${total}${RESET}"
    echo "  ${ARROW} ${CYAN}${BOLD}${name}${RESET}"; echo
    draw_progress "$idx" "$total"; echo
    echo "  ${GREEN}${OK} Connected: ${BOLD}${PASSED}${RESET}   ${RED}${FAIL} Failed: ${BOLD}${FAILED}${RESET}"; echo
    hr; echo
}

show_live_log() {
    local logfile=$1 elapsed=$2
    local last=""
    [[ -f "$logfile" ]] && last=$(grep -v '^[[:space:]]*$' "$logfile" 2>/dev/null | tail -1 || true)
    local color="${GRAY}"
    echo "$last" | grep -qi "error\|failed\|denied"    2>/dev/null && color="${RED}"
    echo "$last" | grep -qi "tls\|cipher\|handshake"   2>/dev/null && color="${MAGENTA}"
    echo "$last" | grep -qi "tcp\|udp\|connecting\|peer" 2>/dev/null && color="${CYAN}"
    printf "  ${GRAY}[%02ds]${RESET} ${color}%-80s${RESET}\n" "$elapsed" "${last:0:80}"
}

run_speed_test() {
    local url="https://speed.cloudflare.com/__down?bytes=$((SPEED_TEST_MB * 1024 * 1024))"
    local result
    result=$(curl -s -o /dev/null -w "%{speed_download}" --max-time 15 --connect-timeout 5 "$url" 2>/dev/null || echo "0")
    awk "BEGIN {printf \"%.2f\", ${result:-0} * 8 / 1000000}"
}

get_external_ip() {
    curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo "unknown"
}

get_assigned_ip() {
    local logfile=$1
    grep -oE 'ifconfig [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$logfile" 2>/dev/null \
        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "N/A"
}

get_fail_reason() {
    local logfile=$1
    local reason="Timeout (${CONNECT_TIMEOUT}s)"
    [[ ! -f "$logfile" ]] && echo "$reason" && return
    grep -qi "AUTH_FAILED"         "$logfile" 2>/dev/null && reason="Authentication Failed"
    grep -qi "TLS Error"           "$logfile" 2>/dev/null && reason="TLS Handshake Error"
    grep -qi "Connection refused"  "$logfile" 2>/dev/null && reason="Connection Refused"
    grep -qi "Network unreachable" "$logfile" 2>/dev/null && reason="Network Unreachable"
    grep -qi "getaddrinfo.*failed" "$logfile" 2>/dev/null && reason="DNS Resolution Failed"
    grep -qi "process exiting"     "$logfile" 2>/dev/null && reason="Process Exited Unexpectedly"
    grep -qi "certificate.*verify" "$logfile" 2>/dev/null && reason="Certificate Verification Failed"
    grep -qi "options error"       "$logfile" 2>/dev/null && reason="Config Options Error"
    grep -qi "No route to host"    "$logfile" 2>/dev/null && reason="No Route to Host"
    echo "$reason"
}

test_config() {
    local cfg=$1 idx=$2 total=$3
    local name; name=$(basename "$cfg")
    local tmplog="/tmp/ovpn_temp_$$.log"
    local pidfile="/tmp/ovpn_pid_$$.pid"
    local connected=0

    > "$tmplog"; rm -f "$pidfile"
    print_config_header "$name" "$idx" "$total"

    log_d "════════════════════════════════════════"
    log_d "CONFIG  : $name"
    log_d "STARTED : $(date '+%Y-%m-%d %H:%M:%S')"
    log "TESTING: $name"

    echo "  ${CYAN}${ARROW} Starting OpenVPN...${RESET}"; echo

    # ── اجرا بدون --daemon، ریدایرکت output به tmplog ──
    sudo openvpn \
        --config "$cfg" \
        --auth-user-pass "$AUTH_FILE" \
        --connect-retry-max 1 \
        --verb 4 \
        >> "$tmplog" 2>&1 &

    local vpn_pid=$!
    echo "$vpn_pid" > "$pidfile"

    # چک کن پروسه واقعاً زنده‌ست
    sleep 1
    if ! kill -0 "$vpn_pid" 2>/dev/null; then
        (( FAILED++ ))
        local err; err=$(cat "$tmplog" 2>/dev/null | head -5)
        echo "  ${BG_RED}  ${FAIL} FAILED  ${RESET}"
        echo "  ${RED}OpenVPN failed to start:${RESET}"
        echo "  ${YELLOW}${err}${RESET}"
        log "FAIL | $name | Failed to start"
        log_d "RESULT  : FAILED — process died immediately"
        log_d "OUTPUT  : $err"
        cat "$tmplog" >> "$DETAIL_LOG" 2>/dev/null || true
        rm -f "$tmplog" "$pidfile"
        echo; hr; sleep 1
        return
    fi

    # ── Poll ──
    local elapsed=0
    tput civis 2>/dev/null || true

    while (( elapsed < CONNECT_TIMEOUT )); do
        show_live_log "$tmplog" "$elapsed"

        if grep -q "Initialization Sequence Completed" "$tmplog" 2>/dev/null; then
            connected=1; break
        fi

        # fatal errors → توقف زود
        if grep -qi "AUTH_FAILED\|options error\|certificate.*verify\|No route to host" \
            "$tmplog" 2>/dev/null; then
            sleep 0.5; break
        fi

        # چک کن پروسه هنوز زنده‌ست
        if ! kill -0 "$vpn_pid" 2>/dev/null; then break; fi

        sleep 1; (( elapsed++ ))
    done

    echo; tput cnorm 2>/dev/null || true

    log_d "── OpenVPN Raw Output ──"
    cat "$tmplog" >> "$DETAIL_LOG" 2>/dev/null || true
    log_d "── End Raw Output ──"

    if [[ $connected -eq 1 ]]; then
        (( PASSED++ ))
        local assigned_ip ext_ip speed_mbps
        assigned_ip=$(get_assigned_ip "$tmplog")
        echo "  ${BG_GREEN}  ${OK} CONNECTED  ${RESET}"; echo
        echo "  ${GREEN}${BOLD}Tunnel established!${RESET}"
        echo "  ${GRAY}Assigned IP   :${RESET} ${WHITE}${assigned_ip}${RESET}"
        echo "  ${GRAY}Getting external IP...${RESET}"
        ext_ip=$(get_external_ip)
        echo "  ${GRAY}External IP   :${RESET} ${WHITE}${ext_ip}${RESET}"
        if [[ "$SPEED_TEST" == "true" ]]; then
            echo "  ${GRAY}${SPEED} Speed test...${RESET}"
            speed_mbps=$(run_speed_test)
            echo "  ${GRAY}Download      :${RESET} ${WHITE}${speed_mbps} Mbps${RESET}"
        else
            speed_mbps="skipped"
        fi
        mkdir -p "$RESULTS_DIR"
        { echo "══════════════════════════════════════"
          echo "  Config : $name"
          echo "  Time   : $(date '+%Y-%m-%d %H:%M:%S')"
          echo "  VPN IP : $assigned_ip"
          echo "  Ext IP : $ext_ip"
          echo "  Speed  : ${speed_mbps} Mbps"
          echo "══════════════════════════════════════"; } >> "$GOOD_FILE"
        echo "$name" >> "${RESULTS_DIR}/working_names.txt"
        log "OK   | $name | VPN=$assigned_ip | Ext=$ext_ip | Speed=${speed_mbps}Mbps"
        log_d "RESULT  : CONNECTED"
        echo; echo "  ${GREEN}${OK} Saved to ${BOLD}${GOOD_FILE}${RESET}"
    else
        (( FAILED++ ))
        local reason; reason=$(get_fail_reason "$tmplog")
        echo "  ${BG_RED}  ${FAIL} FAILED  ${RESET}"; echo
        echo "  ${RED}${BOLD}Could not connect${RESET}"
        echo "  ${GRAY}Reason: ${YELLOW}${reason}${RESET}"
        log "FAIL | $name | $reason"
        log_d "RESULT  : FAILED | $reason"
    fi

    kill_openvpn
    rm -f "$tmplog" "$pidfile"
    echo; hr; sleep 1
}

print_final_report() {
    local total=$(( PASSED + FAILED ))
    local rate=0
    (( total > 0 )) && rate=$(( PASSED * 100 / total )) || true
    print_banner
    echo "${BOLD}${WHITE}  ══════════════════ FINAL REPORT ══════════════════${RESET}"; echo
    echo "  ${GRAY}Total tested  :${RESET} ${BOLD}${total}${RESET}"
    echo "  ${GREEN}${OK} Connected   :${RESET} ${BOLD}${PASSED}${RESET}"
    echo "  ${RED}${FAIL} Failed      :${RESET} ${BOLD}${FAILED}${RESET}"
    echo "  ${CYAN}${SPEED} Success rate:${RESET} ${BOLD}${rate}%${RESET}"; echo
    hr
    if [[ -f "$GOOD_FILE" && -s "$GOOD_FILE" ]]; then
        echo; echo "  ${GREEN}${BOLD}Working Configs:${RESET}"; echo
        cat "$GOOD_FILE"
    else
        echo; echo "  ${YELLOW}  No working configs found.${RESET}"
    fi
    echo; hr
    echo "  ${GRAY}${BULLET} Summary : ${WHITE}${LOG_FILE}${RESET}"
    echo "  ${GRAY}${BULLET} Debug   : ${WHITE}${DETAIL_LOG}${RESET}"
    echo "  ${GRAY}${BULLET} Working : ${WHITE}${GOOD_FILE}${RESET}"; echo
    echo "  ${GRAY}Finished: $(date '+%Y-%m-%d %H:%M:%S')${RESET}"; echo
    log "════ FINAL: ${PASSED}/${total} connected (${rate}%) — $(date '+%Y-%m-%d %H:%M:%S')"
}

prompt_credentials() {
    if [[ -z "$USERNAME" ]]; then
        printf "  ${CYAN}Username: ${RESET}"; read -r USERNAME || true
    fi
    if [[ -z "$PASSWORD" ]]; then
        printf "  ${CYAN}Password: ${RESET}"; read -rs PASSWORD || true; echo
    fi
    printf '%s\n%s\n' "$USERNAME" "$PASSWORD" > "$AUTH_FILE"
    chmod 600 "$AUTH_FILE"
}

view_results() {
    clear; echo; echo "${CYAN}${BOLD}  ▸ Working Configs${RESET}"; echo
    if [[ -f "$GOOD_FILE" && -s "$GOOD_FILE" ]]; then cat "$GOOD_FILE"
    else echo "  ${YELLOW}No results yet.${RESET}"; fi
    echo; read -rp "  Press Enter to return..." _ || true; show_menu
}

view_logs() {
    clear; echo; echo "${CYAN}${BOLD}  ▸ Logs${RESET}"; echo
    echo "  ${CYAN}[1]${RESET} Summary  (${LOG_FILE})"
    echo "  ${CYAN}[2]${RESET} Debug    (${DETAIL_LOG})"
    echo "  ${CYAN}[b]${RESET} Back"; echo
    printf "  Choice: "; read -r lc || lc="b"
    case "$lc" in
        1) [[ -f "$LOG_FILE"    ]] && less "$LOG_FILE"    || echo "  No log yet." ;;
        2) [[ -f "$DETAIL_LOG"  ]] && less "$DETAIL_LOG"  || echo "  No log yet." ;;
    esac
    show_menu
}

run_tester() {
    clear; print_banner

    if ! command -v openvpn &>/dev/null; then
        echo "  ${RED}openvpn not found. Install dependencies first (option 2).${RESET}"
        echo; read -rp "  Press Enter..." _ || true; show_menu; return
    fi

    if [[ ! -d "$OVPN_DIR" ]]; then
        echo "  ${RED}Config directory not found: ${OVPN_DIR}${RESET}"
        echo "  ${YELLOW}Put your .ovpn files in a folder named 'configs'.${RESET}"
        echo; read -rp "  Press Enter..." _ || true; show_menu; return
    fi

    local configs=()
    while IFS= read -r -d '' f; do
        configs+=("$f")
    done < <(find "$OVPN_DIR" -maxdepth 1 -name '*.ovpn' -print0 2>/dev/null)

    local total=${#configs[@]}
    if (( total == 0 )); then
        echo "  ${RED}No .ovpn files found in: ${OVPN_DIR}${RESET}"
        echo; read -rp "  Press Enter..." _ || true; show_menu; return
    fi

    echo "  ${GREEN}Found ${total} config(s) in ${OVPN_DIR}/${RESET}"; echo
    prompt_credentials

    printf "  ${CYAN}Run speed test per connection? [Y/n]: ${RESET}"
    read -r spd || spd="y"
    [[ "${spd,,}" == "n" ]] && SPEED_TEST=false

    mkdir -p "$RESULTS_DIR"
    > "$GOOD_FILE"; > "$LOG_FILE"; > "$DETAIL_LOG"
    PASSED=0; FAILED=0

    log "OpenVPN Bulk Tester v3.2 started"
    log "Configs: $total | Dir: $OVPN_DIR | User: $USERNAME | Timeout: ${CONNECT_TIMEOUT}s"

    local idx=0
    for cfg in "${configs[@]}"; do
        (( idx++ ))
        test_config "$cfg" "$idx" "$total"
    done

    print_final_report
    echo; read -rp "  Press Enter to return to menu..." _ || true; show_menu
}

show_menu() {
    print_banner
    echo "  ${GRAY}Config dir : ${WHITE}${OVPN_DIR}${RESET}"
    echo "  ${GRAY}Timeout    : ${WHITE}${CONNECT_TIMEOUT}s per config${RESET}"; echo
    hr; echo
    echo "  ${CYAN}[1]${RESET}  Run bulk tester"
    echo "  ${CYAN}[2]${RESET}  Check & install dependencies"
    echo "  ${CYAN}[3]${RESET}  Remove dependencies (openvpn)"
    echo "  ${CYAN}[4]${RESET}  View working configs"
    echo "  ${CYAN}[5]${RESET}  View logs"
    echo "  ${CYAN}[q]${RESET}  Quit"; echo
    printf "  ${BOLD}Choice: ${RESET}"
    read -r choice || choice="q"
    case "$choice" in
        1) run_tester ;;
        2) check_deps ;;
        3) uninstall_deps ;;
        4) view_results ;;
        5) view_logs ;;
        q|Q) echo; exit 0 ;;
        *) echo "  ${RED}Invalid.${RESET}"; sleep 1; show_menu ;;
    esac
}

# ── Entry ──
if ! sudo -n true 2>/dev/null; then
    echo "${YELLOW}OpenVPN needs sudo. You may be prompted for your password.${RESET}"
    sudo -v 2>/dev/null || { echo "${RED}sudo required.${RESET}"; exit 1; }
fi

show_menu
