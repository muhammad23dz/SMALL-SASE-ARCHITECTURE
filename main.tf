terraform {
  required_version = ">= 1.5.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "random_id" "tunnel_secret" {
  byte_length = 32
}

# Zero Trust Tunnel for internal applications
resource "cloudflare_zero_trust_tunnel_cloudflared" "internal_apps" {
  account_id = var.cloudflare_account_id
  name       = "sase-internal-apps-tunnel"
  secret     = base64encode(random_id.tunnel_secret.hex)
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "internal_apps_config" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.internal_apps.id

  config {
    ingress_rule {
      hostname = "wiki.${var.cloudflare_domain}"
      service  = "http://10.1.0.10:80"
    }

    ingress_rule {
      hostname = "grafana.${var.cloudflare_domain}"
      service  = "http://10.1.0.11:3000"
    }

    ingress_rule {
      hostname = "keycloak.${var.cloudflare_domain}"
      service  = "http://keycloak.sase-lab.local:8080"
    }

    ingress_rule {
      hostname = "topology.${var.cloudflare_domain}"
      service  = "http://sase-topology-server:50080"
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

# Zero Trust Identity Provider Configuration
resource "cloudflare_zero_trust_access_identity_provider" "keycloak" {
  account_id = var.cloudflare_account_id
  name       = "Keycloak"
  type       = "oidc"
  config {
    client_id     = var.keycloak_client_id
    client_secret = var.keycloak_client_secret
    issuer_url    = var.keycloak_issuer_url
    pkce_enabled  = true
  }
}

# Zero Trust Access Application for Topology Architecture Console
resource "cloudflare_zero_trust_access_application" "topology_app" {
  account_id       = var.cloudflare_account_id
  name             = "SASE Architecture Console"
  domain           = "topology.${var.cloudflare_domain}"
  type             = "self_hosted"
  session_duration = "12h"
}

resource "cloudflare_zero_trust_access_policy" "topology_app_policy" {
  account_id     = var.cloudflare_account_id
  application_id = cloudflare_zero_trust_access_application.topology_app.id
  name           = "Allow Authenticated"
  precedence     = 1
  decision       = "allow"
  include {
    email_domain = ["example.com", "sase-lab.local"]
  }
}

# Zero Trust Access Application for Wiki
resource "cloudflare_zero_trust_access_application" "wiki_app" {
  account_id       = var.cloudflare_account_id
  name             = "Internal Wiki"
  domain           = "wiki.${var.cloudflare_domain}"
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_policy" "wiki_app_policy" {
  account_id     = var.cloudflare_account_id
  application_id = cloudflare_zero_trust_access_application.wiki_app.id
  name           = "Allow Authenticated"
  precedence     = 1
  decision       = "allow"
  include {
    email_domain = ["example.com", "sase-lab.local"]
  }
}

# Zero Trust Access Application for Grafana
resource "cloudflare_zero_trust_access_application" "grafana_app" {
  account_id       = var.cloudflare_account_id
  name             = "Grafana Dashboard"
  domain           = "grafana.${var.cloudflare_domain}"
  type             = "self_hosted"
  session_duration = "8h"
}

resource "cloudflare_zero_trust_access_policy" "grafana_app_policy" {
  account_id     = var.cloudflare_account_id
  application_id = cloudflare_zero_trust_access_application.grafana_app.id
  name           = "Allow Authenticated"
  precedence     = 1
  decision       = "allow"
  include {
    email_domain = ["example.com", "sase-lab.local"]
  }
}

# Gateway Lists for policy enforcement
resource "cloudflare_zero_trust_list" "malicious_domains" {
  account_id = var.cloudflare_account_id
  name       = "Malicious Domains"
  type       = "DOMAIN"
  items = [
    "malware-site.com",
    "phishing-attempt.net",
    "suspicious-domain.org"
  ]
}

resource "cloudflare_zero_trust_list" "genai_domains" {
  account_id = var.cloudflare_account_id
  name       = "GenAI Domains"
  type       = "DOMAIN"
  items = [
    "api.openai.com",
    "chatgpt.com",
    "claude.ai",
    "anthropic.com",
    "google.ai"
  ]
}

resource "cloudflare_zero_trust_list" "saas_dlp_list" {
  account_id = var.cloudflare_account_id
  name       = "SaaS DLP List"
  type       = "DOMAIN"
  items = [
    "personal-drive.example.com",
    "file-sharing-site.net"
  ]
}

# Secure Web Gateway - DNS Filtering
resource "cloudflare_zero_trust_gateway_policy" "dns_filtering" {
  account_id  = var.cloudflare_account_id
  name        = "DNS Security Filtering"
  description = "Block malicious domains and adult content"
  precedence  = 1
  action      = "block"
  traffic     = format("any(dns.domains[*] in $%s)", cloudflare_zero_trust_list.malicious_domains.id)
}

# CASB - SaaS Application Controls
resource "cloudflare_zero_trust_gateway_policy" "saas_dlp" {
  account_id  = var.cloudflare_account_id
  name        = "SaaS DLP Controls"
  description = "Prevent data exfiltration to SaaS applications"
  precedence  = 2
  action      = "block"
  traffic     = format("http.request.host in $%s", cloudflare_zero_trust_list.saas_dlp_list.id)
}

# GenAI Controls - HTTP Gateway Policies
resource "cloudflare_zero_trust_gateway_policy" "genai_monitoring" {
  account_id  = var.cloudflare_account_id
  name        = "GenAI Traffic Monitoring"
  description = "Log and monitor GenAI application traffic"
  precedence  = 3
  action      = "allow"
  traffic     = format("http.request.host in $%s", cloudflare_zero_trust_list.genai_domains.id)
}

# Logpush configuration for SIEM integration
resource "cloudflare_logpush_job" "access_logs" {
  count              = var.enable_logpush ? 1 : 0
  account_id         = var.cloudflare_account_id
  name               = "Zero-Trust-Access-Logs"
  enabled            = var.enable_logpush
  logpull_options    = "fields=Event,Timestamp,Action,RuleID,UserEmail,UserIP,ApplicationID,ApplicationName"
  destination_conf   = "http://${var.wazuh_endpoint}:55000/api/v1/events"
  dataset            = "access_requests"
  max_upload_interval_seconds = 30
  filter = <<EOF
  Event eq "access_requests"
  EOF
}

resource "cloudflare_logpush_job" "gateway_logs" {
  count              = var.enable_logpush ? 1 : 0
  account_id         = var.cloudflare_account_id
  name               = "Zero-Trust-Gateway-Logs"
  enabled            = var.enable_logpush
  logpull_options    = "fields=Event,Timestamp,Action,RuleID,UserEmail,UserIP,HTTPHost,HTTPMethod,HTTPPath"
  destination_conf   = "http://${var.wazuh_endpoint}:55000/api/v1/events"
  dataset            = "gateway_dns"
  max_upload_interval_seconds = 30
  filter = <<EOF
  Event eq "gateway_dns"
  EOF
}
