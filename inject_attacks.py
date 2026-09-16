#!/usr/bin/env python3
import json
import random
import subprocess
import sys
from datetime import datetime, timedelta

DOCKER_BIN = "/Applications/Docker.app/Contents/Resources/bin/docker"
INDEXER_CONTAINER = "sase-wazuh-indexer"
INDEXER_URL = "https://localhost:9200"
USER = "admin"
PASS = "admin"

now = datetime.utcnow()

ATTACKER_IPS = [
    "198.51.100.42", "203.0.113.88", "45.33.32.156", "185.220.101.5",
    "194.26.29.112", "91.240.118.172", "185.191.171.18", "45.146.164.110",
    "193.142.146.210", "141.98.10.35"
]

TARGET_HOSTS = ["hq-rtr", "branch-fw", "keycloak", "wiki-app", "remote-rtr", "hq-lan-sw"]
USERS = ["contractor-user1", "dev-alice", "root", "admin", "guest-user", "sales-bob"]

events = []

def generate_events():
    global events
    print("[+] Generating ~250 realistic security attack events...")

    # 1. SSH Brute Force Attack (70 events)
    for i in range(70):
        # Generate 20 events in the last 10 minutes for immediate visibility
        minutes_ago = random.randint(0, 10) if i < 20 else random.randint(1, 2880)
        ts = (now - timedelta(minutes=minutes_ago)).strftime("%Y-%m-%dT%H:%M:%S.000Z")
        src_ip = random.choice(ATTACKER_IPS[:4])
        user = random.choice(["root", "admin", "postgres", "ubuntu", "test"])
        events.append({
            "@timestamp": ts,
            "rule": {
                "level": random.choice([10, 11, 12]),
                "description": f"sshd: Brute force attack pattern detected (failed login for {user})",
                "id": "5712",
                "groups": ["syslog", "sshd", "authentication_failures", "attack"]
            },
            "agent": {"id": "001", "name": "hq-rtr"},
            "data": {
                "srcip": src_ip,
                "dstip": "10.10.0.1",
                "dstport": "22",
                "srcuser": user
            },
            "full_log": f"Failed password for {user} from {src_ip} port {random.randint(30000, 60000)} ssh2"
        })

    # 2. Suricata IDS / Nmap & Web Scans (50 events)
    scan_types = [
        ("ET SCAN Nmap SYN Scan Detected", "Network Scan", 10),
        ("ET WEB_SERVER SQL Injection Attempt - UNION SELECT", "Web Attack", 13),
        ("ET WEB_SERVER Cross Site Scripting (XSS) Pattern", "Web Attack", 11),
        ("ET SCAN Nikto Web Scanner User-Agent", "Reconnaissance", 12),
        ("ET WEB_SERVER DirBuster Brute Force Directory Enumeration", "Reconnaissance", 10)
    ]
    for i in range(50):
        ts = (now - timedelta(minutes=random.randint(1, 2880))).strftime("%Y-%m-%dT%H:%M:%S.000Z")
        sig, cat, lvl = random.choice(scan_types)
        src_ip = random.choice(ATTACKER_IPS)
        events.append({
            "@timestamp": ts,
            "rule": {
                "level": lvl,
                "description": f"Suricata IPS Alert: {sig}",
                "id": str(86600 + i),
                "groups": ["suricata", "ids", "pcap", cat.lower().replace(" ", "_")]
            },
            "agent": {"id": "002", "name": "branch-fw"},
            "data": {
                "srcip": src_ip,
                "dstip": "172.16.0.10",
                "alert": {
                    "signature": sig,
                    "category": cat,
                    "severity": 1 if lvl > 11 else 2
                }
            },
            "full_log": f"Suricata IPS blocked payload from {src_ip} -> 172.16.0.10:80 [{sig}]"
        })

    # 3. Privilege Escalation & Unauthorized Root Access (30 events)
    for i in range(30):
        ts = (now - timedelta(minutes=random.randint(1, 2880))).strftime("%Y-%m-%dT%H:%M:%S.000Z")
        user = random.choice(["contractor-user1", "dev-alice", "sales-bob"])
        events.append({
            "@timestamp": ts,
            "rule": {
                "level": random.choice([12, 14, 15]),
                "description": f"Privilege Escalation: Unauthorized root escalation attempt by {user}",
                "id": "5402",
                "groups": ["syslog", "sudo", "privilege_escalation", "critical"]
            },
            "agent": {"id": "001", "name": "hq-rtr"},
            "data": {
                "srcip": "10.10.0.50",
                "dstip": "10.10.0.1",
                "srcuser": user
            },
            "full_log": f"{user} : TTY=pts/{i} ; PWD=/tmp ; USER=root ; COMMAND=/bin/bash /tmp/exploit.sh"
        })

    # 4. Cloudflare Zero Trust (ZTNA) Access Denied (40 events)
    ztna_resources = ["engineering-wiki.sase-lab.win", "admin-console.sase-lab.win", "finance-vault.sase-lab.win"]
    for i in range(40):
        ts = (now - timedelta(minutes=random.randint(1, 2880))).strftime("%Y-%m-%dT%H:%M:%S.000Z")
        res = random.choice(ztna_resources)
        user = random.choice(USERS)
        src_ip = random.choice(ATTACKER_IPS)
        events.append({
            "@timestamp": ts,
            "rule": {
                "level": random.choice([8, 9, 10]),
                "description": f"Cloudflare ZTNA: Access Denied to {res} for user {user}",
                "id": "99100",
                "groups": ["cloudflare", "ztna", "access_control", "policy_denial"]
            },
            "agent": {"id": "003", "name": "cloudflare-tunnel"},
            "data": {
                "action": "blocked",
                "srcip": src_ip,
                "user": user,
                "resource": res,
                "reason": "Identity context violation (untrusted Geo-IP / Device posture fail)"
            },
            "full_log": f"ZTNA DENY: {user} from {src_ip} blocked accessing {res} (policy violation)"
        })

    # 5. Ransomware & Malware File Integrity Detections (20 events)
    malware_files = [
        ("/tmp/mimikatz.exe", "92f7ef5c3a2b0f01ef8e7afe8c26e64a", "Mimikatz Password Dumper"),
        ("/var/tmp/wannacry.bin", "84c82835a5d21bbcf5d6a61c68d0556e", "WannaCry Ransomware Drop"),
        ("/tmp/c2_beacon.py", "e4da3b7fbbce2345d7772b0674a318d5", "Reverse Shell C2 Agent"),
        ("/etc/shadow.bak", "4152ef3a72661ab20908811234900111", "Exfiltrated Password Hash Store")
    ]
    for i in range(20):
        ts = (now - timedelta(minutes=random.randint(1, 2880))).strftime("%Y-%m-%dT%H:%M:%S.000Z")
        path, md5, desc = random.choice(malware_files)
        events.append({
            "@timestamp": ts,
            "rule": {
                "level": 15,
                "description": f"FIM Critical Alert: Known Malware Signature ({desc})",
                "id": "550",
                "groups": ["ossec", "fim", "malware", "ransomware"]
            },
            "agent": {"id": "001", "name": "hq-rtr"},
            "data": {
                "srcip": "10.10.0.50",
                "file": path,
                "md5": md5
            },
            "full_log": f"File Integrity Monitoring ALERT: {path} (MD5={md5}) matches critical signature [{desc}]"
        })

    # 6. Keycloak Authentication Anomalies & MFA Bypass (25 events)
    for i in range(25):
        ts = (now - timedelta(minutes=random.randint(1, 2880))).strftime("%Y-%m-%dT%H:%M:%S.000Z")
        user = random.choice(USERS)
        src_ip = random.choice(ATTACKER_IPS)
        events.append({
            "@timestamp": ts,
            "rule": {
                "level": random.choice([9, 11, 13]),
                "description": f"Keycloak Security Event: Credential stuffing & Impossible Travel for {user}",
                "id": "98101",
                "groups": ["keycloak", "identity", "authentication", "impossible_travel"]
            },
            "agent": {"id": "004", "name": "keycloak"},
            "data": {
                "srcip": src_ip,
                "user": user,
                "event_type": "LOGIN_ERROR",
                "error": "invalid_user_credentials"
            },
            "full_log": f"Keycloak IAM Alert: Multiple failed authentication attempts for {user} from {src_ip}"
        })

    # 7. BGP Route Hijack & Anomaly Alerts (15 events)
    for i in range(15):
        ts = (now - timedelta(minutes=random.randint(1, 2880))).strftime("%Y-%m-%dT%H:%M:%S.000Z")
        events.append({
            "@timestamp": ts,
            "rule": {
                "level": 13,
                "description": "BGP Anomaly: Unauthorized AS path prefix advertisement detected (AS65099)",
                "id": "97001",
                "groups": ["network", "bgp", "routing_anomaly", "hijack"]
            },
            "agent": {"id": "001", "name": "hq-rtr"},
            "data": {
                "srcip": "198.51.100.99",
                "asn": "65099",
                "prefix": "10.1.0.0/24"
            },
            "full_log": "BGP Daemon Alert: Prefix 10.1.0.0/24 advertised by unauthorized peer AS65099"
        })

def setup_index_template():
    print("[+] Deleting old mismatched indices to clean mapping conflicts...")
    subprocess.run([
        DOCKER_BIN, "exec", INDEXER_CONTAINER,
        "curl", "-sk", "-u", f"{USER}:{PASS}", "-X", "DELETE", f"{INDEXER_URL}/wazuh-alerts-*"
    ], stdout=subprocess.DEVNULL)

    print("[+] Creating unified index template for wazuh-alerts-*...")
    template = {
      "index_patterns": ["wazuh-alerts-*"],
      "template": {
        "mappings": {
          "properties": {
            "@timestamp":        { "type": "date" },
            "rule.level":        { "type": "integer" },
            "rule.description":  { "type": "keyword" },
            "rule.groups":       { "type": "keyword" },
            "rule.id":           { "type": "keyword" },
            "agent.name":        { "type": "keyword" },
            "agent.id":          { "type": "keyword" },
            "data.srcip":        { "type": "keyword" },
            "data.dstip":        { "type": "keyword" },
            "data.srcuser":      { "type": "keyword" },
            "data.user":         { "type": "keyword" },
            "data.file":         { "type": "keyword" },
            "data.md5":          { "type": "keyword" },
            "full_log":          { "type": "text" }
          }
        }
      }
    }
    cmd = [
        DOCKER_BIN, "exec", "-i", INDEXER_CONTAINER,
        "curl", "-sk", "-u", f"{USER}:{PASS}", "-X", "PUT",
        f"{INDEXER_URL}/_index_template/wazuh_alerts_template",
        "-H", "Content-Type: application/json",
        "-d", json.dumps(template)
    ]
    subprocess.run(cmd, stdout=subprocess.DEVNULL)

def inject_to_indexer():
    print(f"[+] Injecting {len(events)} clean events into Wazuh Indexer...")
    bulk_data = ""
    for ev in events:
        ts_date = ev["@timestamp"].split("T")[0].replace("-", ".")
        index_name = f"wazuh-alerts-4.x-{ts_date}"
        bulk_data += json.dumps({"index": {"_index": index_name}}) + "\n"
        bulk_data += json.dumps(ev) + "\n"

    cmd = [
        DOCKER_BIN, "exec", "-i", INDEXER_CONTAINER,
        "curl", "-sk", "-u", f"{USER}:{PASS}", "-X", "POST",
        f"{INDEXER_URL}/_bulk",
        "-H", "Content-Type: application/x-ndjson",
        "--data-binary", "@-"
    ]

    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = proc.communicate(input=bulk_data.encode("utf-8"))

    if proc.returncode != 0:
        print(f"[-] Failed to inject events: {stderr.decode()}")
        sys.exit(1)

    print("[+] Injected all events cleanly!")
    subprocess.run([
        DOCKER_BIN, "exec", INDEXER_CONTAINER,
        "curl", "-sk", "-u", f"{USER}:{PASS}", "-X", "POST", f"{INDEXER_URL}/wazuh-alerts-*/_refresh"
    ], stdout=subprocess.DEVNULL)

if __name__ == "__main__":
    generate_events()
    setup_index_template()
    inject_to_indexer()
