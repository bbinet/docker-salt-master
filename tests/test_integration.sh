#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$SCRIPT_DIR"

COMPOSE="docker compose -f docker-compose.test.yml"

cleanup() {
    echo "=> Cleaning up..."
    $COMPOSE down -v --remove-orphans 2>/dev/null || true
}
trap cleanup EXIT

echo "=> Building salt-master image..."
docker build -t bbinet/salt-master:test "$PROJECT_DIR"

echo "=> Building salt-minion image..."
docker build -f "$SCRIPT_DIR/Dockerfile.minion" -t bbinet/salt-minion:test "$SCRIPT_DIR"

echo "=> Starting salt-master..."
$COMPOSE up -d salt-master

echo "=> Waiting for salt-master to be ready..."
for i in $(seq 1 30); do
    if docker exec salt-master-test salt-run manage.status 2>/dev/null; then
        break
    fi
    echo "   Waiting... ($i/30)"
    sleep 2
done

echo "=> Starting salt-minion..."
$COMPOSE up -d salt-minion

echo "=> Waiting for minion to connect and key to be accepted..."
MINION_READY=false
for i in $(seq 1 30); do
    ACCEPTED=$(docker exec salt-master-test salt-run manage.up 2>/dev/null || true)
    if echo "$ACCEPTED" | grep -q "test-minion"; then
        MINION_READY=true
        echo "   Minion connected!"
        break
    fi
    echo "   Waiting for minion... ($i/30)"
    sleep 2
done

if [ "$MINION_READY" != "true" ]; then
    echo "=> FAIL: Minion did not connect within timeout"
    echo "=> Master logs:"
    docker logs salt-master-test 2>&1 | tail -20
    echo "=> Minion logs:"
    docker logs salt-minion-test 2>&1 | tail -20
    exit 1
fi

echo "=> Running test.ping..."
RESULT=$(docker exec salt-master-test salt 'test-minion' test.ping --timeout=30 --output=json 2>/dev/null)
echo "   Result: $RESULT"

if echo "$RESULT" | grep -q '"test-minion": true'; then
    echo "=> SUCCESS: test.ping returned True"
    exit 0
else
    echo "=> FAIL: test.ping did not return expected result"
    echo "=> Master logs:"
    docker logs salt-master-test 2>&1 | tail -20
    echo "=> Minion logs:"
    docker logs salt-minion-test 2>&1 | tail -20
    exit 1
fi
