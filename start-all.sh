#!/usr/bin/env bash
# ============================================================
# SASE Lab - One-shot startup script
# Usage: ./start-all.sh
# ============================================================
set -euo pipefail

DOCKER="$(which docker 2>/dev/null || echo '/Applications/Docker.app/Contents/Resources/bin/docker')"
COMPOSE="$DOCKER compose"
ROOT="$(cd "$(dirname "$0")" && pwd)"

info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()    { echo -e "\033[1;32m[ OK ]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
die()   { echo -e "\033[1;31m[FAIL]\033[0m  $*"; exit 1; }

# ── sanity checks ────────────────────────────────────────────
info "Checking Docker..."
$DOCKER info &>/dev/null || die "Docker is not running. Start Docker Desktop first."
ok "Docker is running."

# ── Step 1: Wazuh / Grafana / Loki / Promtail ────────────────
info "Starting Wazuh stack (indexer → manager → dashboard + Grafana + Loki)..."
cd "$ROOT/docker/wazuh"
$COMPOSE build --quiet
$COMPOSE up -d

info "Waiting 60s for Wazuh indexer to start up..."
sleep 60

# ── Initialize OpenSearch Security (required on fresh volumes) ─
info "Initializing OpenSearch Security plugin..."
$DOCKER exec -e JAVA_HOME=/usr/share/wazuh-indexer/jdk sase-wazuh-indexer \
  bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh \
    -cd /usr/share/wazuh-indexer/opensearch-security/ \
    -icl -nhnv \
    -cacert /usr/share/wazuh-indexer/certs/root-ca.pem \
    -cert   /usr/share/wazuh-indexer/certs/admin.pem \
    -key    /usr/share/wazuh-indexer/certs/admin-key.pem \
    -p 9200 2>&1 | tail -5
ok "Security initialized."

# ── Step 2: Keycloak ─────────────────────────────────────────
info "Starting Keycloak + PostgreSQL..."
cd "$ROOT/docker/keycloak"
$COMPOSE build --quiet
$COMPOSE up -d

# ── Step 3: Show status ──────────────────────────────────────
info "Waiting 15s for services to settle..."
sleep 15

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SASE Lab — Service Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
$DOCKER ps --format "table {{.Names}}\t{{.Status}}" | grep -E "sase|NAME" || true
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Access URLs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Wazuh Dashboard  → https://localhost:5601  (admin / admin)"
echo "  Grafana          → http://localhost:3000   (admin / see .env)"
echo "  Keycloak Admin   → http://localhost:8080   (admin / see .env)"
echo "  Wazuh API        → https://localhost:55000 (wazuh-wui / WazuhApi123!)"
echo "  Loki             → http://localhost:3100"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "All services started. Give Wazuh ~2-3 minutes to fully boot."
