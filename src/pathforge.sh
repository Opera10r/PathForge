#!/bin/bash
# PathForge — Path Resolution Engine
# Right-click any file/folder in Finder → copy its path in any format
# Usage: pathforge.sh <format> <file1> [file2] ...
# Formats: absolute, shell_escaped, git_relative, quoted, cd_command, url_encoded, all_formats

set -uo pipefail

# Log errors when running inside Automator
LOG_FILE="$HOME/Library/Application Support/PathForge/debug.log"

# ─── Config ───────────────────────────────────────────────────────────────────

APP_NAME="PathForge"
SUPPORT_DIR="$HOME/Library/Application Support/PathForge"
USAGE_FILE="$SUPPORT_DIR/usage"
DAILY_LIMIT=3
LICENSE_FILE="$SUPPORT_DIR/license"
LICENSE_KEY_FILE="$SUPPORT_DIR/license_key"
API_URL="https://pathforge-worker.opera10r.workers.dev"

# ─── Setup ────────────────────────────────────────────────────────────────────

mkdir -p "$SUPPORT_DIR"

# ─── Usage Tracking (Freemium: 3 free copies/day) ────────────────────────────

check_usage() {
    # Licensed users skip the check
    if [[ -f "$LICENSE_FILE" ]]; then
        local status
        status=$(cat "$LICENSE_FILE" 2>/dev/null || echo "")
        if [[ "$status" == "active" ]]; then
            return 0
        fi
    fi

    local today
    today=$(date +%Y-%m-%d)

    if [[ -f "$USAGE_FILE" ]]; then
        local stored_date stored_count
        stored_date=$(cut -d: -f1 "$USAGE_FILE")
        stored_count=$(cut -d: -f2 "$USAGE_FILE")

        if [[ "$stored_date" == "$today" ]]; then
            if (( stored_count >= DAILY_LIMIT )); then
                notify "Daily Limit Reached" "You've used your $DAILY_LIMIT free copies today. Unlimited for \$1/month."
                exit 0
            fi
        fi
    fi
}

increment_usage() {
    # Licensed users don't need tracking
    if [[ -f "$LICENSE_FILE" ]]; then
        local status
        status=$(cat "$LICENSE_FILE" 2>/dev/null || echo "")
        if [[ "$status" == "active" ]]; then
            return 0
        fi
    fi

    local today
    today=$(date +%Y-%m-%d)

    if [[ -f "$USAGE_FILE" ]]; then
        local stored_date stored_count
        stored_date=$(cut -d: -f1 "$USAGE_FILE")
        stored_count=$(cut -d: -f2 "$USAGE_FILE")

        if [[ "$stored_date" == "$today" ]]; then
            echo "${today}:$(( stored_count + 1 ))" > "$USAGE_FILE"
            return
        fi
    fi

    # New day or first use
    echo "${today}:1" > "$USAGE_FILE"
}

# ─── Notification ─────────────────────────────────────────────────────────────

notify() {
    local title="$1"
    local body="$2"
    # Escape quotes and backslashes for AppleScript
    body="${body//\\/\\\\}"
    body="${body//\"/\\\"}"
    osascript -e "display notification \"$body\" with title \"$title\"" 2>/dev/null &
}

# ─── Path Formatters ─────────────────────────────────────────────────────────

format_absolute() {
    echo "$1"
}

format_shell_escaped() {
    # Use printf + sed to escape all shell metacharacters
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' \
        -e 's/ /\\ /g' \
        -e 's/(/\\(/g' \
        -e 's/)/\\)/g' \
        -e 's/\[/\\[/g' \
        -e 's/\]/\\]/g' \
        -e 's/{/\\{/g' \
        -e 's/}/\\}/g' \
        -e "s/'/\\\\'/g" \
        -e 's/"/\\"/g' \
        -e 's/&/\\&/g' \
        -e 's/|/\\|/g' \
        -e 's/;/\\;/g' \
        -e 's/!/\\!/g' \
        -e 's/\$/\\$/g' \
        -e 's/`/\\`/g' \
        -e 's/#/\\#/g' \
        -e 's/\*/\\*/g' \
        -e 's/?/\\?/g' \
        -e 's/</\\</g' \
        -e 's/>/\\>/g' \
        -e 's/~/\\~/g'
}

format_git_relative() {
    local filepath="$1"
    local dir

    if [[ -d "$filepath" ]]; then
        dir="$filepath"
    else
        dir="$(dirname "$filepath")"
    fi

    # Use git to find the repo root
    local git_root
    if ! git_root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null); then
        # Not in a git repo — fall back to absolute
        echo "$filepath"
        return 1
    fi

    # Compute relative path from git root
    local relative="${filepath#"$git_root"}"
    relative="${relative#/}"

    if [[ -z "$relative" ]]; then
        echo "."
    else
        echo "$relative"
    fi
}

format_quoted() {
    echo "\"$1\""
}

format_cd_command() {
    local target="$1"

    # If it's a file, use its parent directory
    if [[ -f "$target" ]]; then
        target="$(dirname "$target")"
    fi

    echo "cd $(format_shell_escaped "$target")"
}

format_url_encoded() {
    local path="$1"
    # Use python3 (ships with macOS) for proper URL encoding
    local encoded
    encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$path', safe='/'))" 2>/dev/null) || {
        # Fallback: basic encoding for spaces only
        encoded="${path// /%20}"
    }
    echo "file://$encoded"
}

format_all() {
    local filepath="$1"
    local git_rel
    local git_label="Git-Relative Path"

    if git_rel=$(format_git_relative "$filepath" 2>/dev/null) && [[ -n "$git_rel" ]]; then
        # Check if it fell back to absolute (git_relative returns absolute + exit 1 when not in repo)
        if [[ "$git_rel" == "$filepath" ]]; then
            git_label="Git-Relative Path (no repo found)"
        fi
    else
        git_rel="$filepath"
        git_label="Git-Relative Path (no repo found)"
    fi

    echo "[Absolute Path]"
    format_absolute "$filepath"
    echo ""
    echo "[Shell-Escaped Path]"
    format_shell_escaped "$filepath"
    echo ""
    echo "[$git_label]"
    echo "$git_rel"
    echo ""
    echo "[Quoted Path]"
    format_quoted "$filepath"
    echo ""
    echo "[cd Command]"
    format_cd_command "$filepath"
    echo ""
    echo "[File URL]"
    format_url_encoded "$filepath"
}

# ─── License Activation ───────────────────────────────────────────────────────

activate_license() {
    local key="$1"

    if [[ -z "$key" ]]; then
        echo "Usage: pathforge activate <license_key>"
        echo "  e.g. pathforge activate pf_abc123..."
        exit 1
    fi

    if [[ ! "$key" == pf_* ]]; then
        echo "Error: License keys start with pf_"
        exit 1
    fi

    echo "Validating license key..."

    local response
    response=$(curl -s -X POST "$API_URL/validate-license" \
        -H "Content-Type: application/json" \
        -d "{\"license_key\": \"$key\"}" 2>/dev/null)

    if [[ -z "$response" ]]; then
        echo "Error: Could not reach license server. Check your internet connection."
        exit 1
    fi

    local valid
    valid=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('valid', False))" 2>/dev/null)

    if [[ "$valid" == "True" ]]; then
        echo "$key" > "$LICENSE_KEY_FILE"
        echo "active" > "$LICENSE_FILE"
        local email
        email=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('email',''))" 2>/dev/null)
        echo ""
        echo "License activated! ($email)"
        echo "Unlimited path copies unlocked."
    else
        echo "Error: Invalid or expired license key."
        exit 1
    fi
}

deactivate_license() {
    rm -f "$LICENSE_FILE" "$LICENSE_KEY_FILE"
    echo "License deactivated. Back to free tier (3 copies/day)."
}

show_status() {
    echo "PathForge v1.0.0"
    echo ""
    if [[ -f "$LICENSE_FILE" ]] && [[ "$(cat "$LICENSE_FILE")" == "active" ]]; then
        local key
        key=$(cat "$LICENSE_KEY_FILE" 2>/dev/null || echo "unknown")
        echo "License: Active (${key:0:10}...)"
        echo "Copies:  Unlimited"
    else
        local today count remaining
        today=$(date +%Y-%m-%d)
        if [[ -f "$USAGE_FILE" ]]; then
            local stored_date stored_count
            stored_date=$(cut -d: -f1 "$USAGE_FILE")
            stored_count=$(cut -d: -f2 "$USAGE_FILE")
            if [[ "$stored_date" == "$today" ]]; then
                count=$stored_count
            else
                count=0
            fi
        else
            count=0
        fi
        remaining=$(( DAILY_LIMIT - count ))
        if (( remaining < 0 )); then remaining=0; fi
        echo "License: Free tier"
        echo "Today:   $count/$DAILY_LIMIT copies used ($remaining remaining)"
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: pathforge <format> <file1> [file2] ..."
        echo "       pathforge activate <license_key>"
        echo "       pathforge deactivate"
        echo "       pathforge status"
        echo ""
        echo "Formats: absolute, shell_escaped, git_relative, quoted, cd_command, url_encoded, all_formats"
        exit 1
    fi

    # Handle subcommands
    case "$1" in
        activate)
            activate_license "${2:-}"
            exit 0
            ;;
        deactivate)
            deactivate_license
            exit 0
            ;;
        status)
            show_status
            exit 0
            ;;
    esac

    if [[ $# -lt 2 ]]; then
        echo "Usage: pathforge <format> <file1> [file2] ..."
        exit 1
    fi

    local format="$1"
    shift
    local files=("$@")

    # Check usage limit
    check_usage

    local result=""
    local not_in_git=false
    local notification_title=""
    local notification_body=""

    for filepath in "${files[@]}"; do
        # Resolve symlinks
        filepath=$(realpath "$filepath" 2>/dev/null || echo "$filepath")

        local formatted=""
        case "$format" in
            absolute)
                formatted=$(format_absolute "$filepath")
                notification_title="Absolute Path Copied"
                ;;
            shell_escaped)
                formatted=$(format_shell_escaped "$filepath")
                notification_title="Shell Path Copied"
                ;;
            git_relative)
                if formatted=$(format_git_relative "$filepath"); then
                    notification_title="Git-Relative Copied"
                else
                    not_in_git=true
                    notification_title="Absolute Path Copied"
                fi
                ;;
            quoted)
                formatted=$(format_quoted "$filepath")
                notification_title="Quoted Path Copied"
                ;;
            cd_command)
                formatted=$(format_cd_command "$filepath")
                notification_title="cd Command Copied"
                ;;
            url_encoded)
                formatted=$(format_url_encoded "$filepath")
                notification_title="File URL Copied"
                ;;
            all_formats)
                formatted=$(format_all "$filepath")
                notification_title="All Formats Copied"
                ;;
            *)
                echo "Unknown format: $format"
                exit 1
                ;;
        esac

        if [[ -n "$result" ]]; then
            result="${result}"$'\n'"${formatted}"
        else
            result="$formatted"
        fi
    done

    # Copy to clipboard
    echo -n "$result" | pbcopy

    # Build notification
    if (( ${#files[@]} > 1 )); then
        notification_title="${#files[@]} Paths Copied"
        notification_body="${format} format for ${#files[@]} files"
    elif [[ "$not_in_git" == true ]]; then
        notification_body="No git repo found. Showing absolute path."
    elif [[ "$format" == "all_formats" ]]; then
        notification_body="6 path formats copied to clipboard"
    else
        # Truncate long paths for notification (show last 60 chars)
        if (( ${#result} > 60 )); then
            notification_body="…${result: -57}"
        else
            notification_body="$result"
        fi
    fi

    notify "$notification_title" "$notification_body"

    # Track usage
    increment_usage
}

main "$@"
