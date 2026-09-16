#!/usr/bin/env bash
# ============================================================
# SASE Lab — Attack Simulation Script
# Injects realistic security events into Wazuh Indexer so
# they appear on the Grafana dashboard immediately.
# Usage: ./simulate-attack.sh
# ============================================================
set -euo pipefail

DOCKER="/Applications/Docker.app/Contents/Resources/bin/docker"
INDEXER_CONTAINER="sase-wazuh-indexer"
INDEXER_URL="https://localhost:9200"
INDEX="wazuh-alerts-4.x-$(date +%Y.%m.%d)"
USER="admin"
PASS="admin"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

info()  { echo -e "\033[1;34m[+]\033[0m $*"; }
ok()    { echo -e "\033[1;32m[✓]\033[0m $*"; }
die()   { echo -e "\033[1;31m[✗]\033[0m $*"; exit 1; }

# ── verify indexer is up ─────────────────────────────────────
info "Checking Wazuh Indexer connectivity..."
$DOCKER exec "$INDEXER_CONTAINER" \
  curl -sk -u "$USER:$PASS" "$INDEXER_URL/_cluster/health" \
  | grep -q '"status"' || die "Wazuh Indexer not reachable. Run start-all.sh first."
ok "Indexer is up."

# ── create index if needed ───────────────────────────────────
info "Ensuring index $INDEX exists..."
$DOCKER exec "$INDEXER_CONTAINER" \
  curl -sk -u "$USER:$PASS" -X PUT "$INDEXER_URL/$INDEX" \
  -H 'Content-Type: application/json' \
  -d '{
    "settings": { "number_of_shards": 1, "number_of_replicas": 0 },
    "mappings": {
      "properties": {
        "@timestamp":        { "type": "date" },
        "rule.level":        { "type": "integer" },
        "rule.description":  { "type": "keyword" },
        "rule.groups":       { "type": "keyword" },
        "agent.name":        { "type": "keyword" },
        "data.srcip":        { "type": "ip" },
        "data.dstip":        { "type": "ip" },
        "full_log":          { "type": "text" }
      }
    }
  }' > /dev/null 2>&1 || true
ok "Index ready."

# ── helper: inject event ─────────────────────────────────────
inject() {
  local doc="$1"
  $DOCKER exec "$INDEXER_CONTAINER" \
    curl -sk -u "$USER:$PASS" -X POST \
    "$INDEXER_URL/$INDEX/_doc" \
    -H 'Content-Type: application/json' \
    -d "$doc" > /dev/null
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "Injecting Attack Scenario: SSH Brute Force + Port Scan + Privilege Escalation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Scenario 1: SSH Brute Force (10 failed logins) ──────────
info "Scenario 1 — SSH Brute Force Attack from 198.51.100.42"
for i in $(seq 1 10); do
  TS=$(date -u -v -${i}m +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -d "-${i} minutes" +"%Y-%m-%dT%H:%M:%S.000Z")
  inject "{
    \"@timestamp\": \"$TS\",
    \"rule\": {
      \"level\": 10,
      \"description\": \"sshd: brute force attack (multiple failed logins)\",
      \"id\": \"5712\",
      \"groups\": [\"syslog\", \"sshd\", \"authentication_failures\"]
    },
    \"agent\": { \"id\": \"001\", \"name\": \"hq-router\" },
    \"data\": {
      \"srcip\": \"198.51.100.42\",
      \"dstip\": \"10.10.0.1\",
      \"dstport\": \"22\"
    },
    \"full_log\": \"Failed password for root from 198.51.100.42 port 4${i}210 ssh2\"
  }"
done
ok "SSH brute force events injected (rule level 10)"

# ── Scenario 2: Port Scan Detected (Suricata) ───────────────
info "Scenario 2 — Port Scan by Suricata IPS"
for i in $(seq 1 5); do
  TS=$(date -u -v -$((i+12))m +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -d "-$((i+12)) minutes" +"%Y-%m-%dT%H:%M:%S.000Z")
  inject "{
    \"@timestamp\": \"$TS\",
    \"rule\": {
      \"level\": 12,
      \"description\": \"Suricata: ET SCAN Nmap SYN Scan Detected\",
      \"id\": \"86601\",
      \"groups\": [\"suricata\", \"ids\", \"recon\"]
    },
    \"agent\": { \"id\": \"002\", \"name\": \"branch-fw\" },
    \"data\": {
      \"srcip\": \"203.0.113.77\",
      \"dstip\": \"172.16.0.0\",
      \"alert\": {
        \"signature\": \"ET SCAN Nmap SYN Scan\",
        \"category\": \"Network Scan\",
        \"severity\": 1
      }
    },
    \"full_log\": \"Suricata IPS blocked port scan from 203.0.113.77 → 172.16.0.0/24\"
  }"
done
ok "Suricata port scan alerts injected (rule level 12)"

# ── Scenario 3: Privilege Escalation ────────────────────────
info "Scenario 3 — Privilege Escalation (sudo su)"
TS=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
inject "{
  \"@timestamp\": \"$TS\",
  \"rule\": {
    \"level\": 14,
    \"description\": \"Privilege escalation: user ran sudo to become root\",
    \"id\": \"5402\",
    \"groups\": [\"syslog\", \"sudo\", \"privilege_escalation\"]
  },
  \"agent\": { \"id\": \"001\", \"name\": \"hq-router\" },
  \"data\": {
    \"srcip\": \"10.10.0.50\",
    \"dstip\": \"10.10.0.1\"
  },
  \"full_log\": \"contractor-user1 : TTY=pts/0 ; PWD=/home/contractor-user1 ; USER=root ; COMMAND=/bin/bash\"
}"
ok "Privilege escalation event injected (rule level 14 — CRITICAL)"

# ── Scenario 4: ZTNA Policy Block ───────────────────────────
info "Scenario 4 — Cloudflare ZTNA Access Denied"
for i in 1 2 3; do
  TS=$(date -u -v -$((i+20))m +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -d "-$((i+20)) minutes" +"%Y-%m-%dT%H:%M:%S.000Z")
  inject "{
    \"@timestamp\": \"$TS\",
    \"rule\": {
      \"level\": 8,
      \"description\": \"Cloudflare ZTNA: access denied — identity policy violation\",
      \"id\": \"99100\",
      \"groups\": [\"cloudflare\", \"ztna\", \"access_denied\"]
    },
    \"agent\": { \"id\": \"003\", \"name\": \"cloudflare-tunnel\" },
    \"data\": {
      \"action\": \"blocked\",
      \"srcip\": \"198.51.100.99\",
      \"user\": \"contractor-user1\",
      \"resource\": \"engineering-wiki.sase-lab.win\"
    },
    \"full_log\": \"ZTNA DENY: contractor-user1 attempted access to engineering-wiki — policy: engineering-only\"
  }"
done
ok "ZTNA access denied events injected (rule level 8)"

# ── Scenario 5: Malware Hash Detection ──────────────────────
info "Scenario 5 — Malware File Detected (FIM)"
TS=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
inject "{
  \"@timestamp\": \"$TS\",
  \"rule\": {
    \"level\": 15,
    \"description\": \"File integrity: malicious file detected — known malware hash (Mimikatz)\",
    \"id\": \"550\",
    \"groups\": [\"ossec\", \"fim\", \"malware\"]
  },
  \"agent\": { \"id\": \"001\", \"name\": \"hq-router\" },
  \"data\": {
    \"srcip\": \"10.10.0.50\",
    \"file\": \"/tmp/mimikatz.exe\",
    \"md5\": \"92f7ef5c3a2b0f01ef8e7afe8c26e64a\"
  },
  \"full_log\": \"FIM ALERT: New file /tmp/mimikatz.exe MD5=92f7ef5c3a2b0f01ef8e7afe8c26e64a matches known malware signature\"
}"
ok "Malware detection event injected (rule level 15 — MAXIMUM)"

# ── Refresh index ────────────────────────────────────────────
$DOCKER exec "$INDEXER_CONTAINER" \
  curl -sk -u "$USER:$PASS" -X POST \
  "$INDEXER_URL/$INDEX/_refresh" > /dev/null

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "ALL DONE — 5 attack scenarios injected into Wazuh!"
echo ""
echo "  📊 Open Grafana:          http://localhost:3000"
echo "     Login: admin / $(grep GRAFANA_ADMIN_PASSWORD "$(dirname "$0")/docker/wazuh/.env" 2>/dev/null | cut -d= -f2 || echo 'check .env')"
echo ""
echo "  🔍 Open Wazuh Dashboard:  https://localhost:5601"
echo "     Login: admin / admin"
echo ""
echo "  Scenarios injected:"
echo "  • Level 10 — SSH Brute Force (×10 events from 198.51.100.42)"
echo "  • Level 12 — Suricata Port Scan / Nmap (×5 events)"
echo "  • Level 14 — Privilege Escalation: contractor → root"
echo "  • Level  8 — Cloudflare ZTNA Blocks (×3 events)"
echo "  • Level 15 — Mimikatz Malware Hash Detected"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
