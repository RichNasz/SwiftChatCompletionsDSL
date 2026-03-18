#!/bin/bash
set -euo pipefail

echo "=== Phase 1: Running simulated tests ==="
swift test
echo ""
echo "=== Phase 1 passed: All simulated tests succeeded ==="
echo ""
echo "=== Phase 2: Running live endpoint tests ==="
LIVE_TEST=1 swift test --filter LiveEndpointTests
echo ""
echo "=== Phase 2 passed: All live endpoint tests succeeded ==="
