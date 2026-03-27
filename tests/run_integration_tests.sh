#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE="docker compose -f ${PROJECT_DIR}/docker-compose.yml"

cleanup() {
    echo "==> Cleaning up..."
    $COMPOSE down -v --remove-orphans 2>/dev/null || true
}
trap cleanup EXIT

echo "==> Building salt-master image..."
$COMPOSE build salt-master

echo "==> Pulling salt-minion image..."
docker pull bbinet/salt-minion:buster_3003

echo "==> Starting services..."
$COMPOSE up -d

echo "==> Waiting for salt-master to be ready..."
RETRIES=60
for i in $(seq 1 $RETRIES); do
    if $COMPOSE exec -T salt-master salt-run manage.status 2>/dev/null | grep -q "up" 2>/dev/null; then
        break
    fi
    # Also check if salt-master process is running
    if $COMPOSE exec -T salt-master pgrep -f "salt-master" >/dev/null 2>&1; then
        if [ $i -ge 15 ]; then
            # After 15s, salt-master should be ready enough
            break
        fi
    fi
    echo "    Waiting for salt-master... ($i/$RETRIES)"
    sleep 2
done

echo "==> Waiting for salt-minion to connect..."
RETRIES=60
for i in $(seq 1 $RETRIES); do
    MINIONS=$($COMPOSE exec -T salt-master salt-key -l accepted --out=json 2>/dev/null || echo "{}")
    if echo "$MINIONS" | grep -q "salt-minion"; then
        echo "    Minion 'salt-minion' accepted!"
        break
    fi
    echo "    Waiting for minion to be accepted... ($i/$RETRIES)"
    sleep 3
done

# Give the minion a moment to fully connect after key acceptance
sleep 5

TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expect_pattern="$3"

    echo ""
    echo "=== TEST: $test_name ==="
    OUTPUT=$(eval "$test_cmd" 2>&1) || true
    echo "$OUTPUT"

    if echo "$OUTPUT" | grep -q "$expect_pattern"; then
        echo "--- PASS: $test_name ---"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "--- FAIL: $test_name ---"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 1: test.ping
run_test "test.ping" \
    "$COMPOSE exec -T salt-master salt '*' test.ping --out=json --timeout=30" \
    "true"

# Test 2: Check Freexian LTS repo is configured in the master
run_test "Freexian LTS repo present" \
    "$COMPOSE exec -T salt-master cat /etc/apt/sources.list" \
    "deb.freexian.com/extended-lts"

# Test 3: Reclass ext_pillar delivers pillar data
run_test "Reclass ext_pillar delivers motd_message" \
    "$COMPOSE exec -T salt-master salt 'salt-minion' pillar.get motd_message --out=json --timeout=30" \
    "Hello from Reclass ext_pillar"

# Test 4: state.highstate applies successfully
run_test "state.highstate succeeds" \
    "$COMPOSE exec -T salt-master salt '*' state.highstate --out=json --timeout=120" \
    "Succeeded"

# Test 5: Verify /etc/motd was created with reclass pillar content
run_test "motd file created with reclass pillar content" \
    "$COMPOSE exec -T salt-minion cat /etc/motd" \
    "Hello from Reclass ext_pillar"

echo ""
echo "==============================="
echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"
echo "==============================="

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi
