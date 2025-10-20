#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Check if required arguments are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <expected_version> <health_check_url>"
    exit 1
fi

# Assign arguments to variables
EXPECTED_VERSION="$1"
HEALTH_CHECK_URL="$2"

# Validate that expected version is not empty
if [ -z "$EXPECTED_VERSION" ]; then
    echo "❌ Error: Expected version parameter is empty or not provided"
    echo "Usage: $0 <expected_version> <health_check_url>"
    echo "The expected_version parameter cannot be empty"
    exit 1
fi

# Function to log messages
log() {
    echo "[Version Check] $1"
}

# Wait a few seconds to ensure deployment is complete
log "Waiting 5s for deployment to stabilize..."
sleep 5

# Perform HTTP GET request and capture the response with status code
log "Fetching version from health check endpoint..."
MAX_RETRIES=3
RETRY_COUNT=0
CURL_SUCCESS=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$CURL_SUCCESS" != "true" ]; do
    if [ $RETRY_COUNT -gt 0 ]; then
        log "Retry attempt $RETRY_COUNT of $MAX_RETRIES..."
        sleep 5
    fi
    
    # Use curl with -w to output HTTP status code
    CURL_RESPONSE=$(mktemp)
    HTTP_CODE=$(curl -s -w "%{http_code}" "$HEALTH_CHECK_URL" -o "$CURL_RESPONSE" 2>&1)
    
    # Check if HTTP status code is 200
    if [ "$HTTP_CODE" -eq 200 ]; then
        RESPONSE=$(cat "$CURL_RESPONSE")
        CURL_SUCCESS=true
        log "Successfully connected to health check endpoint (HTTP 200)"
        rm "$CURL_RESPONSE"
    else
        log "Failed to connect to health check endpoint (HTTP code: $HTTP_CODE)"
        rm "$CURL_RESPONSE"
        RETRY_COUNT=$((RETRY_COUNT+1))
    fi
done

if [ "$CURL_SUCCESS" != "true" ]; then
    log "❌ Failed to connect to health check endpoint after $MAX_RETRIES attempts"
    log "Health check URL: $HEALTH_CHECK_URL"
    log "Last HTTP Status Code: $HTTP_CODE"
    log "Please verify the URL is correct and the service is running"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    log "❌ Error: jq is not installed. Please install jq to parse JSON responses."
    exit 1
fi

# Validate JSON structure
if ! echo "$RESPONSE" | jq -e . >/dev/null 2>&1; then
    log "❌ Error: Response is not a valid JSON"
    log "Response content (first 500 chars):"
    echo "$RESPONSE" | head -c 500
    exit 1
fi

# Extract the app version using jq
log "Extracting app version..."

# Try to parse the JSON and extract appVersion
ACTUAL_VERSION=$(echo "$RESPONSE" | jq -r '.appVersion // empty' 2>/dev/null)
JQ_EXIT_CODE=$?

# Check if jq command was successful
if [ $JQ_EXIT_CODE -ne 0 ]; then
    log "❌ Error: Failed to parse JSON response with jq (exit code: $JQ_EXIT_CODE)"
    log "Response content (first 500 chars):"
    echo "$RESPONSE" | head -c 500
    exit 1
fi

# Check if appVersion field exists and is not empty
if [ -z "$ACTUAL_VERSION" ]; then
    log "❌ Error: appVersion field is missing or empty in the response"
    log "Response content (first 500 chars):"
    echo "$RESPONSE" | head -c 500
    exit 1
fi

# Log the versions for debugging
log "Expected version: $EXPECTED_VERSION"
log "Actual version:   $ACTUAL_VERSION"

# Compare versions
if [ "$ACTUAL_VERSION" != "$EXPECTED_VERSION" ]; then
    log "❌ Version mismatch detected!"
    exit 1
else
    log "✅ Version verified successfully"
    exit 0
fi
