variable "cloudflare_api_token" {
  description = "Cloudflare API token with appropriate permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
}

variable "cloudflare_domain" {
  description = "Your Cloudflare domain (e.g., example.com)"
  type        = string
}

variable "keycloak_client_id" {
  description = "Keycloak OIDC client ID"
  type        = string
  sensitive   = true
}

variable "keycloak_client_secret" {
  description = "Keycloak OIDC client secret"
  type        = string
  sensitive   = true
}

variable "keycloak_issuer_url" {
  description = "Keycloak OIDC issuer URL (e.g., http://keycloak.sase-lab.local:8080/realms/sase-lab)"
  type        = string
}

variable "wazuh_endpoint" {
  description = "Wazuh server endpoint for log ingestion"
  type        = string
  default     = "wazuh-manager.sase-lab.local"
}

variable "enable_logpush" {
  description = "Enable Cloudflare logpush to Wazuh SIEM"
  type        = bool
  default     = false
}

variable "enable_keycloak_idp" {
  description = "Enable Keycloak OIDC IdP. Only set to true after cloudflared is running and keycloak.sase-lab.win is reachable."
  type        = bool
  default     = false
}
