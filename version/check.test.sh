#!/bin/bash
set -e

# Change to the script's directory so all paths are relative to it.
cd "$(dirname "$0")"

# --- Test Configuration ---
TEST_PORT=8080
URL="http://localhost:$TEST_PORT"
SERVER_PID=""
PASSED_COUNT=0
FAILED_COUNT=0

# --- Mock HTTP Responses ---
RESPONSE_GOOD_VERSION="HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"appVersion\": \"1.2.3\"}"
RESPONSE_WRONG_VERSION="HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"appVersion\": \"9.9.9\"}"
RESPONSE_MISSING_FIELD="HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"otherField\": \"1.2.3\"}"
RESPONSE_BAD_JSON="HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{this is not json"
RESPONSE_UNAUTHORIZED="HTTP/1.1 401 Unauthorized\r\n\r\nUnauthorized"
RESPONSE_SERVER_ERROR="HTTP/1.1 500 Internal Server Error\r\n\r\nError"


# --- Mock Server Functions ---
start_mock_server() {
    local response="$1"
    local nc_flags="-l"

    # GNU netcat supports -q flag to prevent hangs in CI
    nc -h 2>&1 | grep -q -- '-q' && nc_flags="-l -q 1"

    (echo -e "$response" | nc $nc_flags $TEST_PORT >/dev/null) &
    SERVER_PID=$!

    # Wait for server to be ready (max 2 seconds)
    for i in {1..20}; do
        lsof -iTCP:$TEST_PORT -sTCP:LISTEN -t >/dev/null 2>&1 && return
        sleep 0.1
    done

    echo "Error: Mock server failed to start on port $TEST_PORT." >&2
    stop_mock_server
    exit 1
}

stop_mock_server() {
    if [ -n "$SERVER_PID" ]; then
        kill $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
    fi
    SERVER_PID=""
}

# --- Test Runner Function ---
run_test() {
    local expected_code="$1"
    local description="$2"
    shift 2
    local actual_code=0

    echo -n "Test: $description... "

    # Speed up tests by reducing sleep duration
    sed 's/sleep 5/sleep 0.1/g' ./check.sh | bash -s -- "$@" >/dev/null 2>&1 || actual_code=$?

    if [ $actual_code -eq "$expected_code" ]; then
        echo -e "\033[32mPASS\033[0m"
        PASSED_COUNT=$((PASSED_COUNT + 1))
    else
        echo -e "\033[31mFAIL\033[0m (Expected $expected_code, got $actual_code)"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
}


# --- Cleanup ---
cleanup() {
    stop_mock_server
    echo "---"
    echo -e "Test Summary: \033[32m$PASSED_COUNT Passed\033[0m | \033[31m$FAILED_COUNT Failed\033[0m"
    if [ $FAILED_COUNT -ne 0 ]; then
        exit 1
    fi
    exit 0
}

trap cleanup EXIT

# --- Test Execution ---
echo "Running Version Check Tests..."
echo "---"

# Success cases
start_mock_server "$RESPONSE_GOOD_VERSION"
run_test 0 "Success: Correct version (no auth)" "1.2.3" "$URL"
stop_mock_server

start_mock_server "$RESPONSE_GOOD_VERSION"
run_test 0 "Success: Correct version (with auth)" "1.2.3" "$URL" "user" "pass"
stop_mock_server

# Failure cases: Server Responses
start_mock_server "$RESPONSE_WRONG_VERSION"
run_test 1 "Fail: Incorrect version (no auth)" "1.2.3" "$URL"
stop_mock_server

start_mock_server "$RESPONSE_WRONG_VERSION"
run_test 1 "Fail: Incorrect version (with auth)" "1.2.3" "$URL" "user" "pass"
stop_mock_server

start_mock_server "$RESPONSE_UNAUTHORIZED"
run_test 1 "Fail: Auth required, none provided (HTTP 401)" "1.2.3" "$URL"
stop_mock_server

start_mock_server "$RESPONSE_SERVER_ERROR"
run_test 1 "Fail: Server error (HTTP 500)" "1.2.3" "$URL"
stop_mock_server

# Failure case: Connection
stop_mock_server
run_test 1 "Fail: Connection refused (no server running)" "1.2.3" "$URL"

# Failure cases: JSON content
start_mock_server "$RESPONSE_BAD_JSON"
run_test 1 "Fail: Response is not valid JSON" "1.2.3" "$URL"
stop_mock_server

start_mock_server "$RESPONSE_MISSING_FIELD"
run_test 1 "Fail: JSON response missing 'appVersion' field" "1.2.3" "$URL"
stop_mock_server

# Failure cases: Argument Validation
echo "---"
echo "Running Argument Validation Tests..."
run_test 1 "Fail: No arguments"
run_test 1 "Fail: One argument" "1.2.3"
run_test 1 "Fail: Three arguments" "1.2.3" "$URL" "user"
run_test 1 "Fail: Five arguments" "1.2.3" "$URL" "user" "pass" "extra"
run_test 1 "Fail: Empty version string" "" "$URL"
run_test 1 "Fail: Empty URL" "1.2.3" ""
run_test 1 "Fail: Empty username" "1.2.3" "$URL" "" "pass"
run_test 1 "Fail: Empty password" "1.2.3" "$URL" "user" ""
