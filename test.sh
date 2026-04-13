#!/usr/bin/env bash
# Warms both Kong instances with a few proxy requests, then counts the
# rate-limiting-advanced sync debug lines each container emitted in
# the sampling window.
set -euo pipefail

DUR="${1:-15}"

echo "warming up RLA on both instances..."
for port in 8000 8010; do
    for _ in $(seq 1 5); do
        curl -s -o /dev/null -H 'Host: httpbin.konghq.com' "http://localhost:${port}/anything" || true
    done
done

echo "sampling logs for ${DUR}s..."
sleep "${DUR}"

count() {
    docker logs --since "${DUR}s" "$1" 2>&1 \
        | grep -cE '\[rate-limiting-advanced\] (start sync|empty sync, do fetch|end sync)' \
        || true
}

baseline=$(count kong-baseline)
filtered=$(count kong-filtered)

echo
echo "=== RLA sync debug lines in last ${DUR}s ==="
printf "  baseline (no custom template): %s\n" "$baseline"
printf "  filtered (Option B template):  %s\n" "$filtered"
echo
echo "(baseline should be nonzero; filtered should be 0)"
