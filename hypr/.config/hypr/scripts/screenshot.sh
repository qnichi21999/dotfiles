#!/usr/bin/env bash
# Screenshot script — standalone (no hyde-shell required)
# Dependencies: grimblast, wl-clipboard, libnotify
# Optional: swappy or satty (annotation), tesseract (OCR), zbar (QR)

# ── helpers ──────────────────────────────────────────────────────────────────

pkg_installed() { command -v "$1" &>/dev/null; }

send_notifs() {
    # Minimal drop-in: parse -i (icon), -r (replace-id), -a (app-name), -e (expire)
    local icon="" replaces="" app="Screenshot" summary="" body="" urgency="normal"
    local args=()
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i) icon="$2";      shift 2 ;;
            -r) replaces="$2";  shift 2 ;;
            -a) app="$2";       shift 2 ;;
            -e) urgency="critical"; shift ;;
            *)  args+=("$1");   shift ;;
        esac
    done
    summary="${args[0]:-Screenshot}"
    body="${args[1]:-}"
    local notify_args=(-a "$app" -u "$urgency")
    [[ -n $icon     ]] && notify_args+=(-i "$icon")
    [[ -n $replaces ]] && notify_args+=(-r "$replaces")
    notify-send "${notify_args[@]}" "$summary" "$body"
}

print_log() {
    local color="" reset="\033[0m"
    case $1 in
        -g) color="\033[0;32m"; shift ;;
        -r) color="\033[0;31m"; shift ;;
        -y) color="\033[0;33m"; shift ;;
        *)  ;;
    esac
    echo -e "${color}[screenshot] $*${reset}" >&2
}

USAGE() {
    cat <<USAGE

Usage: $(basename "$0") [option]
Options:
    p     Print all outputs (full screen)
    s     Select area or window to screenshot
    sf    Select area or window with frozen screen
    m     Screenshot focused monitor
    sc    Use tesseract to scan image, then add to clipboard (OCR)
    sq    Scan QR code from selected area

USAGE
}

# ── config ────────────────────────────────────────────────────────────────────

SCREENSHOT_ANNOTATION_ENABLED="${SCREENSHOT_ANNOTATION_ENABLED:-true}"
SCREENSHOT_ANNOTATION_TOOL="${SCREENSHOT_ANNOTATION_TOOL:-}"
SCREENSHOT_PRE_COMMAND+=()
SCREENSHOT_POST_COMMAND+=()

temp_screenshot="${XDG_RUNTIME_DIR:-/tmp}/screenshot_$$.png"
XDG_PICTURES_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}"
save_dir="${2:-$XDG_PICTURES_DIR/Screenshots}"
save_file=$(date +'%y%m%d_%Hh%Mm%Ss_screenshot.png')
confDir="${XDG_CONFIG_HOME:-$HOME/.config}"

# Annotation tool: prefer env var, then auto-detect
annotation_tool="$SCREENSHOT_ANNOTATION_TOOL"
if [[ -z $annotation_tool ]]; then
    pkg_installed satty  && annotation_tool="satty"
    pkg_installed swappy && annotation_tool="swappy"
fi

annotation_args=("-o" "$save_dir/$save_file" "-f" "$temp_screenshot")
[[ $annotation_tool == "satty"  ]] && annotation_args+=("--copy-command" "wl-copy")
[[ -n ${SCREENSHOT_ANNOTATION_ARGS[*]} ]] && annotation_args+=("${SCREENSHOT_ANNOTATION_ARGS[@]}")

# Tesseract OCR languages
tesseract_languages=("${SCREENSHOT_OCR_TESSERACT_LANGUAGES[@]:-eng}")
tesseract_languages+=("osd")

# swappy needs its config written before use
if [[ $annotation_tool == "swappy" ]]; then
    swpy_dir="$confDir/swappy"
    mkdir -p "$swpy_dir"
    printf '[Default]\nsave_dir=%s\nsave_filename_format=%s\n' \
        "$save_dir" "$save_file" >"$swpy_dir/config"
fi

mkdir -p "$save_dir"

# ── lifecycle hooks ───────────────────────────────────────────────────────────

pre_cmd() {
    for cmd in "${SCREENSHOT_PRE_COMMAND[@]}"; do eval "$cmd"; done
    trap 'post_cmd' EXIT
}

post_cmd() {
    for cmd in "${SCREENSHOT_POST_COMMAND[@]}"; do eval "$cmd"; done
}

# ── grimblast wrapper ─────────────────────────────────────────────────────────

GRIMBLAST="${GRIMBLAST:-$(command -v grimblast)}"
if [[ -z $GRIMBLAST ]]; then
    echo "Error: grimblast not found. Install it or set GRIMBLAST=/path/to/grimblast" >&2
    exit 1
fi

# ── screenshot modes ──────────────────────────────────────────────────────────

take_screenshot() {
    local mode=$1; shift
    local extra_args=("$@")
    if "$GRIMBLAST" "${extra_args[@]}" copysave "$mode" "$temp_screenshot"; then
        [[ $SCREENSHOT_ANNOTATION_ENABLED == false ]] && return 0
        if [[ -z $annotation_tool ]]; then
            # No annotation tool: just copy the file to the save destination
            cp "$temp_screenshot" "$save_dir/$save_file"
            return 0
        fi
        if ! "$annotation_tool" "${annotation_args[@]}"; then
            send_notifs -r 9 -a "Screenshot" "Screenshot Error" "Failed to open annotation tool ($annotation_tool)"
            return 1
        fi
    else
        send_notifs -a "Screenshot" "Screenshot Error" "Failed to take screenshot"
        return 1
    fi
}

ocr_screenshot() {
    local mode=$1; shift
    local extra_args=("$@")
    if "$GRIMBLAST" "${extra_args[@]}" copysave "$mode" "$temp_screenshot"; then
        if ! pkg_installed tesseract; then
            send_notifs -r 9 -a "Screenshot" "OCR Error" "tesseract is not installed"
            return 1
        fi
        print_log -g "Performing OCR on $temp_screenshot"
        send_notifs "OCR" "Performing OCR on screenshot..." -i "document-scan" -r 9
        local out
        out=$(tesseract "$temp_screenshot" stdout -l "$(IFS=+; echo "${tesseract_languages[*]}")" 2>/dev/null) || {
            send_notifs -r 9 -a "Screenshot" "OCR: extraction error" -e -i "dialog-error"
            return 1
        }
        echo -n "$out" | wl-copy
        send_notifs -r 9 -a "Screenshot" "OCR complete" "Text copied to clipboard" -i "document-scan"
    else
        send_notifs -a "Screenshot" "OCR: screenshot error" -e -i "dialog-error"
        return 1
    fi
}

qr_screenshot() {
    local mode=$1; shift
    local extra_args=("$@")
    if "$GRIMBLAST" "${extra_args[@]}" copysave "$mode" "$temp_screenshot"; then
        if ! pkg_installed zbarimg; then
            send_notifs -r 9 -a "Screenshot" "QR Error" "zbar (zbarimg) is not installed"
            return 1
        fi
        print_log -g "Performing QR scan on $temp_screenshot"
        send_notifs "QR Scan" "Performing QR scan on screenshot..." -i "document-scan" -r 9
        local out
        out=$(zbarimg --quiet --raw "$temp_screenshot" 2>/dev/null) || {
            send_notifs -r 9 -a "Screenshot" "QR: no code found" -e -i "dialog-error"
            return 1
        }
        echo -n "$out" | wl-copy
        send_notifs -r 9 -a "Screenshot" "QR decoded" "$out" -i "document-scan"
    else
        send_notifs -a "Screenshot" "QR: screenshot error" -e -i "dialog-error"
        return 1
    fi
}

# ── main ──────────────────────────────────────────────────────────────────────

pre_cmd

case $1 in
    p)  take_screenshot "screen" ;;
    s)  take_screenshot "area" ;;
    sf) take_screenshot "area" "--freeze" ;;
    m)  take_screenshot "output" ;;
    sc) ocr_screenshot  "area"  "--freeze" ;;
    sq) qr_screenshot   "area"  "--freeze" ;;
    *)  USAGE ;;
esac

# Cleanup temp file
[[ -f $temp_screenshot ]] && rm -f "$temp_screenshot"

# Notify on successful save
if [[ -f "$save_dir/$save_file" ]]; then
    send_notifs -r 9 -a "Screenshot" "Saved" "$save_dir/$save_file" -i "$save_dir/$save_file"
fi
