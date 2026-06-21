#!/bin/bash
# mirror.sh - Universal Mirror v11
# TUI wrapper around HTTrack for website mirroring (incl. Wayback Machine)
# https://github.com/kikuon/universal-mirror
#
# Copyright (c) 2026 T.K DΞSIGN
# MIT License

shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_EXCLUSIONS="${SCRIPT_DIR}/exclusions.txt"
WAYBACK_EXTRAS="${SCRIPT_DIR}/wayback_extras.txt"
V8_SCRIPT="${SCRIPT_DIR}/mirror_v8.sh"

# ===== Colors =====
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# ===== Helpers =====
die() {
    if command -v whiptail &> /dev/null; then
        whiptail --title "Error" --msgbox "$1" 10 60 2>/dev/null
    fi
    echo "Error: $1" >&2
    exit 1
}

cancel_exit() {
    clear
    echo "Cancelled"
    exit 0
}

trim() {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

detect_user_agent() {
    case "$(uname -s)" in
        Darwin)
            echo "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15"
            ;;
        Linux)
            echo "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            ;;
        *)
            echo "Mozilla/5.0"
            ;;
    esac
}

# ===== TUI common wrapper (return on cancel, propagates via subshell) =====
tui() {
    local result status
    result=$(whiptail "$@" 3>&1 1>&2 2>&3)
    status=$?
    if [ $status -ne 0 ]; then
        return $status
    fi
    printf '%s' "$result"
}

tui_yesno() {
    whiptail "$@"
    local status=$?
    [ $status -eq 255 ] && return 255
    return $status
}

tui_msg() {
    whiptail "$@"
}

# ===== Dependency check =====
echo "Checking dependencies..."

if ! command -v httrack &> /dev/null; then
    echo "  httrack not found"
    if command -v brew &> /dev/null; then
        read -p "  Install via Homebrew? [y/N]: " INSTALL
        [[ "$INSTALL" =~ ^[yY]$ ]] && brew install httrack
    elif command -v apt-get &> /dev/null; then
        read -p "  Install via apt? [y/N]: " INSTALL
        [[ "$INSTALL" =~ ^[yY]$ ]] && sudo apt-get update && sudo apt-get install -y httrack
    elif command -v dnf &> /dev/null; then
        read -p "  Install via dnf? [y/N]: " INSTALL
        [[ "$INSTALL" =~ ^[yY]$ ]] && sudo dnf install -y httrack
    elif command -v pacman &> /dev/null; then
        read -p "  Install via pacman? [y/N]: " INSTALL
        [[ "$INSTALL" =~ ^[yY]$ ]] && sudo pacman -S --noconfirm httrack
    fi
    command -v httrack &> /dev/null || die "httrack is required"
fi

if ! command -v whiptail &> /dev/null; then
    echo "  whiptail not found"
    case "$(uname -s)" in
        Darwin)
            if command -v brew &> /dev/null; then
                read -p "  Install newt (provides whiptail) via Homebrew? [y/N]: " INSTALL
                [[ "$INSTALL" =~ ^[yY]$ ]] && brew install newt
            fi
            ;;
        Linux)
            if command -v apt-get &> /dev/null; then
                read -p "  Install whiptail via apt? [y/N]: " INSTALL
                [[ "$INSTALL" =~ ^[yY]$ ]] && sudo apt-get update && sudo apt-get install -y whiptail
            elif command -v dnf &> /dev/null; then
                read -p "  Install newt via dnf? [y/N]: " INSTALL
                [[ "$INSTALL" =~ ^[yY]$ ]] && sudo dnf install -y newt
            elif command -v pacman &> /dev/null; then
                read -p "  Install newt via pacman? [y/N]: " INSTALL
                [[ "$INSTALL" =~ ^[yY]$ ]] && sudo pacman -S --noconfirm newt
            fi
            ;;
    esac

    if ! command -v whiptail &> /dev/null; then
        echo ""
        echo "================================================"
        echo "  whiptail unavailable"
        echo "================================================"
        echo ""
        echo "This script (TUI version) requires whiptail."
        echo ""
        if [ -f "$V8_SCRIPT" ]; then
            echo "Text UI fallback available:"
            echo "  $V8_SCRIPT"
            echo ""
            read -p "Launch v8 (text version)? [y/N]: " RUN_V8
            if [[ "$RUN_V8" =~ ^[yY]$ ]]; then
                if [ -x "$V8_SCRIPT" ]; then
                    exec "$V8_SCRIPT"
                else
                    exec bash "$V8_SCRIPT"
                fi
            fi
        else
            echo "Place mirror_v8.sh in this directory for text UI mode"
        fi
        exit 1
    fi
fi

# ===== Auto-generate exclusion files on first run =====
if [ ! -f "$DEFAULT_EXCLUSIONS" ]; then
    cat > "$DEFAULT_EXCLUSIONS" << 'EXCLUSIONS_EOF'
# ===== Default Exclusion Patterns =====
# One pattern per line, # for comments
# HTTrack filter syntax: -*pattern*

# Social media / tracking
-*facebook*
-*twitter*
-*x.com*
-*instagram*
-*linkedin*
-*youtube*
-*tiktok*
-*pinterest*
-*reddit*

# Ads / analytics
-*google-analytics*
-*googletagmanager*
-*doubleclick*
-*googlesyndication*
-*adsense*
-*addthis*
-*sharethis*
-*disqus*

# Search engines
-*google.com/search*
-*bing.com*
-*duckduckgo*

# Wikipedia / Wikia
-*wikipedia*
-*wikimedia*
-*fandom.com*

# Prevent spidering into OSS license/project ecosystems
-*fsf.org*
-*gnu.org*
-*libreplanet*
-*defectivebydesign*
-*creativecommons*
-*windows7sins*
-*wikidot.com*
EXCLUSIONS_EOF
fi

if [ ! -f "$WAYBACK_EXTRAS" ]; then
    cat > "$WAYBACK_EXTRAS" << 'WAYBACK_EOF'
# Wayback Machine specific exclusions
# Skip resource variants (_if_, _cs_, _js_, _im_, _oe_)
-*web.archive.org/web/*if_*
-*web.archive.org/web/__wb*
-*web.archive.org/web/*cs_*
-*web.archive.org/web/*js_*
-*web.archive.org/web/*im_*
-*web.archive.org/web/*oe_*
WAYBACK_EOF
fi

# ===== TUI screens =====

tui_welcome() {
    tui_msg --title "Universal Mirror v11" --msgbox \
"Universal website mirror tool
  by HTTrack + whiptail

Supports normal sites and Wayback Machine
Mac/Linux compatible

[OK to continue / ESC to cancel]" 14 60
}

tui_url_input() {
    tui --title "[1/7] URL" --inputbox \
"Enter URL to mirror:

Normal  : https://example.com/path
Wayback : https://web.archive.org/web/20110510113426/http://example.com/" \
        15 80 ""
}

tui_wayback_select() {
    tui --title "[1.5/7] Wayback mode" --menu \
"Normal URL detected.
Process as Wayback Machine mirror?" 15 60 4 \
        "regular" "Normal site mirror" \
        "wayback" "Wayback Machine mirror"
}

tui_date_pattern() {
    local default="$1"
    tui --title "[2/7] Wayback date pattern" --inputbox \
"Snapshot date pattern:

  20110510 -> May 10 only (strict)
  201105   -> May only
  2011     -> entire 2011 (recommended)" \
        15 70 "$default"
}

tui_domain_input() {
    local default="$1"
    tui --title "[3/7] Domain scope" --inputbox \
"Domain to restrict crawling:

(detected: $default)" \
        12 70 "$default"
}

tui_outdir_input() {
    local default="$1"
    tui --title "[4/7] Output directory" --inputbox \
"Download destination:" \
        10 70 "$default"
}

tui_existing_dir() {
    tui --title "Directory exists" --menu \
"Output directory already exists." 15 60 4 \
        "overwrite" "Overwrite (delete and start fresh)" \
        "resume" "Resume (--update)" \
        "cancel" "Cancel"
}

tui_delete_confirm() {
    local dir="$1"
    tui_yesno --title "Confirm deletion" --yesno \
"This will delete:

  $dir

Are you sure?" 12 70
}

tui_exclusions_select() {
    local default="$1"
    local options=("default" "Default: $(basename "$default")")

    for f in "${SCRIPT_DIR}"/exclusions_*.txt; do
        local name
        name=$(basename "$f" .txt)
        options+=("$f" "$name")
    done

    options+=("custom" "Custom path")

    local choice
    choice=$(tui --title "[5/7] Exclusion file" --menu \
        "Select exclusion patterns file:" 15 70 6 \
        "${options[@]}") || return 1

    case "$choice" in
        default) printf '%s' "$default" ;;
        custom)
            tui --title "Custom path" --inputbox \
                "Path to exclusion file:" 10 70 "" || return 1
            ;;
        *) printf '%s' "$choice" ;;
    esac
}

tui_performance() {
    local depth
    depth=$(tui --title "[6/7] Recursion depth" --inputbox \
        "How deep to crawl:

  Light: 2-3
  Standard: 5-7
  Thorough: 10+" 15 60 "7") || return 1

    local conn
    conn=$(tui --title "[6/7] Connections per second" --inputbox \
        "Connection rate:

  Gentle: 1-2
  Standard: 3-5
  Aggressive: 10+" 15 60 "2") || return 1

    printf '%s|%s' "$depth" "$conn"
}

tui_bg_mode() {
    tui --title "[7/7] Run mode" --menu \
"How to run the download:" 15 60 4 \
        "foreground" "Foreground (live progress)" \
        "background" "Background (nohup)"
}

tui_confirm_settings() {
    local msg="$1"
    tui_yesno --title "Confirm settings" --yesno "$msg" 25 80
}

tui_show_running() {
    local pid="$1"
    local outdir="$2"
    local logfile="$3"

    tui_msg --title "Background started" --msgbox \
"Download started.

PID    : $pid
Output : $outdir
Log    : $logfile

Monitor:
  tail -f $logfile
  find $outdir -name '*.html' | wc -l
  du -sh $outdir

Stop:
  kill $pid
  touch $outdir/hts-stop.lock" 20 80
}

tui_show_completed() {
    local outdir="$1"
    local elapsed_min="$2"
    local elapsed_sec="$3"

    local total html size
    total=$(find "$outdir" -type f 2>/dev/null | wc -l | tr -d ' ')
    html=$(find "$outdir" -name "*.html" -type f 2>/dev/null | wc -l | tr -d ' ')
    size=$(du -sh "$outdir" 2>/dev/null | cut -f1)

    tui_msg --title "Download complete" --msgbox \
"Process complete

Time   : ${elapsed_min}m ${elapsed_sec}s
Output : $outdir
Files  : ${total}
HTML   : ${html}
Size   : $size

Open in browser:
  open $outdir/index.html" 20 80
}

# ===== Main flow =====

tui_welcome || cancel_exit

INPUT_URL=$(tui_url_input) || cancel_exit
[ -z "$INPUT_URL" ] && die "URL is empty"

# Wayback detection
IS_WAYBACK=0
EXTRACTED_DATE=""
ORIGINAL_URL=""

if [[ "$INPUT_URL" == *"web.archive.org/web/"* ]]; then
    IS_WAYBACK=1
    EXTRACTED_DATE=$(echo "$INPUT_URL" | sed -E 's|.*/web/([0-9]+)/.*|\1|')
    ORIGINAL_URL=$(echo "$INPUT_URL" | sed -E 's|.*/web/[0-9]+/(.*)|\1|')
else
    MODE=$(tui_wayback_select) || cancel_exit
    if [ "$MODE" = "wayback" ]; then
        IS_WAYBACK=1
        ORIGINAL_URL="$INPUT_URL"
    else
        ORIGINAL_URL="$INPUT_URL"
    fi
fi

# Wayback date
if [ "$IS_WAYBACK" = "1" ]; then
    if [ -n "$EXTRACTED_DATE" ]; then
        DEFAULT_DATE="${EXTRACTED_DATE:0:4}"
    else
        DEFAULT_DATE="2011"
    fi

    DATE_PATTERN=$(tui_date_pattern "$DEFAULT_DATE") || cancel_exit
    [ -z "$DATE_PATTERN" ] && die "Date pattern is empty"

    if [ -n "$EXTRACTED_DATE" ]; then
        ENTRY_TIMESTAMP="$EXTRACTED_DATE"
    elif [[ "$DATE_PATTERN" =~ ^[0-9]{8}$ ]]; then
        ENTRY_TIMESTAMP="${DATE_PATTERN}000000"
    elif [[ "$DATE_PATTERN" =~ ^[0-9]{6}$ ]]; then
        ENTRY_TIMESTAMP="${DATE_PATTERN}15000000"
    elif [[ "$DATE_PATTERN" =~ ^[0-9]{4}$ ]]; then
        ENTRY_TIMESTAMP="${DATE_PATTERN}0701000000"
    else
        ENTRY_TIMESTAMP="20110701000000"
    fi

    MIRROR_URL="https://web.archive.org/web/${ENTRY_TIMESTAMP}/${ORIGINAL_URL}"
else
    MIRROR_URL="$INPUT_URL"
    DATE_PATTERN=""
fi

# Domain
DOMAIN=$(echo "$ORIGINAL_URL" | sed -E 's|^https?://||; s|/.*||' | cut -d: -f1)
[ -z "$DOMAIN" ] && die "Failed to extract domain from: $ORIGINAL_URL"
CUSTOM_DOMAIN=$(tui_domain_input "$DOMAIN") || cancel_exit
CUSTOM_DOMAIN=${CUSTOM_DOMAIN:-$DOMAIN}

# Output dir
if [ "$IS_WAYBACK" = "1" ]; then
    DEFAULT_OUTDIR="./mirror_${CUSTOM_DOMAIN}_${DATE_PATTERN}"
else
    DEFAULT_OUTDIR="./mirror_${CUSTOM_DOMAIN}"
fi
OUTDIR=$(tui_outdir_input "$DEFAULT_OUTDIR") || cancel_exit
OUTDIR=${OUTDIR:-$DEFAULT_OUTDIR}
OUTDIR="${OUTDIR%/}"

[ -z "$OUTDIR" ] && die "Output directory is empty"
[ "$OUTDIR" = "/" ] && die "Output cannot be root"
[ "$OUTDIR" = "." ] && die "Output cannot be current directory"
[ "$OUTDIR" = "$HOME" ] && die "Output cannot be home directory"

RESUME_MODE=0
while [ -d "$OUTDIR" ]; do
    ACTION=$(tui_existing_dir) || cancel_exit
    case "$ACTION" in
        overwrite)
            if tui_delete_confirm "$OUTDIR"; then
                rm -rf "$OUTDIR"
                break
            else
                continue
            fi
            ;;
        resume)
            RESUME_MODE=1
            break
            ;;
        cancel)
            cancel_exit
            ;;
    esac
done

# Exclusion file
EXCLUSIONS_FILE=$(tui_exclusions_select "$DEFAULT_EXCLUSIONS") || cancel_exit
[ ! -f "$EXCLUSIONS_FILE" ] && die "Exclusion file not found: $EXCLUSIONS_FILE"

EXCLUSION_PATTERNS=()
while IFS= read -r line || [ -n "$line" ]; do
    trimmed=$(trim "$line")
    [[ -z "$trimmed" || "$trimmed" =~ ^# ]] && continue
    EXCLUSION_PATTERNS+=("$trimmed")
done < "$EXCLUSIONS_FILE"

if [ "$IS_WAYBACK" = "1" ] && [ -f "$WAYBACK_EXTRAS" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        trimmed=$(trim "$line")
        [[ -z "$trimmed" || "$trimmed" =~ ^# ]] && continue
        EXCLUSION_PATTERNS+=("$trimmed")
    done < "$WAYBACK_EXTRAS"
fi

# Performance
PERF=$(tui_performance) || cancel_exit
DEPTH=$(echo "$PERF" | cut -d'|' -f1)
CONN_RATE=$(echo "$PERF" | cut -d'|' -f2)
[[ "$DEPTH" =~ ^[0-9]+$ ]] || die "Depth must be numeric: $DEPTH"
[[ "$CONN_RATE" =~ ^[0-9]+$ ]] || die "Connection rate must be numeric: $CONN_RATE"

# Run mode
BG_CHOICE=$(tui_bg_mode) || cancel_exit
BG_MODE="n"
[ "$BG_CHOICE" = "background" ] && BG_MODE="y"

USER_AGENT=$(detect_user_agent)

# Confirm
SUMMARY="Type        : $([ "$IS_WAYBACK" = "1" ] && echo "Wayback Mirror" || echo "Normal Mirror")
Source URL  : $ORIGINAL_URL
Mirror URL  : $MIRROR_URL"

[ "$IS_WAYBACK" = "1" ] && SUMMARY="$SUMMARY
Date pattern: $DATE_PATTERN"

SUMMARY="$SUMMARY
Domain      : $CUSTOM_DOMAIN
Output      : $OUTDIR
Depth       : $DEPTH
Conn rate   : ${CONN_RATE}/sec
Exclusion   : $(basename "$EXCLUSIONS_FILE")
Patterns    : ${#EXCLUSION_PATTERNS[@]}
Background  : $([ "$BG_MODE" = "y" ] && echo "ON" || echo "OFF")
Mode        : $([ "$RESUME_MODE" = "1" ] && echo "Resume (--update)" || echo "New")

Execute with these settings?"

tui_confirm_settings "$SUMMARY" || cancel_exit

# ===== Build command =====
START_TIME=$(date +%s)

INCLUDE_FILTER=""
if [ "$IS_WAYBACK" = "1" ]; then
    INCLUDE_FILTER="+*web.archive.org/web/${DATE_PATTERN}*${CUSTOM_DOMAIN}*"
else
    INCLUDE_FILTER="+*${CUSTOM_DOMAIN}*"
fi

HTTRACK_CMD=(
    httrack
    "$MIRROR_URL"
    -O "$OUTDIR"
    --depth="$DEPTH"
    --connection-per-second="$CONN_RATE"
    # robots.txt ignored: intentional for archival use
    # Note: respect site ToS / robots.txt in normal operation
    --robots=0
    --user-agent "$USER_AGENT"
    --retries=3
    --timeout=60
    --keep-alive
    "$INCLUDE_FILTER"
)

for pattern in "${EXCLUSION_PATTERNS[@]}"; do
    HTTRACK_CMD+=("$pattern")
done

if [ "$RESUME_MODE" = "1" ]; then
    HTTRACK_CMD+=(--update)
fi

# ===== Execute =====
if [ "$BG_MODE" = "y" ]; then
    LOG_FILE="${OUTDIR}_httrack.log"
    nohup "${HTTRACK_CMD[@]}" > "$LOG_FILE" 2>&1 &
    BG_PID=$!

    tui_show_running "$BG_PID" "$OUTDIR" "$LOG_FILE"
else
    clear
    echo "=== Download started ==="
    "${HTTRACK_CMD[@]}" --display || true

    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    ELAPSED_MIN=$((ELAPSED / 60))
    ELAPSED_SEC=$((ELAPSED % 60))

    tui_show_completed "$OUTDIR" "$ELAPSED_MIN" "$ELAPSED_SEC"
fi
