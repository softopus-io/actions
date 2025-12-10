#!/bin/bash
set -e

# --- Argument Validation ---
if [ $# -ne 2 ] && [ $# -ne 4 ]; then
    echo "Usage: $0 <expected_version> <health_check_url> [username] [password]" >&2
    exit 1
fi

EXPECTED_VERSION="$1"
HEALTH_CHECK_URL="$2"

if [ -z "$EXPECTED_VERSION" ]; then
    echo "❌ Error: Expected version cannot be empty" >&2
    exit 1
fi

if [ $# -eq 4 ] && [ -z "$3" ]; then
    echo "❌ Error: Username cannot be empty when using authentication" >&2
    exit 1
fi

# --- Helper Functions ---
log() { echo "[Version Check] $1" >&2; }

# --- Main Logic ---
log "Waiting for deployment to stabilize..."
sleep 5

log "Fetching version from health check endpoint..."

# Build curl auth option
AUTH_OPTION=""
if [ $# -eq 4 ]; then
    AUTH_OPTION="-u $3:$4"
    log "Using authentication with user $3"
fi

# The -0 or --http1.0 flag helps prevent hangs with simple mock servers.
# The --max-time flag is a hard timeout for the entire operation.
for attempt in 1 2 3; do
    if [ $attempt -gt 1 ]; then
        log "Retry attempt $attempt of 3..."
        sleep 5
    fi

    RESPONSE=$(curl -0 --connect-timeout 2 --max-time 5 -s -w "\n%{http_code}" $AUTH_OPTION "$HEALTH_CHECK_URL" 2>/dev/null || true)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    RESPONSE=$(echo "$RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" = "200" ]; then
        log "Successfully connected (HTTP 200)"
        break
    fi

    # Support file:// protocol which returns HTTP 000
    if [ "$HTTP_CODE" = "000" ]; then
         case "$HEALTH_CHECK_URL" in
            file://*)
                log "Successfully loaded local file (HTTP 000)"
                break
                ;;
         esac
    fi

    log "Failed to connect (HTTP $HTTP_CODE)"
    if [ "$HTTP_CODE" = "401" ]; then
        log "Hint: Received HTTP 401. Check credentials."
    fi

    if [ $attempt -eq 3 ]; then
        log "❌ Failed after 3 attempts"
        exit 1
    fi
done

# --- JSON Parsing and Validation ---
if ! command -v jq &> /dev/null; then
    log "❌ Error: jq is not installed"
    exit 1
fi

# Extract version, removing control characters from nc/curl output
ACTUAL_VERSION=$(echo "$RESPONSE" | jq -r '.appVersion // empty' 2>/dev/null | tr -d '[[:cntrl:]]')

if [ -z "$ACTUAL_VERSION" ]; then
    log "❌ Error: Invalid JSON or missing appVersion field"
    echo "$RESPONSE" | head -c 500 >&2
    exit 1
fi

# --- Version Comparison ---
log "Expected: $EXPECTED_VERSION | Actual: $ACTUAL_VERSION"

if [ "$ACTUAL_VERSION" = "$EXPECTED_VERSION" ]; then
    log "✅ Version verified successfully"
else
    log "❌ Version mismatch detected!"
    exit 1
fi
