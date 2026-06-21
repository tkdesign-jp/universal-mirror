#!/bin/bash
# mirror_v8.sh - Universal Mirror v8 (Text UI fallback)
# Same functionality as mirror.sh but without whiptail TUI
# Use when whiptail is unavailable
#
# Copyright (c) 2026 T.K DΞSIGN
# MIT License

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_EXCLUSIONS="${SCRIPT_DIR}/exclusions.txt"
WAYBACK_EXTRAS="${SCRIPT_DIR}/wayback_extras.txt"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

die() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

trim() {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

detect_user_agent() {
    case "$(uname -s)" in
        Darwin) echo "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15" ;;
        Linux)  echo "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" ;;
        *)      echo "Mozilla/5.0" ;;
    esac
}

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Universal Mirror v8 (Text UI)${NC}"
echo -e "${BLUE}=========================================${NC}"
echo

# Dependency check
if ! command -v httrack &> /dev/null; then
    echo -e "${RED}httrack not found${NC}"
    if command -v brew &> /dev/null; then
        read -p "Install via Homebrew? [y/N]: " INSTALL
        [[ "$INSTALL" =~ ^[yY]$ ]] && brew install httrack
    elif command -v apt-get &> /dev/null; then
        read -p "Install via apt? [y/N]: " INSTALL
        [[ "$INSTALL" =~ ^[yY]$ ]] && sudo apt-get update && sudo apt-get install -y httrack
    fi
    command -v httrack &> /dev/null || die "httrack is required"
fi

# Auto-generate exclusion files
if [ ! -f "$DEFAULT_EXCLUSIONS" ]; then
    cat > "$DEFAULT_EXCLUSIONS" << 'EXCLUSIONS_EOF'
-*facebook*
-*twitter*
-*x.com*
-*instagram*
-*linkedin*
-*youtube*
-*tiktok*
-*pinterest*
-*reddit*
-*google-analytics*
-*googletagmanager*
-*doubleclick*
-*googlesyndication*
-*adsense*
-*addthis*
-*sharethis*
-*disqus*
-*google.com/search*
-*bing.com*
-*duckduckgo*
-*wikipedia*
-*wikimedia*
-*fandom.com*
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
-*web.archive.org/web/*if_*
-*web.archive.org/web/__wb*
-*web.archive.org/web/*cs_*
-*web.archive.org/web/*js_*
-*web.archive.org/web/*im_*
-*web.archive.org/web/*oe_*
WAYBACK_EOF
fi

echo -e "${CYAN}[1/7] URL${NC}"
echo "  Normal  : https://example.com/path"
echo "  Wayback : https://web.archive.org/web/20110510113426/http://example.com/"
read -p "URL: " INPUT_URL || die "Input error"
[ -z "$INPUT_URL" ] && die "URL is empty"
echo

# Wayback detection
IS_WAYBACK=0
EXTRACTED_DATE=""
ORIGINAL_URL=""
if [[ "$INPUT_URL" == *"web.archive.org/web/"* ]]; then
    IS_WAYBACK=1
    EXTRACTED_DATE=$(echo "$INPUT_URL" | sed -E 's|.*/web/([0-9]+)/.*|\1|')
    ORIGINAL_URL=$(echo "$INPUT_URL" | sed -E 's|.*/web/[0-9]+/(.*)|\1|')
    echo -e "${GREEN}  -> Wayback URL detected${NC}"
else
    read -p "  Process as Wayback Machine mirror? [y/N]: " USE_WAYBACK
    if [[ "$USE_WAYBACK" =~ ^[yY]$ ]]; then
        IS_WAYBACK=1
        ORIGINAL_URL="$INPUT_URL"
    else
        ORIGINAL_URL="$INPUT_URL"
    fi
fi
echo

if [ "$IS_WAYBACK" = "1" ]; then
    echo -e "${CYAN}[2/7] Wayback date pattern${NC}"
    echo "  20110510 / 201105 / 2011"
    if [ -n "$EXTRACTED_DATE" ]; then
        DEFAULT_DATE_PATTERN="${EXTRACTED_DATE:0:4}"
    else
        DEFAULT_DATE_PATTERN="2011"
    fi
    read -p "Date pattern [${DEFAULT_DATE_PATTERN}]: " DATE_PATTERN
    DATE_PATTERN=${DATE_PATTERN:-$DEFAULT_DATE_PATTERN}

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
    echo
else
    MIRROR_URL="$INPUT_URL"
    DATE_PATTERN=""
fi

DOMAIN=$(echo "$ORIGINAL_URL" | sed -E 's|^https?://||; s|/.*||' | cut -d: -f1)
[ -z "$DOMAIN" ] && die "Domain extraction failed"
echo -e "${CYAN}[3/7] Domain${NC}"
echo "  Detected: $DOMAIN"
read -p "Limit to domain [${DOMAIN}]: " CUSTOM_DOMAIN
CUSTOM_DOMAIN=${CUSTOM_DOMAIN:-$DOMAIN}
echo

echo -e "${CYAN}[4/7] Output directory${NC}"
if [ "$IS_WAYBACK" = "1" ]; then
    DEFAULT_OUTDIR="./mirror_${CUSTOM_DOMAIN}_${DATE_PATTERN}"
else
    DEFAULT_OUTDIR="./mirror_${CUSTOM_DOMAIN}"
fi
read -p "Output [${DEFAULT_OUTDIR}]: " OUTDIR
OUTDIR=${OUTDIR:-$DEFAULT_OUTDIR}
OUTDIR="${OUTDIR%/}"
[ -z "$OUTDIR" ] && die "Output is empty"
[ "$OUTDIR" = "/" ] && die "Output cannot be root"
[ "$OUTDIR" = "." ] && die "Output cannot be current dir"
[ "$OUTDIR" = "$HOME" ] && die "Output cannot be home"

RESUME_MODE=0
if [ -d "$OUTDIR" ]; then
    echo "  A) Overwrite  B) Resume (--update)  C) Cancel"
    read -p "  Choice [A/B/C]: " EXIST_ACTION
    case "$EXIST_ACTION" in
        [aA])
            read -p "  Type 'yes' to confirm deletion: " CONFIRM_DEL
            [ "$CONFIRM_DEL" = "yes" ] && rm -rf "$OUTDIR" || { echo "Cancel"; exit 0; }
            ;;
        [bB]) RESUME_MODE=1 ;;
        *) echo "Cancel"; exit 0 ;;
    esac
fi
echo

echo -e "${CYAN}[5/7] Exclusion file${NC}"
read -p "Path [${DEFAULT_EXCLUSIONS}]: " CUSTOM_EXCL
EXCLUSIONS_FILE=${CUSTOM_EXCL:-$DEFAULT_EXCLUSIONS}
[ ! -f "$EXCLUSIONS_FILE" ] && die "File not found: $EXCLUSIONS_FILE"

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
echo "  Loaded: ${#EXCLUSION_PATTERNS[@]} patterns"
echo

echo -e "${CYAN}[6/7] Performance${NC}"
read -p "Depth [7]: " DEPTH
DEPTH=${DEPTH:-7}
[[ "$DEPTH" =~ ^[0-9]+$ ]] || die "Depth must be numeric"
read -p "Conn/sec [2]: " CONN_RATE
CONN_RATE=${CONN_RATE:-2}
[[ "$CONN_RATE" =~ ^[0-9]+$ ]] || die "Conn must be numeric"
echo

echo -e "${CYAN}[7/7] Run mode${NC}"
read -p "Background? [y/N]: " BG_MODE
echo

USER_AGENT=$(detect_user_agent)

echo -e "${YELLOW}========== Settings ==========${NC}"
echo "  Type        : $([ "$IS_WAYBACK" = "1" ] && echo "Wayback Mirror" || echo "Normal Mirror")"
echo "  Source URL  : $ORIGINAL_URL"
echo "  Mirror URL  : $MIRROR_URL"
[ "$IS_WAYBACK" = "1" ] && echo "  Date pattern: $DATE_PATTERN"
echo "  Domain      : $CUSTOM_DOMAIN"
echo "  Output      : $OUTDIR"
echo "  Depth       : $DEPTH"
echo "  Conn rate   : ${CONN_RATE}/sec"
echo "  Exclusion   : $(basename "$EXCLUSIONS_FILE") (${#EXCLUSION_PATTERNS[@]} patterns)"
echo "  Background  : $([[ "$BG_MODE" =~ ^[yY]$ ]] && echo "ON" || echo "OFF")"
echo "  Mode        : $([ "$RESUME_MODE" = "1" ] && echo "Resume (--update)" || echo "New")"
echo
read -p "Execute? [y/N]: " CONFIRM
[[ ! "$CONFIRM" =~ ^[yY]$ ]] && { echo "Cancel"; exit 0; }

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

[ "$RESUME_MODE" = "1" ] && HTTRACK_CMD+=(--update)

echo
echo -e "${GREEN}=== Download started ===${NC}"

if [[ "$BG_MODE" =~ ^[yY]$ ]]; then
    LOG_FILE="${OUTDIR}_httrack.log"
    nohup "${HTTRACK_CMD[@]}" > "$LOG_FILE" 2>&1 &
    BG_PID=$!
    echo "PID  : $BG_PID"
    echo "Log  : $LOG_FILE"
    echo "Monitor: tail -f $LOG_FILE"
    echo "Stop   : kill $BG_PID"
else
    "${HTTRACK_CMD[@]}" --display || true
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    echo
    echo -e "${GREEN}========== Complete ==========${NC}"
    echo "Time: $((ELAPSED/60))m $((ELAPSED%60))s"
    if [ -d "$OUTDIR" ]; then
        echo "Files: $(find "$OUTDIR" -type f | wc -l | tr -d ' ')"
        echo "HTML : $(find "$OUTDIR" -name "*.html" -type f | wc -l | tr -d ' ')"
        echo "Size : $(du -sh "$OUTDIR" | cut -f1)"
    fi
fi
